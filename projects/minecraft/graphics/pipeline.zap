# How a frame of the world is drawn, pass by pass, on the GPU:
#   0. the sky view: the light the air scatters in every direction, into a small texture, when
#      the sun has moved (shaders/atmosphere.gpu.zap); the sky, the haze and the reflections read it
#   1. the shadow maps: the solid chunks near the player seen from the sun (or the moon) where it
#      stood at the last whole step of its course and where it will stand at the next, blended
#      between: each map holds still, so no shadow's edge crawls from texel to texel; a map is
#      drawn again only when the sun steps on, the player moves to another part of it, or a
#      block changes
#   2. the scene, in a half float target: the sky, the solid chunks the camera sees lit and
#      shadowed, the outline of the block aimed at, then the water over them
#   3. bloom: the bright parts at half size, blurred across and up
#   4. the picture: the scene and its bloom mapped to colors on the screen's scale, then its
#      edges smoothed onto the screen
# The game's 2D (the crosshair, the hotbar) is drawn over it after. Nothing is allocated per
# frame: the lists of chunks are kept and refilled.

import engine
import graphics.shaders
import math

shadowSize = 2048
shadowReach f32 = 72.0   # the shadow map covers this far around the player, each way
# The map's box moves in steps of 128 of its texels: whole texels, so the shadows keep still,
# and long ones, so walking does not draw the map again every frame.
shadowSnap f32 = 9.0
dayLength f32 = 600.0   # seconds from one dawn to the next
sunSteps f32 = 600.0   # the steps of the sun's course a shadow map is drawn for
viewDistance f32 = 170.0   # the fog hides the land beyond

# a shadow map and what it was drawn for
type ShadowMap:
	target engine.RenderTarget
	step f32   # the step of the sun's course (-1: not drawn yet)
	center Vec3   # the box's center in the light's space, snapped
	edits i64   # the world's edits it shows
	matrix Mat4

pub type Pipeline:
	world engine.Program   # the programs
	shadow engine.Program
	skyView engine.ScreenPass
	sky engine.ScreenPass
	final engine.ScreenPass   # the picture made of the scene and its bloom
	skyTarget engine.RenderTarget
	skyTime f32   # the time of day the sky view was drawn for (-1: never)
	shadowA ShadowMap   # the sun at the last whole step
	shadowB ShadowMap   # at the next
	scene engine.RenderTarget
	post engine.Post   # the bloom, the picture before its edges are smoothed
	width i64
	height i64
	near i64[]   # the chunks that cast shadows, refilled each frame
	seen i64[]   # the chunks in view

# The chunks' shape: `size` blocks across, `height` high.
pub type Grid:
	size i64
	height i64

# a chunk to draw: its meshes and the corner it is drawn from
pub type ChunkDraw:
	solid engine.Mesh
	water engine.Mesh
	origin Vec3

# the textures of the blocks' faces: their colors, their surfaces (normal, roughness, occlusion)
pub type Materials:
	colors engine.GpuTextureArray
	surfaces engine.GpuTextureArray

# What a frame shows: from where, looking where, at what time of day.
pub type View:
	eye Vec3
	forward Vec3
	fovY f32   # radians
	time f32   # seconds since the start, for what moves
	dayTime f32   # 0 .. 1 over a day: 0 dawn, 0.25 noon, 0.5 dusk, 0.75 midnight
	underwater bool

pub fn newPipeline(w i64, h i64) Pipeline:
	p = Pipeline(
		world = worldProgram(),
		shadow = shadowProgram(),
		skyView = skyViewPass(),
		sky = skyPass(),
		final = finalPass(),
		skyTarget = engine.newRenderTarget(256, 128, true, false),
		skyTime = -1.0,
		shadowA = newShadowMap(),
		shadowB = newShadowMap(),
		scene = engine.newRenderTarget(
			w,
			h,
			true,
			true
		), post = engine.newPost(w, h), width = w, height = h, near = [], seen = [])
	p

fn newShadowMap():
	ShadowMap(
		target = engine.newShadowTarget(shadowSize),
		step = -1.0,
		center = Vec3(0.0, 0.0, 0.0),
		edits = -1,
		matrix = Mat4(1.0)
	)

# the targets made again for a window of a new size
fn fitTo(mut p Pipeline, w i64, h i64):
	if w == p.width and h == p.height or w == 0 or h == 0: return
	p.scene = engine.newRenderTarget(w, h, true, true)
	p.post.fitPost(w, h)
	p.width = w
	p.height = h

# ---------- the sun ----------

# the direction toward the sun at a time of day (it rises in +x, sets in -x, a little south)
pub fn sunDirection(dayTime f32) Vec3:
	a = dayTime * 2.0 * pi
	Vec3(a.cos(), a.sin(), 0.35).normalized()

# the time of day dt seconds later
pub fn advanceDay(dayTime f32, dt f32) f32:
	t = dayTime + dt / dayLength
	t - t.floor()

# The light that casts the shadows: the sun by day, the moon (across from it) by night, each as
# much of it as gets through the air (a low sun is dimmer and redder), handing over around the
# moment the sun sets.
fn mainLight(sun Vec3):
	if sun.y > -0.03: return (sun, sun.throughAir() * 3.4)
	moon = sun * -1.0
	(moon, moon.throughAir() * Vec4(0.09, 0.11, 0.16, 1.0))

# The air the light crosses (as shaders/atmosphere.gpu.zap has it): the earth's radius and the air's top in
# meters, the scattering of its molecules (by color) and of its haze, their scale heights.
earthRadius = 6360000.0
airTop = 6420000.0
rayleighBeta = [0.0000058, 0.0000135, 0.0000331]
mieBeta = 0.000021
rayleighHeight = 7994.0
mieHeight = 1200.0

# how much of a light from `dir` reaches the ground through the air, by color (none from below
# the horizon)
fn throughAir(dir Vec3):
	d = dir.normalized()
	start = earthRadius + 100.0
	b = start * f64(d.y)
	if b < 0.0 and b * b - (start * start - earthRadius * earthRadius) >= 0.0:
		return Vec4(0.0, 0.0, 0.0, 1.0)
	far = -b + (b * b - (start * start - airTop * airTop)).sqrt()
	steps = 16
	stepLength = far / steps
	depthR = 0.0
	depthM = 0.0
	for i in 0..steps:
		t = stepLength * (i + 0.5)
		x = f64(d.x) * t
		y = start + f64(d.y) * t
		z = f64(d.z) * t
		height = (x * x + y * y + z * z).sqrt() - earthRadius
		depthR += (-height / rayleighHeight).exp() * stepLength
		depthM += (-height / mieHeight).exp() * stepLength
	c f32[3]
	for k in 0..3:
		c[k] = f32((-(rayleighBeta[k] * depthR + mieBeta * 1.1 * depthM)).exp())
	Vec4(c[0], c[1], c[2], 1.0)

# ---------- the shadow maps ----------

# The light's view of the box around `around` for a step of the sun's course: looking along the
# light, the box's center snapped (in the light's space) so the map holds still; the snapped
# center comes back with the matrix.
fn lightView(around Vec3, step f32):
	light, _ = sunDirection(step / sunSteps).mainLight()
	view = Mat4.lookAlong(Vec3(0.0, 0.0, 0.0), light * -1.0)
	c = view.project(around)
	for a in 0..3:
		c[a] = (c[a] / shadowSnap).round() * shadowSnap
	box = Mat4.orthoBox(
		c.x - shadowReach,
		c.x + shadowReach,
		c.y - shadowReach,
		c.y + shadowReach,
		-c.z - 200.0,
		-c.z + 200.0
	)
	(box @ view, c)

# The map made current for the step: kept when it was drawn for that step, around that center,
# over the same world; else drawn again.
fn updateShadowMap(
	mut r engine.Renderer,
	shadow engine.Program,
	near i64[],
	mut map ShadowMap,
	step f32,
	eye Vec3,
	edits i64,
	chunks ChunkDraw[],
	tiles Materials
):
	matrix, center = eye.lightView(step)
	if map.step == step and map.edits == edits and map.center == center: return
	map.step = step
	map.center = center
	map.edits = edits
	map.matrix = matrix
	r.useTarget(map.target)
	r.setDepth(true, true, false)
	r.clearTarget(engine.white)
	r.setDepthBias(true)
	params = shaders.Shadow(
		lightViewProjection = matrix,
		time = 0.0,
		chunkOrigin = Vec3(0.0, 0.0, 0.0),
		tiles = tiles.colors.textureArray()
	)
	for i in near:
		m = chunks[i].solid
		if m.model.count > 0:
			params.chunkOrigin = chunks[i].origin
			shadow.setParams(params)
			r.drawMesh(shadow, m)
	r.setDepthBias(false)

# ---------- the chunks ----------

# a chunk's mesh drawn by the world's program from its corner
fn drawChunk(
	r engine.Renderer,
	world engine.Program,
	mut params shaders.World,
	m engine.Mesh,
	origin Vec3
):
	if m.model.count > 0:
		params.chunkOrigin = origin
		world.setParams(params)
		r.drawMesh(world, m)

# The chunks within the shadows' reach of the eye across the ground (`near`), and those the
# camera's view takes in this side of the fog (`seen`).
fn sortChunks(mut p Pipeline, e Vec3, viewProjection Mat4, chunks ChunkDraw[], grid Grid):
	p.near.clear()
	p.seen.clear()
	planes = viewProjection.frustumPlanes()
	s = f32(grid.size)
	for i in 0..chunks.len:
		lo = chunks[i].origin
		hi = lo + Vec3(s, f32(grid.height), s)
		dx = lo.x + s * 0.5 - e.x
		dz = lo.z + s * 0.5 - e.z
		far = (dx * dx + dz * dz).sqrt()
		# a chunk is about 23 blocks across corner to corner: a margin of half that
		if far < shadowReach + 12.0:
			p.near.push(i)
		if far < viewDistance + 12.0 and math.isBoxInFrustum(planes, lo, hi):
			p.seen.push(i)

# ---------- the frame ----------

# Draws a frame of the world to the window (w x h): the chunks' meshes, `outline` (drawn from
# `outlineAt` when there is one) the lines around the block aimed at; `edits` counts the changes
# to the meshes (the shadows are drawn again when it moves on).
pub fn drawFrame(
	mut r engine.Renderer,
	mut p Pipeline,
	v View,
	chunks ChunkDraw[],
	grid Grid,
	outline engine.Mesh,
	outlineAt Vec3?,
	edits i64,
	tiles Materials,
	w i64,
	h i64
):
	p.fitTo(w, h)
	sun = sunDirection(v.dayTime)
	r.setBlending(false)
	r.drawFrameSky(p, v, sun)
	skyView = p.skyTarget.colorTexture()
	step = (v.dayTime * sunSteps).floor()
	blend = v.dayTime * sunSteps - step
	light, lightColor = sunDirection(step / sunSteps).mainLight()
	lightB, lightColorB = sunDirection((step + 1.0) / sunSteps).mainLight()
	aspect = f32(w) / f32(h.max(1))
	viewProjection = Mat4.perspective(v.fovY, aspect, 0.05, 600.0) @
		Mat4.lookAlong(v.eye, v.forward)
	p.sortChunks(v.eye, viewProjection, chunks, grid)

	r.drawFrameShadows(p, v, step, edits, chunks, tiles)

	r.drawFrameScene(
		p,
		v,
		chunks,
		outline,
		outlineAt,
		tiles,
		sun,
		light,
		lightB,
		lightColor,
		lightColorB,
		blend,
		aspect,
		viewProjection,
		skyView
	)

	r.drawFramePost(p, v, w, h)

fn drawFrameSky(
	mut r engine.Renderer,
	mut p Pipeline,
	v View,
	sun Vec3
):
	# 0. the sky view, again when the sun has moved a tenth of a degree
	if (v.dayTime - p.skyTime).abs() > 0.0003:
		r.useTarget(p.skyTarget)
		r.setDepth(false, false, false)
		r.drawScreenPass(p.skyView, shaders.SkyView(sunDirection = sun))
		p.skyTime = v.dayTime

fn drawFrameShadows(
	mut r engine.Renderer,
	mut p Pipeline,
	v View,
	step f32,
	edits i64,
	chunks ChunkDraw[],
	tiles Materials
):
	# 1. the shadow maps (the leaves held still in them: a swaying shadow reads as a flicker); as
	# the sun steps on, the next map becomes the last one
	if p.shadowB.step == step and p.shadowA.step != step:
		p.swapShadowMaps()
	r.updateShadowMap(p.shadow, p.near, p.shadowA, step, v.eye, edits, chunks, tiles)
	r.updateShadowMap(p.shadow, p.near, p.shadowB, step + 1.0, v.eye, edits, chunks, tiles)

fn drawFrameScene(
	mut r engine.Renderer,
	p Pipeline,
	v View,
	chunks ChunkDraw[],
	outline engine.Mesh,
	outlineAt Vec3?,
	tiles Materials,
	sun Vec3,
	light Vec3,
	lightB Vec3,
	lightColor Vec4,
	lightColorB Vec4,
	blend f32,
	aspect f32,
	viewProjection Mat4,
	skyView engine.Texture
):
	# 2. the scene: the sky behind all, then the world
	r.useTarget(p.scene)
	r.clearTarget(engine.black)
	r.setDepth(false, false, false)
	forward = v.forward.normalized()
	right = forward.cross(Vec3(0.0, 1.0, 0.0)).normalized()
	tanHalf = (v.fovY * 0.5).tan()
	shown = lightColor + (lightColorB - lightColor) * blend
	litBy = Vec3(shown.r, shown.g, shown.b)
	r.drawScreenPass(p.sky, shaders.Sky(
		sunDirection = sun,
		time = v.time,
		eye = v.eye,
		lightColor = litBy,
		camForward = forward,
		camRight = right,
		camUp = right.cross(forward), tanHalf = Vec2(tanHalf * aspect, tanHalf), skyView))

	world = p.world
	r.setDepth(true, true, true)
	params = shaders.World(
		viewProjection,
		lightViewProjection = p.shadowA.matrix,
		lightViewProjectionB = p.shadowB.matrix,
		time = v.time,
		chunkOrigin = Vec3(0.0, 0.0, 0.0),
		sunDirection = sun,
		eye = v.eye,
		lightDirection = (light + (lightB - light) * blend).normalized(),
		lightColor = litBy,
		fogDensity = 0.0085,
		alphaCut = 0.5,
		shadowTexel = 1.0 / f32(shadowSize),
		shadowBlend = blend,
		underwater = v.underwater,
		tiles = tiles.colors.textureArray(),
		shadowMap = p.shadowA.target.shadowMap(), shadowMapB = p.shadowB.target.shadowMap(), surfaces = tiles.surfaces.textureArray(), skyView)
	for i in p.seen:
		r.drawChunk(world, params, chunks[i].solid, chunks[i].origin)
	if outlineAt is at:
		r.drawChunk(world, params, outline, at)
	# the water: blended over what is under it, seen from both sides, hiding nothing
	r.setBlending(true)
	r.setDepth(true, false, false)
	params.alphaCut = 0.01
	for i in p.seen:
		r.drawChunk(world, params, chunks[i].water, chunks[i].origin)
	r.setBlending(false)
	r.setDepth(false, true, false)

fn drawFramePost(
	mut r engine.Renderer,
	p Pipeline,
	v View,
	w i64,
	h i64
):
	# 3. bloom
	bloom = r.drawBloom(p.post.bloom, p.scene.colorTexture())

	# 4. the picture, then its edges smoothed onto the screen
	r.useTarget(p.post.picture)
	r.drawScreenPass(p.final, shaders.Final(
		scene = p.scene.colorTexture(),
		bloom,
		time = v.time,
		underwater = v.underwater,
		exposure = 0.85
	))
	r.drawFxaa(p.post, w, h)
	r.setBlending(true)

# the next map becomes the last one (its target and what it was drawn for), the last one's
# target free for the next
fn swapShadowMaps(mut p Pipeline):
	last = move p.shadowA
	p.shadowA = move p.shadowB
	p.shadowB = last
