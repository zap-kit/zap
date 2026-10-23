# The sequences of a model's NiControllerManager (a door's Open and Close, a lever's): each one an
# NiControllerSequence that plays NiTransformInterpolators on named nodes, their keys in
# NiTransformData. A node's local transform at a time of a sequence is the interpolator's value
# where it keys one (its constant, else its data's keys) and the node's own where it does not.

import engine
import math

# NiTransformInterpolator: the constant translation, rotation (x y z w) and scale, each -FLT_MAX
# when it has none, and its NiTransformData
pub type TransformInterpolator:
	translation Vec3
	rotation Vec4
	scale f32
	data i64

# NiTransformData: the rotation as quaternion keys, or as three Euler angles' keys (x, y, z), the
# translation and the scale
pub type TransformData:
	quaternions engine.Curve
	euler engine.Curve[]
	translation engine.Curve
	scale engine.Curve

# a sequence of the manager: its cycle (NiTimeController's: 0 loops, 1 back and forth, 2 clamped),
# frequency and span, and the interpolators it plays on nodes by name
pub type SequenceBlockData:
	name str
	cycle i64
	frequency f32
	start f32
	stop f32
	nodes str[]
	interpolators i64[]

# a value the file leaves out is -FLT_MAX
fn given(v f32):
	v > -1.0e30

fn readQuaternion(mut s Reader):
	w = s.f32()
	x = s.f32()
	y = s.f32()
	Vec4(x, y, s.f32(), w)

fn readTransformInterpolator(mut s Reader):
	translation = s.vec3()
	rotation = s.readQuaternion()
	scale = s.f32()
	TransformInterpolator(translation, rotation, scale, data = s.i32())

# Quaternion keys of the type (1 linear, 3 with Kochanek-Bartels' bias), or the three Euler angles'
# key groups (type 4) that take their place.
fn readTransformData(mut s Reader):
	data = TransformData(quaternions = engine.Curve(), euler = [], translation = engine.Curve(),
		scale = engine.Curve())
	count = s.u32()
	if count > 0:
		kind = s.u32()
		if kind == 4:
			loop 3:
				data.euler.push(s.readKeys(1))
		else:
			data.quaternions.interpolation = kind
			tbc = []
			loop count:
				if s.short: break
				data.quaternions.times.push(s.f32())
				data.quaternions.values.push(s.readQuaternion())
				if kind == engine.curveTbc: tbc.push(s.vec3())
			if kind == engine.curveTbc: data.quaternions.tbcTangents(tbc)
	data.translation = s.readKeys(3)
	data.scale = s.readKeys(1)
	data

# NiControllerSequence: the name, the controlled blocks (their interpolator and the name of the
# node they move, with the controller, priority and strings the game does not use), then the
# weight, the text keys, the cycle, frequency, start and stop.
fn readSequence(mut s Reader, names str[]):
	name = s.readName(names)
	count = s.u32()
	s.skip(4)
	seq = SequenceBlockData(name, cycle = 0, frequency = 1.0, start = 0.0, stop = 0.0, nodes = [],
		interpolators = [])
	loop count:
		if s.short: break
		seq.interpolators.push(s.i32())
		s.skip(5)
		seq.nodes.push(s.readName(names))
		s.skip(16)
	s.skip(8)
	seq.cycle = s.u32()
	seq.frequency = s.f32()
	seq.start = s.f32()
	seq.stop = s.f32()
	seq

# what a sequence plays on one node, from its interpolator and keys
pub type NodeTrack:
	node str
	translation Vec3?
	rotation Vec4?
	scale f32?
	translationKeys engine.Curve
	rotationKeys engine.Curve
	eulerKeys engine.Curve[]
	scaleKeys engine.Curve

# a sequence with the tracks it plays
pub type Sequence:
	name str
	cycle i64
	frequency f32
	start f32
	stop f32
	tracks NodeTrack[]

fn trackOfNode(n Nif, node str, interpolator i64) NodeTrack?:
	if interpolator < 0 or interpolator >= n.blocks.len: return none
	i = match n.blocks[interpolator]:
		TransformInterpolatorBlock(p): p.copy()
		_: return none
	track = NodeTrack(node = node.copy(),
		translation = i.translation if i.translation.x.given() else none,
		rotation = i.rotation if i.rotation.x.given() else none,
		scale = i.scale if i.scale.given() else none,
		translationKeys = engine.Curve(), rotationKeys = engine.Curve(), eulerKeys = [],
		scaleKeys = engine.Curve())
	if i.data >= 0 and i.data < n.blocks.len:
		if n.blocks[i.data] is TransformDataBlock(d):
			track.translationKeys = d.translation.copy()
			track.rotationKeys = d.quaternions.copy()
			track.eulerKeys = d.euler.map(.copy())
			track.scaleKeys = d.scale.copy()
	track

# the model's sequences by name: its manager's, each with the tracks of the nodes it moves
pub fn sequencesOf(n Nif) Sequence[]:
	out = []
	for b in n.blocks:
		if b is SequenceBlock(q):
			tracks = []
			for k, node in q.nodes:
				if n.trackOfNode(node, q.interpolators[k]) is t: tracks.push(t)
			out.push(Sequence(name = q.name.copy(), cycle = q.cycle, frequency = q.frequency,
				start = q.start, stop = q.stop, tracks))
	out

# the rest of a node: its local transform's parts
fn partsOf(rest Mat4):
	scale = Vec3(rest.m[0], rest.m[1], rest.m[2]).length()
	k = 1.0 / scale.max(1.0e-9)
	turn = Mat4(
		Vec4(rest.m[0] * k, rest.m[1] * k, rest.m[2] * k, 0.0),
		Vec4(rest.m[4] * k, rest.m[5] * k, rest.m[6] * k, 0.0),
		Vec4(rest.m[8] * k, rest.m[9] * k, rest.m[10] * k, 0.0),
		Vec4(0.0, 0.0, 0.0, 1.0)
	)
	(Vec3(rest.m[12], rest.m[13], rest.m[14]), turn, scale)

fn turnAt(t NodeTrack, rest Mat4, time f32):
	if t.eulerKeys.len == 3:
		x = t.eulerKeys[0].sampleCurve(time).x
		y = t.eulerKeys[1].sampleCurve(time).x
		z = t.eulerKeys[2].sampleCurve(time).x
		return Mat4.rotationZ(z) @ Mat4.rotationY(y) @ Mat4.rotationX(x)
	if not t.rotationKeys.times.isEmpty:
		q = t.rotationKeys.sampleCurve(time)
		return Mat4.rotationOf(Quat(q.x, q.y, q.z, q.w))
	if t.rotation is q: return Mat4.rotationOf(Quat(q.x, q.y, q.z, q.w))
	rest

# The node's local transform `time` seconds into the sequence's own clock: the track's where it
# has a value, `rest` (the node's own) where it does not.
pub fn localAt(t NodeTrack, rest Mat4, time f32) Mat4:
	at, turn, size = rest.partsOf()
	if not t.translationKeys.times.isEmpty:
		at = t.translationKeys.sampleCurve(time).xyz
	elif t.translation is p:
		at = p
	if not t.scaleKeys.times.isEmpty:
		size = t.scaleKeys.sampleCurve(time).x
	elif t.scale is f:
		size = f
	Mat4.translation(at) @ t.turnAt(turn, time) @ Mat4.scaling(Vec3(size, size, size))

# the time on the sequence's clock at `seconds` since it began: its frequency and cycle applied
pub fn clockOf(q Sequence, seconds f32) f32:
	engine.CurveTiming(frequency = q.frequency, start = q.start, stop = q.stop, cycle = q.cycle)
		.curveTime(seconds)

# an animated node's place in the model at rest: its local transform, its parent's and its own
# transform to the model's space
pub type NodeFrame:
	node str
	local Mat4
	parent Mat4
	world Mat4

# the nearest node above the part (its own shape not counted) that a sequence moves, by block
pub fn controlledAncestor(n Nif, p Part, moved str[]) i64?:
	k = p.ancestors.len
	while k > 0:
		k -= 1
		if n.blockName(p.ancestors[k]) in moved: return p.ancestors[k]
	none

# the frame of the node at block i, with `drawn`'s transforms
pub fn frameOf(n Nif, drawn Drawn, i i64) NodeFrame:
	node = match n.blocks[i]:
		NodeBlock(v): v.copy()
		_: fail("block {i} is no node")
	parent = Mat4(1.0)
	for j, b in n.blocks:
		if b is NodeBlock(above) and i in above.children:
			parent = drawn.worlds.get(j) ?? Mat4(1.0)
	NodeFrame(node = node.av.name.copy(), local = node.av.transform, parent,
		world = drawn.worlds.get(i) ?? Mat4(1.0))

# where the frame's node is at `time` of the sequence: what takes the model's rest pose to its pose
pub fn poseAt(f NodeFrame, q Sequence, time f32) Mat4:
	local = f.local
	if q.tracks.find(.node == f.node) is t: local = t.localAt(f.local, time)
	f.parent @ local @ f.world.inverseAffine()
