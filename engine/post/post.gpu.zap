# The passes over a whole picture post.zap runs: the bright parts of a scene (what blooms), a
# blur in one direction, the eye's adaptation, ACES tone mapping with darker corners and the
# screen's gamma, and edges smoothed (FXAA). A program's own composite (its finalPixel) is a pass
# of its own module, which calls engine.aces for the curve.

# The bright parts of the scene, drawn at half its size (one read between four texels): what
# blooms. `knee` 0: light from a luma of `threshold` on, all of it 1.1 above; above 0: the light
# above 1 of the brightest channel, eased in over `knee`.
pub type BloomBright:
	scene Texture
	knee f32
	threshold f32
	gain f32   # above 0: the game's pass, each channel's light over `threshold` times `gain`
	adapted Texture   # the eye's adaptation (the game's pass scales the scene by its ratio)

# the scene's color scaled by how bright it is
pub fn brightPixel(uv Vec2, p BloomBright) Vec4:
	c = p.scene.sample(uv).rgb
	if p.gain > 0.0:
		avg = p.adapted.sample(uv).rg
		seen = c * (avg.y / avg.x.max(1.0e-5))
		return (
			(seen - Vec3(p.threshold, p.threshold, p.threshold)).max(Vec3(0.0, 0.0, 0.0)) * p.gain
		).withW(1.0)
	if p.knee > 0.0:
		l = c.r.max(c.g).max(c.b)
		over = (l - 1.0).max(0.0)
		return (c * (over * over / (over + p.knee)) / l.max(1.0e-4)).withW(1.0)
	luma = c @ Vec3(0.2126, 0.7152, 0.0722)
	(c * luma.smoothstep(p.threshold, p.threshold + 1.1)).withW(1.0)

# the image as it is (what a blur starts from), drawn at the target's size
pub type Copy:
	image Texture

pub fn copyPixel(uv Vec2, p Copy) Vec4:
	p.image.sample(uv).rgb.withW(1.0)

# A Gaussian blur along `direction` (one texel across, or one up), 9 taps `spread` texels apart.
pub type BloomBlur:
	image Texture
	direction Vec2
	spread f32

blurWeights f32[5] = [0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216]

pub fn blurPixel(uv Vec2, p BloomBlur) Vec4:
	c = p.image.sample(uv).rgb * blurWeights[0]
	for i in 1..5:
		c += p.image.sample(uv + p.direction * f32(i) * p.spread).rgb * blurWeights[i]
		c += p.image.sample(uv - p.direction * f32(i) * p.spread).rgb * blurWeights[i]
	c.withW(1.0)

# The luminance an eye adapts to, by cell of a `cells` x `cells` grid over the screen (each cell's
# texel lies over its part): the scene's over a 32 x 24 grid of the cell's texels (the exp of the
# mean of their logs, or the plain mean when not `geometric`), which red and green close on from
# `before`'s by their `shares` of the way, a step at least `least` (none past the scene's).
pub type Adapt:
	scene Texture
	before Texture
	shares Vec2
	least f32
	cells f32
	geometric bool

pub fn adaptPixel(uv Vec2, p Adapt) Vec4:
	cell = (uv * p.cells).floor()
	total = 0.0
	for y in 0..24:
		for x in 0..32:
			at = (cell + Vec2((f32(x) + 0.5) / 32.0, (f32(y) + 0.5) / 24.0)) / p.cells
			luma = p.scene.sample(at).rgb @ Vec3(0.2126, 0.7152, 0.0722)
			total += (luma + 1.0e-4).ln() if p.geometric else luma
	now = (total / 768.0).exp() if p.geometric else total / 768.0
	was = p.before.sample(uv).rg
	r = was.x + stepToward(now - was.x, p.shares.x, p.least)
	g = was.y + stepToward(now - was.y, p.shares.y, p.least)
	Vec4(r, g, 0.0, 1.0)

# the step toward a value `gap` away: `share` of it, at least `least`, never past it
fn stepToward(gap f32, share f32, least f32) f32:
	gap.sign() * (gap.abs() * share).max(least).min(gap.abs())

# the filmic curve of ACES (Krzysztof Narkowicz's fit): light of any strength to 0..1
pub fn aces(x Vec3) Vec3:
	(x * (2.51 * x + 0.03) / (x * (2.43 * x + 0.59) + 0.14)).clamp(0.0, 1.0)

# The picture of an HDR scene and its bloom: `glow` of the bloom added, the exposure, ACES,
# corners darkened by `vignette` (0: none), the screen's gamma; the luma goes in alpha for FXAA.
pub type Tonemap:
	scene Texture
	bloom Texture
	exposure f32
	glow f32
	vignette f32

# in the screen's gamma, the luma in alpha
pub fn tonemapPixel(uv Vec2, p Tonemap) Vec4:
	c = p.scene.sample(uv).rgb + p.bloom.sample(uv).rgb * p.glow
	c = aces(c * p.exposure)
	q = uv - 0.5
	c *= 1.0 - q @ q * p.vignette
	c = c.pow(1.0 / 2.2)
	c.withW(c @ Vec3(0.299, 0.587, 0.114))

# Edges smoothed (FXAA, after Timothy Lottes): where the luma of a pixel's corners says an edge
# runs, the picture is read along it at two and four points and the blend that stays within the
# neighbors' range is kept.
pub type Fxaa:
	picture Texture   # luma in alpha
	texel Vec2   # one pixel, across and up

pub fn fxaaPixel(uv Vec2, p Fxaa) Vec4:
	nw = p.picture.sample(uv + Vec2(-1.0, -1.0) * p.texel).a
	ne = p.picture.sample(uv + Vec2(1.0, -1.0) * p.texel).a
	sw = p.picture.sample(uv + Vec2(-1.0, 1.0) * p.texel).a
	se = p.picture.sample(uv + Vec2(1.0, 1.0) * p.texel).a
	m = p.picture.sample(uv)
	lo = m.a.min(nw.min(ne).min(sw.min(se)))
	hi = m.a.max(nw.max(ne).max(sw.max(se)))
	dir = Vec2(-(nw + ne - (sw + se)), nw + sw - (ne + se))
	reduce = ((nw + ne + sw + se) * 0.03125).max(1.0 / 128.0)
	scale = 1.0 / (dir.x.abs().min(dir.y.abs()) + reduce)
	dir = (dir * scale).clamp(-8.0, 8.0) * p.texel
	a = 0.5 *
		(
			p.picture.sample(uv + dir * (1.0 / 3.0 - 0.5)).rgb +
				p.picture.sample(uv + dir * (2.0 / 3.0 - 0.5)).rgb
		)
	b = a * 0.5 +
		0.25 * (p.picture.sample(uv - dir * 0.5).rgb + p.picture.sample(uv + dir * 0.5).rgb)
	lb = b @ Vec3(0.299, 0.587, 0.114)
	(a if (lb < lo or lb > hi) else b).withW(1.0)
