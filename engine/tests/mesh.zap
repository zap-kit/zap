# The normals of triangles: a face's, smooth ones per vertex (weighted by area), and per corner
# within smoothing groups.

import engine

fn shown(p Vec3):
	"{(p.x * 1000.0).round() / 1000.0} {(p.y * 1000.0).round() / 1000.0} {(p.z * 1000.0).round() / 1000.0}"

# a roof of two slopes meeting along z at x 0: the left one rising toward +x, the right falling
fn roof():
	[
		Vec3(-1.0, 0.0, 0.0),
		Vec3(0.0, 1.0, 0.0),
		Vec3(0.0, 1.0, -1.0),
		Vec3(1.0, 0.0, 0.0)
	]

test "a face's normal is the side it winds counter-clockwise on":
	print(
		shown(
			engine.faceNormal(
				Vec3(0.0, 0.0, 0.0),
				Vec3(1.0, 0.0, 0.0),
				Vec3(0.0, 1.0, 0.0)
			)
		)
	)
	prints "0 0 1"

test "smooth normals per vertex: the ridge between two slopes points up":
	normals = engine.vertexNormals(roof(), [0, 1, 2, 1, 3, 2])
	for n in normals:
		print(n.shown())
	prints """
		-0.707 0.707 0
		0 1 0
		0 1 0
		0.707 0.707 0
		"""

test "per smoothing group: the ridge is smooth in one group and sharp across two":
	indices = [0, 1, 2, 1, 3, 2]
	smooth = engine.groupNormals(roof(), indices, [1, 1])
	print(smooth[1].shown())
	sharp = engine.groupNormals(roof(), indices, [1, 2])
	print(sharp[1].shown())
	print(sharp[3].shown())
	prints """
		0 1 0
		-0.707 0.707 0
		0.707 0.707 0
		"""
