# RSM, a model: "GRSM", a version, the animation's length, how it is shaded (0 none, 1 flat,
# 2 smooth), its textures (names under data\texture\), then its nodes, each a mesh with a name
# and its parent's: the textures it uses, a 3 x 3 matrix and a pivot (the mesh's own offset), a
# position, a rotation (an angle in radians about an axis) and a scale relative to its parent,
# its vertices, texture coordinates and triangles, and rotation keyframes (quaternions). From
# 2.2 names have lengths, the node transform is a matrix with position, rotation and scale
# keyframes, and from 2.3 each node names its own textures. Values are in the file's axes (y
# down).

pub shadeNone = 0
pub shadeFlat = 1
pub shadeSmooth = 2

pub type Face:
	vertices u16[3]
	uvs u16[3]
	texture i64   # an index into the node's textures
	twoSided bool
	smoothGroup i64

# a face as the file holds it (newer files put its size first, older ones no smoothing group)
type FaceRecord:
	vertices u16[3]
	uvs u16[3]
	texture u16
	unused u16
	twoSided i32

# a keyframe as the file holds it: its time, its value, a word unused
type VecRecord:
	time i32
	v Vec3
	unused u32

type TurnRecord:
	time i32
	q f32[4]

pub type RotFrame:
	time i64
	q f32[4]   # x, y, z, w

pub type VecFrame:
	time i64
	v Vec3

pub type Node:
	name u8[]
	parentName u8[]
	textures i64[]   # indexes into the model's textures
	offset Mat4   # the 3 x 3 matrix, as a 4 x 4 one
	pivot Vec3   # where the mesh sits in its node
	position Vec3   # the node relative to its parent (before 2.2)
	rotAngle f32
	rotAxis Vec3
	scale Vec3
	vertices Vec3[]
	uvs Vec2[]
	faces Face[]
	rotFrames RotFrame[]
	posFrames VecFrame[]
	scaleFrames VecFrame[]
	parent i64   # the parent node's index, -1 for the root
	children i64[]

pub type Rsm:
	version i64   # major * 256 + minor
	animLength i64
	shade i64
	alpha f32
	textures u8[,]
	nodes Node[]
	root i64

# a name of the newer files: its length, then its bytes
fn lengthText(mut r Reader) u8[]:
	n = r.u32()
	if n > 1024:
		r.short = true
		return []
	r.cStringBytes(n)

# the model of an RSM file, or why it cannot be read
pub fn parseRsm(d u8[]) Rsm ? str:
	if d.len < 6 or not d.startsWith("GRSM"): return "not an RSM file"
	version = i64(d[4]) * 256 + i64(d[5])
	r = Reader(d, at = 6)
	animLength = i64(r.i32())
	shade = r.i32()
	alpha = f32(r.u8()) / 255.0 if version >= 0x104 else 1.0
	fps = 0.0
	textures = []
	rootName = []
	if version >= 0x202:
		fps = r.f32()
		animLength = i64((f32(animLength) * fps).ceil())
		if version < 0x203:
			loop r.u32():
				textures.push(r.lengthText())
		roots = i64(r.u32())
		loop roots:
			rootName = r.lengthText()
	else:
		r.skip(16)
		count = i64(r.u32())
		if count > 1000: return "an RSM with {count} textures"
		loop count:
			textures.push(r.cStringBytes(40))
		rootName = r.cStringBytes(40)
	count = i64(r.u32())
	if count > 10_000: return "an RSM with {count} nodes"
	nodes = []
	loop count:
		nodes.push(r.readNode(version, fps, textures))
		if r.short: return "an RSM node runs past the end"
	if nodes.isEmpty: return "an RSM with no nodes"
	# the tree: each node under the one its parent name names (a node never its own parent)
	root = 0
	for i, node in nodes:
		if node.name == rootName:
			root = i
			break
	for i in 0..nodes.len:
		if i == root: continue
		for j in 0..nodes.len:
			if j != i and nodes[j].name == nodes[i].parentName:
				nodes[i].parent = j
				nodes[j].children.push(i)
				break
	Rsm(version, animLength, shade, alpha, textures, nodes, root)

fn readNode(mut r Reader, version i64, fps f32, mut textures u8[,]):
	newer = version >= 0x202
	name = r.lengthText() if newer else r.cStringBytes(40)
	parentName = r.lengthText() if newer else r.cStringBytes(40)
	used = []
	count = i64(r.u32())
	loop count.min(1000):
		if version >= 0x203:
			file = r.lengthText()
			at = -1
			for k, texture in textures:
				if texture == file:
					at = k
					break
			if at < 0:
				at = textures.len
				textures.push(file)
			used.push(at)
		else:
			used.push(r.i32())
	offset = Mat4(Mat3.fromBytes(r))
	pivot = Vec3.fromBytes(r)
	position = Vec3(0.0, 0.0, 0.0)
	rotAngle = 0.0
	rotAxis = Vec3(0.0, 0.0, 0.0)
	scale = Vec3(1.0, 1.0, 1.0)
	if not newer:
		position = Vec3.fromBytes(r)
		rotAngle = r.f32()
		rotAxis = Vec3.fromBytes(r)
		scale = Vec3.fromBytes(r)
	vertices = Vec3[].fromBytes(r)
	uvCount = r.recordCount(8)
	uvs = []
	loop uvCount:
		if version >= 0x102:
			r.skip(4)   # a color, unused
		uvs.push(Vec2.fromBytes(r))
	faceCount = r.recordCount(24)
	faces = []
	loop faceCount:
		size = 24
		if newer:
			size = r.i32()
		f = FaceRecord.fromBytes(r)
		vs = f.vertices
		ts = f.uvs
		group = 0
		if version >= 0x102:
			group = r.i32()
			r.skip((size - 24).max(0))
		ok = vs[0] < vertices.len and vs[1] < vertices.len and vs[2] < vertices.len and
			ts[0] < uvs.len and ts[1] < uvs.len and ts[2] < uvs.len
		if ok:
			faces.push(Face(
				vertices = vs,
				uvs = ts,
				texture = f.texture,
				twoSided = f.twoSided > 0,
				smoothGroup = group))
	scaleFrames = []
	if version >= 0x106:
		loop r.u32().min(100_000):
			k = VecRecord.fromBytes(r)
			scaleFrames.push(
				VecFrame(time = i64((f32(k.time) * fps).ceil()) if newer else k.time, v = k.v)
			)
	rotFrames = []
	loop r.u32().min(100_000):
		k = TurnRecord.fromBytes(r)
		rotFrames.push(
			RotFrame(time = i64((f32(k.time) * fps).ceil()) if newer else k.time, q = k.q)
		)
	posFrames = []
	if newer:
		loop r.u32().min(100_000):
			k = VecRecord.fromBytes(r)
			posFrames.push(VecFrame(time = i64((f32(k.time) * fps).ceil()), v = k.v))
		if version >= 0x203:
			# texture animations: per texture, per kind, frames of (time, value); not shown
			loop r.u32().min(1000):
				r.skip(4)
				loop r.u32().min(100):
					r.skip(4)
					r.skip(r.u32().min(100_000) * 8)
	Node(name, parentName, textures = used, offset, pivot, position, rotAngle, rotAxis,
		scale, vertices, uvs, faces, rotFrames, posFrames, scaleFrames, parent = -1, children = [])
