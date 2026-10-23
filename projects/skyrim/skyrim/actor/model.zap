# The worn models as the engine's skinned models take them (engine/scene/skin.zap's newSkinned):
# the skeleton's bones as the nodes at their reference pose, one palette entry per bone of each
# part (its node, its skin-to-bone matrix as the inverse bind), the vertices laid out as
# gltf.skinVertexFloats, the triangles grouped by diffuse texture, the animations as clips of a
# key per frame. Skyrim's units, Z up.

import engine.gltf
import skyrim.hkx
import skyrim.nif

# how a part of the body looks: its textures' paths as the models name them, its highlight, the
# alpha under which a texel is dropped (0..1; 0 keeps every one)
pub type BodyMaterial:
	diffuse str
	normal str
	glossiness f32
	specularStrength f32
	cutout f32
	shading nif.Shading   # its lighting and how the skin shader tones it

pub type BodyModel:
	model gltf.Model   # its images empty: a part's image indexes `materials`
	materials BodyMaterial[]

# Gamebryo's alpha test threshold, or half way for a blended part (drawn unsorted, cut out)
fn materialOf(p nif.Part):
	cutout = 0.0
	if p.alpha.test: cutout = f32(p.alpha.threshold) / 255.0
	elif p.alpha.blend: cutout = 0.5
	BodyMaterial(
		diffuse = p.diffuse.copy(),
		normal = p.normal.copy(),
		glossiness = p.glossiness,
		specularStrength = p.specularStrength,
		cutout,
		shading = p.shading.copy()
	)

fn nodesOf(s hkx.Skeleton):
	s.bones.map(
		gltf.Node(
			name = it.name.copy(),
			parent = it.parent,
			translation = it.pose.translation,
			rotation = it.pose.rotation,
			scale = it.pose.scale
		)
	)

fn floatsOf(m Mat4):
	(0..16).map(m.m[it])

# the part's vertices appended, their palette entries counted from `base`
fn addVertices(p nif.Part, base i64, textured bool, mut out f32[]):
	for v, at in p.positions:
		n = p.normals[v] if v < p.normals.len else Vec3(0.0, 0.0, 1.0)
		uv = p.uvs[v] if v < p.uvs.len else Vec2(0.0, 0.0)
		c = p.colors[v] if v < p.colors.len else Vec4(1.0, 1.0, 1.0, 1.0)
		out.extend([at.x, at.y, at.z, n.x, n.y, n.z, uv.x, uv.y, 1.0 if textured else 0.0, 0.0])
		out.extend([c.x, c.y, c.z, c.w])
		out.extend((v * 4..v * 4 + 4).map(f32(base + p.bones[it])))
		out.extend(p.weights[v * 4..v * 4 + 4])

# the part's triangles into the model's part of its material
fn addTriangles(p nif.Part, first i64, mut m BodyModel):
	look = p.materialOf()
	image = m.materials.findIndex(it == look) ?? -1
	if image < 0:
		image = m.materials.len
		m.materials.push(look)
	at = m.model.parts.findIndex(.image == image) ?? -1
	if at < 0:
		at = m.model.parts.len
		m.model.parts.push(gltf.Part(image, indices = []))
	m.model.parts[at].indices.extend(p.indices.map(u32(first + it)))

fn channelOf(node i64, path gltf.Path, times f32[], move values f32[]):
	gltf.Channel(node, path, step = false, cubic = false, times = times.copy(), values)

# an animation as a clip: each track's translation, rotation and scale at every frame
pub fn clipOf(name str, a hkx.Animation) gltf.Clip:
	times = (0..a.frames).map(f32(it) * a.frameDuration)
	frames = (0..a.frames).map(a.frame(it))
	channels = []
	for t in 0..a.trackCount():
		moves = []
		turns = []
		sizes = []
		for f in frames:
			p = f[t].translation
			q = f[t].rotation
			s = f[t].scale
			moves.extend([p.x, p.y, p.z])
			turns.extend([q.x, q.y, q.z, q.w])
			sizes.extend([s.x, s.y, s.z])
		node = a.trackToBone[t]
		channels.push(channelOf(node, .Translation, times, move moves))
		channels.push(channelOf(node, .Rotation, times, move turns))
		channels.push(channelOf(node, .Scale, times, move sizes))
	gltf.Clip(name = name.copy(), duration = a.duration, channels)

# The worn models on the skeleton with the animations as clips, ready for newSkinned; a bone the
# skeleton lacks follows its root.
pub fn bodyModel(body BodyPart[], s hkx.Skeleton, animations (str, hkx.Animation)[]) BodyModel:
	clips = []
	for (name, a) in animations:
		clips.push(clipOf(name, a))
	m = BodyModel(
		model = gltf.Model(
			nodes = s.nodesOf(),
			order = (0..s.bones.len).map(it),
			palette = [],
			inverseBinds = [],
			vertices = [],
			parts = [],
			images = [],
			clips
		),
		materials = []
	)
	for b in body:
		for p in b.parts:
			base = m.model.palette.len
			for k, bone in p.partBones(s):
				m.model.palette.push(bone ?? 0)
				m.model.inverseBinds.extend(p.skinToBone[k].floatsOf())
			first = m.model.vertices.len / gltf.skinVertexFloats
			p.addVertices(base, p.diffuse != "", m.model.vertices)
			p.addTriangles(first, m)
	m
