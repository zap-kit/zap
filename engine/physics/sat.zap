# The narrow phase of two convex polyhedra, a body's leaf against a triangle or another leaf: the
# separating axis test over the faces of both and the pairs of edges that make a face of their
# Minkowski difference (Gregorius, GDC 2013), then the contact points: the incident face clipped
# against the sides of the reference face, or the two edges' nearest points.

# a contact point of two convex shapes
pub type Touch:
	point Vec3   # midway between the two surfaces
	depth f32   # how far they overlap there; negative: apart by that much

# where two convex shapes touch: the normal and up to four points
pub type Touching:
	normal Vec3   # from the first shape to the second
	points Touch[]

maxPoints = 4
incidentCosine f32 = 0.98   # q's faces this near the most turned against the reference are incident too

# The hot loops below spell their products out by component: a call per product costs more.

# the face of p that q's vertices pass least, and how far they stay above it (negative: below)
fn faceQuery(p Poly, q Poly):
	best = -1.0e30
	bestFace = -1
	for f in 0..p.faces.len:
		n = p.faces[f].normal
		lowest = 1.0e30
		for v in q.vertices:
			lowest = lowest.min(n.x * v.x + n.y * v.y + n.z * v.z)
		s = lowest - p.faces[f].offset
		if s > best:
			best = s
			bestFace = f
	(best, bestFace)

fn dot(a Vec3, b Vec3):
	a.x * b.x + a.y * b.y + a.z * b.z

# The pair of edges whose axis keeps p and q farthest apart: the separation, the edges, the axis.
# Only the pairs whose arcs on the unit sphere cross (q's arc turned round) make a face of the
# Minkowski difference, and only those are tried.
fn edgeQuery(p Poly, q Poly):
	best = -1.0e30
	bestA = -1
	bestB = -1
	bestAxis = Vec3(0, 0, 0)
	for i in 0..p.edges.len:
		ea = p.edges[i]
		u = ea.dir
		for j in 0..q.edges.len:
			eb = q.edges[j]
			c = eb.left
			d = eb.right
			cu = c.x * u.x + c.y * u.y + c.z * u.z
			du = d.x * u.x + d.y * u.y + d.z * u.z
			if cu * du >= 0.0: continue
			w = eb.dir
			aw = ea.left.x * w.x + ea.left.y * w.y + ea.left.z * w.z
			bw = ea.right.x * w.x + ea.right.y * w.y + ea.right.z * w.z
			if aw * bw >= 0.0 or cu * bw >= 0.0: continue
			axis = Vec3(u.y * w.z - u.z * w.y, u.z * w.x - u.x * w.z, u.x * w.y - u.y * w.x)
			size = dot(axis, axis)
			if size <= 1.0e-10 * dot(u, u) * dot(w, w): continue
			axis /= size.sqrt()
			from = p.vertices[ea.a]
			if dot(axis, from - p.center) < 0.0: axis = -axis
			s = dot(axis, q.vertices[eb.a] - from)
			if s > best:
				best = s
				bestA = i
				bestB = j
				bestAxis = axis
	(best, bestA, bestB, bestAxis)

# the polygon's part on the side of the plane (normal, offset) its normal points away from
fn clipBelow(points Vec3[], normal Vec3, offset f32):
	out = []
	for k in 0..points.len:
		a = points[k]
		b = points[(k + 1) % len]
		da = normal @ a - offset
		db = normal @ b - offset
		if da <= 0.0: out.push(a)
		if (da <= 0.0) != (db <= 0.0): out.push(a + (b - a) * (da / (da - db)))
	out

# the face of q's incident polygon clipped by the sides of face f of p
fn clippedBy(p Poly, f i64, q Poly, incident i64):
	n = p.faces[f].normal
	points = q.faces[incident].corners.map(q.vertices[it])
	corners = p.faces[f].corners
	for k in 0..corners.len:
		a = p.vertices[corners[k]]
		side = (p.vertices[corners[(k + 1) % len]] - a).cross(n)
		points = clipBelow(points, side, side @ a)
		if points.isEmpty: break
	points

# The points of q's faces turned against face f of p (those within incidentCosine of the most
# turned, so a base split into faces a little apart counts whole) clipped by that face's sides,
# those within `margin` of it; the normal from p to q, turned round when `flip` (p is the second).
fn faceContacts(p Poly, f i64, q Poly, margin f32, shellP f32, shellQ f32, flip bool) Touching?:
	face = p.faces[f]
	n = face.normal
	most = (0..q.faces.len).map(q.faces[it].normal @ n).min() ?? return none
	touches = []
	for g in 0..q.faces.len:
		if q.faces[g].normal @ n > most.max(-incidentCosine): continue
		for x in p.clippedBy(f, q, g):
			s = n @ x - face.offset
			if s <= margin + shellP + shellQ:
				touches.push(
					Touch(
						point = x - n * ((s - shellP + shellQ) * 0.5),
						depth = shellP + shellQ - s
					)
				)
	if touches.isEmpty: return none
	Touching(normal = -n if flip else n, points = reduced(touches, n))

# signed twice the area of a b c seen along n
fn areaAlong(a Vec3, b Vec3, c Vec3, n Vec3):
	(b - a).cross(c - a) @ n

# At most four of the points, spanning the most: the deepest, the farthest from it, the one that
# makes the largest triangle with those two, and the one farthest outside that triangle.
pub fn reduced(points Touch[], n Vec3) Touch[]:
	if points.len <= maxPoints: return points.copy()
	first = (0..points.len).maxBy(points[it].depth) ?? 0
	p1 = points[first].point
	second = (0..points.len).maxBy((points[it].point - p1).length()) ?? 0
	p2 = points[second].point
	third = (0..points.len).maxBy(p1.areaAlong(p2, points[it].point, n).abs()) ?? 0
	p3 = points[third].point
	if p1.areaAlong(p2, p3, n) < 0.0:
		p2, p3 = p3, p2
		second, third = third, second
	fourth = (0..points.len).minBy(
		p1.areaAlong(p2, points[it].point, n)
			.min(p2.areaAlong(p3, points[it].point, n))
			.min(p3.areaAlong(p1, points[it].point, n))
	) ?? 0
	[first, second, third, fourth].map(points[it])

# the contact of two convex polyhedra in one space, each grown by its shell, none when they stay
# more than `margin` apart;
# a face is preferred to a pair of edges, and q's face to p's, unless the other is clearly shallower
pub fn polyContacts(p Poly, q Poly, margin f32, shellP f32, shellQ f32) Touching?:
	reach = margin + shellP + shellQ
	sp, fp = p.faceQuery(q)
	if sp > reach or fp < 0: return none
	sq, fq = q.faceQuery(p)
	if sq > reach or fq < 0: return none
	se, ea, eb, axis = p.edgeQuery(q)
	if se > reach: return none
	bias = margin * 0.25
	if ea >= 0 and se > sp.max(sq) + bias:
		a0 = p.vertices[p.edges[ea].a]
		b0 = q.vertices[q.edges[eb].a]
		onP, onQ = a0.closestOnSegments(p.vertices[p.edges[ea].b], b0, q.vertices[q.edges[eb].b])
		middle = (onP + axis * shellP + onQ - axis * shellQ) * 0.5
		return Touching(
			normal = axis,
			points = [Touch(point = middle, depth = shellP + shellQ - se)]
		)
	if sq + bias * 0.5 >= sp: return q.faceContacts(fq, p, margin, shellQ, shellP, true)
	p.faceContacts(fp, q, margin, shellP, shellQ, false)
