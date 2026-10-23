# Where a model's meshes are, as the client places them (BrowEdit 3's reading of it, which map
# makers check against the client): before 2.2, the root node is moved so the model's box sits
# on its base and is centred (when it has children), each node is turned (by its angle and axis,
# or by its rotation keyframes at the moment asked for) and scaled under its parent, and its mesh
# is moved by its pivot and its 3 x 3 matrix; from 2.2 each node is its matrix or its keyframes
# under its parent's. A placed model is then moved where the RSW puts it, turned (z, x, then y),
# scaled and lifted so its lowest point stands on its place. Everything here is in the world of
# the map: x east, y up, z south, a GAT cell 1 wide (the file's units divided by 5).

import math
import ragnarok.rsm
import ragnarok.rsw

# the box of the model's meshes before posing (BrowEdit's setBoundingBox), from the root
fn meshBounds(model rsm.Rsm, i i64, mut lo Vec3, mut hi Vec3):
	n = model.nodes[i]
	nlo = Vec3(1.0e9, 1.0e9, 1.0e9)
	nhi = Vec3(-1.0e9, -1.0e9, -1.0e9)
	if n.parent >= 0:
		nlo = Vec3(0.0, 0.0, 0.0)
		nhi = nlo
	moved = n.parent >= 0 or not n.children.isEmpty
	for f in n.faces:
		for k in 0..3:
			v = n.offset.applyPoint(n.vertices[f.vertices[k]])
			if moved:
				v = v + n.position + n.pivot
			nlo = Vec3(nlo.x.min(v.x), nlo.y.min(v.y), nlo.z.min(v.z))
			nhi = Vec3(nhi.x.max(v.x), nhi.y.max(v.y), nhi.z.max(v.z))
	lo = Vec3(lo.x.min(nlo.x), lo.y.min(nlo.y), lo.z.min(nlo.z))
	hi = Vec3(hi.x.max(nhi.x), hi.y.max(nhi.y), hi.z.max(nhi.z))
	for c in n.children:
		model.meshBounds(c, lo, hi)

# the turn a keyframe's quaternion (x, y, z, w) stands for
fn turnOf(q f32[4]):
	Mat4.rotationOf(Quat(q[0], q[1], q[2], q[3]))

# the turn of rotation keyframes at `time` (the last frame's time the loop's length), as the
# client blends them
fn keyframeTurn(frames rsm.RotFrame[], time i64):
	last = frames[len - 1].time
	if last == 0: return turnOf(frames[0].q)
	tick = time % last
	current = 0
	for i in 0..frames.len:
		if frames[i].time > tick:
			current = (i - 1).max(0)
			break
	next = 0 if current + 1 >= frames.len else current + 1
	span = frames[next].time - frames[current].time
	t f32 = 0.0 if span == 0 else f32(tick - frames[current].time) / f32(span)
	a = frames[current].q
	b = frames[next].q
	q f32[4]
	for k in 0..4:
		q[k] = a[k] + (b[k] - a[k]) * t
	turnOf(q)

# the value of position or scale keyframes at `time` (2.2 and later), `start` before the first
fn keyframeVec(frames rsm.VecFrame[], time i64, length i64, start Vec3):
	tick = time % length.max(1)
	next = 0
	while next < frames.len and tick >= frames[next].time:
		next += 1
	prev = next - 1
	prevTick = 0 if prev < 0 else frames[prev].time
	nextTick = length if next == frames.len else frames[next].time
	a = start if prev < 0 else frames[prev].v
	b = frames[next - 1].v if next == frames.len else frames[next].v
	t f32 = 0.0 if nextTick == prevTick else f32(tick - prevTick) / f32(nextTick - prevTick)
	a + (b - a) * t

# Each node's matrix at `time` (milliseconds of the model's animation), in the model's own
# space: what its mesh's vertices are moved by.
pub fn poseNodes(model rsm.Rsm, time i64) Mat4[]:
	lo = Vec3(1.0e9, 1.0e9, 1.0e9)
	hi = Vec3(-1.0e9, -1.0e9, -1.0e9)
	if model.version < 0x202:
		model.meshBounds(model.root, lo, hi)
	out = fill(model.nodes.len, Mat4(1.0))
	model.poseNode(model.root, time, Mat4(1.0), (lo + hi) * 0.5, hi, out)
	out

fn poseNode(
	model rsm.Rsm,
	i i64,
	time i64,
	above Mat4,
	middle Vec3,
	hi Vec3,
	mut out Mat4[]
):
	n = model.nodes[i]
	own = Mat4(1.0)
	if model.version < 0x202:
		if n.parent < 0:
			own = Mat4.translation(Vec3(-middle.x, -hi.y, -middle.z)) if not n.children.isEmpty
				else Mat4.translation(Vec3(0.0, -hi.y + middle.y, 0.0))
		else:
			own = Mat4.translation(n.position)
		if not n.rotFrames.isEmpty:
			own = own @ keyframeTurn(n.rotFrames, time)
		elif n.rotAngle.abs() > 0.01:
			own = own @ Mat4.rotationAbout(n.rotAxis, n.rotAngle)
		own = own @ Mat4.scaling(n.scale)
		sub = above @ own
		out[i] = sub @ Mat4.translation(n.pivot) @ n.offset
		for c in n.children:
			model.poseNode(c, time, sub, middle, hi, out)
		return
	# 2.2 and later
	if not n.rotFrames.isEmpty:
		own = keyframeTurn(n.rotFrames, time)
	else:
		own = n.offset
		if n.parent >= 0:
			own = model.nodes[n.parent].offset.inverseAffine() @ own
	if not n.scaleFrames.isEmpty:
		s = keyframeVec(n.scaleFrames, time, model.animLength, Vec3(1.0, 1.0, 1.0))
		own = own @ Mat4.scaling(s)
	position = n.pivot
	if not n.posFrames.isEmpty:
		position = keyframeVec(n.posFrames, time, model.animLength, n.pivot)
	elif n.parent >= 0:
		p = model.nodes[n.parent]
		position = p.offset.inverseAffine().applyDirection(n.pivot - p.pivot)
	own = Mat4.translation(position) @ own
	placed = above @ own if n.parent >= 0 else own
	out[i] = placed
	for c in n.children:
		model.poseNode(c, time, placed, middle, hi, out)

# whether any node of the model turns, moves or scales over time
pub fn isAnimated(model rsm.Rsm) bool:
	model.nodes.any(.rotFrames.len > 1 or .posFrames.len > 1 or .scaleFrames.len > 1)

# The transform from a model's space (posed at time 0 by `nodes`) to the map's world for one of
# its RSW placements: the client's lift onto the base, then the RSW's move, turn and scale.
pub fn placement(
	model rsm.Rsm,
	nodes Mat4[],
	m rsw.Model,
	gndWidth i64,
	gndHeight i64
) Mat4:
	# the box of the posed model with y up (BrowEdit's setBoundingBox2)
	lo = Vec3(1.0e9, 1.0e9, 1.0e9)
	hi = Vec3(-1.0e9, -1.0e9, -1.0e9)
	if model.version < 0x202:
		for i in 0..model.nodes.len:
			for v in model.nodes[i].vertices:
				p = nodes[i].applyPoint(v)
				lo = Vec3(lo.x.min(p.x), lo.y.min(-p.y), lo.z.min(p.z))
				hi = Vec3(hi.x.max(p.x), hi.y.max(-p.y), hi.z.max(p.z))
	middle = (lo + hi) * 0.5
	w = f32(gndWidth)
	h = f32(gndHeight)
	toRad f32 = pi / 180.0
	# BrowEdit's world (x east, y up, z south, the file's units) ...
	t = Mat4.scaling(Vec3(1.0, 1.0, -1.0))
	t = t @
		Mat4.translation(
			Vec3(5.0 * w + m.position.x, -m.position.y, -10.0 - 5.0 * h + m.position.z)
		)
	t = t @ Mat4.rotationZ(-m.rotation.z * toRad)
	t = t @ Mat4.rotationX(-m.rotation.x * toRad)
	t = t @ Mat4.rotationY(m.rotation.y * toRad)
	t = t @ Mat4.scaling(Vec3(m.scale.x, -m.scale.y, m.scale.z))
	if model.version < 0x202:
		t = t @ Mat4.translation(Vec3(-middle.x, lo.y, -middle.z))
	else:
		t = t @ Mat4.scaling(Vec3(1.0, -1.0, 1.0))
	# ... made the map's: a cell 1 wide, the map's south-west corner at the origin
	fromBrowEdit(gndHeight) @ t

# BrowEdit's world (the file's units, the map's south edge at z = 10 + 10 * height) as the map's
pub fn fromBrowEdit(gndHeight i64) Mat4:
	Mat4.scaling(Vec3(0.2, 0.2, 0.2)) @
		Mat4.translation(Vec3(0.0, 0.0, -10.0 - 10.0 * f32(gndHeight)))
