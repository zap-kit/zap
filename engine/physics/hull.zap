# The triangles of the convex leaves of a collision (collision.zap): a box's, a sphere's or a
# capsule's surface, and a convex hull's faces, each face the vertices lying on one of its planes
# fanned in order around their middle. Triangles wind counter-clockwise seen from outside.

import math

ringSegments = 12
ringSteps = 8   # rings from pole to pole of a sphere

# the triangle a b c, turned to face `outward`
fn pushFacing(mut out u32[], positions Vec3[], a i64, b i64, c i64, outward Vec3):
	normal = (positions[b] - positions[a]).cross(positions[c] - positions[a])
	if normal @ outward >= 0.0:
		out.extend([u32(a), u32(b), u32(c)])
	else:
		out.extend([u32(a), u32(c), u32(b)])

# the 8 corners of the box -half..half and its 12 triangles
pub fn boxTriangles(half Vec3) (Vec3[], u32[]):
	positions = (0..8).map(
		Vec3(
			half.x if (it & 1) != 0 else -half.x,
			half.y if (it & 2) != 0 else -half.y,
			half.z if (it & 4) != 0 else -half.z
		)
	)
	indices u32[] = []
	for face in [
		[0, 2, 6, 4],
		[1, 3, 7, 5],
		[0, 1, 5, 4],
		[2, 3, 7, 6],
		[0, 1, 3, 2],
		[4, 5, 7, 6]
	]:
		outward = (positions[face[0]] + positions[face[2]]) * 0.5
		indices.pushFacing(positions, face[0], face[1], face[2], outward)
		indices.pushFacing(positions, face[0], face[2], face[3], outward)
	(positions, indices)

# the surface of the points within `radius` of the segment a..b: a sphere when a is b, else a
# capsule; rings of a half sphere around b then of one around a, and a pole at each end
pub fn roundTriangles(a Vec3, b Vec3, radius f32) (Vec3[], u32[]):
	along = b - a
	axis = along.normalized() if along.length() > 0.0 else Vec3(0, 0, 1)
	u, v = axis.sideways()
	positions = []
	for k in 0..ringSteps:
		step = k + 1 if k < ringSteps / 2 else k
		angle = f32(step) * pi / f32(ringSteps)
		mid = (b if k < ringSteps / 2 else a) + axis * (radius * angle.cos())
		for s in 0..ringSegments:
			turn = f32(s) * tau / f32(ringSegments)
			positions.push(mid + (u * turn.cos() + v * turn.sin()) * (radius * angle.sin()))
	top = positions.len
	positions.push(b + axis * radius)
	positions.push(a - axis * radius)
	middle = (a + b) * 0.5
	indices u32[] = []
	for s in 0..ringSegments:
		next = (s + 1) % ringSegments
		indices.pushFacing(positions, top, s, next, axis)
		last = (ringSteps - 1) * ringSegments
		indices.pushFacing(positions, top + 1, last + s, last + next, -axis)
		for k in 0..ringSteps - 1:
			if k == ringSteps / 2 - 1 and a == b: continue   # a sphere's two middle rings are one
			p = k * ringSegments + s
			q = k * ringSegments + next
			outward = positions[p] - middle
			indices.pushFacing(positions, p, q, q + ringSegments, outward)
			indices.pushFacing(positions, p, q + ringSegments, p + ringSegments, outward)
	(positions, indices)

# how near a vertex must lie to a plane to be on its face, for a hull of this size
fn planeTolerance(vertices Vec3[]):
	lo, hi = vertices.boundsOf()
	(hi - lo).length() * 0.002 + 0.0001

# the corners of a first tetrahedron of the points: the two farthest apart along x, y or z, the
# farthest from their line, the farthest from their plane; none when all lie on one plane
fn firstTetrahedron(points Vec3[], tolerance f32) i64[]?:
	a = 0
	b = 0
	for axis in 0..3:
		lo = (0..points.len).minBy(points[it][axis]) ?? 0
		hi = (0..points.len).maxBy(points[it][axis]) ?? 0
		if (points[hi] - points[lo]).length() > (points[b] - points[a]).length():
			a = lo
			b = hi
	line = (points[b] - points[a]).normalized()
	c = (0..points.len).maxBy((points[it] - points[a]).cross(line).length()) ?? 0
	normal = (points[b] - points[a]).cross(points[c] - points[a]).normalized()
	d = (0..points.len).maxBy((normal @ (points[it] - points[a])).abs()) ?? 0
	if (normal @ (points[d] - points[a])).abs() <= tolerance: return none
	[a, b, c, d]

# how far the point lies above triangle t of `faces`, along its unit normal
fn heightAbove(points Vec3[], faces u32[], t i64, p Vec3):
	a = points[faces[t * 3]]
	normal = (points[faces[t * 3 + 1]] - a).cross(points[faces[t * 3 + 2]] - a).normalized()
	normal @ (p - a)

fn edgeKey(a u32, b u32):
	(u64(a) << 32) | b

# the faces of the hull a point sees: those joined to the one it sees most, each more than
# `tolerance` below it, and any they surround (so the edges around them make one loop)
fn seenFaces(heights f32[], faces u32[], best i64, tolerance f32):
	faceOfEdge {u64: i64} = {}
	for t in 0..faces.len / 3:
		for e in 0..3:
			faceOfEdge[edgeKey(faces[t * 3 + e], faces[t * 3 + (e + 1) % 3])] = t
	seen = fill(heights.len, false)
	seen[best] = true
	stack = [best]
	while stack.pop() is t:
		for e in 0..3:
			twin = edgeKey(faces[t * 3 + (e + 1) % 3], faces[t * 3 + e])
			u = faceOfEdge.get(twin) ?? continue
			if not seen[u] and heights[u] > tolerance:
				seen[u] = true
				stack.push(u)
	for t in 0..heights.len:
		if not seen[t] and
			(0..3).all(
				seen[faceOfEdge.get(edgeKey(faces[t * 3 + (it + 1) % 3], faces[t * 3 + it])) ?? t]
			):
			seen[t] = true   # a face the seen ones close around, its point a hair above it
	(seen, faceOfEdge)

# the hull grown by point p: the faces it sees go, and the edges around them close on it
fn addHullPoint(points Vec3[], faces u32[], p i64, tolerance f32) u32[]?:
	heights = (0..faces.len / 3).map(heightAbove(points, faces, it, points[p]))
	best = (0..heights.len).maxBy(heights[it]) ?? return none
	if heights[best] <= tolerance: return none
	seen, faceOfEdge = seenFaces(heights, faces, best, tolerance)
	kept = []
	for t in 0..heights.len:
		if not seen[t]:
			kept.extend(faces[t * 3..t * 3 + 3])
			continue
		for e in 0..3:
			a = faces[t * 3 + e]
			b = faces[t * 3 + (e + 1) % 3]
			beyond = faceOfEdge.get(edgeKey(b, a)) ?? -1
			if beyond < 0 or not seen[beyond]: kept.extend([a, b, u32(p)])
	kept

# The triangles of the convex hull of the points, from a first tetrahedron, the points added
# farthest from it first; a point within `tolerance` of the hull is left out.
fn convexHull(points Vec3[], tolerance f32) u32[]:
	faces = []
	corners = firstTetrahedron(points, tolerance) ?? return faces
	middle = (points[corners[0]] + points[corners[1]] + points[corners[2]] + points[corners[3]]) *
		0.25
	for f in [[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]:
		a = corners[f[0]]
		faces.pushFacing(points, a, corners[f[1]], corners[f[2]], points[a] - middle)
	order = (0..points.len).sortedBy(-(points[it] - middle).length())
	for p in order:
		if p in corners: continue
		faces = addHullPoint(points, faces, p, tolerance) ?? continue
	faces

# the triangles of the convex hull of the points, wound counter-clockwise seen from outside
pub fn hullOf(points Vec3[]) u32[]:
	convexHull(points, planeTolerance(points))

# the directions a vertex lying on no given plane is pushed along onto the shell: the axes and the
# diagonals
roundDirections = [
	Vec3(1, 0, 0), Vec3(-1, 0, 0), Vec3(0, 1, 0), Vec3(0, -1, 0), Vec3(0, 0, 1), Vec3(0, 0, -1),
	Vec3(1, 1, 1), Vec3(1, 1, -1), Vec3(1, -1, 1), Vec3(1, -1, -1), Vec3(-1, 1, 1),
	Vec3(-1, 1, -1), Vec3(-1, -1, 1), Vec3(-1, -1, -1)
].map(.normalized())

# the points the triangles use, in their order, and the triangles over them
fn usedOnly(points Vec3[], indices u32[]):
	at = fill(points.len, -1)
	kept = []
	out = []
	for k in indices:
		if at[k] < 0:
			at[k] = kept.len
			kept.push(points[k])
		out.push(u32(at[k]))
	(kept, out)

# The faces of the convex hull of `vertices` grown by the shell `radius` (the hull swept by a ball
# of that radius): the hull of the points each vertex reaches along the normals of the given
# planes it lies on (which lie `radius` out from the vertices already), or along roundDirections
# when it lies on none; every such point lies on the shell, a flat hull's too.
pub fn hullTriangles(vertices Vec3[], given Vec4[], radius f32) (Vec3[], u32[]):
	tolerance = planeTolerance(vertices)
	if radius <= 0.0: return usedOnly(vertices, convexHull(vertices, tolerance))
	shell = []
	for v in vertices:
		normals = given.filter((.xyz @ v + .w + radius).abs() <= tolerance).map(.xyz)
		for n in (normals if not normals.isEmpty else roundDirections.copy()):
			shell.push(v + n * radius)
	usedOnly(shell, convexHull(shell, tolerance))
