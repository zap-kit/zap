# A ragdoll in the world, as Havok's hkaRagdollInstance runs one: a rigid body a bone (its
# collision, center of mass, mass and inertia in the bone's frame), joints between them, put where
# a pose has the bones and moving as the pose last moved (from the bones' frames of two frames in
# a row), then run by the world with everything else; the bones' frames read back from where the
# bodies are. Its bodies share a group, so they do not collide with each other.

import math

# a ragdoll's body for one bone: its collision, center of mass, mass and surface
pub type RagdollPart:
	name str
	piece Piece   # its collision in its bone's frame
	center Vec3   # its center of mass in its bone's frame
	mass f32
	inertia Vec3   # about its bone's axes, through its center
	friction f32
	restitution f32
	linearDamping f32
	angularDamping f32
	slow Slowing   # its solver deactivation
	part i64 = -1   # its part, for the world's partPairs
	layer i64 = -1   # its collision layer, for the world's layerPairs

# a joint between parts a (the child) and b, each side's frame in its part's bone frame
pub type RagdollLink:
	kind JointKind
	a i64
	b i64
	frameA Frame
	frameB Frame
	friction f32
	stabilization f32   # the ball socket's velocity stabilization

# a bone's rigid frame in the world: where it is and how it is turned
pub type Placement:
	at Vec3
	turn Quat

# a ragdoll in the world: its parts' bodies and joints
pub type Ragdoll:
	bodies i64[]   # the world's body of each part
	joints i64[]
	centers Vec3[]   # each part's center of mass in its bone's frame

# the turn that takes `before` to `now` over dt, as a spin (radians a second about its axis)
fn spinBetween(before Quat, now Quat, dt f32):
	d = now @ before.inverse()
	if d.w < 0.0: d = -d
	s = d.xyz.length()
	if s < 1.0e-7: return Vec3(0, 0, 0)
	d.xyz / s * (2.0 * s.atan2(d.w) / dt)

fn placedFrame(p Placement, f Frame):
	Frame(pivot = p.at + p.turn.rotate(f.pivot), axes = p.turn.turnOf() @ f.axes)

# The ragdoll's bodies placed by the bones' frames `now`, moving as they moved from `before` dt
# seconds ago, joined by its links; `group` (not 0) its own.
pub fn addRagdoll(
	mut w World,
	parts RagdollPart[],
	links RagdollLink[],
	now Placement[],
	before Placement[],
	dt f32,
	group i64
) Ragdoll:
	bodies = []
	for k, p in parts:
		inertia = Mat3(Vec3(p.inertia.x, 0, 0), Vec3(0, p.inertia.y, 0), Vec3(0, 0, p.inertia.z))
		b = framedBody(p.name, [p.piece.copy()], p.center, p.mass, inertia, now[k].at, now[k].turn,
			p.friction, p.restitution)
		b.linearDamping = p.linearDamping
		b.angularDamping = p.angularDamping
		b.group = group
		b.part = p.part
		b.layer = p.layer
		b.slow = p.slow
		b.velocity = (b.position - before[k].at - before[k].turn.rotate(p.center)) / dt
		b.spin = before[k].turn.spinBetween(now[k].turn, dt)
		w.bodies.push(b)
		bodies.push(w.bodies.len - 1)
	joints = []
	for l in links:
		j = w.addJoint(l.kind, bodies[l.a], bodies[l.b], now[l.a].placedFrame(l.frameA),
			now[l.b].placedFrame(l.frameB))
		w.joints[j].friction = l.friction
		w.joints[j].stabilization = l.stabilization
		joints.push(j)
	Ragdoll(bodies, joints, centers = parts.map(.center))

# each part's bone frame where its body is now
pub fn ragdollPlacements(w World, r Ragdoll) Placement[]:
	(0..r.bodies.len).map(k:
		b = w.bodies[r.bodies[k]]
		Placement(at = b.position - b.orientation.rotate(r.centers[k]), turn = b.orientation)
	)

# whether every body of the ragdoll sleeps
pub fn isRagdollAsleep(w World, r Ragdoll) bool:
	r.bodies.all(w.bodies[it].asleep)
