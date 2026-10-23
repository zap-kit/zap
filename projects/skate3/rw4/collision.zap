# RenderWare's clustered collision meshes (ClusteredMesh, 0x00080006), what the skater touches:
# a 96-byte header (the bounds, the triangle count at 40, the KD-tree at 48, the cluster table at
# 52, the granularity of compressed vertices at 56, flags, the widths of group and surface ids at
# 62 and 63, the cluster count at 64, the mesh's size at 80), a table of cluster offsets, then the
# clusters. A cluster (16-byte header: unit count, unit bytes, vertex blocks of 16 bytes, its size,
# its vertex count, its compression) holds its vertices (floats; or 32-bit integers times the
# granularity; or a 32-bit base and 16-bit offsets) and then its units: a flags byte (the low four
# bits: 1 triangle, 2 quad), the vertex indices, edge codes (flag 0x20), a group id (0x40) and a
# surface id (0x80), the ids little-endian. A quad is the triangles 0 1 2 and 3 2 1.

# the triangles of a collision mesh: nine floats each (three corners), and each one's surface
pub type CollisionSoup:
	corners f32[]
	surfaces i64[]

# The triangles of every clustered mesh of the arena added to `into`; or why they cannot be read.
pub fn addCollision(a Arena, mut into CollisionSoup) bool ? str:
	for k in a.objectsOf(typeClusteredMesh):
		try addClusteredMesh(a.bytes, a.entries[k].at, into)
	true

fn addClusteredMesh(d u8[], at i64, mut into CollisionSoup) bool ? str:
	expected = d.u32be(at + 40)
	table = i64(d.u32be(at + 52))
	granularity = f64(d.f32be(at + 56))
	groupWidth = i64(d[at + 62])
	surfaceWidth = i64(d[at + 63])
	clusters = d.u32be(at + 64)
	meshBytes = i64(d.u32be(at + 80))
	before = into.surfaces.len
	for c in 0..clusters:
		from = at + d.u32be(at + table + c * 4)
		size = i64(d.u16be(from + 8))
		if from + size > at + meshBytes: return "a collision cluster runs past its mesh"
		try addCluster(d, from, granularity, groupWidth, surfaceWidth, into)
	if into.surfaces.len - before != expected:
		return "a collision mesh gave {into.surfaces.len - before} of {expected} triangles"
	true

fn addCluster(
	d u8[],
	at i64,
	granularity f64,
	groupWidth i64,
	surfaceWidth i64,
	mut into CollisionSoup
) bool ? str:
	units = i64(d.u16be(at))
	unitBytes = i64(d.u16be(at + 2))
	blocks = i64(d.u16be(at + 4))
	count = i64(d[at + 10])
	compression = i64(d[at + 12])
	vertices = []
	for i in 0..count:
		for axis in 0..3:
			v = 0.0
			if compression == 0:
				v = f64(d.f32be(at + 16 + i * 16 + axis * 4))
			elif compression == 2:
				v = i64(d.i32be(at + 16 + i * 12 + axis * 4)) * granularity
			elif compression == 1:
				base = i64(d.i32be(at + 16 + axis * 4))
				v = (base + d.i16be(at + 28 + i * 6 + axis * 2)) * granularity
			else:
				return "collision vertices compressed with method {compression}"
			vertices.push(f32(v))
	cursor = at + (blocks + 1) * 16
	end = cursor + unitBytes
	loop units:
		flags = i64(d[cursor])
		cursor += 1
		kind = flags & 15
		corners = 3
		if kind == 2:
			corners = 4
		elif kind == 3:
			corners = i64(d[cursor]) + 2
			cursor += 1
		elif kind != 1:
			return "a collision unit of kind {kind}"
		index = d[cursor..cursor + corners].map(i64(it))
		cursor += corners
		if (flags & 0x20) != 0:
			cursor += corners
		if (flags & 0x40) != 0:
			cursor += groupWidth
		surface = 0
		if (flags & 0x80) != 0:
			surface = d[cursor]
			if surfaceWidth == 2:
				surface |= i64(d[cursor + 1]) << 8
			cursor += surfaceWidth
		for i in index:
			if i >= count: return "a collision unit refers past its cluster's vertices"
		if kind == 1:
			addTriangle(vertices, index[0], index[1], index[2], surface, into)
		elif kind == 2:
			addTriangle(vertices, index[0], index[1], index[2], surface, into)
			addTriangle(vertices, index[3], index[2], index[1], surface, into)
		else:
			# a strip of triangles
			for t in 0..corners - 2:
				if t % 2 == 0:
					addTriangle(vertices, index[t], index[t + 1], index[t + 2], surface, into)
				else:
					addTriangle(vertices, index[t + 1], index[t], index[t + 2], surface, into)
	if cursor != end: return "a collision cluster's units end at {cursor - at}, not {end - at}"
	true

fn addTriangle(v f32[], a i64, b i64, c i64, surface i64, mut into CollisionSoup):
	for k in [a, b, c]:
		into.corners.push(v[k * 3])
		into.corners.push(v[k * 3 + 1])
		into.corners.push(v[k * 3 + 2])
	into.surfaces.push(surface)
