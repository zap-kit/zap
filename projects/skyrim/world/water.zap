# The water on the GPU and drawn into the cell's picture (shaders/water.gpu.zap), after the opaque
# parts and their ambient occlusion: the picture's color and depth copied (what the water refracts
# and how deep it is over what it covers), the sky and the far land drawn again as seen from the
# eye mirrored in the water (what it reflects), then the planes of water drawn over the picture. The
# way in: addWaterMesh with the planes (game/water.zap makes them), each frame advance (the flow's
# clock) and finishCell draws them.

import engine
import world.shaders

# how a water type's three normal layers move: each layer's direction in degrees and its speed
pub type WaterMotion:
	directions f32[]
	speeds f32[]

# What the scene keeps of its water: the planes, each plane's material and how it moves, the
# passes and the targets they draw into, the clock.
pub type WaterSet:
	program engine.Program
	copyPass engine.ScreenPass
	depthPass engine.ScreenPass
	refraction engine.RenderTarget
	depths engine.RenderTarget
	reflection engine.RenderTarget
	draws MeshDraw[] = []
	textures engine.GpuTexture[] = []   # the water's own, kept as long as it is drawn
	materials shaders.WaterMaterial[] = []
	motions WaterMotion[] = []
	height f32 = 0.0   # the water the reflection mirrors about
	seconds f32 = 0.0
	debug f32 = 0.0   # a diagnostic picture of the water (shaders/water.gpu.zap)

pub fn newWaterSet() WaterSet:
	WaterSet(
		program = engine.newProgram(shader(shaders.waterVertex, shaders.waterPixel)),
		copyPass = engine.newScreenPass(shader(shaders.waterCopyPixel)),
		depthPass = engine.newScreenPass(shader(shaders.waterDepthPixel)),
		refraction = engine.newRenderTarget(1, 1, true, false),
		depths = engine.newRenderTarget(1, 1, true, false),
		reflection = engine.newRenderTarget(1, 1, true, true)
	)

fn shiftedMaterial(m shaders.WaterMaterial, by f32):
	shaders.WaterMaterial(
		shallow = m.shallow,
		deep = m.deep,
		fresnel = m.fresnel,
		amounts = m.amounts,
		amplitude = m.amplitude,
		params = m.params,
		fog = m.fog,
		depth = m.depth,
		scale = m.scale,
		scroll = m.scroll,
		scrollThird = m.scrollThird,
		maps = m.maps + Vec4(by, by, by, by)
	)

fn movedVertex(v shaders.WaterVertex, textures f32, materials f32):
	flow = v.data.y + textures if v.data.y >= 0.0 else v.data.y
	shaders.WaterVertex(
		position = v.position,
		uv = v.uv,
		data = Vec4(v.data.x + materials, flow, v.data.z, v.data.w)
	)

# The water added to a scene: its textures join the cell's list, which its vertices' flow maps and
# its materials' normal maps index from where the cell's end; the materials join the scene's (the
# vertices name theirs by index, `firstMaterial` moves them).
pub fn addWaterMesh(
	mut sc CellScene,
	vertices shaders.WaterVertex[],
	indices u32[],
	materials shaders.WaterMaterial[],
	motions WaterMotion[],
	move textures engine.GpuTexture[],
	height f32
):
	first = f32(sc.params.textures.len)
	for t in textures:
		sc.params.textures.push(t.texture())
	sc.water.textures.extend(textures)
	firstMaterial = f32(sc.water.materials.len)
	for m in materials:
		sc.water.materials.push(m.shiftedMaterial(first))
	sc.water.motions.extend(motions.copy())
	sc.water.draws.push(newMeshDraw(vertices.map(.movedVertex(first, firstMaterial)), indices))
	sc.water.height = height

# the flow clock on
pub fn advanceWater(mut sc CellScene, dt f32):
	sc.water.seconds += dt

# a layer's offset: the wind direction (degrees from north: x its sine, y its cosine, the sincos of
# 0x1415a8050 returns the sine first) times the speed times the clock, the fraction kept
# (TESWaterNormals::Update 0x140528cd0)
fn scrollOf(direction f32, speed f32, seconds f32):
	turn = direction.radians()
	Vec2(turn.sin() * speed * seconds, turn.cos() * speed * seconds).fractional()

fn fractional(v Vec2):
	Vec2(v.x - v.x.floor(), v.y - v.y.floor())

# the materials with this frame's normal layers' offsets
fn materialsNow(w WaterSet):
	out = []
	for k, m in w.materials:
		motion = w.motions[k]
		a = scrollOf(motion.directions[0], motion.speeds[0], w.seconds)
		b = scrollOf(motion.directions[1], motion.speeds[1], w.seconds)
		c = scrollOf(motion.directions[2], motion.speeds[2], w.seconds)
		moved = m.copy()
		moved.scroll = Vec4(a.x, a.y, b.x, b.y)
		moved.scrollThird = Vec4(c.x, c.y, 0.0, 0.0)
		out.push(moved)
	out

# the targets made again for a picture of w x h (nothing when they have that size)
fn fitWater(mut s WaterSet, w i64, h i64):
	if s.refraction.width == w and s.refraction.height == h: return
	s.refraction = engine.newRenderTarget(w, h, true, false)
	s.depths = engine.newRenderTarget(w, h, true, false)
	s.reflection = engine.newRenderTarget(w, h, true, true)

# The projection that clips what lies on the near side of the plane C (in the view's space, the
# side with C . v >= 0 kept) in place of the near plane (Lengyel's oblique near plane; the
# engine's depth runs -1 to 1), its image turned over so the mirrored view keeps its triangles'
# winding.
fn obliqueProjection(projection Mat4, c Vec4):
	m = projection.m
	sx = 1.0 if c.x > 0.0 else -1.0
	sy = 1.0 if c.y > 0.0 else -1.0
	# the far corner the plane's signs pick, in the view's space
	q = Vec4(sx / m[0], sy / m[5], -1.0, (1.0 + m[10]) / m[14])
	scale = 2.0 / (c.x * q.x + c.y * q.y + c.z * q.z + c.w * q.w)
	m[2] = c.x * scale
	m[6] = c.y * scale
	m[10] = c.z * scale + 1.0
	m[14] = c.w * scale
	# the image turned over
	m[1] = -m[1]
	m[5] = -m[5]
	m[9] = -m[9]
	m[13] = -m[13]
	Mat4(m)

# the view of the eye mirrored in the plane y = height (the world's y is up)
fn mirroredView(view Mat4, height f32):
	flip = Mat4(1.0)
	flip.m[5] = -1.0
	flip.m[13] = 2.0 * height
	view @ flip

# The sky, the near land, the distant land and trees drawn from the eye mirrored in the water of
# `height` into the reflection target.
fn drawReflection(mut r engine.Renderer, mut sc CellScene, height f32):
	saved = sc.params.copy()
	view = sc.params.view
	mirrored = view.mirroredView(height)
	back = mirrored.inverseAffine()
	c = Vec4(back.m[1], back.m[5], back.m[9], back.m[13] - height)
	projection = sc.params.projection.obliqueProjection(c)
	eye = sc.params.eye
	r.useTarget(sc.water.reflection)
	r.clearTarget(sc.params.fogFarColor)
	sc.params.view = mirrored
	sc.params.projection = projection
	sc.params.eye = Vec4(eye.x, 2.0 * height - eye.y, eye.z, 1.0)
	r.drawSkyBehind(sc, projection, mirrored)
	r.setBlending(false)
	r.drawTerrains(sc)
	r.drawLods(sc)
	r.drawTrees(sc)
	sc.params = saved

# The water of the scene drawn into the picture: the color and the depths copied first, the
# reflection made, the planes drawn over the opaque parts and the ambient occlusion.
pub fn drawWaters(mut r engine.Renderer, mut sc CellScene):
	if sc.water.draws.isEmpty: return
	scene = sc.picture.scene
	sc.water.fitWater(scene.width, scene.height)
	m = sc.params.projection.m
	unproject = Vec4(1.0 / m[0], 1.0 / m[5], m[10], m[14])
	r.setBlending(false)
	r.setDepth(false, false, false)
	r.useTarget(sc.water.refraction)
	r.drawScreenPass(sc.water.copyPass, shaders.WaterCopy(scene = scene.colorTexture()))
	r.useTarget(sc.water.depths)
	r.drawScreenPass(
		sc.water.depthPass,
		shaders.WaterDepth(depth = scene.depthTexture(), unproject)
	)
	r.drawReflection(sc, sc.water.height)
	r.useTarget(scene)
	mirrored = sc.params.view.mirroredView(sc.water.height)
	back = mirrored.inverseAffine()
	c = Vec4(back.m[1], back.m[5], back.m[9], back.m[13] - sc.water.height)
	cell = sc.params
	params = shaders.WaterParams(
		projection = cell.projection,
		view = cell.view,
		eye = cell.eye,
		sunToward = cell.sunToward,
		sunColor = cell.sunColor,
		fogNearColor = cell.fogNearColor,
		fogFarColor = cell.fogFarColor,
		fog = cell.fog,
		textures = cell.textures.copy(),
		materials = sc.water.materialsNow(),
		refraction = sc.water.refraction.colorTexture(),
		depth = sc.water.depths.colorTexture(),
		reflection = sc.water.reflection.colorTexture(),
		mirror = sc.params.projection.obliqueProjection(c) @ mirrored,
		toWorld = sc.params.view.inverseAffine(),
		unproject = Vec4(1.0 / m[0], 1.0 / m[5], 0.0, 0.0),
		seconds = sc.water.seconds,
		debug = sc.water.debug
	)
	program = sc.water.program
	program.setParams(params)
	r.setBlending(false)
	r.setDepth(true, true, false)
	for d in sc.water.draws:
		r.drawIndexed(program, d.model, d.indices, d.indices.count)
