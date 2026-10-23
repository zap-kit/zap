# Terrain drawn as patches of a height grid (the grid and its triangles are physics' heightfield.zap,
# one definition for the drawn surface and the collider). A patch has a normal and a color per
# vertex and up to `terrainLayers` texture tiles, each with a weight per vertex; the pixel stage
# (terrain.gpu.zap) blends the tiles by those weights as Skyrim's landscape shader does. A vertex
# names its tiles' textures by index in the program's texture list (bindless).

# the tiles a patch blends at most
pub terrainLayers = 6

# a tile: the indices of its diffuse and normal textures in the program's texture list
pub type TerrainTile:
	diffuse i64
	normalMap i64

# A patch of the height grid: side x side vertices `step` apart with the first at `origin` (x, y),
# the textures repeating `uvStep` times from one vertex to the next. Normals and colors are one
# per vertex; each tile has a weight per vertex, 0 to 1 (the pixel stage divides by their sum).
pub type TerrainPatch:
	side i64
	step f32
	origin Vec2
	uvStep f32
	heights f32[]
	normals Vec3[]
	colors Vec3[]
	tiles TerrainTile[]
	weights (f32[])[]   # by tile

fn weightOf(p TerrainPatch, tile i64, vertex i64):
	p.weights[tile][vertex] if tile < p.tiles.len else 0.0

fn indexOfTile(p TerrainPatch, tile i64, normals bool) f32:
	if tile >= p.tiles.len: return 0.0
	f32(p.tiles[tile].normalMap if normals else p.tiles[tile].diffuse)

# the patch's vertices, in the grid's order
pub fn terrainVertices(p TerrainPatch) TerrainVertex[]:
	out = []
	for r in 0..p.side:
		for c in 0..p.side:
			k = r * p.side + c
			n = p.normals[k]
			# the textures' u runs along +x: the tangent is that axis made square to the normal
			t = Vec3(1.0, 0.0, 0.0) - n * n.x
			out.push(
				TerrainVertex(
					position = Vec3(
						p.origin.x + f32(c) * p.step,
						p.origin.y + f32(r) * p.step,
						p.heights[k]
					),
					normal = n,
					tangent = t.normalized(),
					color = p.colors[k].withW(1.0),
					uv = Vec2(f32(c), f32(r)) * p.uvStep,
					weights = Vec4(p.weightOf(0, k), p.weightOf(1, k), p.weightOf(2, k), p.weightOf(3, k)),
					weights2 = Vec4(p.weightOf(4, k), p.weightOf(5, k), 0.0, 0.0),
					diffuse = Vec4(
						p.indexOfTile(0, false),
						p.indexOfTile(1, false),
						p.indexOfTile(2, false),
						p.indexOfTile(3, false)
					),
					diffuse2 = Vec4(p.indexOfTile(4, false), p.indexOfTile(5, false), 0.0, 0.0),
					normalMaps = Vec4(
						p.indexOfTile(0, true),
						p.indexOfTile(1, true),
						p.indexOfTile(2, true),
						p.indexOfTile(3, true)
					),
					normalMaps2 = Vec4(p.indexOfTile(4, true), p.indexOfTile(5, true), 0.0, 0.0)
				)
			)
	out

# a vertex with its tiles' indices moved by `by` (the patch's textures joined to a longer list)
pub fn shiftedTiles(v TerrainVertex, by f32) TerrainVertex:
	TerrainVertex(
		position = v.position,
		normal = v.normal,
		tangent = v.tangent,
		color = v.color,
		uv = v.uv,
		weights = v.weights,
		weights2 = v.weights2,
		diffuse = v.diffuse + Vec4(by, by, by, by),
		diffuse2 = v.diffuse2 + Vec4(by, by, 0.0, 0.0),
		normalMaps = v.normalMaps + Vec4(by, by, by, by),
		normalMaps2 = v.normalMaps2 + Vec4(by, by, 0.0, 0.0)
	)
