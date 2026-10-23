# DefineShape 1 to 4 and the glyph shapes of the fonts (SWF specification v19, chapter 6): the fill
# styles (solid, linear, radial and focal gradients, bitmaps with their matrices), the line styles
# (LINESTYLE, and LINESTYLE2's width and fill), and the shape records: a style change (a move, the
# fill on each side of the edges that follow, their line, new style arrays) and straight and
# curved edges. Each edge keeps the styles in force where it was drawn, as indices into the
# shape's fills and lines that count from 1 over every array the shape declared (0: none).

# a color at a place along a gradient
pub type GradientStop:
	ratio f32   # 0..1 along the gradient
	color Vec4

# the gradient square is -16384..16384 twips each way, placed by `matrix`
pub type Gradient:
	radial bool
	matrix Affine
	stops GradientStop[]
	spread i64   # 0 pad, 1 reflect, 2 repeat
	linearRgb bool   # stops blended in linear RGB
	focal f32   # -1..1, the focal point of a focal radial gradient

# a fill style
pub type Fill:
	Solid(color Vec4)
	Gradient(gradient Gradient)
	Bitmap(id i64, matrix Affine, repeat bool, smooth bool)

# a line style: its width and color (a filled line's first color)
pub type LineStyle:
	width f32   # twips
	color Vec4

# a straight or curved edge with the styles in force on it
pub type Edge:
	from Vec2
	control Vec2   # a curve's control point (a straight edge's is its middle)
	to Vec2
	curved bool
	fill0 i64   # the fill on the edge's left (from start to end), 0 none
	fill1 i64   # on its right
	line i64

# a DefineShape, or a glyph's shape (its one fill the glyph's)
pub type Shape:
	id i64
	bounds Rect
	fills Fill[]
	lines LineStyle[]
	edges Edge[]
	nonzero bool   # DefineShape4's UsesFillWindingRule; else the even-odd rule

# DefineShape (tag 2), 2 (22), 3 (32) or 4 (83), the version 1 to 4
pub fn readShape(mut r TagReader, version i64) Shape:
	s = Shape(id = r.u16(), bounds = r.rect(), fills = [], lines = [], edges = [], nonzero = false)
	if version >= 4:
		r.rect()   # the edge bounds
		s.nonzero = (r.u8() & 4) != 0
	r.readStyles(version, s)
	fillBits = r.ub(4)
	lineBits = r.ub(4)
	r.readRecords(version, s, fillBits, lineBits)
	s

# a font's glyph: a SHAPE whose fill 1 is the glyph's
pub fn readGlyphShape(mut r TagReader) Shape:
	s = Shape(id = 0, bounds = Rect(), fills = [.Solid(Vec4(1.0, 1.0, 1.0, 1.0))], lines = [],
		edges = [], nonzero = false)
	r.align()
	fillBits = r.ub(4)
	lineBits = r.ub(4)
	r.readRecords(1, s, fillBits, lineBits)
	s

fn readStyles(mut r TagReader, version i64, mut s Shape):
	n = r.u8()
	if n == 255 and version >= 2: n = r.u16()
	loop n:
		s.fills.push(r.readFill(version))
	n = r.u8()
	if n == 255 and version >= 2: n = r.u16()
	loop n:
		s.lines.push(r.readLineStyle(version))

# a FILLSTYLE of a shape of version 1 to 4
pub fn readFill(mut r TagReader, version i64) Fill:
	kind = r.u8()
	if kind == 0: return .Solid(r.shapeColor(version))
	if kind in [0x10, 0x12, 0x13]:
		m = r.matrix()
		spread = r.ub(2)
		linearRgb = r.ub(2) == 1
		n = r.ub(4)
		stops = []
		loop n:
			ratio = f32(r.u8()) / 255.0
			stops.push(GradientStop(ratio, color = r.shapeColor(version)))
		focal = r.fixed8() if kind == 0x13 else 0.0
		return .Gradient(
			Gradient(radial = kind != 0x10, matrix = m, stops, spread, linearRgb, focal)
		)
	if kind >= 0x40 and kind <= 0x43:
		id = r.u16()
		m = r.matrix()
		return .Bitmap(id, m, kind == 0x40 or kind == 0x42, kind <= 0x41)
	r.short = true
	.Solid(Vec4(0.0, 0.0, 0.0, 0.0))

fn readLineStyle(mut r TagReader, version i64):
	width = f32(r.u16())
	if version < 4: return LineStyle(width, color = r.shapeColor(version))
	r.ub(2)   # the start cap
	join = r.ub(2)
	hasFill = r.ub(1) == 1
	r.ub(16 - 5)   # no horizontal or vertical scale, pixel hinting, reserved, no close, the end cap
	if join == 2: r.u16()   # the miter limit
	if not hasFill: return LineStyle(width, color = r.rgba())
	color = match r.readFill(version):
		Solid(c): c
		Gradient(g): g.stops[0].color if not g.stops.isEmpty else Vec4(0.0, 0.0, 0.0, 1.0)
		Bitmap: Vec4(0.5, 0.5, 0.5, 1.0)
	LineStyle(width, color)

# The shape records up to the end record. A style change's indices count in the arrays of the
# record that declared them, new styles in the same record included.
fn readRecords(mut r TagReader, version i64, mut s Shape, fillBits0 i64, lineBits0 i64):
	fillBits = fillBits0
	lineBits = lineBits0
	fillBase = 0
	lineBase = 0
	at = Vec2(0.0, 0.0)
	fill0 = 0
	fill1 = 0
	line = 0
	while not r.short:
		if r.ub(1) == 0:
			flags = r.ub(5)
			if flags == 0: return
			if (flags & 1) != 0:
				n = r.ub(5)
				x = f32(r.sb(n))
				at = Vec2(x, f32(r.sb(n)))
			new0 = r.ub(fillBits) if (flags & 2) != 0 else -1
			new1 = r.ub(fillBits) if (flags & 4) != 0 else -1
			newLine = r.ub(lineBits) if (flags & 8) != 0 else -1
			if (flags & 16) != 0 and version >= 2:
				fillBase = s.fills.len
				lineBase = s.lines.len
				r.readStyles(version, s)
				fillBits = r.ub(4)
				lineBits = r.ub(4)
			if new0 >= 0: fill0 = new0 + fillBase if new0 > 0 else 0
			if new1 >= 0: fill1 = new1 + fillBase if new1 > 0 else 0
			if newLine >= 0: line = newLine + lineBase if newLine > 0 else 0
		elif r.ub(1) == 1:
			n = r.ub(4) + 2
			dx = 0
			dy = 0
			if r.ub(1) == 1:
				dx = r.sb(n)
				dy = r.sb(n)
			elif r.ub(1) == 1:
				dy = r.sb(n)
			else:
				dx = r.sb(n)
			to = Vec2(at.x + f32(dx), at.y + f32(dy))
			s.edges.push(
				Edge(from = at, control = (at + to) * 0.5, to, curved = false, fill0, fill1, line)
			)
			at = to
		else:
			n = r.ub(4) + 2
			cx = f32(r.sb(n))
			cy = f32(r.sb(n))
			control = Vec2(at.x + cx, at.y + cy)
			ax = f32(r.sb(n))
			to = Vec2(control.x + ax, control.y + f32(r.sb(n)))
			s.edges.push(Edge(from = at, control, to, curved = true, fill0, fill1, line))
			at = to
