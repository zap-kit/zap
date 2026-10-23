# Skyrim's temporal anti-aliasing (ISTemporalAA, bUseTAA=1) over the graded picture, ported from the
# DXBC of the capture's event 13129 through Community Shaders' ISTemporalAA.hlsl, the SDR path. The
# game keeps a feedback texture, not a color: the luma its last resolve had (8 bits), a confidence
# and the motion of that frame. The color comes from the picture itself: the pixel and its eight
# neighbours give a bracket, the nearest luma under the history's and the nearest at or over it
# (-0.001 and 1.001 where there is none), and the resolve is the bracket's color interpolated at
# where the history's luma lies; the weight of that on the pixel's own color rises to 0.99 with the
# confidence, which an edge (more than four neighbours 0.2 apart in luma) raises and the history
# keeps at 0.95 a frame. The picture's own color is un-jittered first, and the resolve is sharpened
# and laid back over it (BlendParams z and w). The luma, the confidence and the motion go to the
# feedback target in a pass of their own (the RHI has one target a pass). Not ported: the mask and
# the alpha coverage (the capture's mask.y is zero and its alpha texture black, so their branches
# never run), the dynamic resolution.

import engine

pub type Taa:
	current engine.Texture   # the picture of this frame
	history engine.Texture   # the last frame's feedback: luma, confidence, motion
	depth engine.Texture
	unproject Vec4   # the projection's 1 / m[0], 1 / m[5], m[10] and m[14]
	toPrevious Mat4   # this frame's view space into the last frame's
	texel Vec2   # one pixel in uv
	jitter Vec2   # the pixels (in uv) the frame's picture was shifted by
	blend Vec4   # the weight at rest and at speed, the sharpen and the overlay
	fresh f32   # 1 on the first frame, with no history

fn tapLuma(c Vec3) f32:
	c @ Vec3(0.25, 0.5, 0.25)

# a bracket's end: red, blue and luma (the green is what the luma leaves)
fn endOf(c Vec3) Vec3:
	Vec3(c.x, c.z, tapLuma(c))

fn colorOf(e Vec3) Vec3:
	Vec3(e.x, 2.0 * (e.z - 0.25 * e.x - 0.25 * e.y), e.y)

# where the surface seen at uv was on the last frame's screen
fn previousUv(uv Vec2, p Taa) Vec2:
	v = viewAtDepth(p.depth, p.unproject, uv)
	q = p.toPrevious @ Vec4(v.x, v.y, v.z, 1.0)
	k = -1.0 / q.z
	Vec2(0.5 + 0.5 * q.x * k / p.unproject.x, 0.5 + 0.5 * q.y * k / p.unproject.y)

# the nearest surface's uv of the 3 x 3 around uv
fn nearestUv(uv Vec2, p Taa) Vec2:
	best = uv
	least = p.depth.sampleLevel(uv, 0.0).r
	for k in 0..9:
		at = uv + Vec2(f32(k % 3) - 1.0, f32(k / 3) - 1.0) * p.texel
		d = p.depth.sampleLevel(at, 0.0).r
		if d < least:
			least = d
			best = at
	best

# the neighbours in the order the game folds them into the bracket (its C1, C0, B1, B0, A1, A0,
# the lower and the upper corner), in pixels; uv's y grows upward here, downward there
fn neighbour(k i64) Vec2:
	if k == 0: return Vec2(0.0, 1.0)
	if k == 1: return Vec2(-1.0, 0.0)
	if k == 2: return Vec2(-1.0, 1.0)
	if k == 3: return Vec2(0.0, -1.0)
	if k == 4: return Vec2(1.0, 0.0)
	if k == 5: return Vec2(1.0, -1.0)
	if k == 6: return Vec2(-1.0, -1.0)
	Vec2(1.0, 1.0)

# the resolve's color (rgb, alpha 1) or its feedback (luma, confidence, motion)
fn resolve(uv Vec2, p Taa, feedback bool) Vec4:
	c = p.current.sample(uv).rgb
	nearest = nearestUv(uv, p)
	previous = uv + previousUv(nearest, p) - nearest
	rejected = p.fresh > 0.5 or previous.x <= 0.0 or previous.y <= 0.0 or previous.x >= 1.0 or
		previous.y >= 1.0
	past = p.history.sample(previous)
	histLuma = past.r
	centerLuma = tapLuma(c)
	centerEnd = endOf(c)
	low = Vec3(-0.001, -0.001, -0.001)
	high = Vec3(1.001, 1.001, 1.001)
	if centerLuma < histLuma:
		low = centerEnd
	elif centerLuma < 1.001:
		high = centerEnd
	similar = 0.0
	for k in 0..8:
		e = endOf(p.current.sample(uv + neighbour(k) * p.texel).rgb)
		if e.z < histLuma:
			if low.z < e.z: low = e
		elif e.z < high.z:
			high = e
		if (centerLuma - e.z).abs() < 0.2: similar += 1.0
	# with no end on a side the other side's stands in for it
	lowStand = low if low.z >= 0.0 else high
	highStand = lowStand if high.z > 1.0 else high
	confidence = ((4.0 - similar).clamp(0.0, 1.0) * 0.25 + 0.95 * past.g).clamp(0.0, 1.0)
	narrow = confidence < 0.9025
	lowEnd = lowStand if narrow else low
	highEnd = highStand if narrow else high
	seen = histLuma.max(lowStand.z).min(highStand.z) if narrow else histLuma
	span = highEnd.z - lowEnd.z
	share = ((seen - lowEnd.z) / span) if span > 0.01 else 0.5
	lowColor = colorOf(lowEnd)
	resolved = lowColor + (colorOf(highEnd) - lowColor) * share
	unjittered = p.current.sample(uv + p.jitter * p.texel).rgb
	if rejected:
		seen = centerLuma
		resolved = c
		unjittered = c
	storedMotion = 0.0 if rejected else past.b
	motion = ((previous - uv).length() / (128.0 * p.texel.x)).clamp(0.0, 1.0)
	change = (motion - storedMotion).abs()
	keepFrame = (1.0 - 20.0 * change).max(0.0)
	keepPast = (1.0 - 100.0 * change).max(0.0)
	base = unjittered + (c - unjittered) * keepFrame
	kept = keepPast * confidence
	weight = p.blend.x.lerp(p.blend.y, motion).min(keepFrame)
	weight = weight + (0.99 - weight) * kept
	if feedback:
		step = weight * (seen - centerLuma)
		luma = centerLuma if step.abs() < 0.01 else centerLuma + step
		return Vec4(luma.clamp(0.0, 1.0), kept, motion, 1.0)
	toward = (base + (resolved - base) * weight).clamp(0.0, 1.0)
	sharpened = (toward + (toward - unjittered) * p.blend.z).clamp(0.0, 1.0)
	(sharpened + (unjittered - sharpened) * p.blend.w).clamp(0.0, 1.0).withW(1.0)

pub fn taaPixel(uv Vec2, p Taa) Vec4:
	resolve(uv, p, false)

pub fn taaFeedbackPixel(uv Vec2, p Taa) Vec4:
	resolve(uv, p, true)

pub type Resolved:
	picture engine.Texture

# the resolve onto the screen
pub fn resolvedPixel(uv Vec2, p Resolved) Vec4:
	p.picture.sample(uv).rgb.withW(1.0)
