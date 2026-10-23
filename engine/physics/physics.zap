# Rigid-body physics in the manner of Havok 2010: convex bodies on a static scene of triangles,
# joints, ragdolls and a character controller. The world is stepped as Havok steps a game's: a
# fixed step of 1/60 s, the contacts found, the constraints solved in the solver's sub-steps
# (solver.zap, gravity given a sub-step at a time), the bodies carried, and the islands that have
# stayed in place put to sleep (sleep.zap). Lengths are the world's units, `unitsPerMeter` of them
# to a meter, masses kilograms, z up. The same calls give the same frames.

# the bodies, their joints and the scene they rest on
pub type World:
	unitsPerMeter f32
	scene Scene
	bodies Body[] = []
	manifolds Manifold[] = []
	joints Joint[] = []
	solver Solver = Solver()
	subStep f32 = 1.0 / 60.0   # the step the world is run in, whatever time it is given
	pending f32 = 0.0   # time given to step not yet stepped
	steps i64 = 0
	partPairs i64[] = []   # by part, the bits of the parts of the same group it collides with
	layerPairs i64[] = []   # by layer, the bits of the layers it collides with; empty: all collide

gravityMeters f32 = 9.81
maxSpeedMeters f32 = 104.4   # Havok's default cap on a body's speed
marginMeters f32 = 0.02   # contacts kept this far apart, so a resting body keeps its points
matchMeters f32 = 0.02   # a contact this near last step's same point is it again

# an empty world measured in units of which unitsPerMeter make a meter, solved with Havok's
# default settings
pub fn worldOf(unitsPerMeter f32) World:
	World(unitsPerMeter, scene = sceneOf(unitsPerMeter))

# gravity in the world's units
pub fn gravity(w World) Vec3:
	Vec3(0, 0, -gravityMeters * w.unitsPerMeter)

# how far apart contacts are kept, in the world's units
pub fn margin(w World) f32:
	marginMeters * w.unitsPerMeter

# how far apart body i's contacts are found: the margin and what it may cross this step (so a
# fast body meets what it would pass through)
fn reach(w World, i i64):
	w.margin() + w.bodies[i].velocity.length() * w.subStep

# a static surface: triangles (three indices each) where they stand, each of its material (none:
# all 0)
pub fn addSurface(
	mut w World,
	positions Vec3[],
	indices u32[],
	friction f32,
	restitution f32,
	materials i64[] = []
):
	for t in 0..indices.len / 3:
		w.scene.addTriangle(
			positions[indices[t * 3]],
			positions[indices[t * 3 + 1]],
			positions[indices[t * 3 + 2]],
			friction,
			restitution,
			materials[t] if t < materials.len else 0
		)

# a dynamic body of the pieces where they stand; its index
pub fn addBody(mut w World, name str, pieces Piece[], mass f32, friction f32, restitution f32) i64:
	w.bodies.push(bodyOf(name, pieces, mass, friction, restitution))
	w.bodies.len - 1

# a joint of the world's bodies (constraints.zap), its frames given where they are now; its index
pub fn addJoint(mut w World, kind JointKind, a i64, b i64, fa Frame, fb Frame) i64:
	w.joints.push(jointOf(w.bodies, kind, a, b, fa, fb))
	w.joints.len - 1

# the pairs of bodies a joint links, which do not collide
fn jointPairs(w World):
	out {i64: bool} = {}
	for j in w.joints:
		if j.broken or j.a < 0 or j.b < 0: continue
		out[j.a.min(j.b) * 1_000_000 + j.a.max(j.b)] = true
	out

# how many bodies are awake
pub fn awakeCount(w World) i64:
	w.bodies.count(not .asleep)

# the world run for dt seconds in whole steps, what is left kept for the next call
pub fn step(mut w World, dt f32):
	w.pending += dt
	while w.pending >= w.subStep * 0.999:
		w.pending -= w.subStep
		w.stepOnce()

# whether two collision layers collide: a layer outside the world's table (-1 too) meets them all
pub fn layersMeet(w World, a i64, b i64) bool:
	if a < 0 or b < 0 or a >= w.layerPairs.len or b >= w.layerPairs.len: return true
	(w.layerPairs[a] >> b) & 1 != 0

# two bodies of one group collide only when the world's partPairs say their parts do
fn partsCollide(w World, i i64, j i64):
	a = w.bodies[i].part
	b = w.bodies[j].part
	if a < 0 or b < 0 or a >= w.partPairs.len: return false
	(w.partPairs[a] >> b) & 1 != 0

# the contacts of this step, each matched with last step's of the same key
fn collideAll(mut w World):
	found = []
	for i in 0..w.bodies.len:
		if not w.bodies[i].asleep: w.scene.collideScene(w.bodies, i, w.reach(i), found)
	linked = w.jointPairs()
	for (i, j) in bodyPairs(w.bodies, w.margin(), w.subStep):
		if i.min(j) * 1_000_000 + i.max(j) in linked: continue
		g = w.bodies[i].group
		if g != 0 and g == w.bodies[j].group and not w.partsCollide(i, j): continue
		if not w.layersMeet(w.bodies[i].layer, w.bodies[j].layer): continue
		collidePair(w.bodies, i, j, w.reach(i) + w.reach(j) - w.margin(), found)
	last {i64: i64} = {}
	for k, mut manifold in w.manifolds:
		last[manifold.key] = k
	near = matchMeters * w.unitsPerMeter
	for m in 0..found.len:
		k = last.get(found[m].key) ?? continue
		found[m].keepFrom(w.manifolds[k], near)
	found

fn stepOnce(mut w World):
	dt = w.subStep
	maxSpeed = maxSpeedMeters * w.unitsPerMeter
	for mut body in w.bodies:
		if not body.asleep: body.damp(dt)
	w.manifolds = w.collideAll()
	w.wakeTouched()
	solve(w.bodies, w.manifolds, w.joints, w.solver.stepOf(w.unitsPerMeter, w.gravity(), dt))
	for mut body in w.bodies:
		if body.asleep: continue
		body.capSpeeds(maxSpeed)
		body.advance(dt)
	w.settle()
	w.steps += 1

# a sleeping body met by an awake one that moved at its last check wakes, as does one joined to an
# awake one
fn wakeTouched(mut w World):
	for m in w.manifolds:
		w.wakeEither(m.a, m.b)
	for j in w.joints:
		if not j.broken: w.wakeEither(j.a, j.b)

fn wakeEither(mut w World, a i64, b i64):
	if a < 0 or b < 0 or w.bodies[a].asleep == w.bodies[b].asleep: return
	mover = b if w.bodies[a].asleep else a
	sleeper = a if w.bodies[a].asleep else b
	if w.bodies[mover].isMoving(): w.bodies[sleeper].wake()
