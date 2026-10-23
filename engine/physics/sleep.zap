# Havok's deactivation (hkpWorld's integration, as SkyrimSE.exe runs it): every 4th step a body is
# checked against where it stood at its last check, a near check against 0.02 m and a quaternion
# 0.04 apart (about 0.08 radians), every 16th a far check against 0.08 m and 0.16 (hkpSolverInfo's
# maxDistSqrd and maxRotSqrd, the same for every class). A body farther than a check allows starts
# that check's count again from where it is; else the count grows. An island (bodies joined by
# contacts and joints) sleeps when every body has passed more than 5 checks of either kind in a
# row: at the earliest 28 steps after it stopped.

# a body's deactivation checks: the steps since its last far check, and each check's place, turn
# and count of checks passed in a row
pub type Resting:
	steps i64 = 0
	nearAt Vec3 = Vec3(0, 0, 0)
	nearTurn Quat = Quat(0, 0, 0, 1)
	near i64 = 0
	farAt Vec3 = Vec3(0, 0, 0)
	farTurn Quat = Quat(0, 0, 0, 1)
	far i64 = 0

checkEvery = 4
farEvery = 16
passesToSleep = 5   # an island sleeps when every body has passed more than this many checks
nearMeters f32 = 0.02
farMeters f32 = 0.08
nearTurnSquared f32 = 0.0016   # the squared distance of two unit quaternions
farTurnSquared f32 = 0.0256
mostPasses = 64

fn quatDistanceSquared(a Quat, b Quat):
	(a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) + (a.z - b.z) * (a.z - b.z) +
		(a.w - b.w) * (a.w - b.w)

# whether the body stayed within `meters` (in units) and `turnSquared` of the place and turn
fn stayed(b Body, at Vec3, turn Quat, meters f32, turnSquared f32):
	(b.position - at).length() <= meters and b.orientation.quatDistanceSquared(turn) <= turnSquared

# this step's check of the body, when it is a checking step
fn checkRest(mut b Body, unitsPerMeter f32):
	r = mut ref b.rest
	r.steps += 1
	if r.steps % checkEvery != 0: return
	if r.steps % farEvery != 0:
		if b.stayed(r.nearAt, r.nearTurn, nearMeters * unitsPerMeter, nearTurnSquared):
			r.near = (r.near + 1).min(mostPasses)
		else:
			r.near = 0
			r.nearAt = b.position
			r.nearTurn = b.orientation
		return
	r.steps = 0
	if b.stayed(r.farAt, r.farTurn, farMeters * unitsPerMeter, farTurnSquared):
		r.far = (r.far + 1).min(mostPasses)
	else:
		r.far = 0
		r.farAt = b.position
		r.farTurn = b.orientation

# whether the body has passed enough checks in a row to sleep
fn restsLongEnough(b Body):
	b.rest.near.max(b.rest.far) > passesToSleep

# whether the body moved at its last check
pub fn isMoving(b Body) bool:
	b.rest.near == 0 and b.rest.far == 0

# the body woken: awake, its checks starting again
pub fn wake(mut b Body):
	b.asleep = false
	b.rest.near = 0
	b.rest.far = 0

fn rootOf(mut parent i64[], i i64):
	r = i
	while parent[r] != r:
		r = parent[r]
	parent[i] = r
	r

# each awake body checked, and the islands whose every body rests long enough put to sleep, their
# speeds zeroed
fn settle(mut w World):
	for i in 0..w.bodies.len:
		if not w.bodies[i].asleep: w.bodies[i].checkRest(w.unitsPerMeter)
	parent = (0..w.bodies.len).map(it)
	for m in w.manifolds:
		if m.b >= 0: parent[rootOf(parent, m.a)] = rootOf(parent, m.b)
	for j in w.joints:
		if not j.broken and j.a >= 0 and j.b >= 0:
			parent[rootOf(parent, j.a)] = rootOf(parent, j.b)
	ready = fill(w.bodies.len, true)
	for i, mut body in w.bodies:
		if not body.asleep and not body.restsLongEnough(): ready[rootOf(parent, i)] = false
	for i in 0..w.bodies.len:
		b = mut ref w.bodies[i]
		if b.asleep or not ready[rootOf(parent, i)]: continue
		b.asleep = true
		b.velocity = Vec3(0, 0, 0)
		b.spin = Vec3(0, 0, 0)
