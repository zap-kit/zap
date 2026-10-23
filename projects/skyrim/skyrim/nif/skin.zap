# Skinning. A skinned shape of Special Edition keeps no vertices of its own: they are in its skin
# instance's NiSkinPartition (Special Edition puts the whole vertex buffer there, as BSTriShape
# lays it out, before the partitions). Each partition maps its vertices to that buffer's and names
# the bones it uses; its weights and bone indices are by its own numbering, so they are turned into
# the buffer's vertices and the skin instance's bones here. Its triangles are taken from the copy
# Special Edition keeps by the buffer's numbering: the first list is not always by the
# partition's (a head's second partition holds the buffer's numbers there too).

pub type Skin:
	data i64   # NiSkinData: the bones' bind transforms
	partition i64
	root i64   # the skeleton's root node
	bones i64[]   # the nodes, which bone indices count from

# NiSkinInstance and BSDismemberSkinInstance (which adds body parts after)
fn readSkin(mut s Reader):
	data = s.i32()
	partition = s.i32()
	root = s.i32()
	Skin(data, partition, root, bones = s.readRefs())

# NiSkinData: each bone's transform from the skin's space to the bone's in the bind pose, the
# skin-to-bone matrix a posed vertex is moved by before its bone's world matrix
pub type SkinData:
	transform Mat4   # the skin's own, from the skeleton's root
	bones Mat4[]

fn readSkinData(mut s Reader):
	transform = s.readSkinTransform()
	count = s.u32()
	weighted = s.u8() != 0
	bones = []
	loop count:
		if s.short: break
		bones.push(s.readSkinTransform())
		s.skip(16)   # the bounding sphere
		if weighted: s.skip(s.u16() * 6)
	SkinData(transform, bones)

type Partition:
	vertexMap i64[]
	bones i64[]
	weights f32[]
	boneIndices i64[]
	triangles u32[]   # by the partition's numbering
	perVertex i64
	bufferTriangles u32[]   # Special Edition's copy by the buffer's numbering

fn readPartition(mut s Reader, bsVersion i64):
	vertices = s.u16()
	triangles = s.u16()
	bones = s.u16()
	strips = s.u16()
	perVertex = s.u16()
	p = Partition(
		vertexMap = [],
		bones = s.numbers(bones, u16(0)).map(i64(it)),
		weights = [],
		boneIndices = [],
		triangles = [],
		perVertex,
		bufferTriangles = []
	)
	if s.u8() != 0: p.vertexMap = s.numbers(vertices, u16(0)).map(i64(it))
	if s.u8() != 0 and s.has(vertices * perVertex * 4):
		loop vertices * perVertex:
			p.weights.push(s.f32())
	lengths = s.numbers(strips, u16(0)).map(i64(it))
	if s.u8() != 0:
		if strips == 0:
			p.triangles = s.readTriangles(triangles)
		else:
			for n in lengths:
				stripTriangles(s.numbers(n, u16(0)).map(i64(it)), p.triangles)
	if s.u8() != 0:
		loop vertices * perVertex:
			p.boneIndices.push(s.u8())
	s.skip(2)   # the level of detail, the global buffer flag
	if bsVersion == 100:
		s.skip(8)   # the vertex description
		p.bufferTriangles = s.readTriangles(triangles)
	p

# the shared buffer's vertex of the partition's vertex k
fn bufferVertex(p Partition, k i64):
	p.vertexMap[k] if k < p.vertexMap.len else k

# a partition's triangles, weights and bones put in the shared buffer's numbering
fn addPartition(p Partition, mut g Geometry):
	if p.bufferTriangles.isEmpty:
		g.indices.extend(p.triangles.map(u32(p.bufferVertex(it))))
	else:
		g.indices.extend(p.bufferTriangles)
	for k in 0..p.vertexMap.len:
		at = p.bufferVertex(k) * 4
		for w in 0..p.perVertex.min(4):
			if at + w >= g.weights.len: break
			if k * p.perVertex + w < p.weights.len:
				g.weights[at + w] = p.weights[k * p.perVertex + w]
			local = p.boneIndices[k * p.perVertex + w] if k * p.perVertex + w < p.boneIndices.len
				else 0
			g.bones[at + w] = p.bones[local] if local < p.bones.len else 0

fn readSkinPartition(mut s Reader, bsVersion i64):
	partitions = s.u32()
	g = Geometry()
	vertices = 0   # a face's buffer has no positions: its shape keeps them (BSDynamicTriShape)
	if bsVersion == 100:
		size = s.u32()
		stride = s.u32()
		desc = s.u64()
		if stride > 0:
			vertices = size / stride
			g = s.readPackedVertices(desc, vertices, 0, bsVersion)
	g.weights = fill(vertices * 4, f32(0.0))
	g.bones = fill(vertices * 4, 0)
	loop partitions:
		if s.short: break
		s.readPartition(bsVersion).addPartition(g)
	g

# the drawn node named `name`, none when the model draws none of that name
fn drawnNode(n Nif, d Drawn, name str) Mat4?:
	for i in d.worlds.keys():
		if n.blockName(i) == name: return d.worlds[i]
	none

# A skinned part whose bones are all nodes of its own model (a hanging rabbit on its own ragdoll's
# bones) posed where the model places them, made rigid; none when a bone is not in the model.
pub fn posedInPlace(n Nif, d Drawn, p Part) Part?:
	moves = []
	for k, name in p.boneNames:
		bone = try n.drawnNode(d, name)
		moves.push(bone @ p.skinToBone[k])
	out = p.copy()
	for j in 0..p.positions.len:
		at = Vec3(0.0, 0.0, 0.0)
		normal = Vec3(0.0, 0.0, 0.0)
		for c in 0..4:
			w = p.weights[j * 4 + c]
			if w <= 0.0: continue
			m = moves[p.bones[j * 4 + c]]
			at += m.applyPoint(p.positions[j]) * w
			if j < p.normals.len: normal += m.applyDirection(p.normals[j]) * w
		out.positions[j] = at
		if j < p.normals.len: out.normals[j] = normal.normalized()
	out.tangents = []
	out.bitangents = []
	out.skinned = false
	out
