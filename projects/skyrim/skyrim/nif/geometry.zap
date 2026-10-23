# The shapes. Skyrim Special Edition's own (BSTriShape and the kinds that extend it) hold their
# vertices: a 64-bit vertex description whose low nibbles are the vertex's size and its parts'
# offsets (in 4-byte units: size, dynamic size, UV, second UV, normal, tangent, color, skinning) and
# whose bits from 44 say which parts there are, then the triangle and vertex counts, the data's
# size and the vertices and u16 triangles. A vertex is its position (three floats, or halves in
# Fallout 4's files without the full-precision bit) with the bitangent's x after it, the UV (two
# halves), the normal (three bytes, 0..255 for -1..1) with the bitangent's y, the tangent with
# its z, the color (four bytes) and the skinning (four half weights, four bone indices). The older
# NiTriShape and NiTriStrips point to a data block of plain arrays (NiTriShapeData, NiTriStripsData).

shapeKinds = ["BSTriShape", "BSDynamicTriShape", "BSMeshLODTriShape", "BSSubIndexTriShape"]
oldShapeKinds = ["NiTriShape", "NiTriStrips", "BSLODTriShape"]

vfVertex = 0x1
vfUv = 0x2
vfNormals = 0x8
vfTangents = 0x10
vfColors = 0x20
vfSkinned = 0x40
vfFullPrecision = 0x400

# what a renderer draws of one shape, in the shape's space
pub type Geometry:
	positions Vec3[] = []
	normals Vec3[] = []
	tangents Vec3[] = []   # as the file names them, when it keeps them
	bitangents Vec3[] = []
	uvs Vec2[] = []
	colors Vec4[] = []
	weights f32[] = []   # four per vertex
	bones i64[] = []   # four per vertex, indices into the skin's bones
	indices u32[] = []   # three per triangle

pub type Shape:
	av Av
	skin i64
	shader i64
	alpha i64
	data i64   # the data block of a NiTriShape; -1 when the geometry is the shape's own
	center Vec3   # the bounding sphere
	radius f32
	geometry Geometry
	lodTriangles i64 = -1   # a LOD shape's: the triangles of its first level, which come first

# the part at the nibble `shift` of a vertex description, in bytes from the vertex's start
fn partOffset(desc u64, shift i64):
	i64((desc >> shift) & 0xF) * 4

fn unitByte(b u8):
	f32(b) / 255.0 * 2.0 - 1.0

fn readVertex(d u8[], at i64, desc u64, full bool, mut g Geometry):
	attrs = i64(desc >> 44)
	if (attrs & vfVertex) != 0:
		g.positions.push(
			Vec3(d.f32le(at), d.f32le(at + 4), d.f32le(at + 8)) if full
			else Vec3(d.f16le(at), d.f16le(at + 2), d.f16le(at + 4))
		)
	if (attrs & vfTangents) != 0 and (attrs & vfNormals) != 0:
		n = at + partOffset(desc, 16)
		t = at + partOffset(desc, 20)
		g.tangents.push(Vec3(unitByte(d[t]), unitByte(d[t + 1]), unitByte(d[t + 2])))
		x = d.f32le(at + 12) if full else d.f16le(at + 6)
		g.bitangents.push(Vec3(x, unitByte(d[n + 3]), unitByte(d[t + 3])))
	if (attrs & vfUv) != 0:
		uv = at + partOffset(desc, 8)
		g.uvs.push(Vec2(d.f16le(uv), d.f16le(uv + 2)))
	if (attrs & vfNormals) != 0:
		n = at + partOffset(desc, 16)
		g.normals.push(Vec3(unitByte(d[n]), unitByte(d[n + 1]), unitByte(d[n + 2])))
	if (attrs & vfColors) != 0:
		c = at + partOffset(desc, 24)
		g.colors.push(Vec4(d[c], d[c + 1], d[c + 2], d[c + 3]) / 255.0)
	if (attrs & vfSkinned) != 0:
		w = at + partOffset(desc, 28)
		for k in 0..4:
			g.weights.push(d.f16le(w + k * 2))
		for k in 0..4:
			g.bones.push(d[w + 8 + k])

fn readTriangles(mut s Reader, count i64):
	if not s.has(count * 6): return []
	out = (0..count * 3).map(u32(s.d.u16le(s.at + it * 2)))
	s.at += count * 6
	out

fn readPackedVertices(mut s Reader, desc u64, vertices i64, triangles i64, bsVersion i64):
	g = Geometry()
	stride = partOffset(desc, 0)
	if not s.has(stride * vertices): return g
	full = bsVersion < 130 or (i64(desc >> 44) & vfFullPrecision) != 0
	for v in 0..vertices:
		readVertex(s.d, s.at + v * stride, desc, full, g)
	s.at += stride * vertices
	g.indices = s.readTriangles(triangles)
	g

# BSTriShape and its kinds, after Special Edition's particle data: BSMeshLODTriShape's levels'
# triangle counts, BSDynamicTriShape's positions (a face's, moved at run time) as four floats each
fn readTriShape(mut s Reader, names str[], kind str, bsVersion i64):
	av = s.readAv(names)
	center = s.vec3()
	radius = s.f32()
	skin = s.i32()
	shader = s.i32()
	alpha = s.i32()
	desc = s.u64()
	triangles = s.u32() if bsVersion >= 130 else s.u16()
	vertices = s.u16()
	size = s.u32()
	geometry = Geometry()
	if size > 0:
		if size != partOffset(desc, 0) * vertices + triangles * 6: s.short = true
		geometry = s.readPackedVertices(desc, vertices, triangles, bsVersion)
	if bsVersion == 100 and s.u32() > 0: s.skip(vertices * 12 + triangles * 6)
	lod = i64(s.u32()) if kind == "BSMeshLODTriShape" else -1
	if kind == "BSDynamicTriShape":
		count = s.u32() / 16
		if s.has(count * 16):
			geometry.positions = []
			loop count:
				geometry.positions.push(s.vec4().xyz)
	Shape(av, skin, shader, alpha, data = -1, center, radius, geometry, lodTriangles = lod)

# NiTriShape, NiTriStrips and BSLODTriShape (NiGeometry's fields): the data, the skin, the
# materials (names and extra data the renderer does not use), the shader and the alpha property;
# BSLODTriShape's first level's triangle count after them
fn readOldShape(mut s Reader, names str[], kind str):
	av = s.readAv(names)
	data = s.i32()
	skin = s.i32()
	materials = s.u32()
	s.skip(materials * 8 + 5)
	shader = s.i32()
	alpha = s.i32()
	Shape(
		av,
		skin,
		shader,
		alpha,
		data,
		center = Vec3(0, 0, 0),
		radius = 0.0,
		geometry = Geometry(),
		lodTriangles = s.u32() if kind == "BSLODTriShape" else -1
	)

fn readVec3s(mut s Reader, n i64):
	out = []
	if not s.has(n * 12): return out
	loop n:
		out.push(s.vec3())
	out

# NiGeometryData's arrays as Bethesda's 20.2.0.7 files keep them, up to the triangle count
fn readGeometryData(mut s Reader):
	g = Geometry()
	s.skip(4)   # the group id
	n = s.u16()
	s.skip(2)   # the keep and compress flags
	if s.u8() != 0: g.positions = s.readVec3s(n)
	dataFlags = s.u16()
	s.skip(4)   # the material's CRC
	if s.u8() != 0:
		g.normals = s.readVec3s(n)
		if (dataFlags & 4096) != 0:
			g.tangents = s.readVec3s(n)
			g.bitangents = s.readVec3s(n)
	s.skip(16)   # the bounding sphere
	if s.u8() != 0 and s.has(n * 16):
		loop n:
			g.colors.push(s.vec4())
	if (dataFlags & 1) != 0 and s.has(n * 8):
		loop n:
			g.uvs.push(s.vec2())
	s.skip(6)   # the consistency flags, the additional data
	(g, s.u16())

fn readTriShapeData(mut s Reader):
	g, triangles = s.readGeometryData()
	s.skip(4)   # the triangle points' count
	if s.u8() != 0: g.indices = s.readTriangles(triangles)
	g

# the triangles of strips, every other one turned back so all face one way, the empty ones left out
fn stripTriangles(points i64[], mut out u32[]):
	for i in 2..points.len:
		a = points[i - 2]
		b = points[i - 1]
		c = points[i]
		if a == b or b == c or a == c: continue
		if i % 2 == 0:
			out.extend([u32(a), u32(b), u32(c)])
		else:
			out.extend([u32(a), u32(c), u32(b)])

fn readTriStripsData(mut s Reader):
	g, _ = s.readGeometryData()
	strips = s.u16()
	if not s.has(strips * 2): return g
	lengths = s.numbers(strips, u16(0)).map(i64(it))
	if s.u8() == 0: return g
	for n in lengths:
		stripTriangles(s.numbers(n, u16(0)).map(i64(it)), g.indices)
	g
