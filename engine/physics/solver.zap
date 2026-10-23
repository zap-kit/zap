# Havok 2010's constraint solver (hkpSolver, read from SkyrimSE.exe's hkpWorld step, its solver
# loop and its contact jacobians). A step of dt is solved in `iterations` sub-steps of
# h = dt / iterations, each of `microSteps` passes over the constraints, gravity given before each
# sub-step. A row asks for its velocity rhs = -(tau / damping) * error / h and is solved for the
# impulse damping * (rhs - v) / K, so tau is the share of the error a sub-step closes and damping
# the share of the velocity it stops: a spring-damper on the error. The errors are measured once,
# where the bodies stood at the step's start; the sub-steps move the bodies only virtually: after
# each, every body's velocity carries tau / damping times the sum of its motion in the sub-steps
# so far (a bias the rows see as the error's change), and the step's end leaves the bodies their
# true velocity and carries them by its mean over the sub-steps. Nothing is warm started.
# Contacts: a point's impulse accumulated at or above zero, the points of a manifold solved two at
# a time (exactly, as a 2x2 problem). An overlap deeper than a step's recovery is held as the
# point's allowance, given back 5% a step (at most 1 m/s), so a body placed into another is pushed
# out slowly while its contact carries it (the executable's per-point offset; the solver's own
# share of the error it reads is taken as none). Friction is the manifold's (friction.zap), a
# joint's rows Havok's schemas' (rows.zap, constraints.zap). Restitution, after the solve, parts the
# contacts that closed faster than restingMeters a second (Box2D's relax pass: not read from the
# executable).

# Havok's solver settings (hkpWorldCinfo's), its defaults Havok's own
pub type Solver:
	tau f32 = 0.6
	damping f32 = 1.0
	iterations i64 = 4   # the sub-steps of a step (m_solverIterations)
	microSteps i64 = 1   # the passes over the constraints in a sub-step
	restingMeters f32 = 1.0   # contacts closing slower than this, meters a second, do not bounce

# what a step's rows are built and solved with, in the world's units
pub type StepInfo:
	unitsPerMeter f32
	gravity Vec3
	dt f32
	h f32   # the sub-step
	subSteps i64
	microSteps i64
	tau f32
	gain f32   # tau / damping: the share of a sub-step's motion fed back as error
	rhsFactor f32   # the velocity asked for an error of 1
	frictionRhsFactor f32   # and of friction's anchor (Havok's friction tau is half the tau)
	damping f32
	relaxMost f32   # the most of a contact's allowance given back in a step
	restingSpeed f32

# the solver's factors for a step of dt
pub fn stepOf(s Solver, unitsPerMeter f32, gravity Vec3, dt f32) StepInfo:
	h = dt / f32(s.iterations)
	StepInfo(
		unitsPerMeter,
		gravity,
		dt,
		h,
		subSteps = s.iterations,
		microSteps = s.microSteps,
		tau = s.tau,
		gain = s.tau / s.damping,
		rhsFactor = s.tau / s.damping / h,
		frictionRhsFactor = 0.5 * s.tau / s.damping / h,
		damping = s.damping,
		relaxMost = relaxMeters * unitsPerMeter * dt,
		restingSpeed = s.restingMeters * unitsPerMeter
	)

relaxShare f32 = 0.05   # the share of a contact's allowance given back a step
relaxMeters f32 = 1.0   # and the most, meters a second
allowanceLeast f32 = -1.0e-7   # an allowance stays below zero

# The distance the contact's velocity asked for is made from: its distance less its allowance,
# the allowance relaxed by its share (at most relaxMost); an overlap left deeper than twice the
# relaxing and relaxMost taken into the allowance whole.
fn allowedDistance(mut c Contact, distance f32, relaxMost f32):
	left = distance - c.allowance
	relax = (-relaxShare * c.allowance).min(relaxMost)
	c.allowance += relax
	e = left - relax
	if -left > 2.0 * relax + relaxMost:
		c.allowance += left
		e -= left
	c.allowance = c.allowance.min(allowanceLeast)
	e

fn invMassOf(bodies Body[], i i64) f32:
	0.0 if i < 0 or bodies[i].asleep else bodies[i].invMass

# what an impulse along d2 at the arms (a2, b2) does to the velocity along d1 at (a1, b1): K's
# entry; with the same arms and directions, the inverse of the mass the impulse meets
fn response(bodies Body[], a i64, b i64, a1 Vec3, b1 Vec3, d1 Vec3, a2 Vec3, b2 Vec3, d2 Vec3):
	k = (invMassOf(bodies, a) + invMassOf(bodies, b)) * (d1 @ d2)
	if not bodies[a].asleep: k += (bodies[a].invInertiaWorld @ a2.cross(d2)) @ a1.cross(d1)
	if b >= 0 and not bodies[b].asleep:
		k += (bodies[b].invInertiaWorld @ b2.cross(d2)) @ b1.cross(d1)
	k

# the velocity of b's point at its arm relative to a's
fn relativeVelocity(bodies Body[], a i64, b i64, armA Vec3, armB Vec3):
	va = bodies[a].velocity + bodies[a].spin.cross(armA)
	if b < 0: return -va
	bodies[b].velocity + bodies[b].spin.cross(armB) - va

# the impulse j given to body i at the arm
fn take(mut bodies Body[], i i64, arm Vec3, j Vec3):
	if i < 0 or bodies[i].asleep: return
	b = mut ref bodies[i]
	b.velocity += j * b.invMass
	b.spin += b.invInertiaWorld @ arm.cross(j)

# the impulse j given to b at its arm, and taken from a at its
fn apply(mut bodies Body[], a i64, b i64, armA Vec3, armB Vec3, j Vec3):
	take(bodies, a, armA, -j)
	take(bodies, b, armB, j)

# the bodies hung from the world by a joint: placed by their joints alone, their overlaps with the
# scene are held (not deepened) but not pushed out, which would fight the joint where the game
# hangs them into a beam
fn hungBodies(bodies Body[], joints Joint[]):
	hung = fill(bodies.len, false)
	for j in joints:
		if j.broken: continue
		if j.a >= 0 and j.b < 0: hung[j.a] = true
		if j.b >= 0 and j.a < 0: hung[j.b] = true
	hung

# the arms, masses and velocities asked for of the step's contacts
fn prepareContacts(mut bodies Body[], mut manifolds Manifold[], joints Joint[], s StepInfo):
	hung = hungBodies(bodies, joints)
	for mi in 0..manifolds.len:
		a = manifolds[mi].a
		b = manifolds[mi].b
		n = manifolds[mi].normal
		held = b < 0 and hung[a]
		manifolds[mi].pairAcross()
		for k in 0..manifolds[mi].contacts.len:
			c = mut ref manifolds[mi].contacts[k]
			c.armA = c.point - bodies[a].position
			c.armB = c.point - bodies[b].position if b >= 0 else Vec3(0, 0, 0)
			k1 = response(bodies, a, b, c.armA, c.armB, n, c.armA, c.armB, n)
			c.normalMass = s.damping / k1 if k1 > 0.0 else 0.0
			c.closing = relativeVelocity(bodies, a, b, c.armA, c.armB) @ n
			distance = c.allowedDistance(-c.depth, s.relaxMost)
			c.rhs = -s.rhsFactor * (distance.max(0.0) if held else distance)
			c.normalImpulse = 0.0

# one point's normal impulse, accumulated at or above zero
fn solveSingle(mut bodies Body[], mut m Manifold, k i64):
	c = m.contacts[k].copy()
	v = relativeVelocity(bodies, m.a, m.b, c.armA, c.armB) @ m.normal
	total = (c.normalImpulse + c.normalMass * (c.rhs - v)).max(0.0)
	apply(bodies, m.a, m.b, c.armA, c.armB, m.normal * (total - c.normalImpulse))
	m.contacts[k].normalImpulse = total

# Two points' normal impulses solved together (Havok's pair contact; Box2D's block solver): the
# impulses at or above zero that give each point its velocity asked for, or leave it faster.
fn solvePair(mut bodies Body[], mut m Manifold, i i64, j i64, damping f32):
	c1 = m.contacts[i].copy()
	c2 = m.contacts[j].copy()
	n = m.normal
	m11 = 1.0 / c1.normalMass
	m22 = 1.0 / c2.normalMass
	m12 = response(bodies, m.a, m.b, c1.armA, c1.armB, n, c2.armA, c2.armB, n) / damping
	a1 = c1.normalImpulse
	a2 = c2.normalImpulse
	b1 = (relativeVelocity(bodies, m.a, m.b, c1.armA, c1.armB) @ n) - c1.rhs - (m11 * a1 + m12 * a2)
	b2 = (relativeVelocity(bodies, m.a, m.b, c2.armA, c2.armB) @ n) - c2.rhs - (m12 * a1 + m22 * a2)
	pair = pairImpulses(m11, m12, m22, b1, b2)
	if pair == none:
		solveSingle(bodies, m, i)
		solveSingle(bodies, m, j)
		return
	x1, x2 = pair ?? return
	apply(bodies, m.a, m.b, c1.armA, c1.armB, n * (x1 - a1))
	apply(bodies, m.a, m.b, c2.armA, c2.armB, n * (x2 - a2))
	m.contacts[i].normalImpulse = x1
	m.contacts[j].normalImpulse = x2

# the impulses x >= 0 with M x + b >= 0 and x (M x + b) = 0, for the symmetric M of m11, m12, m22
fn pairImpulses(m11 f32, m12 f32, m22 f32, b1 f32, b2 f32) (f32, f32)?:
	det = m11 * m22 - m12 * m12
	if det > 1.0e-3 * m11 * m22:
		x1 = (m12 * b2 - m22 * b1) / det
		x2 = (m12 * b1 - m11 * b2) / det
		if x1 >= 0.0 and x2 >= 0.0: return (x1, x2)
	x1 = -b1 / m11
	if x1 >= 0.0 and m12 * x1 + b2 >= 0.0: return (x1, f32(0.0))
	x2 = -b2 / m22
	if x2 >= 0.0 and m12 * x2 + b1 >= 0.0: return (f32(0.0), x2)
	if b1 >= 0.0 and b2 >= 0.0: return (f32(0.0), f32(0.0))
	none

# the point farthest from the first made the second, so the first pair spans the manifold (two
# points side by side would carry it alone and turn it)
fn pairAcross(mut m Manifold):
	if m.contacts.len < 3: return
	first = m.contacts[0].point
	far = 1
	for k in 2..m.contacts.len:
		if (m.contacts[k].point - first).length() > (m.contacts[far].point - first).length():
			far = k
	if far == 1: return
	other = m.contacts[1].copy()
	m.contacts[1] = m.contacts[far].copy()
	m.contacts[far] = other

# one pass over a manifold's points, two at a time
fn solveContacts(mut bodies Body[], mut m Manifold, damping f32):
	k = 0
	while k + 1 < m.contacts.len:
		solvePair(bodies, m, k, k + 1, damping)
		k += 2
	if k < m.contacts.len: solveSingle(bodies, m, k)

# the contacts that pushed after closing fast part at their restitution times that speed
fn bounce(mut bodies Body[], mut manifolds Manifold[], s StepInfo):
	for mi in 0..manifolds.len:
		restitution = manifolds[mi].restitution
		if restitution <= 0.0: continue
		a = manifolds[mi].a
		b = manifolds[mi].b
		n = manifolds[mi].normal
		for k in 0..manifolds[mi].contacts.len:
			c = mut ref manifolds[mi].contacts[k]
			if c.closing >= -s.restingSpeed or c.normalImpulse <= 0.0: continue
			closing = relativeVelocity(bodies, a, b, c.armA, c.armB) @ n
			total = (c.normalImpulse + c.normalMass * (-restitution * c.closing - closing)).max(0.0)
			apply(bodies, a, b, c.armA, c.armB, n * (total - c.normalImpulse))
			c.normalImpulse = total

# The end of a sub-step for each awake body: slowed by its solver deactivation, its true velocity
# (the solver's less the bias) added to the bias times the gain; then, but for the last sub-step,
# the bias and gravity given back to its velocity; after the last, the bias over the gain and the
# sub-steps is the mean velocity that carries it.
fn endSubStep(mut bodies Body[], s StepInfo, last bool):
	for mut b in bodies:
		if b.asleep: continue
		b.slowDown(s.unitsPerMeter)
		real = b.velocity - b.bias
		realSpin = b.spin - b.turnBias
		b.bias += real * s.gain
		b.turnBias += realSpin * s.gain
		if last:
			share = 1.0 / (s.gain * f32(s.subSteps))
			b.meanVelocity = b.bias * share
			b.meanSpin = b.turnBias * share
			b.velocity = real
			b.spin = realSpin
		else:
			b.velocity = real + b.bias + s.gravity * s.h
			b.spin = realSpin + b.turnBias

# the contacts and the joints (rows.zap) solved together for a step
pub fn solve(mut bodies Body[], mut manifolds Manifold[], mut joints Joint[], s StepInfo):
	prepareContacts(bodies, manifolds, joints, s)
	for mut m in manifolds:
		m.prepareGrip(bodies, s)
	for mut j in joints:
		if not j.broken: j.buildRows(bodies, s)
	for mut b in bodies:
		b.bias = Vec3(0, 0, 0)
		b.turnBias = Vec3(0, 0, 0)
		if not b.asleep: b.velocity += s.gravity * s.h
	for k in 0..s.subSteps:
		loop s.microSteps:
			for mut m in manifolds:
				solveContacts(bodies, m, s.damping)
				m.solveGrip(bodies)
			solveJoints(bodies, joints, s)
		endSubStep(bodies, s, k == s.subSteps - 1)
	for mut m in manifolds:
		m.keepGrip(bodies, s.dt)
	bounce(bodies, manifolds, s)
	keepResults(bodies, joints, s)
