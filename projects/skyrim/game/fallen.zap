# An actor who dies falls as its skeleton's ragdoll (skeleton.hkx's, prepared with the cast), as
# the game hands a dead actor to Havok: the pose it had mapped to the ragdoll's bones (the
# skeleton mapper, animation to ragdoll), its bodies set there moving as the last two frames
# moved, run by the cell's world; each frame the ragdoll's pose mapped back (ragdoll to
# animation) for the skinned body, the bones the ragdoll does not drive keeping the local
# transforms they last had. Lengths scale with the actor's height (its masses do not).

import engine
import math
import skyrim.hkx
import skyrim.nif
import engine.physics
import world

pub type Fallen:
	resident i64
	ragdoll physics.Ragdoll
	place hkx.Transform   # where the actor stood when it fell: its feet, its turn about z, its scale
	locals hkx.Transform[]   # the animation skeleton's locals as it fell, by bone
	nodes i64[]   # the rig's node of each bone
	pose f32[]   # the rig's locals this frame (engine.Pose.locals)

ragdollGroup = 1_000   # the first body group of a ragdoll, one more each
# the solver deactivation of the ragdoll's bodies (body.zap's levels): the file's bodies have it
# off, and the game's ragdoll settles within seconds by what is not read (its behavior's powered
# ragdoll); this stands in for it

fn limitsKind(l hkx.RagdollLimits) physics.JointKind:
	match l:
		ConeLimits(cone, planeMin, planeMax, twistMin, twistMax):
			.Ragdoll(cone, planeMin, planeMax, twistMin, twistMax)
		HingeLimits(min, max): .LimitedHinge(min, max)

# the ragdoll's bodies as the physics takes them, at the actor's scale
pub fn ragdollParts(r hkx.Ragdoll, scale f32) physics.RagdollPart[]:
	r.bodies.map(b:
		a = b.a * scale
		e = b.b * scale
		radius = b.radius * scale
		positions, indices = a.roundTriangles(e, radius)
		physics.RagdollPart(
			name = b.name.copy(),
			piece = physics.Piece(round = .Ball(a, e, radius), positions, indices),
			center = b.center * scale,
			mass = b.mass,
			inertia = b.inertia * (scale * scale),
			friction = b.friction,
			restitution = b.restitution,
			linearDamping = b.linearDamping,
			angularDamping = b.angularDamping,
			slow = slowingOf(b.deactivation),
			part = b.part,
			layer = deadBipLayer
		)
	)

# the ragdoll's constraints as the physics takes them, at the actor's scale
pub fn ragdollLinks(r hkx.Ragdoll, scale f32) physics.RagdollLink[]:
	r.joints.map(physics.RagdollLink(
		kind = it.limits.limitsKind(),
		a = it.a,
		b = it.b,
		frameA = physics.Frame(pivot = it.pivotA * scale, axes = it.axesA),
		frameB = physics.Frame(pivot = it.pivotB * scale, axes = it.axesB),
		friction = it.maxFriction * nif.havokScale * nif.havokScale,
		stabilization = skeletonStabilization
	))

# the velocity stabilization every ball socket of skeleton.hkx holds (hkUFloat8 byte 48)
skeletonStabilization f32 = 1.067

# the ragdoll bone each body follows
fn boneOfBody(r hkx.Ragdoll, body i64):
	r.boneToBody.indexOf(body) ?? fail("no ragdoll bone has body {body}")

# where an actor standing at `feet` facing `heading`, `scale` times its skeleton's height, puts
# its skeleton's model space
pub fn actorPlace(feet Vec3, heading f32, scale f32) hkx.Transform:
	hkx.Transform(
		translation = feet,
		rotation = Quat.about(Vec3(0, 0, 1), -heading),
		scale = Vec3(scale, scale, scale)
	)

# The ragdoll's bodies' frames in the world for the animation skeleton's pose (its locals) of an
# actor placed at `place`.
pub fn ragdollFrames(
	r hkx.Ragdoll,
	bones hkx.Skeleton,
	locals hkx.Transform[],
	place hkx.Transform
) physics.Placement[]:
	model = bones.modelPose(locals)
	bind = r.skeleton.bones.map(.pose.copy())
	rag = r.toRagdoll.mapPose(model, r.skeleton, bind)
	(0..r.bodies.len).map(k:
		w = place.times(rag[r.boneOfBody(k)])
		physics.Placement(at = w.translation, turn = w.rotation)
	)

# The animation skeleton's locals the ragdoll's bodies' frames give, the bones it does not drive
# keeping `locals`; but a bone between two it drives (the pelvis, a clavicle) takes its reference
# pose's, the ragdoll's joints keeping its two ends as the reference pose had them.
pub fn animationLocals(
	r hkx.Ragdoll,
	bones hkx.Skeleton,
	frames physics.Placement[],
	place hkx.Transform,
	locals hkx.Transform[]
) hkx.Transform[]:
	back = place.inverted()
	rag = r.skeleton.modelPose(r.skeleton.bones.map(.pose.copy()))
	for k, f in frames:
		rag[r.boneOfBody(k)] = hkx.times(
			back,
			hkx.Transform(translation = f.at, rotation = f.turn, scale = place.scale)
		)
	kept = locals.copy()
	for i in r.toAnimation.betweenBones(bones):
		kept[i] = bones.bones[i].pose.copy()
	model = r.toAnimation.mapPose(rag, bones, kept)
	bones.localPose(model)

# the bones' locals of a rig's (10 floats a node: translation, rotation, scale)
pub fn bonesOfRig(pose f32[], nodes i64[]) hkx.Transform[]:
	nodes.map(n:
		at = n * 10
		hkx.Transform(
			translation = Vec3(pose, at),
			rotation = Quat(pose, at + 3),
			scale = Vec3(pose, at + 7)
		)
	)

# the rig's locals with the bones' put in
pub fn rigOfBones(pose f32[], nodes i64[], bones hkx.Transform[]) f32[]:
	out = pose.copy()
	for i, n in nodes:
		t = bones[i]
		at = n * 10
		for c, v in [
			t.translation.x, t.translation.y, t.translation.z, t.rotation.x, t.rotation.y,
			t.rotation.z, t.rotation.w, t.scale.x, t.scale.y, t.scale.z
		]:
			out[at + c] = v
	out

# the rig's node of each of the skeleton's bones
pub fn nodesOf(rig engine.Rig, bones hkx.Skeleton) i64[]:
	bones.bones.map(i64(rig.names.indexOf(.name) ?? fail("the rig has no {.name}")))

# Resident k falls: its pose of this frame and of dt before mapped to its skeleton's ragdoll, the
# ragdoll's bodies put in the world (the death the combat flags); false when its skeleton has
# none. `rigs` are the skeletons' (world.ActorScene's motions).
pub fn fall(
	mut rs Residents,
	cast world.CastHead,
	k i64,
	rigs engine.Rig[],
	mut w physics.World,
	dt f32
) bool:
	if rs.fallenIndex(k) >= 0: return true
	r = rs.all[k].copy()
	head = cast.skeletons[r.skeleton]
	ragdoll = head.ragdoll ?? return false
	rig = rigs[r.skeleton]
	nodes = rig.nodesOf(head.bones)
	pose = rs.poseOfResident(k)
	nowRig = rig.poseLocals(pose)
	earlier = pose.copy()
	earlier.time = (pose.time - dt).max(0.0)
	earlier.fromTime = (pose.fromTime - dt).max(0.0)
	scale = cast.npcs[r.npc].look.scale
	place = r.body.feetOf().actorPlace(r.body.heading, scale)
	locals = bonesOfRig(nowRig, nodes)
	now = ragdoll.ragdollFrames(head.bones, locals, place)
	before = ragdoll.ragdollFrames(
		head.bones,
		bonesOfRig(rig.poseLocals(earlier), nodes),
		r.was.actorPlace(r.body.heading, scale)
	)
	rs.addFallen(k, ragdoll, scale, now, before, dt, w, Fallen(resident = k, ragdoll = physics.Ragdoll(
		bodies = [], joints = [], centers = []), place, locals, nodes, pose = nowRig))
	true

# The ragdoll's bodies put in the world as the fallen actor `f` lies (its ragdoll filled in), moving
# as they moved from `before` dt seconds ago.
fn addFallen(
	mut rs Residents,
	k i64,
	ragdoll hkx.Ragdoll,
	scale f32,
	now physics.Placement[],
	before physics.Placement[],
	dt f32,
	mut w physics.World,
	move f Fallen
):
	group = ragdollGroup + rs.fallen.len
	f.ragdoll = w.addRagdoll(ragdoll.ragdollParts(scale), ragdoll.ragdollLinks(scale), now, before,
		dt, group)
	rs.fallen.push(f)

# Resident k lying as saved (a save's `place`, `locals` and `pose`): its ragdoll's bodies put where
# the pose maps them, at rest; the caller sets them as they were. False when its skeleton has no
# ragdoll.
pub fn fallAgain(
	mut rs Residents,
	cast world.CastHead,
	k i64,
	rigs engine.Rig[],
	mut w physics.World,
	place hkx.Transform,
	locals hkx.Transform[],
	pose f32[]
) bool:
	r = rs.all[k].copy()
	head = cast.skeletons[r.skeleton]
	ragdoll = head.ragdoll ?? return false
	now = ragdoll.ragdollFrames(head.bones, locals, place)
	rs.addFallen(k, ragdoll, cast.npcs[r.npc].look.scale, now, now, 1.0, w, Fallen(resident = k,
		ragdoll = physics.Ragdoll(bodies = [], joints = [], centers = []), place = place.copy(),
		locals = locals.copy(), nodes = rigs[r.skeleton].nodesOf(head.bones), pose = pose.copy()))
	true

# where resident k is among the fallen, -1 for one standing
pub fn fallenIndex(rs Residents, k i64) i64:
	rs.fallen.findIndex(.resident == k) ?? -1

# each fallen actor's pose where its ragdoll's bodies are now
fn followRagdolls(mut rs Residents, cast world.CastHead, w physics.World):
	for i in 0..rs.fallen.len:
		f = rs.fallen[i].copy()
		head = cast.skeletons[rs.all[f.resident].skeleton]
		ragdoll = head.ragdoll ?? continue
		frames = w.ragdollPlacements(f.ragdoll)
		bones = ragdoll.animationLocals(head.bones, frames, f.place, f.locals)
		rs.fallen[i].pose = rigOfBones(f.pose, f.nodes, bones)

# an order to kill an actor at a frame (main.zap's --kill frame:EditorId), while the combat is not
# hooked to the player's input
pub type KillOrder:
	frame i64
	editorId str

pub fn killOrderOf(text str) KillOrder?:
	parts = text.split(":")
	if parts.len != 2: return none
	KillOrder(frame = try i64.parse(parts[0]), editorId = parts[1].copy())

# The present actor of that editor id falls (fall); false when none is there.
pub fn killNamed(
	mut rs Residents,
	cast world.CastHead,
	editorId str,
	rigs engine.Rig[],
	mut w physics.World,
	dt f32
) bool:
	k = rs.all.findIndex(.present and cast.npcs[.npc].editorId == editorId) ?? return false
	rs.fall(cast, k, rigs, w, dt)
