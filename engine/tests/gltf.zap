# The engine's glTF reader and the poses of skinned models, on a two-bone arm (gltf/arm.gltf,
# its buffer a data: URI): the nodes, the palette (two joints and the rigid mesh hung on the
# hand), the materials as vertex colors, and the arm bent by its clip.

import engine
import engine.gltf

fn arm():
	gltf.loadGltf("engine/tests/gltf/arm.gltf")

# where palette entry `e` of a pose puts the point p
fn moved(rows f32[], e i64, p Vec3):
	b = e * 12
	x = rows[b] * p.x + rows[b + 1] * p.y + rows[b + 2] * p.z + rows[b + 3]
	y = rows[b + 4] * p.x + rows[b + 5] * p.y + rows[b + 6] * p.z + rows[b + 7]
	z = rows[b + 8] * p.x + rows[b + 9] * p.y + rows[b + 10] * p.z + rows[b + 11]
	"{x:.3} {y:.3} {z:.3}"

test "a data URI's base64 decodes to its bytes, padding included":
	expect gltf.decodeBase64("TWFueQ==") == [77, 97, 110, 121]
	expect gltf.decodeBase64("aGk=") == [104, 105]

test "the arm's nodes, palette, parts and clip":
	g = arm()
	print(g.nodes.map(.name).join(" "))
	print(g.nodes.map("{.parent}").join(" "))
	print(g.palette)
	n = gltf.skinVertexFloats
	print(
		"{g.vertices.len / n} vertices, {g.parts.len} part, {g.parts[0].indices.len} indices"
	)
	v = g.vertices
	print("flag: {v[10]} {v[11]} {v[12]} {v[13]}, emissive {v[9]}; strip: {v[3 * n + 10]} {v[3 * n + 11]} {v[3 * n + 12]} {v[3 * n + 13]}, emissive {v[3 * n + 9]}")
	print("{g.clips[0].name} {g.clips[0].duration}")
	prints """
		shoulder elbow hand arm
		-1 0 1 -1
		[0, 1, 2]
		7 vertices, 1 part, 9 indices
		flag: 1 1 0.5 1, emissive 1; strip: 1 0 0 1, emissive 0
		Bend 1
		"""

test "the arm bends with its clip, the hand's mesh with it":
	model = arm()
	rig = model.rigOf()
	rows = []
	rig.posePalette(engine.Pose(clip = -1, time = 0.0), rows)
	print(moved(rows, 1, Vec3(0.0, 2.0, 0.0)))
	rows.clear()
	rig.posePalette(engine.Pose(clip = 0, time = 0.5), rows)
	print(moved(rows, 1, Vec3(0.0, 2.0, 0.0)))
	rows.clear()
	rig.posePalette(engine.Pose(clip = 0, time = 1.0), rows)
	print(moved(rows, 1, Vec3(0.0, 2.0, 0.0)))
	print(moved(rows, 2, Vec3(0.5, 0.0, 0.0)))
	# the clip's end eased in halfway from its start: the 45 degree pose again
	rows.clear()
	engine.posePalette(
		rig,
		engine.Pose(clip = 0, time = 1.0, from = 0, fromTime = 0.0, blend = 0.5),
		rows
	)
	print(moved(rows, 1, Vec3(0.0, 2.0, 0.0)))
	prints """
		0.000 2.000 0.000
		-0.707 1.707 0.000
		-1.000 1.000 0.000
		-1.000 1.500 0.000
		-0.707 1.707 0.000
		"""

# a clip holding both nodes' x translation at one value
fn holdingX(name str, x f32):
	gltf.Clip(
		name = name.copy(),
		duration = 1.0,
		channels = (0..2).map(
			gltf.Channel(
				node = it,
				path = .Translation,
				step = true,
				cubic = false,
				times = [0.0],
				values = [x, 0.0, 0.0]
			)
		)
	)

# two nodes at rest and two clips, one at 10 and one at 20
fn twoClipRig():
	engine.Rig(
		parents = [-1, 0],
		order = [0, 1],
		rest = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0],
		palette = [],
		inverseBinds = [],
		clips = [holdingX("ten", 10.0), holdingX("twenty", 20.0)],
		names = ["a", "b"]
	)

test "a mixed pose averages the clips node by node by the weight each layer has on the node":
	rig = twoClipRig()
	whole = rig.poseLocals(
		engine.Pose(
			clip = 0,
			time = 0.0,
			mixed = [
				engine.PoseLayer(clip = 0, time = 0.0, weight = 1.0),
				engine.PoseLayer(clip = 1, time = 0.0, weight = 1.0)
			]
		)
	)
	expect whole[0] == 15.0 and whole[10] == 15.0
	masked = rig.poseLocals(
		engine.Pose(
			clip = 0,
			time = 0.0,
			mixed = [
				engine.PoseLayer(clip = 0, time = 0.0, weight = 1.0, bones = [1.0, 0.0]),
				engine.PoseLayer(clip = 1, time = 0.0, weight = 1.0, bones = [0.0, 1.0])
			]
		)
	)
	expect masked[0] == 10.0 and masked[10] == 20.0
