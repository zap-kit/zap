# The terrain patch: its vertices in the grid's order with the tiles' weights and textures.

import engine

fn patch(move heights f32[]):
	engine.TerrainPatch(
		side = 3,
		step = 128.0,
		origin = Vec2(1000.0, 2000.0),
		uvStep = 0.75,
		heights,
		normals = fill(9, Vec3(0.0, 0.0, 1.0)),
		colors = fill(9, Vec3(0.5, 0.25, 1.0)),
		tiles = [engine.TerrainTile(diffuse = 2, normalMap = 3), engine.TerrainTile(diffuse = 4, normalMap = 5)],
		weights = [fill(9, 0.25), (0..9).map(f32(it) / 8.0)]
	)

test "a patch's vertices lie on the grid, repeat the textures by the uv step and carry the tiles":
	vs = patch((0..9).map(f32(it) * 10.0)).terrainVertices()
	expect vs.len == 9
	expect vs[4].position == Vec3(1128.0, 2128.0, 40.0)
	expect vs[5].uv == Vec2(1.5, 0.75)
	expect vs[8].weights.x == 0.25 and vs[8].weights.y == 1.0 and vs[8].weights.z == 0.0
	expect vs[0].diffuse == Vec4(2.0, 4.0, 0.0, 0.0) and vs[0].normalMaps.y == 5.0
	expect vs[3].color == Vec4(0.5, 0.25, 1.0, 1.0)
	expect vs[0].tangent == Vec3(1.0, 0.0, 0.0)

test "a patch's textures moved to a longer list shift every index":
	v = patch(fill(9, 0.0)).terrainVertices()[0].shiftedTiles(10.0)
	expect v.diffuse.x == 12.0 and v.diffuse2.x == 10.0 and v.normalMaps.y == 15.0
