# Convex shapes as the narrow phase reads them: a polyhedron of welded corners, its faces (each a
# loop of corners on one plane) and its edges (each with the normals of the two faces it joins),
# made from a convex leaf's triangles; and the mass properties of a solid of uniform density.

import math

# a face of a convex polyhedron: its plane and its corners
pub type Face:
	normal Vec3
	offset f32   # normal @ p for every p on the face
	corners i64[]   # counter-clockwise seen from outside

# an edge of a convex polyhedron with the normals of its two faces
pub type Edge:
	a i64
	b i64
	left Vec3   # the normals of the two faces it joins
	right Vec3
	dir Vec3   # right x left: along the edge, the arc's pole on the unit sphere

fn edgeOf(a i64, b i64, left Vec3, right Vec3):
	Edge(a, b, left, right, dir = right.cross(left))

# a convex polyhedron of welded corners, its faces and its edges
pub type Poly:
	vertices Vec3[]
	faces Face[]
	edges Edge[]
	center Vec3   # the mean of the vertices, inside

# how a leaf is tested against the scene's triangles: by its polyhedron, or exactly as a ball
# around a point or a segment
pub type Round:
	Hull
	Ball(a Vec3, b Vec3, radius f32)   # a sphere when a is b, else a capsule

weldShare f32 = 1.0e-4   # corners nearer than this share of the shape's size are one
planeCosine f32 = 0.9995   # faces whose normals agree this well and lie on one plane are one
planeShare f32 = 0.002   # a face lies on a plane this share of the shape's size from another's

fn sizeOf(points Vec3[]):
	lo, hi = points.boundsOf()
	(hi - lo).length()

# the index of p among the corners, added when no corner lies within `tolerance`
fn weldedIndex(mut corners Vec3[], p Vec3, tolerance f32):
	for i, mut corner in corners:
		if (corner - p).length() <= tolerance: return i
	corners.push(p)
	corners.len - 1

# how far o a b turns counter-clockwise in the plane of u and v
fn turnIn(o Vec3, a Vec3, b Vec3, u Vec3, v Vec3):
	((a - o) @ u) * ((b - o) @ v) - ((a - o) @ v) * ((b - o) @ u)

# the corners of one face in counter-clockwise order around `normal`, those inside the loop or on
# its sides left out (Andrew's monotone chain in the face's plane)
fn faceLoop(vertices Vec3[], corners i64[], normal Vec3):
	u, v = normal.sideways()
	order = corners.sortedBy((vertices[it] @ u, vertices[it] @ v))
	hull i64[] = []
	for pass in 0..2:
		start = hull.len
		for k in 0..order.len:
			i = order[k] if pass == 0 else order[len - 1 - k]
			while hull.len >= start + 2 and
				vertices[hull[len - 2]].turnIn(vertices[hull[len - 1]], vertices[i], u, v) <= 0.0:
				hull.pop()
			hull.push(i)
		hull.pop()
	hull

# the faces of the triangles first..end of a convex leaf, coplanar ones merged
fn facesOf(vertices Vec3[], triangles i64[], center Vec3, tolerance f32, onPlane f32):
	normals Vec3[] = []
	offsets f32[] = []
	groups (i64[])[] = []
	for t in 0..triangles.len / 3:
		a = vertices[triangles[t * 3]]
		n = (vertices[triangles[t * 3 + 1]] - a).cross(vertices[triangles[t * 3 + 2]] - a)
		if n.length() <= tolerance * tolerance: continue
		n = n.normalized() if n @ (a - center) >= 0.0 else -n.normalized()
		d = n @ a
		g = (0..normals.len).find(
			normals[it] @ n >= planeCosine and (offsets[it] - d).abs() <= onPlane
		) ??
			-1
		if g < 0:
			normals.push(n)
			offsets.push(d)
			groups.push([])
			g = normals.len - 1
		for k in 0..3:
			c = triangles[t * 3 + k]
			if c not in groups[g]: groups[g].push(c)
	faces = []
	for g, group in groups:
		corners = faceLoop(vertices, group, normals[g])
		if corners.len >= 3:
			faces.push(Face(normal = normals[g], offset = offsets[g], corners))
	faces

# each edge of the faces' loops met twice, with the two faces' normals
fn edgesOf(faces Face[]):
	firstFace {i64: i64} = {}
	edges = []
	for f in 0..faces.len:
		corners = faces[f].corners
		for k in 0..corners.len:
			a = corners[k]
			b = corners[(k + 1) % len]
			key = a.min(b) * 1_000_000 + a.max(b)
			match firstFace.get(key):
				other: edges.push(edgeOf(a, b, faces[f].normal, faces[other].normal))
				none: firstFace[key] = f
	edges

# the polyhedron of triangles first..end (three indices each) of a convex surface
pub fn polyOf(positions Vec3[], indices u32[], first i64, end i64) Poly:
	size = sizeOf(positions)
	tolerance = size * weldShare
	vertices Vec3[] = []
	triangles = []
	for k in first * 3..end * 3:
		triangles.push(vertices.weldedIndex(positions[indices[k]], tolerance))
	center = Vec3(0, 0, 0)
	for p in vertices:
		center += p
	center /= f32(vertices.len.max(1))
	faces = facesOf(vertices, triangles, center, tolerance.max(1.0e-6), size * planeShare + 1.0e-4)
	Poly(vertices, faces, edges = edgesOf(faces), center)

# the poly turned by `turn` and moved by `by`
pub fn moved(p Poly, turn Mat3, by Vec3) Poly:
	Poly(
		vertices = p.vertices.map(turn @ it + by),
		faces = p.faces.map(Face(normal = turn @ .normal, offset = (turn @ .normal) @ (turn @ p.vertices[.corners[0]] + by), corners = .corners.copy())),
		edges = p.edges.map(Edge(a = .a, b = .b, left = turn @ .left, right = turn @ .right, dir = turn @ .dir)),
		center = turn @ p.center + by
	)

# the triangle a b c as a flat polyhedron: a face each way, and each edge twice, joining the front
# to its outward side and that side to the back (so each pair of normals spans less than a half turn)
pub fn trianglePoly(a Vec3, b Vec3, c Vec3) Poly:
	n = (b - a).cross(c - a).normalized()
	vertices = [a, b, c]
	edges = []
	for k in 0..3:
		p = vertices[k]
		q = vertices[(k + 1) % 3]
		out = (q - p).cross(n).normalized()
		edges.push(edgeOf(k, (k + 1) % 3, n, out))
		edges.push(edgeOf(k, (k + 1) % 3, out, -n))
	Poly(
		vertices,
		faces = [Face(normal = n, offset = n @ a, corners = [0, 1, 2]), Face(normal = -n, offset = -(n @ a), corners = [0, 2, 1])],
		edges,
		center = (a + b + c) / 3.0
	)

# Mass properties of a solid of convex polyhedra (Blow and Binstock's covariance of the
# tetrahedra from `origin`, a point near them, so the sums keep their precision far from the
# world's origin): its volume, the integral of p - origin and the covariance about origin
pub type Solid:
	origin Vec3
	volume f32 = 0.0
	moment Vec3 = Vec3(0, 0, 0)
	covariance Mat3

# an empty solid measured about origin
pub fn solidAround(origin Vec3) Solid:
	Solid(origin, covariance = Mat3(0.0))

fn outer(a Vec3, b Vec3):
	Mat3(a * b.x, a * b.y, a * b.z)

# the solid grown by a convex polyhedron's, each face fanned from its first corner
pub fn addPoly(mut s Solid, p Poly):
	for f in p.faces:
		a = p.vertices[f.corners[0]] - s.origin
		for k in 1..f.corners.len - 1:
			b = p.vertices[f.corners[k]] - s.origin
			c = p.vertices[f.corners[k + 1]] - s.origin
			det = a @ b.cross(c)
			sum = a + b + c
			s.volume += det / 6.0
			s.moment += sum * (det / 24.0)
			s.covariance += (a.outer(a) + b.outer(b) + c.outer(c) + sum.outer(sum)) *
				(det / 120.0)

# the solid's center of mass
pub fn centroid(s Solid) Vec3:
	s.origin + s.moment / s.volume

# the inertia tensor about the centroid of the solid of this mass
pub fn inertiaOf(s Solid, mass f32) Mat3:
	density = mass / s.volume
	c = s.moment / s.volume
	central = s.covariance * density - c.outer(c) * mass
	trace = central.m[0] + central.m[4] + central.m[8]
	Mat3(trace) - central
