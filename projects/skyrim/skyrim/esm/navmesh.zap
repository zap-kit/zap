# A cell's navigation meshes (NAVM, in its temporary children): NVNM's version and magic, the
# parent world (0 for an interior) and cell, the vertices (three floats), the triangles (three
# corners, the triangles across their three edges or -1, the flags and the cover flags: 16 bytes
# each); the edge links to other meshes, the doors' triangles, the cover and the search grid
# that follow are not read. Layout after UESP's Skyrim Mod File Format (NAVM) and xEdit's.

import engine

triangleBytes = 16
edgeLinkBytes = 10   # a mark, the other mesh and its triangle
doorBytes = 10
# a triangle flag: its edge k (0-1, 1-2, 2-0) leads into another mesh through an edge link,
# its number then that link's, not a triangle's
edgeLinkFlags = [0x1, 0x2, 0x4]

# a triangle's edge that leads into another mesh: the mesh (its form id) and its triangle there
type EdgeLink:
	triangle i64   # in the whole mesh
	edge i64
	mesh i64
	across i64

# the vertices and triangles of one NAVM record's NVNM, its corners counted from `base`; the edges
# that lead into other meshes are left in `links`
fn readNavmesh(body u8[], at i64, base i64, mut m engine.NavMesh, mut links EdgeLink[]):
	v = at + 16   # past the version, the magic and the parent (a world and cell, or a grid)
	count = body.u32le(v)
	for k in 0..count:
		p = v + 4 + k * 12
		m.vertices.push(Vec3(body.f32le(p), body.f32le(p + 4), body.f32le(p + 8)))
	t = v + 4 + count * 12
	first = m.triangleCount()
	triangles = body.u32le(t)
	listed = t + 4 + triangles * triangleBytes
	for k in 0..triangles:
		p = t + 4 + k * triangleBytes
		flags = body.u16le(p + 12)
		for c in 0..3:
			m.triangles.push(base + body.i16le(p + c * 2))
		for e in 0..3:
			across = i64(body.i16le(p + 6 + e * 2))
			linked = (flags & edgeLinkFlags[e]) != 0
			if linked and across >= 0 and across < body.u32le(listed):
				l = listed + 4 + across * edgeLinkBytes
				links.push(
					EdgeLink(
						triangle = first + k,
						edge = e,
						mesh = body.u32le(l + 4),
						across = body.u16le(l + 8)
					)
				)
			m.neighbours.push(-1 if across < 0 or linked else first + across)
	readDoors(body, t + 4 + triangles * triangleBytes, first, m)

# the doors' triangles after the edge links: the triangle, a checksum, the door's reference
fn readDoors(body u8[], at i64, first i64, mut m engine.NavMesh):
	d = at + 4 + body.u32le(at) * edgeLinkBytes
	for k in 0..body.u32le(d):
		p = d + 4 + k * doorBytes
		m.doors.push(engine.DoorTriangle(first + body.u16le(p), body.u32le(p + 6)))

# The navigation meshes of the cell with this editor id (an interior, or an exterior area's id:
# the meshes of its whole grid, joined across their edge links) as one mesh (Skyrim's units, Z
# up), none when there is no such cell.
pub fn cellNavmesh(e Esm, editorId str) engine.NavMesh?:
	records = try e.cellRecords(editorId)
	m = engine.NavMesh(vertices = [], triangles = [], neighbours = [])
	links = []
	starts {i64: i64} = {}
	for r in records:
		if r.kind != "NAVM": continue
		at = dataOf(r.fields, "NVNM") ?? continue
		starts[r.formId] = m.triangleCount()
		readNavmesh(r.body, at, m.vertices.len, m, links)
	for l in links:
		if starts.get(l.mesh) is first: m.neighbours[l.triangle * 3 + l.edge] = first + l.across
	m
