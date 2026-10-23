# The cell's constrained clutter (the rabbits and pheasants hung behind the bar, a book's cover):
# each model's constraints (nif/havok.zap) made the world's joints between its bodies, a body that
# does not move (the hook, held where it was placed as the game's fixed motion holds it) standing
# as the world. Havok's lengths are meters, the world's Skyrim's units (havokScale to a meter).

import skyrim.nif
import engine.physics

# the bodies a model's constraints link, in the order they hang, and where the first is held
pub type Chain:
	editorId str
	anchor Vec3?   # the pivot of its joint to what does not move, none when it hangs free
	bodies i64[]
	joints i64[]

# a frame of a body's space (Havok units) where the model placed by `place` puts it
fn frameIn(c nif.Collider, place Mat4, f nif.JointFrame):
	to = place @ c.transform
	axes = Mat3(
		to.applyDirection(f.axes.column(0)).normalized(),
		to.applyDirection(f.axes.column(1)).normalized(),
		to.applyDirection(f.axes.column(2)).normalized()
	)
	physics.Frame(pivot = to.applyPoint(f.pivot), axes)

# the world's joint of a constraint's: its distances in the world's units
fn jointKindOf(j nif.Joint) physics.JointKind:
	s = nif.havokScale
	match j:
		BallJoint: .Ball
		HingeJoint: .Hinge
		LimitedHingeJoint(min, max, _): .LimitedHinge(min, max)
		RagdollJoint(cone, planeMin, planeMax, twistMin, twistMax, _):
			.Ragdoll(cone, planeMin, planeMax, twistMin, twistMax)
		PrismaticJoint(min, max, _): .Prismatic(min * s, max * s)
		SpringJoint(length): .Spring(length * s)

# the most a joint's friction holds: a torque (N m) in the world's units, a prismatic's force (N)
fn frictionOf(j nif.Joint):
	s = nif.havokScale
	match j:
		LimitedHingeJoint(_, _, friction): friction * s * s
		RagdollJoint(_, _, _, _, _, friction): friction * s * s
		PrismaticJoint(_, _, friction): friction * s
		_: 0.0

fn sameConstraint(a nif.Constraint, b nif.Constraint):
	a.entityA == b.entityA and a.entityB == b.entityB and a.a.pivot == b.a.pivot and
		a.b.pivot == b.b.pivot

# The joints of the model's constraints, `bodies` its bodies by their blocks (a block not there
# does not move: the world), each constraint once; the chain they make.
pub fn addConstraints(
	mut cw CellWorld,
	colliders nif.Collider[],
	bodies {i64: i64},
	editorId str,
	place Mat4
):
	seen nif.Constraint[] = []
	chain = Chain(editorId = editorId.copy(), anchor = none, bodies = [], joints = [])
	for c in colliders:
		for k in c.constraints:
			if seen.any(.sameConstraint(k)): continue
			seen.push(k.copy())
			a = bodies.get(k.entityA) ?? -1
			b = bodies.get(k.entityB) ?? -1
			if a < 0 and b < 0: continue
			ca = colliders.find(.block == k.entityA) ?? continue
			cb = colliders.find(.block == k.entityB) ?? continue
			fa = frameIn(ca, place, k.a)
			fb = frameIn(cb, place, k.b)
			j = cw.world.addJoint(k.joint.jointKindOf(), a, b, fa, fb)
			cw.world.joints[j].friction = k.joint.frictionOf()
			cw.world.joints[j].strength = k.strength
			cw.world.joints[j].threshold = k.threshold * nif.havokScale
			chain.joints.push(j)
			if a < 0 or b < 0: chain.anchor = fb.pivot if b < 0 else fa.pivot
			for i in [a, b]:
				if i >= 0 and i not in chain.bodies: chain.bodies.push(i)
	if not chain.joints.isEmpty: cw.chains.push(chain)

# how far the chain's lowest body hangs below its anchor, how far its farthest body is from it
pub fn chainReach(cw CellWorld, chain Chain) (f32, f32):
	anchor = chain.anchor ?? return (0.0, 0.0)
	below = chain.bodies.map(anchor.z - cw.world.bodies[it].position.z).max() ?? 0.0
	far = chain.bodies.map((cw.world.bodies[it].position - anchor).length()).max() ?? 0.0
	(below, far)
