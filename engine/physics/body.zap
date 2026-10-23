# A rigid body: convex leaves in its own space (centered on its center of mass), its mass and
# inertia from their solid, where it is and how it moves.

import math

# a convex leaf as the scene gives it: its surface's triangles where it stands, and its ball when
# it is a sphere or a capsule
pub type Piece:
	round Round = Round.Hull
	positions Vec3[]
	indices u32[]
	shell f32 = 0.0   # the radius the surface reaches around the triangles

# one convex part of a body: its polyhedron, its ball when it is round, its bounds
pub type Leaf:
	round Round   # in the body's space
	poly Poly
	shell f32
	lo Vec3   # its bounds in the body's space
	hi Vec3
	worldLo Vec3 = Vec3(0, 0, 0)   # and in the world's, this step
	worldHi Vec3 = Vec3(0, 0, 0)

# a rigid body: its convex leaves, mass and inertia, where it is and how it moves
pub type Body:
	name str
	leaves Leaf[]
	mass f32
	invMass f32
	radius f32 = 0.0   # of the sphere about its center of mass that holds it
	invInertia Mat3   # in the body's space
	position Vec3   # of the center of mass
	orientation Quat = Quat(0, 0, 0, 1)
	velocity Vec3 = Vec3(0, 0, 0)
	spin Vec3 = Vec3(0, 0, 0)   # the angular velocity, radians a second about its axis
	meanVelocity Vec3 = Vec3(0, 0, 0)   # this step's mean over the solver's sub-steps, which carries it
	meanSpin Vec3 = Vec3(0, 0, 0)
	bias Vec3 = Vec3(0, 0, 0)   # the solver's: tau / damping times its motion in this step's sub-steps so far
	turnBias Vec3 = Vec3(0, 0, 0)
	friction f32
	restitution f32
	linearDamping f32 = 0.0
	angularDamping f32 = 0.05
	slow Slowing = Slowing(0.0, 0.0, 1.0, 0.0)   # Havok's solver deactivation of the body's class
	maxSpeed f32 = 0.0   # this body's cap on its speed (the world's units a second); 0 takes the world's
	maxTurn f32 = 0.0   # and on its spin, radians a second; 0 takes Havok's default
	group i64 = 0   # bodies of one group (not 0: a ragdoll's) do not collide, as Havok's system group
	part i64 = -1   # its part of the group's body (0 to 63), whose pairs the world's partPairs may let collide
	layer i64 = -1   # its collision layer (0 to 63) for the world's layerPairs; -1 collides with every layer
	asleep bool = false
	rest Resting = Resting()   # Havok's deactivation checks (sleep.zap)
	turn Mat3   # the orientation's matrix, this step
	invInertiaWorld Mat3
	lo Vec3 = Vec3(0, 0, 0)   # the bounds of its leaves in the world, this step
	hi Vec3 = Vec3(0, 0, 0)

fn zero3():
	Mat3(0.0)

# the rotation matrix of a quaternion
pub fn turnOf(q Quat) Mat3:
	Mat3(q.rotate(Vec3(1, 0, 0)), q.rotate(Vec3(0, 1, 0)), q.rotate(Vec3(0, 0, 1)))

fn roundMoved(r Round, by Vec3) Round:
	match r:
		Hull: .Hull
		Ball(a, b, radius): .Ball(a + by, b + by, radius)

# the inertia of a box of this mass around the points, for a solid with no volume
fn boxInertia(points Vec3[], mass f32):
	lo, hi = points.boundsOf()
	s = hi - lo
	Mat3(
		Vec3(s.y * s.y + s.z * s.z, 0, 0),
		Vec3(0, s.x * s.x + s.z * s.z, 0),
		Vec3(0, 0, s.x * s.x + s.y * s.y)
	) *
		(mass / 12.0)

# whether the symmetric m is positive definite (its leading minors are)
fn isPositive(m Mat3):
	m.m[0] > 0.0 and m.m[0] * m.m[4] - m.m[1] * m.m[3] > 0.0 and m.determinant() > 0.0

# a body of the pieces (in the world, as placed) and this mass; its space keeps the world's axes
pub fn bodyOf(name str, pieces Piece[], mass f32, friction f32, restitution f32) Body:
	polys = pieces.map(polyOf(.positions, .indices, 0, .indices.len / 3))
	solid = polys[0].center.solidAround()
	for p in polys:
		solid.addPoly(p)
	all = pieces.flatMap(.positions.copy())
	lo, hi = all.boundsOf()
	hasVolume = solid.volume > 1.0e-6 * (hi - lo).length().pow(3.0)
	center = solid.centroid() if hasVolume else (lo + hi) * 0.5
	inertia = solid.inertiaOf(mass) if hasVolume else boxInertia(all, mass)
	if not inertia.isPositive(): inertia = boxInertia(all, mass)
	b = bodyFrom(name, pieces, polys, center, mass, inertia, friction, restitution)
	b.refresh()
	b

# A body whose pieces are given in its own frame, standing at `at` turned by `turn`, with its
# center of mass (in that frame), mass and inertia (about the center, in that frame) given: a
# ragdoll's bone, as its file describes it.
pub fn framedBody(
	name str,
	pieces Piece[],
	center Vec3,
	mass f32,
	inertia Mat3,
	at Vec3,
	turn Quat,
	friction f32,
	restitution f32
) Body:
	polys = pieces.map(polyOf(.positions, .indices, 0, .indices.len / 3))
	b = bodyFrom(name, pieces, polys, center, mass, inertia, friction, restitution)
	b.orientation = turn
	b.position = at + turn.rotate(center)
	b.refresh()
	b

# the body of the pieces (and their polys) in a frame whose center of mass is `center`, at rest
# where that frame is the world's
fn bodyFrom(
	name str,
	pieces Piece[],
	polys Poly[],
	center Vec3,
	mass f32,
	inertia Mat3,
	friction f32,
	restitution f32
):
	leaves = []
	for k in 0..pieces.len:
		poly = polys[k].moved(Mat3(1.0), -center)
		llo, lhi = poly.vertices.boundsOf()
		grown = Vec3(pieces[k].shell, pieces[k].shell, pieces[k].shell)
		leaves.push(
			Leaf(
				round = pieces[k].round.roundMoved(-center),
				poly,
				shell = pieces[k].shell,
				lo = llo - grown,
				hi = lhi + grown
			)
		)
	radius = leaves.map((.poly.vertices.map(.length()).max() ?? 0.0) + .shell).max() ?? 0.0
	Body(
		name = name.copy(),
		leaves,
		radius,
		mass,
		invMass = 1.0 / mass,
		invInertia = inertia.inverse(),
		position = center,
		friction,
		restitution,
		turn = Mat3(1.0),
		invInertiaWorld = zero3()
	)

# the matrix, the world's inverse inertia and the bounds of where it is now
pub fn refresh(mut b Body):
	b.turn = b.orientation.turnOf()
	b.invInertiaWorld = b.turn @ b.invInertia @ b.turn.transpose()
	reach = Mat3(
		(b.turn @ Vec3(1, 0, 0)).abs(),
		(b.turn @ Vec3(0, 1, 0)).abs(),
		(b.turn @ Vec3(0, 0, 1)).abs()
	)
	for i in 0..b.leaves.len:
		l = mut ref b.leaves[i]
		mid = b.position + b.turn @ ((l.lo + l.hi) * 0.5)
		half = reach @ ((l.hi - l.lo) * 0.5)
		l.worldLo = mid - half
		l.worldHi = mid + half
		b.lo = l.worldLo if i == 0 else b.lo.min(l.worldLo)
		b.hi = l.worldHi if i == 0 else b.hi.max(l.worldHi)

# the height of the body's lowest point
pub fn lowest(b Body) f32:
	b.leaves.map((.poly.vertices.map(b.toWorld(it).z).min() ?? 0.0) - .shell).min() ??
		b.position.z

# the point of the body's own space where it is in the world now
pub fn toWorld(b Body, p Vec3) Vec3:
	b.position + b.turn @ p

# the world point p in the body's own space
pub fn toLocal(b Body, p Vec3) Vec3:
	b.turn.transpose() @ (p - b.position)

# the velocity of the body's point at `p` in the world
pub fn velocityAt(b Body, p Vec3) Vec3:
	b.velocity + b.spin.cross(p - b.position)

# the impulse j given at the world point p
pub fn push(mut b Body, j Vec3, p Vec3):
	b.velocity += j * b.invMass
	b.spin += b.invInertiaWorld @ (p - b.position).cross(j)

# damping over dt
pub fn damp(mut b Body, dt f32):
	b.velocity *= 1.0 / (1.0 + dt * b.linearDamping)
	b.spin *= 1.0 / (1.0 + dt * b.angularDamping)

# the velocities (and the step's means) kept below Havok's caps after the solve: the body's own,
# else maxSpeed and Havok's default turn
pub fn capSpeeds(mut b Body, maxSpeed f32):
	cap = b.maxSpeed if b.maxSpeed > 0.0 else maxSpeed
	turnCap = b.maxTurn if b.maxTurn > 0.0 else maxTurning
	b.velocity = b.velocity.atMost(cap)
	b.meanVelocity = b.meanVelocity.atMost(cap)
	b.spin = b.spin.atMost(turnCap)
	b.meanSpin = b.meanSpin.atMost(turnCap)

# v shortened to `most` when it is longer
fn atMost(v Vec3, most f32):
	size = v.length()
	v * (most / size) if size > most else v

maxTurning f32 = 31.57   # Havok's default for a body, radians a second

# A class of Havok's solver deactivation (hkpSolverInfo's DeactivationInfo). On each axis, the
# body's velocity as a share of `speed` (meters a second, the world's axes) plus its spin's as a
# share of `turning` (radians a second, the body's axes): at or below 1 on all three, it keeps
# `keep` of its velocities; at or below `rest` on all three, none. `keep` 1 is no slowing.
pub type Slowing:
	speed f32
	turning f32
	keep f32
	rest f32

# the body slowed as its solver deactivation asks, at the end of a solver sub-step
pub fn slowDown(mut b Body, unitsPerMeter f32):
	if b.slow.keep >= 1.0: return
	share = b.velocity.abs() / (b.slow.speed * unitsPerMeter) +
		(b.turn.transpose() @ b.spin).abs() / b.slow.turning
	most = share.x.max(share.y).max(share.z)
	if most > 1.0: return
	kept = f32(0.0) if most <= b.slow.rest else b.slow.keep
	b.velocity *= kept
	b.spin *= kept

# the body carried over dt by this step's mean velocities
pub fn advance(mut b Body, dt f32):
	b.position += b.meanVelocity * dt
	w = Quat(b.meanSpin.x, b.meanSpin.y, b.meanSpin.z, 0.0)
	b.orientation = (b.orientation + (w @ b.orientation) * (0.5 * dt)).normalized()
	b.refresh()
