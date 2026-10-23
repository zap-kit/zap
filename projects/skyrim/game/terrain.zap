# The land around a set of exterior cells made into what the GPU draws and the physics walks on,
# as SkyrimSE.exe's TESObjectLAND::LoadVertices builds it (0x1402ad5c0, 0x1402aafe0, 0x1402b3380,
# 0x1402b3ce0): a cell's four 17 x 17 quadrants each a patch of the height grid, the vertices'
# normals (VNML) and colors (VCLR), the texture tiles of a quadrant (its base, then the layers
# whose mean opacity reaches 0.001) weighted per vertex by the opacity as a byte (the base taking
# what the layers leave), the textures repeating fLandTextureTilingMult / 4 (3 / 4) times from one
# vertex to the next, the squares cut like a checkerboard. A cell with no LAND has no land.
#
# The way in, for the cell agent:
#   t = terrainOf(install, plugin, world, x0, y0, x1, y1)   the cells x0..x1, y0..y1 (inclusive)
#   sc.showTerrain(t)                                       into the cell's scene (drawn with it)
#   w.collideTerrain(t)                                     into the Havok world (walked on)
#   t.heightAt(x, y)                                        the ground under a game position

import engine
import engine.physics
import skyrim
import skyrim.esm
import world

# the texture a quadrant with no BTXT, or a layer naming no LTEX, falls back to (the executable
# builds it from Landscape\Dirt02.dds)
defaultDiffuse = "Landscape\\Dirt02.dds"
defaultNormal = "Landscape\\Dirt02_N.dds"

tilingMult f32 = 3.0   # fLandTextureTilingMult
mostTiles = 6
shortestLayer f32 = 0.001   # a layer whose mean opacity is under this is dropped

# a cell's heights, in the game's units (z up), row by row from the south west
pub type TerrainGrid:
	x i64
	y i64
	heights f32[]

# The land of the cells ready to draw and walk on: the vertices (y up) with their tiles' textures
# in `textures` (laid in `body`), the triangles over them, and each cell's heights (z up).
pub type Terrain:
	vertices engine.TerrainVertex[]
	indices u32[]
	textures world.PreparedTexture[]
	body u8[]
	grids TerrainGrid[]

# a texture's quality byte as the executable stores it: the opacity times 255, whole
fn byteOf(opacity f32) f32:
	f32(i64(opacity.clamp(0.0, 1.0) * 255.0))

fn subgrid<T Copy>(all T[], quadrant i64) T[]:
	out = []
	for r in 0..esm.quadrantSide:
		for c in 0..esm.quadrantSide:
			out.push(all[((quadrant / 2) * 16 + r) * esm.landSide + (quadrant % 2) * 16 + c])
	out

fn tileOf(
	mut plugin esm.Esm,
	install skyrim.Install,
	mut table TextureTable,
	mut body u8[],
	ltex i64
):
	diffuse = defaultDiffuse
	normal = defaultNormal
	if ltex != 0 and plugin.landTexture(ltex) is t:
		diffuse = t.diffuse
		normal = t.normal
	engine.TerrainTile(
		diffuse = table.textureIndex(install, diffuse, flatDiffuse, body),
		normalMap = table.textureIndex(install, normal, flatNormal, body)
	)

# the layers of a quadrant that count: in order, the first mostTiles - 1, those that reach the mean
fn countedLayers(l esm.Land, quadrant i64):
	l.layers.filter(.quadrant == quadrant and .order < esm.maxLayers).filter(
		.opacity.map(byteOf(it) / 255.0).sum() / f32(.opacity.len) >= shortestLayer
	)

# The patch of a quadrant of a cell's land: the tiles base first, the base weighted by what the
# layers leave of each vertex.
fn patchOf(
	mut plugin esm.Esm,
	install skyrim.Install,
	mut table TextureTable,
	mut body u8[],
	l esm.Land,
	quadrant i64
):
	layers = l.countedLayers(quadrant)
	tiles = [plugin.tileOf(install, table, body, l.base[quadrant])]
	for layer in layers:
		tiles.push(plugin.tileOf(install, table, body, layer.texture))
	vertices = esm.quadrantSide * esm.quadrantSide
	byLayer = layers.map(.opacity.map(byteOf(it) / 255.0))
	rest f32[] = fill(vertices, 1.0)
	for covered in byLayer:
		for k in 0..vertices:
			rest[k] -= covered[k]
	weights = [rest.map(byteOf(.max(0.0)) / 255.0)]
	weights.extend(byLayer)
	engine.TerrainPatch(
		side = esm.quadrantSide,
		step = esm.vertexStep,
		origin = Vec2(
			f32(l.x) * esm.cellSize + f32(quadrant % 2) * 2048.0,
			f32(l.y) * esm.cellSize + f32(quadrant / 2) * 2048.0
		),
		uvStep = tilingMult / 4.0,
		heights = subgrid(l.heights, quadrant),
		normals = subgrid(l.normals, quadrant),
		colors = subgrid(l.colors, quadrant),
		tiles,
		weights
	)

# a vertex of the game's space (z up) in the engine's (y up)
fn inYUp(v engine.TerrainVertex):
	moved = v.copy()
	moved.position = yUp.applyPoint(v.position)
	moved.normal = yUp.applyDirection(v.normal)
	moved.tangent = yUp.applyDirection(v.tangent)
	moved

# The land of the exterior cells x0..x1, y0..y1 (inclusive) of the world, with its textures read
# from the install; a cell the world has no land for adds nothing.
pub fn terrainOf(
	install skyrim.Install,
	mut plugin esm.Esm,
	world i64,
	x0 i64,
	y0 i64,
	x1 i64,
	y1 i64
) Terrain:
	body = []
	table = newTextureTable(body)
	t = Terrain(vertices = [], indices = [], textures = [], body = [], grids = [])
	for y in y0..=y1:
		for x in x0..=x1:
			l = plugin.landOf(world, x, y) ?? continue
			t.grids.push(TerrainGrid(x, y, heights = l.heights.copy()))
			for quadrant in 0..4:
				patch = plugin.patchOf(install, table, body, l, quadrant)
				first = u32(t.vertices.len)
				t.vertices.extend(patch.terrainVertices().map(.inYUp()))
				t.indices.extend(physics.gridTriangles(esm.quadrantSide).map(it + first))
	t.textures = table.textures
	t.body = body
	t

# The game's ground height at (x, y) over the land, none where no cell of it covers the point.
pub fn heightAt(t Terrain, x f32, y f32) f32?:
	for g in t.grids:
		ox = f32(g.x) * esm.cellSize
		oy = f32(g.y) * esm.cellSize
		if x < ox or y < oy or x > ox + esm.cellSize or y > oy + esm.cellSize: continue
		return physics.gridHeight(g.heights, esm.landSide, esm.vertexStep, x - ox, y - oy)
	none

# the landscape in the scene: its textures sent to the GPU, drawn with the cell
pub fn showTerrain(mut sc world.CellScene, t Terrain):
	textures = t.textures.map(world.gpuTexture(t.body, it))
	sc.addTerrainMesh(t.vertices, t.indices, textures)

# the land walked on: each cell's heights a static surface of the world, under the key of its place
pub fn collideTerrain(mut w physics.World, t Terrain):
	for g in t.grids:
		origin = Vec2(f32(g.x) * esm.cellSize, f32(g.y) * esm.cellSize)
		w.addHeightfield(
			terrainKey(g.x, g.y),
			g.heights,
			esm.landSide,
			esm.vertexStep,
			origin,
			0.5,
			0.0
		)

# the key a cell's land is kept in the physics scene under (removeGroup unloads it)
pub fn terrainKey(x i64, y i64) i64:
	-1_000_000_000 - (y + 4096) * 8192 - (x + 4096)
