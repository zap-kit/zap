# The contacts of a step: for each awake body's leaf, the scene's triangles near it and the other
# bodies' leaves, each meeting kept as a manifold of up to four points. A ball leaf meets a
# triangle by its nearest points, a hull by the separating axis test (sat.zap); two bodies' leaves
# meet as hulls. A manifold found again (the same leaf against the same triangle or leaf) keeps the
# normal impulse it gave, which bounds its friction (friction.zap), and its friction's anchor; a
# point found again (near where it was on the body) keeps its overlap's allowance.

# one point where two bodies (or a body and the scene) touch, with its impulses
pub type Contact:
	point Vec3
	depth f32
	local Vec3   # the point in the first body's space, to know it again next step
	normalImpulse f32 = 0.0   # this step's, accumulated over the solver's sub-steps
	allowance f32 = 0.0   # the overlap it holds without pushing out yet (Havok's, solver.zap): 0 or less
	armA Vec3 = Vec3(0, 0, 0)
	armB Vec3 = Vec3(0, 0, 0)
	normalMass f32 = 0.0   # the solver's damping over the mass the normal impulse meets
	rhs f32 = 0.0   # the normal velocity the solver asks for
	closing f32 = 0.0   # the normal velocity before the solve

# the contacts of a leaf of body a with body b or the scene, sharing one normal
pub type Manifold:
	key i64   # the body, its leaf and what it meets
	a i64
	b i64   # the other body, -1 for the scene
	normal Vec3   # from a to b
	friction f32
	restitution f32
	contacts Contact[]
	grip Grip = Grip()

# Havok's mix of two surfaces' friction and restitution
fn mixed(a f32, b f32):
	(a * b).sqrt()

fn sceneKey(body i64, leaf i64, triangle i64):
	((body * 256 + leaf) << 25) | (triangle << 1)

# the scene's triangle a manifold of a body against the scene meets, none for two bodies'
pub fn sceneTriangle(m Manifold) i64?:
	if m.b >= 0 or (m.key & 1) != 0: return none
	(m.key >> 1) & ((1 << 24) - 1)

fn pairKey(a i64, leafA i64, b i64, leafB i64):
	((a * 256 + leafA) << 25) | ((b * 256 + leafB) << 1) | 1

# what a ball (the segment a..b grown by radius) meets of a triangle: the nearest points, and
# where the segment's ends lie near it along the same normal (a capsule lying on it)
pub fn ballContacts(a Vec3, b Vec3, radius f32, t0 Vec3, t1 Vec3, t2 Vec3, margin f32) Touching?:
	onBall, onTriangle = a.closestOnSegmentTriangle(b, t0, t1, t2)
	gap = onTriangle - onBall
	distance = gap.length()
	if distance > radius + margin: return none
	n = (t1 - t0).cross(t2 - t0).normalized()
	normal = gap / distance if distance > 1.0e-4 * radius
		else (n if ((a + b) * 0.5 - t0) @ n < 0.0 else -n)
	points = [
		Touch(point = onTriangle - normal * ((radius - distance) * 0.5), depth = radius - distance)
	]
	if a != b:
		for end in [a, b]:
			q = end.closestOnTriangle(t0, t1, t2)
			along = (q - end) @ normal
			if (q - end - normal * along).length() > 0.05 * radius or
				(q - onTriangle).length() < 0.25 * radius:
				continue
			if along <= radius + margin:
				points.push(
					Touch(point = q - normal * ((radius - along) * 0.5), depth = radius - along)
				)
	Touching(normal, points)

# the touching of leaf l of body b with scene triangle t, in the world
fn leafTriangle(b Body, l Leaf, s Scene, t i64, margin f32):
	match l.round:
		Ball(p, q, radius): ballContacts(
			b.toWorld(p),
			b.toWorld(q),
			radius,
			s.corner(t, 0),
			s.corner(t, 1),
			s.corner(t, 2),
			margin
		)
		Hull:
			triangle = trianglePoly(
				b.toLocal(s.corner(t, 0)),
				b.toLocal(s.corner(t, 1)),
				b.toLocal(s.corner(t, 2))
			)
			found = try l.poly.polyContacts(triangle, margin, l.shell, 0.0)
			Touching(
				normal = b.turn @ found.normal,
				points = found.points.map(Touch(point = b.toWorld(.point), depth = .depth))
			)

fn manifoldOf(
	key i64,
	a Body,
	ai i64,
	bi i64,
	found Touching,
	friction f32,
	restitution f32
):
	Manifold(
		key,
		a = ai,
		b = bi,
		normal = found.normal,
		friction,
		restitution,
		contacts = found.points.map(
			Contact(point = .point, depth = .depth, local = a.toLocal(.point))
		)
	)

faceCosine f32 = 0.999   # a normal this near the triangle's meets its face
weldCosine f32 = 0.9   # an edge's normal this near a face's of the same leaf is that face's

# A leaf meeting the edge of one triangle and, at about the same angle, the face of its
# neighbour meets one surface (an inside edge of a mesh): the face's contacts are kept alone.
fn welded(found Manifold[], faceNormals Vec3[]):
	isFace = (0..found.len).map((found[it].normal @ faceNormals[it]).abs() >= faceCosine)
	kept = []
	for k in 0..found.len:
		shadowed = not isFace[k] and
			(0..found.len).any(isFace[it] and found[it].normal @ found[k].normal >= weldCosine)
		if not shadowed: kept.push(found[k].copy())
	kept

# body i's leaves against the scene's triangles near them
pub fn collideScene(mut s Scene, bodies Body[], i i64, margin f32, mut out Manifold[]):
	b = bodies[i]
	ids = s.trianglesNear(b.lo - margin, b.hi + margin)
	for li in 0..b.leaves.len:
		l = b.leaves[li]
		found = []
		faceNormals = []
		for t in ids:
			lo = s.corner(t, 0).min(s.corner(t, 1)).min(s.corner(t, 2))
			hi = s.corner(t, 0).max(s.corner(t, 1)).max(s.corner(t, 2))
			if not l.worldLo.boxesMeet(l.worldHi, lo, hi, margin): continue
			touching = b.leafTriangle(l, s, t, margin) ?? continue
			friction = mixed(b.friction, s.friction[t])
			restitution = mixed(b.restitution, s.restitution[t])
			found.push(manifoldOf(sceneKey(i, li, t), b, i, -1, touching, friction, restitution))
			faceNormals.push(s.normals[t])
		out.extend(welded(found, faceNormals))

# the leaves of bodies i and j against each other, j's taken into i's space
pub fn collidePair(bodies Body[], i i64, j i64, margin f32, mut out Manifold[]):
	a = bodies[i]
	b = bodies[j]
	into = a.turn.transpose()
	turn = into @ b.turn
	by = into @ (b.position - a.position)
	for la in 0..a.leaves.len:
		for lb in 0..b.leaves.len:
			if not boxesMeet(
				a.leaves[la].worldLo,
				a.leaves[la].worldHi,
				b.leaves[lb].worldLo,
				b.leaves[lb].worldHi,
				margin
			):
				continue
			other = b.leaves[lb].poly.moved(turn, by)
			found = polyContacts(
				a.leaves[la].poly,
				other,
				margin,
				a.leaves[la].shell,
				b.leaves[lb].shell
			) ??
				continue
			inWorld = Touching(
				normal = a.turn @ found.normal,
				points = found.points.map(Touch(point = a.toWorld(.point), depth = .depth))
			)
			out.push(
				manifoldOf(
					pairKey(i, la, j, lb),
					a,
					i,
					j,
					inWorld,
					mixed(a.friction, b.friction),
					mixed(a.restitution, b.restitution)
				)
			)

# what the manifold keeps of last step's of the same key: its friction's load and anchor, and each
# point found again its allowance
pub fn keepFrom(mut m Manifold, last Manifold, near f32):
	m.grip = last.grip.copy()
	m.grip.load = last.contacts.map(.normalImpulse).sum()
	for k in 0..m.contacts.len:
		c = mut ref m.contacts[k]
		best = near
		for old in last.contacts:
			d = (old.local - c.local).length()
			if d < best:
				best = d
				c.allowance = old.allowance
