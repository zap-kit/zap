# The joints' rows, solved by the solver (solver.zap) with the contacts, as Havok 2010's schemas
# solve them (reference/exe/havok-solver.md): a row is one direction the two bodies' velocities
# are held in, along a line through both pivots or about an axis, solved for the impulse
# invDiag * (rhs - J v), the rhs the error where the bodies stood at the step's start times
# tau / damping over the sub-step, the solver's sub-steps feeding back what the bodies have moved
# since. Three kinds: an impulse accumulated within bounds (the pivots', the axles', a slide's), an
# angular limit (it weighs the sub-steps' bias and the velocity apart and keeps its accumulated
# impulse of one sign by a test, never a clamp) and angular friction (each pass's impulse cut to a
# most).

# how a row's impulse is bounded
pub type RowKind:
	Clamped(lo f32, hi f32)   # accumulated within these
	Limit(lower f32, upper f32, tauFactor f32)   # the bounds and the share of the error it closes
	Slip(most f32)   # each pass's impulse at most this

# one direction a joint holds the two bodies' velocities in, with its accumulated impulse
pub type Row:
	slot i64
	line Vec3   # the impulse's direction on b's pivot (against a's)
	turnA Vec3   # how the impulse turns each body: the arm's cross product and the axis
	turnB Vec3
	mass f32   # the inverse of the mass the impulse meets, the solver's factor over it
	rhs f32   # the velocity along it asked for
	kind RowKind
	impulse f32 = 0.0
	used f32 = 1.0   # a Slip row's last cut: the share of the pass's impulse kept

# what a joint's rows are made from this step: each body's inverse mass and inertia (none for the
# world or a sleeping body), center and spin, the pivots in the world, the solver's factors
pub type RowKit:
	invMassA f32
	invMassB f32
	invInertiaA Mat3
	invInertiaB Mat3
	centerA Vec3
	centerB Vec3
	spinA Vec3
	spinB Vec3
	pa Vec3
	pb Vec3
	rhsFactor f32   # the velocity asked for an error of 1
	invH f32   # and for an angle's limit, per sub-step
	tau f32
	damping f32
	strength f32

unbounded f32 = 1.0e30
epsilon f32 = 1.1920929e-7   # added to every mass before the division

fn invMass(bodies Body[], i i64) f32:
	0.0 if i < 0 or bodies[i].asleep else bodies[i].invMass

fn invInertia(bodies Body[], i i64):
	Mat3(0.0) if i < 0 or bodies[i].asleep else bodies[i].invInertiaWorld

fn centerOf(bodies Body[], i i64, otherwise Vec3):
	bodies[i].position if i >= 0 else otherwise

fn spinOf(bodies Body[], i i64):
	Vec3(0, 0, 0) if i < 0 or bodies[i].asleep else bodies[i].spin

# what the rows of a joint between bodies a and b are made from this step
pub fn rowKitOf(bodies Body[], a i64, b i64, pa Vec3, pb Vec3, s StepInfo, strength f32) RowKit:
	RowKit(
		invMassA = invMass(bodies, a),
		invMassB = invMass(bodies, b),
		invInertiaA = invInertia(bodies, a),
		invInertiaB = invInertia(bodies, b),
		centerA = centerOf(bodies, a, pa),
		centerB = centerOf(bodies, b, pb),
		spinA = spinOf(bodies, a),
		spinB = spinOf(bodies, b),
		pa,
		pb,
		rhsFactor = s.rhsFactor,
		invH = 1.0 / s.h,
		tau = s.tau,
		damping = s.damping,
		strength
	)

# a row of these directions asking for velocity rhs, its mass worked out from both bodies and
# scaled by `factor`
fn rowOf(
	k RowKit,
	slot i64,
	line Vec3,
	turnA Vec3,
	turnB Vec3,
	rhs f32,
	kind RowKind,
	factor f32
):
	inverse = (k.invMassA + k.invMassB) * (line @ line) + (k.invInertiaA @ turnA) @ turnA +
		(k.invInertiaB @ turnB) @ turnB
	Row(
		slot,
		line,
		turnA,
		turnB,
		mass = factor * k.strength / (inverse + epsilon) if inverse > 0.0 else 0.0,
		rhs,
		kind
	)

fn bounds(lo f32, hi f32):
	RowKind.Clamped(lo, hi)

# a line row along n pushing b's pivot, the levers taken from the points (a's arm reaching atA, b's
# atB)
fn lineAt(k RowKit, slot i64, n Vec3, rhs f32, atA Vec3, atB Vec3, kind RowKind):
	armA = atA - k.centerA
	armB = atB - k.centerB
	k.rowOf(slot, n, -armA.cross(n), armB.cross(n), rhs, kind, k.damping)

# b's pivot kept where `error` (along n) says it is from a's, through b's pivot
pub fn lineRow(k RowKit, slot i64, n Vec3, error f32) Row:
	k.lineAt(slot, n, -k.rhsFactor * error, k.pb, k.pb, bounds(-unbounded, unbounded))

# b's pivot kept `gap` or more along n
pub fn lineLimit(k RowKit, slot i64, n Vec3, gap f32) Row:
	k.lineAt(slot, n, -k.rhsFactor * gap, k.pb, k.pb, bounds(0.0, unbounded))

# the pivots' slide along n held by friction up to `most`
pub fn lineFriction(k RowKit, slot i64, n Vec3, most f32) Row:
	k.lineAt(slot, n, 0.0, k.pb, k.pb, bounds(-most, most))

# a ball and socket's row along n: the pivots' gap along it closed, `drift` (the pivots' velocity
# along n from the bodies' spin, scaled by the velocity stabilization) added to the velocity asked
pub fn pivotRow(k RowKit, slot i64, n Vec3, error f32, drift f32) Row:
	k.lineAt(slot, n, -k.rhsFactor * error + drift, k.pa, k.pb, bounds(-unbounded, unbounded))

# a stiff spring's row along n, both bodies' levers taken from a's pivot as Havok's builder does
pub fn springRow(k RowKit, slot i64, n Vec3, error f32) Row:
	k.lineAt(slot, n, -k.rhsFactor * error, k.pa, k.pa, bounds(-unbounded, unbounded))

# an angular row turning a about `axis` and b against it, asking for the velocity `rhs`
pub fn angularRow(k RowKit, slot i64, axis Vec3, rhs f32) Row:
	k.rowOf(slot, Vec3(0, 0, 0), axis, -axis, rhs, bounds(-unbounded, unbounded), k.damping)

# b's turn against a's about `axis` held, `error` (an angle) brought back
pub fn turnRow(k RowKit, slot i64, axis Vec3, error f32) Row:
	k.angularRow(slot, -axis, -k.rhsFactor * error)

# an angle about `axis` kept between `lower` and `upper`; tauFactor is the share of the solver's
# tau the joint closes
pub fn limitRow(
	k RowKit,
	slot i64,
	axis Vec3,
	angle f32,
	lower f32,
	upper f32,
	tauFactor f32
) Row:
	k.rowOf(
		slot,
		Vec3(0, 0, 0),
		axis,
		-axis,
		-k.invH * angle,
		.Limit(-k.invH * lower * tauFactor, -k.invH * upper * tauFactor, tauFactor),
		tauFactor
	)

# the turn about `axis` held by friction up to `most` a pass; `before` is what the last step's
# friction left (its internal solver data)
pub fn frictionRow(k RowKit, slot i64, axis Vec3, most f32, before f32) Row:
	k.rowOf(slot, Vec3(0, 0, 0), axis, -axis, k.invH * before, .Slip(most), 1.0)

# b's turn locked to a's about the world's axis i: the small turn from a's axes to b's
pub fn lockRow(k RowKit, slot i64, xa Mat3, xb Mat3, i i64) Row:
	e = Vec3(0, 0, 0)
	for c in 0..3:
		e += xa.column(c).cross(xb.column(c)) * 0.5
	axis = axisOf(i)
	k.turnRow(slot, axis, e @ axis)

# the velocity of the bodies along the row
fn rowVelocity(bodies Body[], a i64, b i64, r Row):
	v = 0.0
	if a >= 0: v += r.turnA @ bodies[a].spin - r.line @ bodies[a].velocity
	if b >= 0: v += r.line @ bodies[b].velocity + r.turnB @ bodies[b].spin
	v

# body i's spin without the solver's bias, and the bias
fn realSpin(bodies Body[], i i64):
	Vec3(0, 0, 0) if i < 0 or bodies[i].asleep else bodies[i].spin - bodies[i].turnBias

fn spinBias(bodies Body[], i i64):
	Vec3(0, 0, 0) if i < 0 or bodies[i].asleep else bodies[i].turnBias

# An angular limit's impulse for this pass: the weighed error is p (the bias given tauFactor, the
# velocity the damping); beyond the lower bound while the accumulated impulse is positive, or
# beyond the upper while it is negative, it is the distance to that bound.
fn limitDelta(
	bodies Body[],
	a i64,
	b i64,
	r Row,
	bound (f32, f32, f32),
	s StepInfo
):
	lower, upper, tauFactor = bound
	biasPart = r.turnA @ spinBias(bodies, a) + r.turnB @ spinBias(bodies, b)
	velocityPart = r.turnA @ realSpin(bodies, a) + r.turnB @ realSpin(bodies, b)
	p = tauFactor * r.rhs - (tauFactor / s.gain * biasPart + s.damping * velocityPart)
	low = (p - lower) * r.mass
	high = (p - upper) * r.mass
	if low > -r.impulse: return low
	if high < -r.impulse: return high
	0.0

# this pass's impulse for the row, and for a Slip row the share of it kept
fn deltaOf(bodies Body[], a i64, b i64, r Row, s StepInfo) (f32, f32):
	match r.kind:
		Clamped(lo, hi):
			total = (r.impulse + r.mass * (r.rhs - rowVelocity(bodies, a, b, r))).clamp(lo, hi)
			(total - r.impulse, 1.0)
		Limit(lower, upper, tauFactor):
			(limitDelta(bodies, a, b, r, (lower, upper, tauFactor), s), 1.0)
		Slip(most):
			delta = r.mass * (r.rhs - rowVelocity(bodies, a, b, r))
			kept = (most / delta.abs()).min(1.0) if delta.abs() > 0.0 else 1.0
			(delta * kept, kept)

fn give(mut bodies Body[], i i64, line Vec3, turn Vec3, amount f32):
	if i < 0 or bodies[i].asleep: return
	b = mut ref bodies[i]
	b.velocity += line * (amount * b.invMass)
	b.spin += b.invInertiaWorld @ (turn * amount)

# one pass over the joints' rows, in the order they were built
pub fn solveJoints(mut bodies Body[], mut joints Joint[], s StepInfo):
	for mut joint in joints:
		if joint.broken: continue
		a = joint.a
		b = joint.b
		for ri in 0..joint.rows.len:
			r = joint.rows[ri].copy()
			delta, used = deltaOf(bodies, a, b, r, s)
			give(bodies, a, -r.line, r.turnA, delta)
			give(bodies, b, r.line, r.turnB, delta)
			joint.rows[ri].impulse += delta
			joint.rows[ri].used = used

# What a limit's or friction's row leaves for the next step (Havok's internal solver data): the
# velocity asked over the sub-step less the step's mean motion along the row, a friction's cut by
# its last pass's share. A limit's is about minus the angle the next step starts from.
pub fn leftBy(bodies Body[], a i64, b i64, r Row, s StepInfo) f32:
	moved = r.turnA @ meanSpinOf(bodies, a) + r.turnB @ meanSpinOf(bodies, b)
	left = r.rhs * s.h - s.dt * moved
	match r.kind:
		Slip: left * r.used
		_: left
