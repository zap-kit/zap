# The water of an exterior world as SkyrimSE.exe's TESWaterSystem has it: each cell whose DATA says
# it has water gets a plane of its size at the cell's water height (XCLW, the world's default where
# the cell sets none) of its water type (XCWT, the world's WRLD NAM2), drawn by
# shaders/water.gpu.zap; the distant planes of the LOD blocks (game/lod.zap) of the world's LOD
# water type. A type with the flow map flag reads the cell's flow map
# (Textures\Water\<plugin>\flow.<x>.<y>.dds, 64 x 64 texels over the cell) and its flow normals.
#
# The way in, for the cell agent:
#   w = install.waterOf(plugin, "skyrim.esm", world, x0, y0, x1, y1, tint)   the cells' water
#   w.addDistant(plugin, world, lod, tint, install)                          the distant planes
#   sc.showWater(w)                                                          into the cell's scene

import skyrim
import skyrim.esm
import world
import world.shaders

# the water the cells' planes and the distant planes make: vertices and triangles, one material per
# water type and how it moves, the textures they name (laid in `body`)
pub type Water:
	vertices shaders.WaterVertex[]
	indices u32[]
	materials shaders.WaterMaterial[]
	motions world.WaterMotion[]
	textures world.PreparedTexture[]
	body u8[]
	height f32   # the height the reflection mirrors about: the first plane's
	planes i64
	byType {i64: i64}   # a water type's form id -> its material
	table TextureTable

# a water type's constants as the shader reads them; `tint` is the weather's water multiplier
fn waterMaterialOf(w esm.WaterType, tint Vec3, maps Vec4):
	shaders.WaterMaterial(
		shallow = (w.shallow * tint).withW(w.sunSparklePower),
		deep = (w.deep * tint).withW(w.sunSpecularMagnitude),
		fresnel = Vec4(w.fresnelAmount, 0.0, w.specularPower, 0.0),
		amounts = Vec4(w.sunSpecularPower, w.reflectionAmount, w.alpha, w.refractionMagnitude),
		amplitude = Vec4(w.amplitude[0], w.amplitude[1], w.amplitude[2], 0.0),
		params = Vec4(w.noiseFalloff, w.reflectionMagnitude, w.sunSparklePower, 0.0),
		fog = Vec4(w.aboveFogFar, w.aboveFogFar - w.aboveFogNear, w.aboveFogAmount, 0.0),
		depth = Vec4(w.depthReflections, w.depthRefraction, w.depthNormals, w.depthSpecular),
		scale = Vec4(w.uvScale[0], w.uvScale[1], w.uvScale[2], 0.0),
		scroll = Vec4(0.0, 0.0, 0.0, 0.0),
		scrollThird = Vec4(0.0, 0.0, 0.0, 0.0),
		maps
	)

# The index of the material of the water type, made the first time: its normal maps and its flow
# normals read from the install.
fn materialIndex(
	mut water Water,
	install skyrim.Install,
	mut plugin esm.Esm,
	form i64,
	tint Vec3
) i64?:
	if water.byType.get(form) is k: return k
	kind = try plugin.waterTypeOf(form)
	maps = Vec4(0.0, 0.0, 0.0, -1.0)
	slots = []
	for k in 0..3:
		slots.push(
			f32(water.table.textureIndex(install, kind.normals[k], flatNormal, water.body))
		)
	flowNormals = -1.0
	if (kind.flags & esm.flagFlowMap) != 0:
		flowNormals = f32(water.table.textureIndex(install, kind.normals[3], -1, water.body))
	maps = Vec4(slots[0], slots[1], slots[2], flowNormals)
	water.materials.push(kind.waterMaterialOf(tint, maps))
	water.motions.push(
		world.WaterMotion(directions = kind.windDirection.copy(), speeds = kind.windSpeed.copy())
	)
	water.byType[form] = water.materials.len - 1
	water.materials.len - 1

fn addPlane(
	mut water Water,
	west f32,
	south f32,
	side f32,
	height f32,
	material i64,
	flow f32,
	lodPlane f32
):
	first = u32(water.vertices.len)
	data = Vec4(f32(material), flow, lodPlane, 0.0)
	for row in 0..2:
		for column in 0..2:
			x = west + f32(column) * side
			y = south + f32(row) * side
			water.vertices.push(
				shaders.WaterVertex(
					position = Vec3(x, height, -y),
					uv = Vec2(f32(column), 1.0 - f32(row)),
					data
				)
			)
	for corner in [0, 2, 1, 1, 2, 3]:
		water.indices.push(first + u32(corner))
	water.planes += 1

# whether the cell's land is wholly over the water (the plane could never show)
fn buriedBy(mut plugin esm.Esm, world i64, x i64, y i64, height f32):
	l = plugin.landOf(world, x, y) ?? return false
	(l.heights.min() ?? height) > height + 16.0

# The water of the cells x0..x1, y0..y1 (inclusive) of the world, whose flow maps are those of
# `source` (the plugin's file name in lower case); `tint` is the weather's water multiplier.
pub fn waterOf(
	install skyrim.Install,
	mut plugin esm.Esm,
	source str,
	world i64,
	x0 i64,
	y0 i64,
	x1 i64,
	y1 i64,
	tint Vec3
) Water:
	body = []
	water = Water(
		vertices = [],
		indices = [],
		materials = [],
		motions = [],
		textures = [],
		body = [],
		height = 0.0,
		planes = 0,
		byType = {},
		table = newTextureTable(body)
	)
	water.body = body
	for y in y0..=y1:
		for x in x0..=x1:
			cell = plugin.cellWaterAt(world, x, y) ?? continue
			if plugin.buriedBy(world, x, y, cell.height): continue
			material = water.materialIndex(install, plugin, cell.waterType, tint) ?? continue
			flow = -1.0
			if water.materials[material].maps.w >= 0.0:
				flow = f32(
					water.table.textureIndex(
						install,
						"textures/water/{source}/flow.{x}.{y}.dds",
						-1,
						water.body
					)
				)
			if water.planes == 0: water.height = cell.height
			water.addPlane(
				f32(x) * cellUnits,
				f32(y) * cellUnits,
				cellUnits,
				cell.height,
				material,
				flow,
				0.0
			)
	water.textures = water.table.textures.copy()
	water

# The distant planes the LOD blocks hold (game/lod.zap's `waterPositions`), of the world's LOD
# water type.
pub fn addDistant(
	mut water Water,
	install skyrim.Install,
	mut plugin esm.Esm,
	world i64,
	lod Lod,
	tint Vec3
):
	distant = plugin.worldLodWater(world) ?? return
	material = water.materialIndex(install, plugin, distant.waterType, tint) ?? return
	first = u32(water.vertices.len)
	for p in lod.waterPositions:
		water.vertices.push(
			shaders.WaterVertex(
				position = p,
				uv = Vec2(0.0, 0.0),
				data = Vec4(f32(material), -1.0, 1.0, 0.0)
			)
		)
	for k in lod.waterIndices:
		water.indices.push(first + k)
	water.textures = water.table.textures.copy()

# the water in the scene: its textures sent to the GPU, drawn with the cell
pub fn showWater(mut sc world.CellScene, water Water):
	textures = water.textures.map(world.gpuTexture(water.body, it))
	sc.addWaterMesh(
		water.vertices,
		water.indices,
		water.materials,
		water.motions,
		textures,
		water.height
	)
