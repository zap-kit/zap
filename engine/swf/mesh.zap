# A shape made ready to draw: for each fill style its triangles with the paint that covers them (a
# color, a bitmap or a gradient) and the matrix from the shape's space to the paint's, and for each
# line style the quads of its strokes. Gradients become images: a row of 256 colors for a linear
# one, a square of 128 for a radial one, read through the inverse of the gradient's matrix.

import image

# the triangles of one fill or line style, in the shape's space, and their paint
pub type MeshPart:
	color Vec4   # a solid fill's or a line's color; white under a bitmap or a gradient
	bitmap i64   # the bitmap's id, -1 none
	gradient i64   # the gradient's place in the mesh's images, -1 none
	paint Affine   # shape space to the bitmap's pixels or to the gradient image's 0..1
	smooth bool
	repeat bool
	triangles Vec2[]
	edges Vec4[] = []   # the outline: each edge's ends (x, y, z, w) once only one triangle has it
	insides Vec2[] = []   # for each edge, the third corner of its triangle: its inner side

# a shape's parts, and its gradients' images until they become textures
pub type ShapeMesh:
	parts MeshPart[]
	gradients image.Image[]

gamma f32 = 2.2   # a stop's color to linear RGB and back
gradientSquare f32 = 32768.0   # the gradient square's side, twips

# the shape's fills and lines as triangles, curves within `tolerance` (shape units) of the truth
pub fn shapeMesh(s Shape, tolerance f32) ShapeMesh:
	mesh = ShapeMesh(parts = [], gradients = [])
	for k, fill in s.fills:
		triangles = s.fillSegments(k + 1, tolerance).fillTriangles(s.nonzero)
		if triangles.isEmpty: continue
		part = MeshPart(
			color = Vec4(1.0, 1.0, 1.0, 1.0),
			bitmap = -1,
			gradient = -1,
			paint = Affine(),
			smooth = true, repeat = false, triangles)
		match fill:
			Solid(c): part.color = c
			Bitmap(id, m, repeat, smooth):
				part.bitmap = id
				part.paint = m.inverse()
				part.repeat = repeat
				part.smooth = smooth
			Gradient(g):
				part.gradient = mesh.gradients.len
				mesh.gradients.push(g.gradientImage())
				part.paint = g.gradientPaint()
		mesh.parts.push(part)
	for k, l in s.lines:
		triangles = s.strokeTriangles(k + 1, l.width.max(20.0), tolerance)
		if triangles.isEmpty: continue
		mesh.parts.push(MeshPart(color = l.color, bitmap = -1, gradient = -1, paint = Affine(),
			smooth = true, repeat = false, triangles))
	for mut part in mesh.parts:
		part.outline()
	mesh

# The part's outline found: the edges only one of its triangles has (an edge two share is inside),
# each with its triangle's third corner, where the fringe of edge anti-aliasing must not go.
fn outline(mut part MeshPart):
	count {str: i64} = {}
	for k in 0..part.triangles.len / 3:
		for j in 0..3:
			count.add(part.triangles[k * 3 + j].edgeKey(part.triangles[k * 3 + (j + 1) % 3]), 1)
	for k in 0..part.triangles.len / 3:
		for j in 0..3:
			a = part.triangles[k * 3 + j]
			b = part.triangles[k * 3 + (j + 1) % 3]
			if count[a.edgeKey(b)] != 1: continue
			part.edges.push(Vec4(a.x, a.y, b.x, b.y))
			part.insides.push(part.triangles[k * 3 + (j + 2) % 3])

# an edge's key, the same both ways along it
fn edgeKey(a Vec2, b Vec2):
	p = "{i64(a.x * 16.0)},{i64(a.y * 16.0)}"
	q = "{i64(b.x * 16.0)},{i64(b.y * 16.0)}"
	"{p};{q}" if p < q else "{q};{p}"

# shape space to the gradient image's 0..1: through the gradient square, then scaled into it
fn gradientPaint(g Gradient):
	toUnit = Affine(a = 1.0 / gradientSquare, d = 1.0 / gradientSquare, tx = 0.5, ty = 0.5)
	toUnit.times(g.matrix.inverse())

# the gradient's colors as an image: 256 by 1 (linear) or 128 by 128 (radial, the center in the
# middle, the last stop at the edge)
pub fn gradientImage(g Gradient) image.Image:
	if not g.radial:
		img = image.Image(256, 1, fill = image.Rgba8(0, 0, 0, 0))
		for x in 0..256:
			img[x, 0] = g.colorAt(f32(x) / 255.0)
		return img
	side = 128
	img = image.Image(side, side, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..side:
		for x in 0..side:
			at = Vec2(f32(x) + 0.5, f32(y) + 0.5) - Vec2(f32(side) / 2.0, f32(side) / 2.0)
			img[x, y] = g.colorAt(at.length() / (f32(side) / 2.0))
	img

# the color at t (0..1) along the stops, padded past the ends
pub fn colorAt(g Gradient, t f32) image.Rgba8:
	if g.stops.isEmpty: return image.Rgba8(0, 0, 0, 0)
	c = g.stops[0].color
	if t > g.stops[0].ratio:
		c = g.stops[len - 1].color
		for k in 1..g.stops.len:
			a = g.stops[k - 1]
			b = g.stops[k]
			if t <= b.ratio:
				f = (t - a.ratio) / (b.ratio - a.ratio).max(1e-6)
				c = a.color.mixColor(b.color, f, g.linearRgb)
				break
	image.Rgba8(
		image.unitToByte(c.x),
		image.unitToByte(c.y),
		image.unitToByte(c.z),
		image.unitToByte(c.w)
	)

fn mixColor(a Vec4, b Vec4, f f32, linear bool):
	if not linear: return a + (b - a) * f
	la = Vec4(a.x.pow(gamma), a.y.pow(gamma), a.z.pow(gamma), a.w)
	lb = Vec4(b.x.pow(gamma), b.y.pow(gamma), b.z.pow(gamma), b.w)
	m = la + (lb - la) * f
	Vec4(m.x.pow(1.0 / gamma), m.y.pow(1.0 / gamma), m.z.pow(1.0 / gamma), m.w)
