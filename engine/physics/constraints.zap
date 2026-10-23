# Joints between two bodies (or a body and the world) as Havok's constraints keep them, each made
# of rows the solver takes with the contacts (rows.zap): a ball and socket (the pivots together), a
# hinge (and the axles along each other), a limited hinge (and its angle within its limits), a
# ragdoll joint (Havok's hkpRagdollConstraintData: a ball and socket whose twist about the twist
# axis is limited, whose twist axis keeps within a cone around the parent's and between two
# planes, which together make an ellipse-like limit), a prismatic joint (no turn, a slide along one
# axis between two distances) and a stiff spring (a rod: the pivots kept at its length). Friction
# holds the turn (the slide) up to its most torque (force). The atoms' rows, their order (friction,
# limits, the axle, the pivots), their angles (Havok's atan2 approximation) and their factors are
# SkyrimSE.exe's (reference/exe/havok-solver.md); the prismatic's, which the executable's lin atoms
# would settle, are not read.

import math

# what a joint holds between its two bodies, with its limits
pub type JointKind:
	Ball
	Hinge
	LimitedHinge(min f32, max f32)   # the angle a turns about the axle from b's zero
	Ragdoll(coneMax f32, planeMin f32, planeMax f32, twistMin f32, twistMax f32)
	Prismatic(min f32, max f32)   # how far b's pivot is along a's sliding axis
	Spring(length f32)

# A joint: each side's frame in its body's space (the world's for b -1), its pivot and three
# axes (constraints.zap's header: the axle or twist or sliding axis first).
pub type Joint:
	kind JointKind
	a i64
	b i64   # -1: the world
	pivotA Vec3
	pivotB Vec3
	axesA Mat3
	axesB Mat3
	friction f32 = 0.0   # the most torque (a prismatic's: force) its friction holds
	strength f32 = 1.0   # a malleable one's share of a rigid one's stiffness
	stabilization f32 = 0.0   # the ball socket's velocity stabilization: how much of the bodies' turn the pivot rows leave out
	limitTau f32 = 1.0   # the share of the solver's tau its angular limits close (m_angularLimitsTauFactor)
	threshold f32 = 0.0   # a breakable one breaks when its rows give more impulse in a step (0: never)
	broken bool = false
	impulses f32[] = fill(slots, f32(0.0))   # each slot's impulse last step
	internals f32[] = fill(slots + 1, f32(0.0))   # what the limits' and friction's rows left, and the cone's offset
	rows Row[] = []   # this step's

slots = 12

# a pivot and three axes (columns)
pub type Frame:
	pivot Vec3
	axes Mat3

# the frame (in the world) in the body's space; the world's own for -1
fn localFrame(bodies Body[], i i64, f Frame):
	if i < 0: return f.copy()
	b = bodies[i]
	Frame(pivot = b.toLocal(f.pivot), axes = b.turn.transpose() @ f.axes)

# the ragdoll joint's data (hkpRagdollConstraintData) closes its limits by 0.8 of the solver's tau,
# the others' (the hinge's) by all of it
fn limitTauOf(kind JointKind) f32:
	match kind:
		Ragdoll: 0.8
		_: 1.0

# a joint of the two bodies whose frames are given where they are now, in the world
pub fn jointOf(bodies Body[], kind JointKind, a i64, b i64, fa Frame, fb Frame) Joint:
	la = localFrame(bodies, a, fa)
	lb = localFrame(bodies, b, fb)
	Joint(
		kind,
		a,
		b,
		pivotA = la.pivot,
		pivotB = lb.pivot,
		axesA = la.axes,
		axesB = lb.axes,
		limitTau = kind.limitTauOf()
	)

fn worldPivot(bodies Body[], i i64, p Vec3):
	bodies[i].toWorld(p) if i >= 0 else p

fn worldAxes(bodies Body[], i i64, axes Mat3):
	bodies[i].turn @ axes if i >= 0 else axes

# a joint's pivots and axes in the world
pub type JointPlace:
	pa Vec3
	pb Vec3
	xa Mat3
	xb Mat3

# the joint's pivots and axes where its bodies are now
pub fn jointPlace(j Joint, bodies Body[]) JointPlace:
	JointPlace(
		pa = worldPivot(bodies, j.a, j.pivotA),
		pb = worldPivot(bodies, j.b, j.pivotB),
		xa = worldAxes(bodies, j.a, j.axesA),
		xb = worldAxes(bodies, j.b, j.axesB)
	)

# column k of m (a frame's axis k)
pub fn column(m Mat3, k i64) Vec3:
	Vec3(m.m[k * 3], m.m[k * 3 + 1], m.m[k * 3 + 2])

# Havok's atan2 (hkMath::atan2fApproximation): the angle of (x, y) by a cubic of the smaller
# component over the larger, exact at 0 and 45 degrees
pub fn angleOf(y f32, x f32) f32:
	ay = y.abs()
	ax = x.abs()
	z = ax.min(ay) / (ax.max(ay) + epsilon)
	p = z - 0.12107899785 * z * z - 0.0935228169 * z * z * z
	if ay > ax: p = pi / 2.0 - p
	if x < 0.0: p = pi - p
	if y < 0.0: p = -p
	p

# the hinge's angle as Havok measures it: a's first square axis in b's two (a, the child, turned
# against b)
pub fn hingeAngle(xa Mat3, xb Mat3) f32:
	angleOf(xa.column(1) @ xb.column(2), xa.column(1) @ xb.column(1))

# The angle between two axes and the unit axis the cone limit's row takes: minus a's cross b
# (the executable's mode 0 sign; the planes' mode 1 negates it). None for parallel axes.
fn separation(a Vec3, b Vec3) (f32, Vec3)?:
	x = b.cross(a)
	if x @ x < epsilon: return none
	(angleOf(x.length(), a @ b), x.normalized())

# the twist limit's axis (the twist axes' mean) and how much of the limit is left as they part
fn twistAxis(xa Mat3, xb Mat3) (Vec3, f32):
	sum = xa.column(0) + xb.column(0)
	length = sum.length()
	if length < 1.0e-16: return (xb.column(0), 0.0)
	(sum / length, 0.5 * length)

# the twist about the axis h: a's plane axis against b's
fn twistAbout(xa Mat3, xb Mat3, h Vec3):
	w = h.cross(xb.column(1))
	angleOf(xa.column(1) @ w, xa.column(1) @ w.cross(h))

# the twist of b's frame against a's about the mean of their twist axes
pub fn twistAngle(xa Mat3, xb Mat3) f32:
	h, _ = xa.twistAxis(xb)
	xa.twistAbout(xb, h)

# The ragdoll joint's three angles: the twist, the cone (between the two twist axes) and the plane
# (of a's twist axis against b's plane axis, 0 when square to it).
pub fn ragdollAngles(xa Mat3, xb Mat3) (f32, f32, f32):
	cone, _ = xa.column(0).separation(xb.column(0)) ?? (0.0, Vec3(0, 0, 0))
	apart, _ = xa.column(0).separation(xb.column(1)) ?? (pi / 2.0, Vec3(0, 0, 0))
	(xa.twistAngle(xb), cone, pi / 2.0 - apart)

# the slots each kind's rows take: the pivots' three, the turn's two, the limits', the friction's
slotPoint = 0
slotTurn = 3
slotLow = 6   # the hinge's and the twist's limit, a prismatic's lower
slotHigh = 7   # a prismatic's upper; a ragdoll's cone shares it
slotCone = 7
slotPlane = 8
slotFriction = 9
slotOffset = 12   # in internals: the cone's ratchet

# The cone limit's angle as the stabilized cone keeps it (reference/exe/havok-solver.md): the
# angle is fed in by a step's allowance (half a frame, or 5% of the offset) while the rest of a
# jump is remembered in an offset that decays by the same allowance.
fn ratcheted(mut j Joint, angle f32, s StepInfo):
	before = -j.internals[slotCone]
	offset = j.internals[slotOffset]
	reached = angle - offset
	allowance = (0.5 * s.dt).max(0.05 * offset)
	left = offset - allowance
	fed = reached + allowance
	if before != 0.0 and reached - before > allowance + 0.25 * s.dt:
		left += reached - before
		fed = before + allowance
	j.internals[slotOffset] = left.max(epsilon)
	fed

# friction's rows, one for each of the first n axes of a's frame
fn frictionRows(j Joint, k RowKit, xa Mat3, n i64, s StepInfo) Row[]:
	most = j.friction * s.h / f32(s.microSteps)
	(0..n).map(
		k.frictionRow(slotFriction + it, xa.column(it), most, j.internals[slotFriction + it])
	) if j.friction > 0.0 else []

# the pivots' rows (Havok's old ball and socket method): one along each world axis, closing the
# pivots' gap and the velocity of their rotation alone, scaled by the velocity stabilization
fn pivotRows(k RowKit, stabilization f32):
	armA = k.pa - k.centerA
	armB = k.pb - k.centerB
	rotating = k.spinB.cross(armB) - k.spinA.cross(armA)
	gap = k.pb - k.pa
	(0..3).map(
		k.pivotRow(
			slotPoint + it,
			axisOf(it),
			gap @ axisOf(it),
			stabilization * (rotating @ axisOf(it))
		)
	)

# The rows of the joint where its bodies are now: its friction and limits, what keeps its axle and
# its pivots (a turn row's axis turns a about it and b against; a line row pushes b's pivot along it
# against a's).
pub fn buildRows(mut j Joint, bodies Body[], s StepInfo):
	at = j.jointPlace(bodies)
	pa = at.pa
	pb = at.pb
	xa = at.xa
	xb = at.xb
	k = rowKitOf(bodies, j.a, j.b, pa, pb, s, j.strength)
	rows = []
	match j.kind:
		Spring(length):
			d = pb - pa
			n = d.normalized() if d.length() > 1.0e-6 else Vec3(0, 0, 1)
			rows.push(k.springRow(slotPoint, n, d.length() - length))
		Prismatic(min, max):
			for i in 0..3:
				rows.push(k.lockRow(slotTurn + i, xa, xb, i))
			rows.push(k.lineRow(slotPoint, xa.column(1), (pb - pa) @ xa.column(1)))
			rows.push(k.lineRow(slotPoint + 1, xa.column(2), (pb - pa) @ xa.column(2)))
			slide = xa.column(0)
			along = (pb - pa) @ slide
			rows.push(k.lineLimit(slotLow, slide, along - min))
			rows.push(k.lineLimit(slotHigh, -slide, max - along))
			if j.friction > 0.0:
				rows.push(k.lineFriction(slotFriction, slide, j.friction * s.h / f32(s.microSteps)))
		_:
			rows.extend(j.turnRows(k, xa, xb, s))
			rows.extend(k.pivotRows(j.stabilization))
	j.rows = rows

# the ragdoll's cone limit between the twist axes, none when they are parallel
fn coneRows(mut j Joint, k RowKit, xa Mat3, xb Mat3, coneMax f32, tauFactor f32, s StepInfo):
	angle, axis = xa.column(0).separation(xb.column(0)) ?? return []
	[k.limitRow(slotCone, axis, j.ratcheted(angle, s), -100.0, coneMax, tauFactor)]

# and the planes' limit, a's twist axis against b's plane axis
fn planeRows(k RowKit, xa Mat3, xb Mat3, planeMin f32, planeMax f32, tauFactor f32):
	angle, axis = xa.column(0).separation(xb.column(1)) ?? return []
	[k.limitRow(slotPlane, -axis, pi / 2.0 - angle, planeMin, planeMax, tauFactor)]

# the hinge's angle limit and its axle's two rows
fn hingeRows(mut j Joint, k RowKit, xa Mat3, xb Mat3, tauFactor f32):
	axle = xa.column(0)
	rows = []
	if j.kind is LimitedHinge(min, max):
		before = -j.internals[slotLow]
		angle = before + before.angleBetween(xa.hingeAngle(xb))
		rows.push(k.limitRow(slotLow, axle, angle, min, max, tauFactor))
	rows.push(k.angularRow(slotTurn, xb.column(2), -k.rhsFactor * (axle @ xb.column(1))))
	rows.push(k.angularRow(slotTurn + 1, -xb.column(1), -k.rhsFactor * (axle @ xb.column(2))))
	rows

# the rows of a hinge's or a ragdoll's turn, in the order Havok solves the atoms: friction, the
# limits, the axle
fn turnRows(mut j Joint, k RowKit, xa Mat3, xb Mat3, s StepInfo):
	tauFactor = k.tau * j.limitTau
	rows = []
	match j.kind:
		Hinge, LimitedHinge:
			rows.extend(j.frictionRows(k, xa, 1, s))
			rows.extend(j.hingeRows(k, xa, xb, tauFactor))
		Ragdoll(coneMax, planeMin, planeMax, twistMin, twistMax):
			rows.extend(j.frictionRows(k, xa, 3, s))
			h, share = xa.twistAxis(xb)
			angle = xa.twistAbout(xb, h)
			rows.push(k.limitRow(slotLow, h, angle, twistMin, twistMax, tauFactor * share * share))
			rows.extend(j.coneRows(k, xa, xb, coneMax, tauFactor, s))
			rows.extend(k.planeRows(xa, xb, planeMin, planeMax, tauFactor))
		_: pass
	rows

fn axisOf(i i64):
	Vec3(1, 0, 0) if i == 0 else (Vec3(0, 1, 0) if i == 1 else Vec3(0, 0, 1))

# whether the joint links bodies i and j
pub fn links(j Joint, i i64, k i64) bool:
	not j.broken and ((j.a == i and j.b == k) or (j.a == k and j.b == i))

# each joint's results kept for the next step (the impulses, and what its limits' and friction's
# rows leave), and those whose rows gave more than their threshold broken
pub fn keepResults(bodies Body[], mut joints Joint[], s StepInfo):
	for mut j in joints:
		given = 0.0
		for r in j.rows:
			j.impulses[r.slot] = r.impulse
			match r.kind:
				Clamped: pass
				_: j.internals[r.slot] = leftBy(bodies, j.a, j.b, r, s)
			given += r.impulse.abs()
		if j.threshold > 0.0 and given > j.threshold: j.broken = true

# how far apart the joint's two pivots are now (0 when it holds; a spring's and a prismatic's
# own length and slide left in)
pub fn pivotGap(j Joint, bodies Body[]) f32:
	at = j.jointPlace(bodies)
	(at.pb - at.pa).length()

# how far past its limits the joint's angles are now (radians, 0 within them; a prismatic's and
# the joints without limits 0)
pub fn limitExcess(j Joint, bodies Body[]) f32:
	at = j.jointPlace(bodies)
	match j.kind:
		LimitedHinge(min, max):
			a = at.xa.hingeAngle(at.xb)
			(min - a).max(a - max).max(0.0)
		Ragdoll(coneMax, planeMin, planeMax, twistMin, twistMax):
			twist, cone, plane = at.xa.ragdollAngles(at.xb)
			excess = [
				cone - coneMax,
				planeMin - plane,
				plane - planeMax,
				twistMin - twist,
				twist - twistMax
			]
			(excess.max() ?? 0.0).max(0.0)
		_: 0.0
