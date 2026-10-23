# Skinned models: a glTF model (gltf.zap) on the GPU, its poses computed on the CPU and its
# vertices bent on the GPU. A pose is a clip at a time, eased in from another: each node's
# translation, rotation and scale sampled from the clips (rotations blended along the shorter
# way), the nodes' matrices multiplied down the tree, and each palette entry's matrix (its
# node's, times its inverse bind matrix) written as three rows of four floats. A crowd is
# what a frame draws of many models: every body's palette in one storage buffer, and each
# model's bodies drawn in one instanced call per texture, so a hundred monsters of ten kinds
# are some ten draws. The vertex stage is shaders.zap's skinnedVertex (SkinVertex, SkinBody,
# SkinParams; it passes on a Skinned); the program's pixel stage is the caller's.

import rhi
import rhi.core
import math
import engine.gltf

# the triangles drawn with one texture
pub type SkinnedPart:
	indices i64   # its index buffer
	count i64
	texture Texture   # the texture of its base color (id -1: none)

# what a pose is computed from: the nodes at rest and the clips
pub type Rig:
	parents i64[]
	order i64[]   # parents before their children
	rest f32[]   # 10 floats a node: translation, rotation (x, y, z, w), scale
	palette i64[]   # the node each palette entry follows
	inverseBinds f32[]
	clips gltf.Clip[]
	names str[]   # the nodes' names

# a glTF model on the GPU
pub type SkinnedModel:
	vertices i64   # its vertex buffer
	parts SkinnedPart[]
	textures GpuTexture[]   # the parts' textures, owned
	rig Rig
	lo Vec3   # the box of its rest pose
	hi Vec3

# a clip at a time, eased in from another: `blend` 1 shows only `clip`, 0 only `from`; `turn`
# added in the model's space to the nodes `turned`, shared out among them (a head that looks);
# `locals`, when given, every node's translation, rotation and scale (10 floats a node, as
# poseLocals gives them) instead of the clips' (a body the physics moves: a ragdoll); `mixed`,
# when given, the clips of its layers averaged node by node by their weights instead of `clip` and `from`
# a clip at a time in a mixed pose: `weight` of the node takes `bones[node]` of it (none: all of it)
pub type PoseLayer:
	clip i64
	time f32
	weight f32
	bones f32[] = []

pub type Pose:
	clip i64
	time f32
	from i64 = -1
	fromTime f32 = 0.0
	blend f32 = 1.0
	turn Quat = Quat(0.0, 0.0, 0.0, 1.0)
	turned i64[] = []
	locals f32[] = []
	mixed PoseLayer[] = []

# the model in a glTF file on the GPU, its textures smoothed and mipmapped
pub fn loadSkinned(path str) SkinnedModel:
	newSkinned(gltf.loadGltf(path))

# its textures smoothed and mipmapped; the skeleton and the clips move out of the model into the rig
pub fn newSkinned(move g gltf.Model) SkinnedModel:
	buffer = gpu.newBuffer(g.vertices.len.max(1) * 4, core.bufVertex, false)
	if not g.vertices.isEmpty:
		gpu.writeBufferFloats(buffer, 0, g.vertices, g.vertices.len)
	textures = g.images.map(.newTexture(smoothTiled))
	parts = []
	for p in g.parts:
		if p.indices.isEmpty: continue
		indices = gpu.newBuffer(p.indices.len * 4, core.bufIndex, false)
		gpu.writeBufferWords(indices, 0, p.indices)
		texture = textures[p.image].texture() if p.image >= 0 and p.image < textures.len
			else Texture(id = -1, width = 0, height = 0)
		parts.push(SkinnedPart(indices, count = p.indices.len, texture))
	rig = g.rigOf()
	lo, hi = rig.restBox(g.vertices)
	SkinnedModel(vertices = buffer, parts, textures, rig, lo, hi)

# Whole vertices (gltf.skinVertexFloats floats each) written into the model's vertex buffer from
# vertex `first`: a head's face moved by the CPU
pub fn writeSkinnedVertices(m SkinnedModel, first i64, vertices f32[]):
	gpu.writeBufferFloats(m.vertices, first * gltf.skinVertexFloats * 4, vertices, vertices.len)

# what poses of the model are computed from (no GPU needed): its nodes, palette and clips moved
# out of the model
pub fn rigOf(mut g gltf.Model) Rig:
	rig = Rig(
		parents = [],
		order = move g.order,
		rest = [],
		palette = move g.palette,
		inverseBinds = move g.inverseBinds,
		clips = move g.clips,
		names = []
	)
	for k in 0..g.nodes.len:
		n = g.nodes[k]
		rig.parents.push(n.parent)
		rig.rest.extend(
			[
				n.translation.x,
				n.translation.y,
				n.translation.z,
				n.rotation.x,
				n.rotation.y,
				n.rotation.z,
				n.rotation.w,
				n.scale.x,
				n.scale.y,
				n.scale.z
			]
		)
		rig.names.push(move g.nodes[k].name)
	rig

# the program that draws a crowd into a shadow map (depth alone)
pub fn skinnedShadowProgram() Program:
	newProgram(shader(skinnedVertex, skinnedDepth))

# the box the vertices fill in the rest pose
fn restBox(rig Rig, vertices f32[]):
	rows = []
	rig.posePalette(Pose(clip = -1, time = 0.0), rows)
	lo = Vec3(1.0e9, 1.0e9, 1.0e9)
	hi = Vec3(-1.0e9, -1.0e9, -1.0e9)
	n = vertices.len / gltf.skinVertexFloats
	for i in 0..n:
		v = i * gltf.skinVertexFloats
		p = Vec3(0.0, 0.0, 0.0)
		for k in 0..4:
			w = vertices[v + 18 + k]
			if w <= 0.0: continue
			e = i64(vertices[v + 14 + k]) * 12
			for r in 0..3:
				q = rows[e + r * 4] * vertices[v] + rows[e + r * 4 + 1] * vertices[v + 1] +
					rows[e + r * 4 + 2] * vertices[v + 2] + rows[e + r * 4 + 3]
				p[r] += q * w
		lo = Vec3(lo.x.min(p.x), lo.y.min(p.y), lo.z.min(p.z))
		hi = Vec3(hi.x.max(p.x), hi.y.max(p.y), hi.z.max(p.z))
	if n == 0: return (Vec3(0.0, 0.0, 0.0), Vec3(0.0, 0.0, 0.0))
	(lo, hi)

# the clip of that name, none when the model has none
pub fn clipNamed(m SkinnedModel, name str) n64?:
	m.rig.clips.findIndex(.name == name)

# seconds; 0 when there is no such clip
pub fn clipDuration(m SkinnedModel, clip i64) f32:
	m.rig.clips[clip].duration if clip >= 0 and clip < m.rig.clips.len else 0.0

# a time `t` seconds into a clip: around again when it is looping, else held at its end
pub fn clipTime(m SkinnedModel, clip i64, t f32, looping bool) f32:
	d = m.clipDuration(clip)
	if d <= 0.0: return 0.0
	t - (t / d).floor() * d if looping else t.clamp(0.0, d)

# the node of that name, none when the model has none
pub fn nodeNamed(m SkinnedModel, name str) n64?:
	m.rig.names.indexOf(name)

# ---------- poses ----------

# what a pose is worked out in, kept between calls
mut localA f32[] = []
mut localB f32[] = []
mut worlds f32[] = []

# The pose's palette appended to `out`: three rows of four floats per entry, the rows of the
# matrix that takes a vertex from the bind pose to where the pose puts it.
pub fn posePalette(rig Rig, pose Pose, mut out f32[]):
	rig.poseWorlds(pose)
	for e in 0..rig.palette.len:
		for r in 0..3:
			row = rig.paletteRow(e, r)
			out.push(row.x)
			out.push(row.y)
			out.push(row.z)
			out.push(row.w)

# the pose's palette appended to `out` as rows (a crowd's, for the storage buffer the vertex
# stage reads)
pub fn posePaletteRows(rig Rig, pose Pose, mut out Vec4[]):
	rig.poseWorlds(pose)
	rig.paletteRows(out)

# the palette's rows of the worlds poseWorlds made last (by a rig of the same nodes)
fn paletteRows(rig Rig, mut out Vec4[]):
	for e in 0..rig.palette.len:
		for r in 0..3:
			out.push(rig.paletteRow(e, r))

# row r of palette entry e's matrix: row r of its node's world times each column of its inverse
# bind matrix (poseWorlds made the worlds)
fn paletteRow(rig Rig, e i64, r i64):
	w = rig.palette[e] * 12
	a = worlds[w + r]
	b = worlds[w + 3 + r]
	c = worlds[w + 6 + r]
	d = worlds[w + 9 + r]
	ib = rig.inverseBinds
	k = e * 16
	Vec4(
		x = a * ib[k] + b * ib[k + 1] + c * ib[k + 2] + d * ib[k + 3],
		y = a * ib[k + 4] + b * ib[k + 5] + c * ib[k + 6] + d * ib[k + 7],
		z = a * ib[k + 8] + b * ib[k + 9] + c * ib[k + 10] + d * ib[k + 11],
		w = a * ib[k + 12] + b * ib[k + 13] + c * ib[k + 14] + d * ib[k + 15]
	)

# every node's translation, rotation (x, y, z, w) and scale in the pose, 10 floats a node: the
# clips sampled and blended, or the pose's own locals
pub fn poseLocals(rig Rig, pose Pose) f32[]:
	rig.localsInto(pose)
	localA.copy()

fn localsInto(rig Rig, pose Pose):
	n = rig.parents.len
	if pose.locals.len == n * 10:
		localA.clear()
		localA.extend(pose.locals)
		return
	if not pose.mixed.isEmpty:
		rig.mixInto(pose.mixed)
		return
	rig.sampleInto(pose.clip, pose.time, localA)
	if pose.from >= 0 and pose.blend < 1.0:
		rig.sampleInto(pose.from, pose.fromTime, localB)
		blendInto(localA, localB, n, pose.blend.clamp(0.0, 1.0))

# the layer's weight on the node
fn weightOn(l PoseLayer, node i64):
	if l.bones.isEmpty: return l.weight
	l.weight * (l.bones[node] if node < l.bones.len else 0.0)

# the layers' clips averaged on each node by the weight they have on it, the first layer's where
# none has any
fn mixInto(rig Rig, layers PoseLayer[]):
	n = rig.parents.len
	first = layers[0]
	rig.sampleInto(first.clip, first.time, localA)
	total = (0..n).map(first.weightOn(it))
	for k in 1..layers.len:
		l = layers[k]
		rig.sampleInto(l.clip, l.time, localB)
		for node in 0..n:
			w = l.weightOn(node)
			if w <= 0.0: continue
			lerpNode(localA, localB, node, w / (total[node] + w))
			total[node] += w

# node `node` of a moved toward b by t
fn lerpNode(mut a f32[], b f32[], node i64, t f32):
	at = node * 10
	for c in [0, 1, 2, 7, 8, 9]:
		a[at + c] += (b[at + c] - a[at + c]) * t
	putQuat(a, at + 3, quatAt(a, at + 3).nlerp(quatAt(b, at + 3), t))

# the nodes' matrices of the pose, parents first: 12 floats each, four columns of three
fn poseWorlds(rig Rig, pose Pose):
	n = rig.parents.len
	rig.localsInto(pose)
	# the nodes' matrices, parents first: 12 floats each, four columns of three
	if worlds.len < n * 12:
		worlds = fill(n * 12, f32(0.0))
	share = Quat(0.0, 0.0, 0.0, 1.0).nlerp(pose.turn, 1.0 / f32(pose.turned.len.max(1)))
	for node in rig.order:
		writeWorld(localA, node, rig.parents[node], worlds)
		if not pose.turned.isEmpty and node in pose.turned:
			turnWorld(worlds, node, share)

# the node's matrix turned by q about its own place, in the model's space
fn turnWorld(mut worlds f32[], node i64, q Quat):
	o = node * 12
	for c in 0..3:
		v = q.rotate(Vec3(worlds[o + c * 3], worlds[o + c * 3 + 1], worlds[o + c * 3 + 2]))
		worlds[o + c * 3] = v.x
		worlds[o + c * 3 + 1] = v.y
		worlds[o + c * 3 + 2] = v.z

# every node's translation, rotation and scale at `time` into the clip (-1: at rest)
fn sampleInto(rig Rig, clip i64, time f32, mut local f32[]):
	local.clear()
	local.extend(rig.rest)
	if clip < 0 or clip >= rig.clips.len: return
	for ch in rig.clips[clip].channels:
		ch.sampleChannel(time, local)

fn sampleChannel(ch gltf.Channel, t f32, mut local f32[]):
	keys = ch.times.len
	if keys == 0: return
	width = 4 if ch.path == .Rotation else 3
	stride = width * 3 if ch.cubic else width
	skip = width if ch.cubic else 0
	at = ch.node * 10 + match ch.path:
		Translation: 0
		Rotation: 3
		Scale: 7
	# the key at or before t, and how far toward the next
	k = 0
	f = 0.0
	if t >= ch.times[keys - 1]:
		k = keys - 1
	elif t > ch.times[0]:
		lo = 0
		hi = keys - 1
		while hi - lo > 1:
			mid = (lo + hi) / 2
			if ch.times[mid] <= t:
				lo = mid
			else:
				hi = mid
		k = lo
		span = ch.times[k + 1] - ch.times[k]
		f = 0.0 if ch.step or span <= 0.0 else (t - ch.times[k]) / span
	a = k * stride + skip
	if f <= 0.0 or k + 1 >= keys:
		for c in 0..width:
			local[at + c] = ch.values[a + c]
		return
	b = (k + 1) * stride + skip
	if width == 4:
		putQuat(local, at, quatAt(ch.values, a).nlerp(quatAt(ch.values, b), f))
		return
	for c in 0..3:
		local[at + c] = ch.values[a + c] * (1.0 - f) + ch.values[b + c] * f

# the four floats at `at` as a quaternion (of the flat lists), and written back
fn quatAt(xs f32[], at i64):
	Quat(x = xs[at], y = xs[at + 1], z = xs[at + 2], w = xs[at + 3])

fn putQuat(mut xs f32[], at i64, v Quat):
	xs[at] = v.x
	xs[at + 1] = v.y
	xs[at + 2] = v.z
	xs[at + 3] = v.w

# a = b + (a - b) * t, node by node (rotations the shorter way)
fn blendInto(mut a f32[], b f32[], n i64, t f32):
	for node in 0..n:
		at = node * 10
		for c in [0, 1, 2, 7, 8, 9]:
			a[at + c] = b[at + c] + (a[at + c] - b[at + c]) * t
		putQuat(a, at + 3, quatAt(b, at + 3).nlerp(quatAt(a, at + 3), t))

# The node's matrix into its 12 floats of `worlds`: its own (translation, rotation, scale), times
# its parent's (-1 none) when it has one.
fn writeWorld(local f32[], node i64, parent i64, mut worlds f32[]):
	s = node * 10
	m = Mat4.transformOf(
		Vec3(local, s),
		quatAt(local, s + 3),
		Vec3(local, s + 7)
	)
	o = node * 12
	if parent < 0:
		for c in 0..4:
			for r in 0..3:
				worlds[o + c * 3 + r] = m.m[c * 4 + r]
		return
	p = parent * 12
	for c in 0..4:
		x = m.m[c * 4]
		y = m.m[c * 4 + 1]
		z = m.m[c * 4 + 2]
		for r in 0..3:
			v = worlds[p + r] * x + worlds[p + 3 + r] * y + worlds[p + 6 + r] * z
			if c == 3:
				v += worlds[p + 9 + r]
			worlds[o + c * 3 + r] = v

# ---------- crowds ----------

# What a frame draws of many skinned models: their bodies' palettes (the vertex stage's
# parameters, its view and projection set when drawn), and each model's bodies.
pub type Crowd:
	params SkinParams
	bodies SkinBody[,]   # by model

	# the frame's bodies forgotten, for the next frame's
	pub mut fn clear():
		params.palette.clear()
		for mut body in bodies:
			body.clear()

	# The crowd's palettes and the view-projection set as the program's skinning parameters (a
	# program of skinnedVertex): its draws from here on bend the crowd's bodies.
	pub mut fn setView(p Program, viewProjection Mat4):
		params.viewProjection = viewProjection
		p.setParams(params)

	# One part of a model drawn once for each of its bodies in the crowd, by the program (its
	# parameters set by the caller: Crowd.setView, and the pixel stage's own, the part's texture
	# among them).
	pub fn drawPart(r Renderer, p Program, models SkinnedModel[], part CrowdPart):
		m = models[part.model]
		placed = bodies[part.model]
		pt = m.parts[part.part]
		handle, offset = frameData(placed)
		layout = p.vertexLayoutFor(gltf.skinVertexFloats * 4, true)
		if placed.byteSize / placed.len != p.instanceStride:
			fail("a crowd drawn by a program whose instance is not a SkinBody")
		streams(gpu.bufferHandle(m.vertices), 0)
		addStream(handle, offset)
		drawWith(
			r,
			p,
			layout,
			streamBuffers,
			streamOffsets,
			gpu.bufferHandle(pt.indices),
			pt.count,
			placed.len,
			false
		)

# a part of a model whose bodies a crowd draws (crowdParts), with the texture of its color
pub type CrowdPart:
	model i64
	part i64
	texture Texture

# `models`: how many models it draws
pub fn newCrowd(models i64) Crowd:
	bodies SkinBody[,] = fill(models, [])
	Crowd(params = SkinParams(viewProjection = Mat4(1.0), palette = []), bodies)

# A body of model `index` (m) in the crowd: posed, standing at `at` turned `yaw` radians about
# y (0 facing +z), `scale` times its size; `flash` whitens it, `fade` (0..1) dims it out, `tint`
# multiplies its colors.
pub fn addBody(
	mut c Crowd,
	index i64,
	m SkinnedModel,
	pose Pose,
	at Vec3,
	yaw f32,
	scale f32,
	flash f32,
	fade f32,
	tint Vec4
):
	c.addMovedBody(index, m, m.rig, pose, at, yaw, scale, flash, fade, tint)

# A body as addBody's, posed by `motion`: a rig of the same nodes whose clips move the model
# (models of one skeleton sharing its clips).
pub fn addMovedBody(
	mut c Crowd,
	index i64,
	m SkinnedModel,
	motion Rig,
	pose Pose,
	at Vec3,
	yaw f32,
	scale f32,
	flash f32,
	fade f32,
	tint Vec4
):
	first = c.params.palette.len
	motion.poseWorlds(pose)
	m.rig.paletteRows(c.params.palette)
	c.bodies[index].push(SkinBody(
		place = Vec4(x = at.x, y = at.y, z = at.z, w = yaw),
		shape = Vec4(x = scale, y = f32(first), z = flash, w = fade),
		tint = Vec4(x = tint.r, y = tint.g, z = tint.b, w = tint.a)))

# Every model's bodies drawn by the program (skinnedVertex and a pixel stage that reads no
# texture of the parts, as skinnedDepth): one instanced draw per model and part.
pub fn drawCrowd(
	r Renderer,
	p Program,
	mut c Crowd,
	models SkinnedModel[],
	viewProjection Mat4
):
	c.setView(p, viewProjection)
	for i in 0..models.len.min(c.bodies.len):
		if not c.bodies[i].isEmpty:
			for k in 0..models[i].parts.len:
				c.drawPart(r, p, models, c.crowdPart(models, i, k))

# the parts the crowd draws: each model with bodies, each of its parts with its texture
pub fn crowdParts(c Crowd, models SkinnedModel[]) CrowdPart[]:
	out = []
	for i in 0..models.len.min(c.bodies.len):
		if not c.bodies[i].isEmpty:
			for k in 0..models[i].parts.len:
				out.push(c.crowdPart(models, i, k))
	out

# part k of model i, with its texture
fn crowdPart(c Crowd, models SkinnedModel[], i i64, k i64):
	CrowdPart(model = i, part = k, texture = models[i].parts[k].texture)
