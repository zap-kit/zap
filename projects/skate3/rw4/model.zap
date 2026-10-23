# A model arena: its meshes (RenderOptiMeshData, 0x00EB0023), each drawing an index buffer over a
# vertex buffer with a vertex descriptor and a material; the materials (RenderMaterialData,
# 0x00EB0005) as lists of named parameters; and the instance placing the model (InstanceData).
#
# An OptiMesh holds its bounds, the handle of its material at 0x24 (0x00800000 + a subreference,
# which the table of contents ties to a material's GUID), and the dictionary indices of its vertex
# descriptor (0x28), index buffer (0x30) and vertex buffer (0x34); its primitive type is at 0x60
# (4: triangle list, 6: strip). Each buffer's bytes are the base resource just before it in the
# dictionary; an index buffer counts its 16-bit indices at 0x20, a vertex buffer its bytes.
#
# A vertex descriptor (16-byte header, the element count at 8) lists 16-byte elements: stream,
# offset, the Xenos vertex format (its low 6 bits the layout), method, usage (0 position, 5
# texture coordinate, 6 tangent, 3 normal, 1 and 2 blend weights and indices, 10 color), usage
# index, type; the strides follow. The static world keeps no normal: its second texture coordinate
# (four signed shorts) holds the lightmap's coordinates in x and y (their absolute values) and the
# normal's x and y in z and w, the sign of y giving the normal's z.

import engine

# a material's texture on one channel (diffuse, lightmap, normal, ...)
pub type ChannelTexture:
	channel str
	id i64

# a material's parameters, as the game names them (diffuse, lightmap, normal, specular, ...):
# textures by their 64-bit ids, numbers, and the shader's name
pub type Material:
	name str
	shader str   # AttribulatorMaterialName: environment.default, ...
	guid i64
	textures ChannelTexture[]
	numbers ChannelNumber[]

pub type ChannelNumber:
	channel str
	value f32

pub type VertexElement:
	offset i64
	format i64   # the Xenos layout (the format's low 6 bits)
	code i64   # the whole format word
	usage i64
	usageIndex i64

# a vertex of a mesh, decoded; the parts its mesh lacks (ModelMesh's flags) are zero
pub type MeshVertex:
	position Vec3
	uv Vec2   # the first texture coordinate
	decalUv Vec2   # its z, w when it has four (a decal's)
	lightmapUv Vec2   # the second, made positive
	normal Vec3   # a stored one, else made from the faces

# one mesh of a model, its vertices decoded
pub type ModelMesh:
	material i64   # index in the model's materials, -1 none
	vertices Table<MeshVertex>
	hasDecal bool
	hasLightmap bool
	indices i64[]   # a triangle list
	elements VertexElement[]
	stride i64

pub type Model:
	materials Material[]
	meshes ModelMesh[]
	transform f32[]   # the instance's 4x4 matrix (rows), identity when none
	name str

pub usagePosition = 0
pub usageBlendWeight = 1
pub usageBlendIndices = 2
pub usageNormal = 3
pub usageTexcoord = 5
pub usageTangent = 6
pub usageColor = 10

# The materials of the arena's RenderMaterialData objects, in order: a header (the parameter count
# at 4, the header's size at 12, where the parameters end at 16) then 32-byte parameters: the
# offset of the parameter's name, its kind (0xFFFF: a GUID at 16 and a string at the offset at 24;
# 0x20000: a float at 16). A parameter named "Name" begins a material.
pub fn arenaMaterials(a Arena) Material[]:
	out = []
	for k in a.objectsOf(typeRenderMaterial):
		at = a.entries[k].at
		d = a.bytes
		count = d.u32be(at + 4)
		headerSize = i64(d.u32be(at + 12))
		for i in 0..count:
			p = at + headerSize + i * 32
			name = d.cStringAt(at + d.u32be(p), 128)
			kind = d.u32be(p + 4)
			if name == "Name":
				out.push(
					Material(
						name = d.cStringAt(at + d.u32be(p + 24), 512),
						shader = "",
						guid = d.i64be(p + 16),
						textures = [],
						numbers = []
					)
				)
				continue
			if out.isEmpty: continue
			last = out.len - 1
			if kind == 0x2_0000:
				out[last].numbers.push((name, d.f32be(p + 16)))
			elif name == "AttribulatorMaterialName":
				out[last].shader = d.cStringAt(at + d.u32be(p + 24), 128)
			else:
				id = d.i64be(p + 16)
				if id != 0:
					out[last].textures.push((name, id))
	out

# the texture id of a material's channel, 0 when it has none
pub fn materialTexture(m Material, channel str) i64:
	for t in m.textures:
		if t.channel == channel: return t.id
	0

# The model of a model arena, its meshes decoded; or why it cannot be read.
pub fn readModel(a Arena) Model ? str:
	materials = a.arenaMaterials()
	toc = a.tableOfContents()
	d = a.bytes
	meshes = []
	for k in a.objectsOf(typeOptiMesh):
		at = a.entries[k].at
		handle = d.u32be(at + 0x24)
		material = -1
		for t in toc:
			if t.object == handle and t.kind == 0x00EB_0066:
				for mi in 0..materials.len:
					if materials[mi].guid == t.id:
						material = mi
		descriptor = d.u32be(at + 0x28)
		indexBuffer = d.u32be(at + 0x30)
		vertexBuffer = d.u32be(at + 0x34)
		primitive = d.u32be(at + 0x60)
		if descriptor >= a.entries.len or indexBuffer >= a.entries.len or
			vertexBuffer >= a.entries.len or indexBuffer < 1 or vertexBuffer < 1:
			return "an OptiMesh refers past the dictionary"
		meshes.push(try a.readMesh(descriptor, vertexBuffer, indexBuffer, primitive, material))
	transform = [
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0
	].map(f32(it))
	name = ""
	for k in a.objectsOf(typeInstance):
		at = a.entries[k].at
		m = at + d.u32be(at + 12)
		for i in 0..16:
			transform[i] = d.f32be(m + i * 4)
		name = d.cStringAt(at + 0xC0, 256)
		break
	Model(materials, meshes, transform, name)

# the elements and stride of a vertex descriptor
pub fn vertexElements(a Arena, k i64) (VertexElement[], i64):
	at = a.entries[k].at
	d = a.bytes
	count = i64(d.u16be(at + 8))
	out = (0..count).map(i:
		e = at + 16 + i * 16
		code = d.u32be(e + 4)
		VertexElement(
			offset = d.u16be(e + 2),
			format = code & 63,
			code,
			usage = d[e + 9],
			usageIndex = d[e + 10]
		)
	)
	(out, d[at + 16 + count * 16])

fn readMesh(
	a Arena,
	descriptor i64,
	vertexBuffer i64,
	indexBuffer i64,
	primitive i64,
	material i64
) ModelMesh ? str:
	d = a.bytes
	elements, stride = a.vertexElements(descriptor)
	if stride <= 0: return "a vertex descriptor without a stride"
	vbAt = a.entries[vertexBuffer - 1].at
	vbSize = i64(d.u32be(a.entries[vertexBuffer].at + 0x20))
	count = vbSize / stride
	ibAt = a.entries[indexBuffer - 1].at
	indexCount = i64(d.u32be(a.entries[indexBuffer].at + 0x20))
	if vbAt + count * stride > d.len or ibAt + indexCount * 2 > d.len:
		return "a mesh's buffers run past the arena"
	vertices Table<MeshVertex> = []
	vertices.reserve(count)
	normals = 0   # the vertices given a normal
	texcoords = []
	position = VertexElement(offset = 0, format = 57, code = 0, usage = 0, usageIndex = 0)
	normal VertexElement? = none
	for e in elements:
		if e.usage == usagePosition and e.usageIndex == 0:
			position = e
		elif e.usage == usageTexcoord:
			texcoords.push(e)
		elif e.usage == usageNormal:
			normal = e
	texcoords = texcoords.sortedBy(.usageIndex)
	hasDecal = not texcoords.isEmpty and (texcoords[0].format == 32 or texcoords[0].format == 38)
	hasLightmap = texcoords.len > 1
	values = fill(4, 0.0).map(f32(it))
	for i in 0..count:
		v = vbAt + i * stride
		readElement(d, v + position.offset, position.format, values)
		vertex = MeshVertex(
			position = Vec3(values),
			uv = Vec2(0.0, 0.0),
			decalUv = Vec2(0.0, 0.0),
			lightmapUv = Vec2(0.0, 0.0),
			normal = Vec3(0.0, 0.0, 0.0)
		)
		if not texcoords.isEmpty:
			readElement(d, v + texcoords[0].offset, texcoords[0].format, values)
			vertex.uv = Vec2(values)
			if hasDecal:
				vertex.decalUv = Vec2(values, 2)
		if hasLightmap:
			readElement(d, v + texcoords[1].offset, texcoords[1].format, values)
			vertex.lightmapUv = Vec2(values[0].abs(), values[1].abs())
			# four signed shorts: the normal's x and y, its z's sign in y's
			if texcoords[1].format == 26 and normal == none:
				nx = values[2]
				ny = values[3]
				nz = (1.0 - nx * nx - ny * ny).max(0.0).sqrt()
				vertex.normal = Vec3(nx, ny, nz if values[1] > 0.0 else -nz)
				normals += 1
		if normal is n:
			readElement(d, v + n.offset, n.format, values)
			vertex.normal = Vec3(values)
			normals += 1
		vertices.push(vertex)
	indices i64[] = []
	if primitive == 6:
		# a strip: each index after the second makes a triangle, every other one turned round; a
		# restart index (0xFFFF) begins a new strip
		run = 0
		for i in 0..indexCount:
			x = d.u16be(ibAt + i * 2)
			if x == 0xFFFF:
				run = 0
				continue
			if run >= 2:
				p0 = d.u16be(ibAt + (i - 2) * 2)
				p1 = d.u16be(ibAt + (i - 1) * 2)
				if p0 != p1 and p1 != x and p0 != x:
					if run % 2 == 0:
						indices.push(p0)
						indices.push(p1)
					else:
						indices.push(p1)
						indices.push(p0)
					indices.push(x)
			run += 1
	else:
		for i in 0..indexCount / 3 * 3:
			indices.push(d.u16be(ibAt + i * 2))
	for x in indices:
		if x >= count: return "a mesh's index {x} is past its {count} vertices"
	if normals != count:
		# one smooth normal a vertex, made from the faces
		for i, n in engine.vertexNormals(vertices.position, indices):
			vertices.normal[i] = n
	ModelMesh(material, vertices, hasDecal, hasLightmap, indices, elements, stride)

# The value of a vertex element at `at` into `out` (up to four components), by its Xenos layout.
pub fn readElement(d u8[], at i64, format i64, mut out f32[]):
	out[0] = 0.0
	out[1] = 0.0
	out[2] = 0.0
	out[3] = 1.0
	if format in [57, 37, 38, 36]:
		n = 1 if format == 36 else 2 if format == 37 else 3 if format == 57 else 4
		for i in 0..n:
			out[i] = d.f32be(at + i * 4)
	elif format == 31 or format == 32:
		n = 2 if format == 31 else 4
		for i in 0..n:
			out[i] = d.f16be(at + i * 2)
	elif format == 25 or format == 26:
		n = 2 if format == 25 else 4
		for i in 0..n:
			out[i] = f32(i64(d.i16be(at + i * 2)) / 32767.0)
	elif format == 6:
		for i in 0..4:
			out[i] = f32(d[at + i] / 255.0)
	elif format in [16, 17, 7]:
		w = d.u32be(at)
		if format == 7:
			out[0] = signedField(w, 0, 10, 511.0)
			out[1] = signedField(w, 10, 10, 511.0)
			out[2] = signedField(w, 20, 10, 511.0)
		else:
			out[0] = signedField(w, 0, 11, 1023.0)
			out[1] = signedField(w, 11, 11, 1023.0)
			out[2] = signedField(w, 22, 10, 511.0)

fn signedField(w i64, shift i64, bits i64, scale f64):
	v = (w >> shift) & ((1 << bits) - 1)
	if v >= 1 << (bits - 1):
		v -= 1 << bits
	f32(v / scale)
