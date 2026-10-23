# The blocks of an hkaSplineCompressedAnimation. A block holds up to maxFramesPerBlock frames of
# every track: a 4-byte mask per transform track (the quantizations: translation in bits 0-1,
# rotation in 2-5, scale in 6-7; then for the translation, the rotation and the scale which parts
# are static, bits 0-3, or a spline, bits 4-7, the rest the identity), a byte per float track,
# then each track's translation, rotation and scale, each padded to 4 bytes. A part with a spline
# starts with the B-spline's header (u16 the last control point's index, u8 its degree, then the
# knots: a byte each, frames of the block); a vector's components then give their range (two
# f32) when they move, their value (f32) when static, and the control points follow, the moving
# components quantized in 8 or 16 bits over their range; a rotation's control points are
# quaternions of 32, 40, 48 or 128 bits. A static part is its value alone, the identity nothing.

# A B-spline over the block's frames: `width` floats a control point (3 a vector, 4 a rotation);
# no knots and one point when the value holds over the block.
type Curve:
	degree i64
	knots f32[]
	points f32[]
	width i64

# a track's three parts over a block
type TrackCurves:
	translation Curve
	rotation Curve
	scale Curve

type SplineBlock:
	tracks TrackCurves[]

# where a part of a track is static (its value alone) or a spline
fn isStatic(types u8, component i64):
	(types >> u8(component)) & 1 != 0

fn isSpline(types u8, component i64):
	not types.isStatic(component) and (types >> u8(component + 4)) & 1 != 0

# the B-spline's header and knots
fn readKnots(mut r Reader) (i64, i64, f32[]) ? str:
	last = i64(r.u16())
	degree = i64(r.u8())
	if degree > 4: return "a spline of degree {degree}"
	knots = []
	loop last + degree + 2:
		knots.push(f32(r.u8()))
	(last, degree, knots)

# a translation (identity 0) or a scale (identity 1): quantization 0 is 8 bits, 1 is 16
fn readVector(mut r Reader, types u8, quantization i64, identity f32) Curve ? str:
	moving = (0..3).any(types.isSpline(it))
	if not moving:
		points = []
		for c in 0..3:
			points.push(r.f32() if types.isStatic(c) else identity)
		return Curve(degree = 0, knots = [], points, width = 3)
	if quantization > 1: return "a vector quantized in mode {quantization}"
	last, degree, knots = try r.readKnots()
	r.at = r.at.alignUp(4)
	lo = [identity, identity, identity]
	hi = [identity, identity, identity]
	for c in 0..3:
		if types.isSpline(c):
			lo[c] = r.f32()
			hi[c] = r.f32()
		elif types.isStatic(c):
			lo[c] = r.f32()
			hi[c] = lo[c]
	points = []
	loop last + 1:
		for c in 0..3:
			if types.isSpline(c):
				q = f32(r.u8()) / 255.0 if quantization == 0 else f32(r.u16()) / 65535.0
				points.push(lo[c] + (hi[c] - lo[c]) * q)
			else:
				points.push(lo[c])
	r.at = r.at.alignUp(4)
	Curve(degree, knots, points, width = 3)

# a rotation: quantization 0 is 32 bits, 1 40, 2 48, 5 four f32
fn readRotation(mut r Reader, types u8, quantization i64) Curve ? str:
	if quantization != 0 and quantization != 1 and quantization != 2 and quantization != 5:
		return "a rotation quantized in mode {quantization}"
	points = []
	if (types & 0xF0) == 0:
		if (types & 0x0F) != 0:
			r.pushQuat(quantization, points)
		else:
			points.extend([0.0, 0.0, 0.0, 1.0])
		r.at = r.at.alignUp(4)
		return Curve(degree = 0, knots = [], points, width = 4)
	last, degree, knots = try r.readKnots()
	if quantization == 2: r.at = r.at.alignUp(2)
	if quantization == 0 or quantization == 5: r.at = r.at.alignUp(4)
	loop last + 1:
		r.pushQuat(quantization, points)
	r.at = r.at.alignUp(4)
	Curve(degree, knots, points, width = 4)

# the next quaternion, x y z w, at the end of out
fn pushQuat(mut r Reader, quantization i64, mut out f32[]):
	if quantization == 5:
		loop 4:
			out.push(r.f32())
	elif quantization == 0:
		out.pushQuat32(r.u32())
	elif quantization == 1:
		low = u64(r.u32())
		out.pushQuat40(low | (u64(r.u8()) << 32))
	else:
		x = i64(r.u16())
		y = i64(r.u16())
		z = i64(r.u16())
		out.pushThreeOfFour(
			[f32((x & 0x7FFF) - 16_383), f32((y & 0x7FFF) - 16_383), f32((z & 0x7FFF) - 16_383)],
			0.000043161,
			((y >> 14) & 2) | ((x >> 15) & 1),
			(z >> 15) != 0
		)

# 40 bits: three 12-bit components, the index of the one left out (the largest) and its sign
fn pushQuat40(mut out f32[], v u64):
	out.pushThreeOfFour(
		[f32(i64(v & 0xFFF) - 2047), f32(i64((v >> 12) & 0xFFF) - 2047), f32(i64((v >> 24) & 0xFFF) - 2047)],
		0.000345436,
		(v >> 36) & 3,
		(v >> 38) & 1 != 0
	)

# A unit quaternion from three of its components, each `scale` times the number given, and the
# index of the fourth, which takes what is left of the length, negative when `negative`.
fn pushThreeOfFour(mut out f32[], given f32[3], scale f32, missing i64, negative bool):
	a = given[0] * scale
	b = given[1] * scale
	c = given[2] * scale
	w = (1.0 - a * a - b * b - c * c).max(0.0).sqrt()
	w = -w if negative else w
	parts = [a, b, c]
	k = 0
	for i in 0..4:
		if i == missing:
			out.push(w)
		else:
			out.push(parts[k])
			k += 1

# 32 bits: a direction in 18 bits (a ring index and the step around it) times the length
# left over by w, whose 10 bits give 1 - w's square root; the top four bits the signs
fn pushQuat32(mut out f32[], v u32):
	r = f32((v >> 18) & 0x3FF) / 1023.0
	w = 1.0 - r * r
	around = f32(v & 0x3_FFFF)
	ring = around.sqrt().floor()
	theta f32 = 0.0
	phi f32 = 0.0
	if ring > 0.0:
		theta = pi / 4.0 * (around - ring * ring) / ring
		phi = pi / 2.0 / 511.0 * ring
	m = (1.0 - w * w).max(0.0).sqrt()
	q = [phi.sin() * theta.cos() * m, phi.sin() * theta.sin() * m, phi.cos() * m, w]
	for i in 0..4:
		out.push(-q[i] if (v >> u32(28 + i)) & 1 != 0 else q[i])

# one block's curves: `tracks` transform tracks and `floats` float tracks from `start`
fn readSplineBlock(data u8[], start i64, tracks i64, floats i64) SplineBlock ? str:
	r = Reader(data, at = (start + tracks * 4 + floats).alignUp(4))
	list = []
	for t in 0..tracks:
		m = start + t * 4
		q = i64(data[m])
		translation = try r.readVector(data[m + 1], q & 3, 0.0)
		rotation = try r.readRotation(data[m + 2], (q >> 2) & 0xF)
		scale = try r.readVector(data[m + 3], (q >> 6) & 3, 1.0)
		if r.short: return "block data of track {t} runs past the end"
		list.push(TrackCurves(translation, rotation, scale))
	SplineBlock(tracks = list)

# the knot span of t: the i with knots[i] <= t < knots[i + 1], degree <= i < the point count
fn knotSpan(c Curve, t f32, count i64):
	if t >= c.knots[count]: return count - 1
	if t <= c.knots[c.degree]: return c.degree
	lo = c.degree
	hi = count
	mid = (lo + hi) / 2
	while t < c.knots[mid] or t >= c.knots[mid + 1]:
		if t < c.knots[mid]:
			hi = mid
		else:
			lo = mid
		mid = (lo + hi) / 2
	mid

# the curve at frame t of its block (its first `width` fields filled)
fn curveAt(c Curve, t f32):
	count = c.points.len / c.width
	out f32[4]
	if count == 1 or c.knots.isEmpty:
		for k in 0..c.width:
			out[k] = c.points[k]
		return Vec4(out[0], out[1], out[2], out[3])
	span = c.knotSpan(t, count)
	# the nonzero basis functions of the span, built up degree by degree
	n f32[5]
	n[0] = 1.0
	for i in 1..=c.degree:
		for k in 0..i:
			j = i - 1 - k
			a = (t - c.knots[span - j]) / (c.knots[span + i - j] - c.knots[span - j])
			part = n[j] * a
			n[j + 1] += n[j] - part
			n[j] = part
	for i in 0..=c.degree:
		p = (span - i) * c.width
		for k in 0..c.width:
			out[k] += c.points[p + k] * n[i]
	Vec4(out[0], out[1], out[2], out[3])

test "a spline of degree 1 is the line between its points":
	c = Curve(
		degree = 1,
		knots = [0.0, 0.0, 4.0, 4.0],
		points = [0.0, 10.0, -2.0, 4.0, 2.0, 2.0],
		width = 3
	)
	expect c.curveAt(0.0).x == 0.0
	mid = c.curveAt(1.0)
	expect mid.x == 1.0 and mid.y == 8.0 and mid.z == -1.0
	expect c.curveAt(4.0).y == 2.0

test "a 40-bit rotation of three zeros is the identity, its largest component where it says":
	out f32[] = []
	zeros = u64(2047) | (u64(2047) << 12) | (u64(2047) << 24)
	out.pushQuat40(zeros | (u64(3) << 36))
	out.pushQuat40(zeros | (u64(1) << 36) | (u64(1) << 38))
	expect out == [0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0]
