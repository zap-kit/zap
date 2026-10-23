# A prepared map on the GPU and drawn as the client draws a map: the ground (its lightmap atlas
# beside), the still models (built once), the moving models (built again each frame), the water
# (blended over what is below it, its frame and its waves moving with time), then the models
# whose textures are blended. Every vertex names its texture, read by index from the map's
# (bindless): the ground is one draw, and the models of each kind are a draw for each run of
# batches of one sidedness, their batches laid one after the other in one buffer. The blended
# ones keep the client's order (what is behind shows through what is drawn after it); the
# opaque ones are put in two runs, the one-sided batches before the two-sided, each in the
# client's order: depth-tested and written, they cover the same whatever their order but where
# two coplanar faces tie (a few pixels of a frame).

import engine
import world.shaders
import ragnarok.rsm

# a run of a model's vertices of one sidedness (batches laid one after the other): one draw
pub type Run:
	first i64
	count i64
	twoSided bool

# batches laid one after the other in one model, and the runs of one sidedness they make
pub type Merged:
	model engine.Model
	runs Run[]

pub type Scene:
	groundProgram engine.Program
	modelProgram engine.Program
	waterProgram engine.Program
	blended bool[]
	lightmap engine.GpuTexture
	textures engine.GpuTexture[]   # the map's, whose handles the params read
	ground engine.Model
	groundParams shaders.GroundParams   # the map's textures, and the frame's view
	modelParams shaders.ModelParams
	opaque Merged   # the still models whose textures are not blended
	translucent Merged   # those whose textures are
	moving ModelBatches
	movingGpu Merged   # the moving models (not blended), made again each frame
	water engine.Model
	waterFrames engine.GpuTextureArray?
	depth engine.RenderTarget
	fogStart f32   # where the haze begins and where it hides all (cells from the eye)
	fogEnd f32

# the sky behind the map and the haze that fades the far ground into it, seen when the camera
# lowers toward the horizon
pub sky = engine.rgb8(168, 196, 224)

pub tiled = engine.Sampling(
	smooth = true,
	mipmaps = true,
	repeat = true,
	mirror = 0,
	anisotropy = true
)

fn gpuTexture(body u8[], t PreparedTexture, s engine.Sampling):
	imageAt(body, t).newTexture(s)

# the runs of one sidedness of batches laid one after the other: (vertices, two-sided) each, in order
fn runsOf(batches (i64, bool)[]):
	runs Run[] = []
	first = 0
	for (count, twoSided) in batches:
		if count == 0: continue
		n = runs.len
		if n > 0 and runs[n - 1].twoSided == twoSided:
			runs[n - 1].count += count
		else:
			runs.push((first, count, twoSided))
		first += count
	runs

# the prepared batches that `keep` picks, laid one after the other in one model: in their order,
# or with `bySide` the one-sided ones first
fn mergedOf(
	body u8[],
	batches PreparedBatch[],
	stride i64,
	bySide bool,
	keep fn(PreparedBatch) bool
):
	bytes = []
	counts = []
	for pass in 0..(2 if bySide else 1):
		for b in batches:
			if keep(b) and (not bySide or b.twoSided == (pass == 1)):
				bytes.extend(body.bytesAt(b.vertices))
				counts.push((b.vertices.len / stride, b.twoSided))
	Merged(model = engine.newModel(bytes, stride), runs = runsOf(counts))

# the prepared map's textures and triangles sent to the GPU as they lie in its file
pub fn newScene(z Zone) Scene:
	h = z.head
	body = z.file.bodyOf()
	textures = []
	blended = []
	for t in h.textures:
		textures.push(gpuTexture(body, t, tiled))
		blended.push(t.blended)
	lightmap = gpuTexture(
		body,
		h.lightmap,
		engine.Sampling(
			smooth = true,
			mipmaps = false,
			repeat = false,
			mirror = 0,
			anisotropy = false
		)
	)
	waterFrames engine.GpuTextureArray? = none
	if not h.waterFrames.isEmpty:
		waterFrames = engine.newTextureArray(h.waterFrames.map(imageAt(body, it)), tiled)
	groundProgram = engine.newProgram(shader(shaders.groundVertex, shaders.groundPixel))
	modelProgram = engine.newProgram(shader(shaders.modelVertex, shaders.modelPixel))
	waterProgram = engine.newProgram(shader(shaders.waterVertex, shaders.waterPixel))
	ground = mergedOf(body, h.ground, groundProgram.vertexStride, false, b: true).model
	stride = modelProgram.vertexStride
	opaque = mergedOf(body, h.statics, stride, true, not blended[.texture])
	translucent = mergedOf(body, h.statics, stride, false, blended[.texture])
	haze = shaders.Haze(color = Vec4(sky.r, sky.g, sky.b, 1.0), start = 1.0e6, end = 2.0e6)
	groundParams = shaders.GroundParams(
		projection = Mat4(1.0),
		view = Mat4(1.0),
		haze,
		lightmap = lightmap.texture(),
		textures = textures.map(.texture())
	)
	modelParams = shaders.ModelParams(
		projection = Mat4(1.0),
		view = Mat4(1.0),
		cutout = 0.5,
		haze,
		textures = textures.map(.texture())
	)
	Scene(groundProgram, modelProgram, waterProgram, blended, lightmap, textures, ground,
		groundParams, modelParams, opaque, translucent, moving = ModelBatches(),
		movingGpu = Merged(model = engine.newDynamicModel(), runs = []),
		water = engine.newModel(body.bytesAt(h.waterSheet), waterProgram.vertexStride),
		waterFrames, depth = engine.newDepthTarget(1, 1), fogStart = 1.0e6, fogEnd = 2.0e6)

# the haze from `start` cells from the eye, hiding all at `end`
pub fn setFog(mut sc Scene, start f32, end f32):
	sc.fogStart = start
	sc.fogEnd = end

fn hazeOf(sc Scene):
	shaders.Haze(
		color = Vec4(sky.r, sky.g, sky.b, 1.0),
		start = sc.fogStart,
		end = sc.fogEnd
	)

# the moving models posed at `ms` milliseconds into their animations and sent to the GPU: the
# batches whose textures are not blended laid one after the other, the one-sided ones first
fn poseMoving(mut sc Scene, z Zone, ms i64):
	sc.moving.clearAll()
	toward = z.head.sun.sunDirection()
	for mm in z.moving:
		rsm = z.models[mm.model]
		bakeModel(
			rsm,
			z.normals[mm.model],
			rsm.poseNodes(ms),
			mm.placed,
			z.head.movingTextures[mm.model],
			z.head.sun,
			toward,
			sc.moving
		)
	vertices = []
	counts = []
	for pass in 0..2:
		for b in sc.moving.batches:
			if not sc.blended[b.texture] and b.twoSided == (pass == 1):
				vertices.extend(b.vertices)
				counts.push((b.vertices.len, b.twoSided))
	sc.movingGpu.model.fillModel(vertices)
	sc.movingGpu.runs = runsOf(counts)

# Begins the frame of the map on a screen of w x h pixels: cleared to the sky's color, with a
# depth of its own.
pub fn beginScene(mut r engine.Renderer, mut sc Scene, w i64, h i64):
	if sc.depth.width != w or sc.depth.height != h:
		sc.depth = engine.newDepthTarget(w, h)
	r.useScreenWithDepth(sc.depth)
	r.clearTarget(sky)

# The opaque part of the map: the ground, then the models whose textures are cut out.
pub fn drawOpaque(mut r engine.Renderer, mut sc Scene, z Zone, projection Mat4, view Mat4, ms i64):
	sc.poseMoving(z, ms)
	r.setBlending(false)
	r.setDepth(true, true, false)
	sc.groundParams.projection = projection
	sc.groundParams.view = view
	sc.groundParams.haze = sc.hazeOf()
	sc.groundProgram.setParams(sc.groundParams)
	r.drawModel(sc.groundProgram, sc.ground)
	sc.modelParams.projection = projection
	sc.modelParams.view = view
	sc.modelParams.haze = sc.hazeOf()
	sc.modelParams.cutout = 0.5
	sc.modelProgram.setParams(sc.modelParams)
	r.drawRuns(sc.modelProgram, sc.opaque, true)
	r.drawRuns(sc.modelProgram, sc.movingGpu, true)

# a merged model's runs drawn, each culled unless two-sided (the depth written or not)
fn drawRuns(mut r engine.Renderer, p engine.Program, m Merged, depthWrite bool):
	for run in m.runs:
		r.setDepth(true, depthWrite, not run.twoSided)
		r.drawModelRange(p, m.model, run.first, run.count)

# What is see-through: the water (its frame and waves at `ms`), then the blended models.
pub fn drawTranslucent(
	mut r engine.Renderer,
	mut sc Scene,
	z Zone,
	projection Mat4,
	view Mat4,
	ms i64
):
	r.setBlending(true)
	if sc.waterFrames is frames:
		w = sc.waterProgram
			# the client's water at 60 frames a second: the waves turn waveSpeed degrees a frame
		frame = ms * 60.0 / 1000.0
		phase = (frame * f64(z.head.water.waveSpeed)) % 360.0 - 180.0
		texture = (frame / z.head.water.animSpeed.max(1)).floor() % 32.0
		w.setParams(shaders.WaterParams(
			projection,
			view,
			height = z.head.water.waveHeight * 0.2,
			pitch = z.head.water.wavePitch,
			phase = f32(phase), frame = f32(texture), opacity = 0.564, haze = hazeOf(
				sc
			), frames = frames.textureArray()))
		r.setDepth(true, false, false)
		r.drawModel(w, sc.water)
	sc.modelParams.projection = projection
	sc.modelParams.view = view
	sc.modelParams.haze = sc.hazeOf()
	sc.modelParams.cutout = 0.01
	sc.modelProgram.setParams(sc.modelParams)
	r.drawRuns(sc.modelProgram, sc.translucent, false)
	r.setDepth(true, true, false)
