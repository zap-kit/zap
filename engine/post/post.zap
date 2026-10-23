# Post-processing of an HDR scene (a target drawn with light kept above 1): its bloom (the bright
# parts drawn at half size, then blurred across and up between two half-size targets), the eye's
# adaptation to its brightness, and the picture made of them, then its edges smoothed
# (post.gpu.zap's passes).
#
#     mut post = engine.newPost(w, h)
#     bloom = engine.drawBloom(r, post.bloom, scene.colorTexture())
#     engine.useTarget(r, post.picture)                     // the picture, luma in alpha:
#     engine.drawTonemap(r, post, scene.colorTexture(), bloom, exposure = 1.0)
#     engine.drawFxaa(r, post, w, h)                        // onto the screen
#
# A program with a composite of its own (weather, a flash, colors graded) draws its pass into
# `picture` in place of drawTonemap, writing the luma to alpha, and smooths it the same way.

# The bloom of an HDR scene: its bright parts at half size, blurred across and up between two
# half-size targets. `knee` picks the bright pass (0: light from a luma of `threshold` on, all of
# it 1.1 above; above 0: the brightest channel's light above 1, eased in over `knee`); `spread` is
# how many texels apart the blur's nine taps lie.
pub type Bloom:
	width i64
	height i64
	a RenderTarget   # the bright parts, then their blur
	b RenderTarget
	knee f32
	spread f32
	threshold f32
	gain f32
	bright ScreenPass
	copy ScreenPass
	blur ScreenPass

	# the targets made again for a scene of a new size (nothing when it has that size)
	pub mut fn fit(w i64, h i64):
		if w == width and h == height or w < 1 or h < 1: return
		a = halfTarget(w, h)
		b = halfTarget(w, h)
		width = w
		height = h

pub fn newBloom(
	w i64,
	h i64,
	knee f32 = 0.0,
	spread f32 = 1.5,
	threshold f32 = 0.9,
	gain f32 = 0.0
) Bloom:
	Bloom(
		width = w,
		height = h,
		a = halfTarget(w, h),
		b = halfTarget(w, h),
		knee,
		spread,
		threshold,
		gain,
		bright = newScreenPass(shader(brightPixel)),
		copy = newScreenPass(shader(copyPixel)),
		blur = newScreenPass(shader(blurPixel)))

# a half-size HDR target of the bloom (at least a pixel each way)
fn halfTarget(w i64, h i64):
	newRenderTarget((w / 2).max(1), (h / 2).max(1), true, false)

# The bloom of the scene, blurred `rounds` times across and up (blending and the depth test off).
# It leaves `a` in use; the texture it returns is a's.
pub fn drawBloom(
	mut r Renderer,
	b Bloom,
	scene Texture,
	rounds i64 = 2,
	adapted Texture? = none
) Texture:
	r.setBlending(false)
	r.setDepth(false, true, false)
	r.useTarget(b.a)
	r.drawScreenPass(b.bright, BloomBright(
		scene,
		knee = b.knee,
		threshold = b.threshold,
		gain = b.gain,
		adapted = adapted ?? scene
	))
	r.blurRounds(b, rounds)

# `image` at half size, blurred `rounds` times across and up (what a menu leaves of the scene
# behind it); the texture it returns is a's, in use again by the next bloom.
pub fn drawBlurred(mut r Renderer, b Bloom, image Texture, rounds i64 = 2) Texture:
	r.setBlending(false)
	r.setDepth(false, true, false)
	r.useTarget(b.a)
	r.drawScreenPass(b.copy, Copy(image))
	r.blurRounds(b, rounds)

fn blurRounds(mut r Renderer, b Bloom, rounds i64):
	loop rounds:
		r.blurInto(b, b.a, b.b, 1.0, 0.0)
		r.blurInto(b, b.b, b.a, 0.0, 1.0)
	b.a.colorTexture()

# one direction of the blur, from one half-size target into the other
fn blurInto(mut r Renderer, b Bloom, from RenderTarget, into RenderTarget, dx f32, dy f32):
	r.useTarget(into)
	drawScreenPass(
		r,
		b.blur,
		BloomBlur(
			image = from.colorTexture(),
			direction = Vec2(dx / f32(from.width), dy / f32(from.height)),
			spread = b.spread
		)
	)

# bloom, tone mapping and FXAA, for a picture of one size
pub type Post:
	bloom Bloom
	picture RenderTarget   # full size, 8 bits: the picture before its edges are smoothed
	tonemap ScreenPass
	fxaa ScreenPass

pub fn newPost(w i64, h i64) Post:
	Post(
		bloom = newBloom(w, h),
		picture = newRenderTarget(w, h, false, false),
		tonemap = newScreenPass(shader(tonemapPixel)),
		fxaa = newScreenPass(shader(fxaaPixel)))

# the targets made again for a picture of a new size (nothing when it has that size)
pub fn fitPost(mut p Post, w i64, h i64):
	if w == p.bloom.width and h == p.bloom.height or w < 1 or h < 1: return
	p.bloom.fit(w, h)
	p.picture = newRenderTarget(w, h, false, false)

# The picture of the scene and its bloom onto the renderer's target (post.gpu.zap's tonemapPixel):
# `glow` of the bloom added, the exposure, ACES, corners darkened by `vignette`, gamma.
pub fn drawTonemap(
	r Renderer,
	p Post,
	scene Texture,
	bloom Texture,
	exposure f32 = 1.0,
	glow f32 = 0.25,
	vignette f32 = 0.45
):
	r.drawScreenPass(p.tonemap, Tonemap(scene, bloom, exposure, glow, vignette))

# `picture` (luma in alpha) onto the screen of w x h with its edges smoothed
pub fn drawFxaa(mut r Renderer, p Post, w i64, h i64):
	r.useScreen()
	drawScreenPass(
		r,
		p.fxaa,
		Fxaa(picture = p.picture.colorTexture(), texel = Vec2(1.0 / f32(w), 1.0 / f32(h)))
	)

# The eye's adaptation to an HDR scene: the luminance it has adapted to, which closes on the
# scene's (the exp of the mean of a grid of its texels' logs; their plain mean when not
# `geometric`), one value a cell of a `cells` x `cells` grid over the screen, kept in one of two
# targets of a texel a cell that trade places each frame.
pub type Adaptation:
	targets RenderTarget[]
	current i64 = 0
	started bool = false
	geometric bool = true
	cells i64 = 1
	adapt ScreenPass

pub fn newAdaptation(geometric bool = true, cells i64 = 1) Adaptation:
	Adaptation(
		targets = [newRenderTarget(cells, cells, true, false), newRenderTarget(cells, cells, true, false)],
		geometric,
		cells,
		adapt = newScreenPass(shader(adaptPixel)))

# The luminance the eye has adapted to `dt` seconds on, in the red and green of the texture
# returned (the scene's own on the first frame): by default both closing at a rate of `speed` a
# second; `shares` gives each its share of the way this frame and `least` the smallest step.
# Blending and the depth test off.
pub fn drawAdaptation(
	mut r Renderer,
	mut a Adaptation,
	scene Texture,
	dt f32,
	speed f32,
	shares Vec2? = none,
	least f32 = 0.0
) Texture:
	before = a.targets[a.current].colorTexture()
	a.current = 1 - a.current
	share = 1.0 - (-speed * dt).exp()
	now = (shares ?? Vec2(share, share)) if a.started else Vec2(1.0, 1.0)
	a.started = true
	r.setBlending(false)
	r.setDepth(false, true, false)
	r.useTarget(a.targets[a.current])
	r.drawScreenPass(
		a.adapt,
		Adapt(
			scene,
			before,
			shares = now,
			least,
			cells = f32(a.cells),
			geometric = a.geometric
		)
	)
	a.targets[a.current].colorTexture()
