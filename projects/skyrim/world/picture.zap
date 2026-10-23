# The picture of a cell as Skyrim makes it of the light it draws: the cell drawn into an HDR
# target, its opaque parts darkened by their ambient occlusion (occlusion.zap), its bloom and the
# eye's adaptation (engine/post), then graded by the cell's image space (shaders/grade.gpu.zap)
# into a target, then smoothed by the temporal anti-aliasing (shaders/taa.gpu.zap) onto the screen:
# SkyrimPrefs.ini has FXAA off (bFXAAEnabled=0) and TAA on (bUseTAA=1). The projection is jittered
# a frame at a time (beginFrame), as the game's is, by a Halton (2, 3) sequence of eight points.

import engine
import skyrim.esm
import world.shaders

pub type Picture:
	scene engine.RenderTarget   # HDR, with its depth
	post engine.Post
	adaptation engine.Adaptation
	grade engine.ScreenPass
	graded engine.RenderTarget   # the graded picture, before its edges are smoothed
	resolves engine.RenderTarget[]   # this and the last frame's TAA resolve, trading places
	feedbacks engine.RenderTarget[]   # the same for its feedback (8 bits, as the game's)
	taa engine.ScreenPass
	taaFeedback engine.ScreenPass
	resolved engine.ScreenPass
	occlusion Occlusion
	space esm.ImageSpace
	frame i64 = 0
	jitterPhase i64 = 0   # frames the jitter sequence is ahead, to land on a capture's index
	fresh bool = true   # no history yet
	projection Mat4   # this frame's, without the jitter
	view Mat4
	previousView Mat4
	jitter Vec2 = Vec2(0.0, 0.0)   # the pixels (in uv) this frame's picture is shifted by
	blurBehind bool = false   # a menu is open over the picture: it shows blurred

pub fn newPicture(space esm.ImageSpace) Picture:
	post = engine.newPost(1, 1)
	# the blur's taps a quarter of the image space's radius apart: it reaches about that far
	reach = space.bloomBlurRadius.max(1.0) * 0.25
	post.bloom = engine.newBloom(
		1,
		1,
		spread = reach,
		threshold = space.bloomThreshold,
		gain = space.bloomScale
	)
	Picture(
		scene = engine.newRenderTarget(1, 1, true, true),
		post,
		adaptation = engine.newAdaptation(geometric = false, cells = 2),
		grade = engine.newScreenPass(shader(shaders.gradePixel)),
		graded = engine.newRenderTarget(1, 1, false, false),
		resolves = [engine.newRenderTarget(1, 1, true, false), engine.newRenderTarget(1, 1, true, false)],
		feedbacks = [engine.newRenderTarget(1, 1, false, false), engine.newRenderTarget(1, 1, false, false)],
		taa = engine.newScreenPass(shader(shaders.taaPixel)),
		taaFeedback = engine.newScreenPass(shader(shaders.taaFeedbackPixel)),
		resolved = engine.newScreenPass(shader(shaders.resolvedPixel)),
		occlusion = newOcclusion(),
		space = space.copy(),
		projection = Mat4(1.0),
		view = Mat4(1.0),
		previousView = Mat4(1.0)
	)

# the targets made again for a screen of w x h (nothing when they have that size)
pub fn fitPicture(mut p Picture, w i64, h i64):
	if p.scene.width == w and p.scene.height == h: return
	p.scene = engine.newRenderTarget(w, h, true, true)
	p.graded = engine.newRenderTarget(w, h, false, false)
	p.resolves = [
		engine.newRenderTarget(w, h, true, false),
		engine.newRenderTarget(w, h, true, false)
	]
	p.feedbacks = [
		engine.newRenderTarget(w, h, false, false),
		engine.newRenderTarget(w, h, false, false)
	]
	p.fresh = true
	p.post.fitPost(w, h)
	p.occlusion.fitOcclusion(w, h)

fn halton(index i64, base i64):
	f = 1.0
	sum = 0.0
	k = index
	while k > 0:
		f /= f32(base)
		sum += f * f32(k % base)
		k /= base
	sum

# The projection of the coming frame, shifted by a sub-pixel jitter of the sequence; the view and
# the unjittered projection are kept for the TAA's reprojection.
pub fn beginFrame(mut p Picture, projection Mat4, view Mat4, w i64, h i64) Mat4:
	p.previousView = p.view if not p.fresh else view
	p.projection = projection
	p.view = view
	at = (p.frame + p.jitterPhase) % 8 + 1
	p.frame += 1
	m = projection.m
	shift = Vec2(halton(at, 2) - 0.5, halton(at, 3) - 0.5)
	m[8] -= shift.x * 2.0 / f32(w)
	m[9] -= shift.y * 2.0 / f32(h)
	p.jitter = shift
	Mat4(m)

# The shares of the way the scene's luminance (red) and the target's (green) close this frame, as
# SkyrimSE.exe sets them (0x14153d860): 1 - (1 - k speed)^(30 dt) with the image space's eye adapt
# speed times fGlobalEyeAdaptSpeedScale 2, k 0.01 for the target and 0.01 / (its strength times
# fGlobalEyeAdaptStrengthScale 0.4) for the scene's. The game keeps a 2 x 2 grid of them over the
# screen (bUseMultipleLuminanceReferences: its downsampling stops at 2 x 2), each its quarter's mean.
fn adaptShares(s esm.ImageSpace, dt f32):
	speed = s.eyeAdaptSpeed * 2.0
	share = (k f32): 1.0 - (1.0 - k * speed).max(0.0).pow(dt * 30.0)
	Vec2(share(0.01 / (s.eyeAdaptStrength * 0.4).max(1.0e-4)), share(0.01))

# SkyrimSE.exe's fReinhardWhiteScale:Display (1.1): the white the curve takes is the image space's
# times it (0x14153d860 passes 1 / (1.1 white)^2)
reinhardWhiteScale = 1.1

# the image space's numbers as the grading pass reads them
fn gradeOf(p Picture, scene engine.Texture, bloom engine.Texture, adapted engine.Texture):
	s = p.space
	white = s.white * reinhardWhiteScale
	shaders.Grade(
		scene,
		bloom,
		adapted,
		hdr = Vec4(1.0 / (white * white).max(1.0e-4), s.receiveBloomThreshold, 0.0, 0.0),
		cinematic = Vec4(s.saturation, s.brightness, s.contrast, 0.0),
		tint = s.tint.withW(s.tintAmount)
	)

# The picture of what was drawn into p.scene, `dt` seconds after the last, onto the screen.
pub fn drawPicture(mut r engine.Renderer, mut p Picture, dt f32):
	scene = p.scene.colorTexture()
	adapted = r.drawAdaptation(
		p.adaptation,
		scene,
		dt,
		p.space.eyeAdaptSpeed,
		shares = p.space.adaptShares(dt),
		least = 1.0 / 256.0
	)
	bloom = r.drawBloom(p.post.bloom, scene, adapted = adapted)
	r.useTarget(p.graded)
	r.drawScreenPass(p.grade, p.gradeOf(scene, bloom, adapted))
	p.drawTaa(r)

# How blurred the scene is under a menu (the game's ISBlur radius is the executable's, and the
# captures keep the menus alone): the half-size blur's rounds, measured by eye
menuBlurRounds i64 = 2

# TAA's BlendParams as SkyrimSE.exe sets them (0x1415455c0, from the ConfigureTAA values at
# 0x1420d8c10..1c): the history's weight at rest (high frequency 0.8) and at speed (low frequency
# 0.5), the post sharpen and the post overlay (0.21 each)
tAABlend = Vec4(0.8, 0.5, 0.21, 0.21)

# the graded picture resolved with the last frame's, onto the screen
fn drawTaa(mut p Picture, mut r engine.Renderer):
	now = p.frame % 2
	m = p.projection.m
	params = shaders.Taa(
		current = p.graded.colorTexture(),
		history = p.feedbacks[1 - now].colorTexture(),
		depth = p.scene.depthTexture(),
		unproject = Vec4(1.0 / m[0], 1.0 / m[5], m[10], m[14]),
		toPrevious = p.previousView @ p.view.inverseAffine(),
		texel = Vec2(1.0 / f32(p.graded.width), 1.0 / f32(p.graded.height)),
		jitter = p.jitter,
		blend = tAABlend,
		fresh = 1.0 if p.fresh else 0.0
	)
	r.useTarget(p.feedbacks[now])
	r.drawScreenPass(p.taaFeedback, params)
	r.useTarget(p.resolves[now])
	r.drawScreenPass(p.taa, params)
	p.fresh = false
	shown = p.resolves[now].colorTexture()
	if p.blurBehind: shown = r.drawBlurred(p.post.bloom, shown, rounds = menuBlurRounds)
	r.useScreen()
	r.drawScreenPass(p.resolved, shaders.Resolved(picture = shown))
