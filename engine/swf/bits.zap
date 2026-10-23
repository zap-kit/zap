# The SWF's basic records read from a tag's bytes: little-endian numbers and, between them, bit
# fields taken from a byte's highest bit first (UB, SB and FB in Adobe's SWF specification v19,
# chapter 1); a byte-aligned read drops the bits left of the byte begun. Rectangles, matrices and
# color transforms are bit records, colors bytes. A read past the tag's end gives 0 and sets
# `short`, so a record is checked once.

# a cursor over one tag's bytes, from `at` to `end`
pub type TagReader:
	d ref u8[]
	at i64 = 0
	end i64 = 0
	byte i64 = 0   # the byte bits are taken from
	left i64 = 0   # its bits not taken yet
	short bool = false

	# whether n more bytes are there; past the end the cursor stays at it, short
	fn has(n i64):
		left = 0
		if n < 0 or at + n > end:
			short = true
			at = end
			return false
		true

	# the bytes left in the tag
	pub fn remaining() i64:
		(end - at).max(0)

	pub mut fn align():
		left = 0

	pub mut fn u8() i64:
		if not has(1): return 0
		at += 1
		d[at - 1]

	pub mut fn u16() i64:
		if not has(2): return 0
		at += 2
		d.u16le(at - 2)

	pub mut fn i16() i64:
		if not has(2): return 0
		at += 2
		d.i16le(at - 2)

	pub mut fn u32() i64:
		if not has(4): return 0
		at += 4
		d.u32le(at - 4)

	pub mut fn float() f32:
		if not has(4): return 0.0
		at += 4
		d.f32le(at - 4)

	# FIXED8: 8.8, and FIXED: 16.16
	pub mut fn fixed8() f32:
		f32(i16()) / 256.0

	pub mut fn fixed() f32:
		f32(i32.wrap(u32())) / 65536.0

	pub mut fn bytes(n i64) u8[]:
		if not has(n): return []
		at += n
		d[at - n..at].copy()

	# the bytes up to the tag's end
	pub mut fn rest() u8[]:
		bytes(remaining())

	# a STRING: bytes up to a NUL
	pub mut fn text() str:
		left = 0
		start = at
		while at < end and d[at] != 0:
			at += 1
		s = str(d[start..at].copy())
		if at < end: at += 1
		else: short = true
		s

	# a length byte, then that many bytes (Scaleform's strings)
	pub mut fn shortText() str:
		n = u8()
		str(bytes(n))

	# n bits as an unsigned number (UB)
	pub mut fn ub(n i64) i64:
		v = 0
		loop n:
			if left == 0:
				if at >= end:
					short = true
					return 0
				byte = d[at]
				at += 1
				left = 8
			left -= 1
			v = (v << 1) | ((byte >> left) & 1)
		v

	# n bits as a signed number (SB)
	pub mut fn sb(n i64) i64:
		if n == 0: return 0
		v = ub(n)
		v - (1 << n) if (v >> (n - 1)) & 1 == 1 else v

	# n bits as a signed 16.16 number (FB)
	pub mut fn fb(n i64) f32:
		f32(sb(n)) / 65536.0

	pub mut fn rect() Rect:
		align()
		n = ub(5)
		r = Rect(xmin = f32(sb(n)), xmax = f32(sb(n)), ymin = f32(sb(n)), ymax = f32(sb(n)))
		align()
		r

	pub mut fn matrix() Affine:
		align()
		m = Affine()
		if ub(1) == 1:
			n = ub(5)
			m.a = fb(n)
			m.d = fb(n)
		if ub(1) == 1:
			n = ub(5)
			m.b = fb(n)
			m.c = fb(n)
		n = ub(5)
		m.tx = f32(sb(n))
		m.ty = f32(sb(n))
		align()
		m

	# CXFORM (alpha false) or CXFORMWITHALPHA: multipliers 8.8, additions 0..255
	pub mut fn colorTransform(alpha bool) ColorTransform:
		align()
		hasAdd = ub(1) == 1
		hasMul = ub(1) == 1
		n = ub(4)
		t = ColorTransform()
		channels = 4 if alpha else 3
		if hasMul:
			m f32[] = [1.0, 1.0, 1.0, 1.0]
			for k in 0..channels:
				m[k] = f32(sb(n)) / 256.0
			t.mul = Vec4(m[0], m[1], m[2], m[3])
		if hasAdd:
			a f32[] = [0.0, 0.0, 0.0, 0.0]
			for k in 0..channels:
				a[k] = f32(sb(n)) / 255.0
			t.add = Vec4(a[0], a[1], a[2], a[3])
		align()
		t

	pub mut fn rgb() Vec4:
		r = u8()
		g = u8()
		b = u8()
		Vec4(f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0, 1.0)

	pub mut fn rgba() Vec4:
		c = rgb()
		c.a = f32(u8()) / 255.0
		c

	# a color as a shape of version `shapeVersion` stores it: RGB before DefineShape3, RGBA from it
	pub mut fn shapeColor(shapeVersion i64) Vec4:
		rgba() if shapeVersion >= 3 else rgb()

# a rectangle in twips (a twentieth of a pixel)
pub type Rect:
	xmin f32 = 0.0
	ymin f32 = 0.0
	xmax f32 = 0.0
	ymax f32 = 0.0

# x' = a x + c y + tx, y' = b x + d y + ty, in twips
pub type Affine:
	a f32 = 1.0
	b f32 = 0.0
	c f32 = 0.0
	d f32 = 1.0
	tx f32 = 0.0
	ty f32 = 0.0

# a color times `mul` plus `add`, each channel 0..1 (r, g, b, a)
pub type ColorTransform:
	mul Vec4 = Vec4(1.0, 1.0, 1.0, 1.0)
	add Vec4 = Vec4(0.0, 0.0, 0.0, 0.0)

# a reader of the bytes from `at` to `end`
pub fn newReader(d ref u8[], at i64, end i64) TagReader:
	TagReader(d, at, end = end.min(d.len))

# ---------- matrices and transforms combined ----------

# the point p under m
pub fn apply(m Affine, p Vec2) Vec2:
	Vec2(m.a * p.x + m.c * p.y + m.tx, m.b * p.x + m.d * p.y + m.ty)

# m after `inner`: a point goes through inner first
pub fn times(m Affine, inner Affine) Affine:
	Affine(
		a = m.a * inner.a + m.c * inner.b,
		b = m.b * inner.a + m.d * inner.b,
		c = m.a * inner.c + m.c * inner.d,
		d = m.b * inner.c + m.d * inner.d,
		tx = m.a * inner.tx + m.c * inner.ty + m.tx,
		ty = m.b * inner.tx + m.d * inner.ty + m.ty
	)

# the matrix that undoes m (the identity when m flattens the plane)
pub fn inverse(m Affine) Affine:
	det = m.a * m.d - m.b * m.c
	if det.abs() < 1e-12: return Affine()
	a = m.d / det
	b = -m.b / det
	c = -m.c / det
	d = m.a / det
	Affine(a, b, c, d, tx = -(a * m.tx + c * m.ty), ty = -(b * m.tx + d * m.ty))

# t after `inner`: a color goes through inner first
pub fn then(t ColorTransform, inner ColorTransform) ColorTransform:
	ColorTransform(mul = inner.mul * t.mul, add = inner.add * t.mul + t.add)

# the color c under t, each channel clamped to 0..1
pub fn applyColor(t ColorTransform, c Vec4) Vec4:
	v = c * t.mul + t.add
	Vec4(v.x.clamp(0.0, 1.0), v.y.clamp(0.0, 1.0), v.z.clamp(0.0, 1.0), v.w.clamp(0.0, 1.0))

# the rectangle's corners under m, bounded again
pub fn transformRect(m Affine, r Rect) Rect:
	corners = [
		m.apply(Vec2(r.xmin, r.ymin)),
		m.apply(Vec2(r.xmax, r.ymin)),
		m.apply(Vec2(r.xmin, r.ymax)),
		m.apply(Vec2(r.xmax, r.ymax))
	]
	out = Rect(xmin = corners[0].x, ymin = corners[0].y, xmax = corners[0].x, ymax = corners[0].y)
	for p in corners:
		out.xmin = out.xmin.min(p.x)
		out.ymin = out.ymin.min(p.y)
		out.xmax = out.xmax.max(p.x)
		out.ymax = out.ymax.max(p.y)
	out
