# A rider's body on a board, posed by code over a biped skeleton (3ds Max's Bip01 names, as the
# Rocketbox figures have): he faces +z with the board along x under him. Each frame a Stance
# (how low he crouches, how he leans, where his feet and arms go) becomes a one-key clip: the
# hips lowered, the spine bent, the legs reaching the feet's places by two-bone IK (knees toward
# a pole in front), the feet flat on the deck, the arms aimed. Everything is worked out in the
# figure's space, parents first, and given back as each node's turn from its parent.

import engine
import math
import engine.gltf

pub type RiderBones:
	root i64   # the skeleton's root (Bip01): the hips move with it
	spine i64
	spine2 i64
	neck i64
	head i64
	# per side: 0 the one at +x (the leading foot), 1 the one at -x
	thigh i64[]
	calf i64[]
	foot i64[]
	clavicle i64[]
	upper i64[]
	fore i64[]
	hand i64[]

pub type Stance:
	crouch f32 = 0.0   # the hips lowered (meters)
	shift Vec3 = Vec3(x = 0.0, y = 0.0, z = 0.0)   # and moved
	lean f32 = 0.0   # the torso forward (radians)
	sway f32 = 0.0   # the torso toward +x
	twist f32 = 0.0   # the shoulders turned toward +x
	look f32 = 0.0   # the head turned toward +x
	board Quat = Quat(x = 0.0, y = 0.0, z = 0.0, w = 1.0)   # the deck's turn (its tilt down a slope)
	deck Vec3 = Vec3(x = 0.0, y = 0.0, z = 0.0)   # where the deck's middle is
	feet f32 = 0.25   # each foot this far from the deck's middle along it
	arms Vec3[] = []   # upper arm and forearm directions: leading side's, then the other's

fn boneNamed(rig engine.Rig, name str):
	rig.names.indexOf(name) ?? fail("the figure has no bone {name}")

fn bothSides(rig engine.Rig, part str):
	[rig.boneNamed("Bip01 L {part}"), rig.boneNamed("Bip01 R {part}")]

# The bones of a figure's rig by their biped names, its sides ordered so the first is at +x in
# the rest pose.
pub fn riderBones(rig engine.Rig) RiderBones:
	b = RiderBones(
		root = rig.boneNamed("Bip01"),
		spine = rig.boneNamed("Bip01 Spine"),
		spine2 = rig.boneNamed("Bip01 Spine2"),
		neck = rig.boneNamed("Bip01 Neck"),
		head = rig.boneNamed("Bip01 Head"),
		thigh = rig.bothSides("Thigh"),
		calf = rig.bothSides("Calf"),
		foot = rig.bothSides("Foot"),
		clavicle = rig.bothSides("Clavicle"),
		upper = bothSides(
			rig,
			"UpperArm"
		), fore = rig.bothSides("Forearm"), hand = rig.bothSides("Hand"))
	rots, places = rig.restWorlds()
	_ = rots
	if places[b.thigh[0]].x < places[b.thigh[1]].x:
		b.thigh = b.thigh.reversed()
		b.calf = b.calf.reversed()
		b.foot = b.foot.reversed()
		b.clavicle = b.clavicle.reversed()
		b.upper = b.upper.reversed()
		b.fore = b.fore.reversed()
		b.hand = b.hand.reversed()
	b

fn restTranslation(rig engine.Rig, node i64):
	Vec3(rig.rest, node * 10)

fn restRotation(rig engine.Rig, node i64):
	Quat(rig.rest, node * 10 + 3)

# every node's turn and place in the figure's space at rest
pub fn restWorlds(rig engine.Rig) (Quat[], Vec3[]):
	n = rig.parents.len
	rots = fill(n, Quat(0.0, 0.0, 0.0, 1.0))
	places = fill(n, Vec3(0.0, 0.0, 0.0))
	for i in rig.order:
		p = rig.parents[i]
		if p < 0:
			rots[i] = rig.restRotation(i)
			places[i] = rig.restTranslation(i)
		else:
			rots[i] = rots[p] @ rig.restRotation(i)
			places[i] = places[p] + rots[p].rotate(rig.restTranslation(i))
	(rots, places)

# where the knee goes for a hip at h, a foot at f, a thigh `a` and a shin `b` long, bent toward
# `pole`
fn kneeAt(h Vec3, f Vec3, a f32, b f32, pole Vec3):
	toFoot = f - h
	d = toFoot.length().clamp(0.01, a + b - 0.001)
	u = toFoot / toFoot.length().max(0.0001)
	x = (a * a - b * b + d * d) / (2.0 * d)
	up = (a * a - x * x).max(0.0).sqrt()
	side = (pole - u * (pole @ u)).normalized()
	h + u * x + side * up

# The stance as a one-key clip of the rig: every node's turn, and the root's place.
pub fn stanceClip(rig engine.Rig, bones RiderBones, st Stance) gltf.Clip:
	n = rig.parents.len
	restRots, restPlaces = rig.restWorlds()
	rots = fill(n, Quat(0.0, 0.0, 0.0, 1.0))
	places = fill(n, Vec3(0.0, 0.0, 0.0))
	up = Vec3(0.0, 1.0, 0.0)
	knees = [Vec3(0.0, 0.0, 0.0), Vec3(0.0, 0.0, 0.0)]
	# the feet's ankles: on the deck at their places along it, as high above it as at rest
	ankles = (0..2).map(s:
		st.deck +
			st.board.rotate(
				Vec3(st.feet if s == 0 else -st.feet, restPlaces[bones.foot[s]].y, 0.0)
			)
	)
	for i in rig.order:
		p = rig.parents[i]
		rot = rig.restRotation(i) if p < 0 else rots[p] @ rig.restRotation(i)
		place = rig.restTranslation(i) if p < 0
			else places[p] + rots[p].rotate(rig.restTranslation(i))
		if i == bones.root:
			place = place + st.shift + Vec3(0.0, -st.crouch, 0.0) +
				Vec3(st.deck.x, st.deck.y, st.deck.z)
		elif i == bones.spine:
			bend = Quat.about(Vec3(0.0, 0.0, 1.0), -st.sway) @
				Quat.about(Vec3(1.0, 0.0, 0.0), st.lean)
			rot = (Quat.about(up, st.twist * 0.5) @ bend) @ rot
		elif i == bones.spine2:
			rot = Quat.about(up, st.twist * 0.5) @ rot
		elif i == bones.neck:
			rot = Quat.about(up, st.look * 0.4) @ rot
		elif i == bones.head:
			rot = Quat.about(up, st.look * 0.6) @ rot
		for s in 0..2:
			if i == bones.thigh[s]:
				a = rig.restTranslation(bones.calf[s]).length()
				b = rig.restTranslation(bones.foot[s]).length()
				pole = Vec3(0.35 if s == 0 else -0.35, 0.0, 1.0)
				knees[s] = place.kneeAt(ankles[s], a, b, pole)
				rot = rot.aimed(rig.restTranslation(bones.calf[s]), knees[s] - place)
			elif i == bones.calf[s]:
				rot = rot.aimed(rig.restTranslation(bones.foot[s]), ankles[s] - place)
			elif i == bones.foot[s]:
				rot = st.board @ restRots[i]   # flat on the deck
			elif i == bones.upper[s] and st.arms.len == 4:
				rot = rot.aimed(rig.restTranslation(bones.fore[s]), st.arms[s * 2])
			elif i == bones.fore[s] and st.arms.len == 4:
				rot = rot.aimed(rig.restTranslation(bones.hand[s]), st.arms[s * 2 + 1])
		rots[i] = rot
		places[i] = place
	channels = []
	for i in 0..n:
		p = rig.parents[i]
		local = rots[i] if p < 0 else rots[p].inverse() @ rots[i]
		channels.push(
			gltf.Channel(
				node = i,
				path = .Rotation,
				step = true,
				cubic = false,
				times = [0.0],
				values = [local.x, local.y, local.z, local.w]
			)
		)
	r = bones.root
	pr = rig.parents[r]
	offset = places[r] if pr < 0 else rots[pr].inverse().rotate(places[r] - places[pr])
	channels.push(
		gltf.Channel(
			node = r,
			path = .Translation,
			step = true,
			cubic = false,
			times = [0.0],
			values = [offset.x, offset.y, offset.z]
		)
	)
	gltf.Clip(name = "stance", duration = 0.0, channels)

# a bone's turn changed the least so that its child (at `child` from it) lies along `toward`
fn aimed(rot Quat, child Vec3, toward Vec3):
	now = rot.rotate(child)
	Quat.between(now, toward) @ rot
