# The distant land and objects of an exterior world, as SkyrimSE.exe's BGSTerrainManager draws them:
# blocks of 4, 8, 16 and 32 cells a side (Meshes\Terrain\<world>\<world>.<level>.<x>.<y>.btr for the
# land, ...\Objects\*.bto for the objects, both NIF files of the lighting shader with the block's
# own texture and model-space normal map), a quadtree of them chosen by the distance to the eye
# (BGSTerrainNode 0x140517da0: a block splits into its four children while the eye is nearer to it
# than fSplitDistanceMult (1.5) times the half of its diagonal; fBlockMaximumDistance ends the
# view), the land under the loaded cells lowered by fLODLandDropAmount (Lighting.hlsl's
# AdjustLodLandscapeVertexPositionMS) so the near land shows over it.
#
# The way in, for the cell agent:
#   m = install.lodOf("tamriel", eye, loaded, settings)   the distant meshes seen from the eye
#   sc.showLod(m)                                         into the cell's scene

import skyrim
import skyrim.nif
import world
import world.shaders

# the block sizes in cells, the smallest first
lodLevels = [4, 8, 16, 32]
cellUnits f32 = 4096.0

# the setting names read here ("name:section"), their defaults the executable's
splitDistanceMult = "fSplitDistanceMult:TerrainManager"
blockMaximumDistance = "fBlockMaximumDistance:TerrainManager"
landDropAmount = "fLODLandDropAmount:LOD"

# the noise texture of the distant land's blend (the executable names it at 0x14051c9f0)
landNoise = "Textures\\Terrain\\Noise.dds"

# A block of the distant world: `level` cells a side with the cell (x, y) at its south west corner.
pub type LodBlock:
	level i64
	x i64
	y i64

# the game's units of the area the loaded cells cover: its centre and half side
pub type LoadedArea:
	center Vec2
	half f32

# the area uGridsToLoad cells about the cell (x, y) cover
pub fn loadedAround(x i64, y i64, grids i64) LoadedArea:
	LoadedArea(
		center = Vec2((f32(x) + 0.5) * cellUnits, (f32(y) + 0.5) * cellUnits),
		half = f32(grids) * cellUnits / 2.0
	)

fn nearestSquared(eye Vec2, b LodBlock):
	west = f32(b.x) * cellUnits
	south = f32(b.y) * cellUnits
	side = f32(b.level) * cellUnits
	dx = (west - eye.x).max(eye.x - (west + side)).max(0.0)
	dy = (south - eye.y).max(eye.y - (south + side)).max(0.0)
	dx * dx + dy * dy

# a block's four quarters
fn quarters(b LodBlock):
	h = b.level / 2
	[
		LodBlock(h, b.x, b.y),
		LodBlock(h, b.x + h, b.y),
		LodBlock(h, b.x, b.y + h),
		LodBlock(h, b.x + h, b.y + h)
	]

fn floorTo(v f32, step i64):
	i64((v / (f32(step) * cellUnits)).floor()) * step

# Whether the eye is near enough to a block for the game to show its quarters instead
# (BGSTerrainNode::ShouldSplit 0x140519c10: the distance to the block's square against the
# multiplier times the half of its diagonal, the smallest blocks never split).
pub fn splits(b LodBlock, eye Vec2, mult f32) bool:
	if b.level <= lodLevels[0]: return false
	reach = mult * 0.5 * f32(b.level) * cellUnits * 1.4142135
	eye.nearestSquared(b) < reach * reach

# The blocks the game shows seen from the eye: the biggest blocks within the maximum distance,
# each split into its quarters while the eye is near it.
pub fn lodBlocks(eye Vec2, mult f32, maximum f32) LodBlock[]:
	top = lodLevels[len - 1]
	out = []
	first = LodBlock(top, floorTo(eye.x - maximum, top), floorTo(eye.y - maximum, top))
	last = LodBlock(top, floorTo(eye.x + maximum, top), floorTo(eye.y + maximum, top))
	pending = []
	y = first.y
	while y <= last.y:
		x = first.x
		while x <= last.x:
			pending.push(LodBlock(top, x, y))
			x += top
		y += top
	while pending.pop() is b:
		if eye.nearestSquared(b) > maximum * maximum: continue
		if b.splits(eye, mult):
			pending.extend(b.quarters())
		else:
			out.push(b)
	out

# the archive key of a block's file under the world's folder
pub fn lodKey(world str, kind str, b LodBlock) str:
	name = "{world}.{b.level}.{b.x}.{b.y}"
	match kind:
		"btr": "meshes/terrain/{world}/{name}.btr"
		"bto": "meshes/terrain/{world}/objects/{name}.bto"
		_: "meshes/terrain/{world}/trees/{name}.btt"

# The distant meshes seen from an eye: vertices (y up), triangles, and the textures they name.
pub type Lod:
	vertices shaders.LodVertex[]
	indices u32[]
	textures world.PreparedTexture[]
	body u8[]
	blocks LodBlock[]
	# the distant water planes the land blocks hold (game/water.zap draws them): their corners (y up)
	# and triangles, those wholly inside the loaded area left out
	waterPositions Vec3[] = []
	waterIndices u32[] = []

fn holds(area LoadedArea, p Vec3):
	(p.x - area.center.x).abs() < area.half and (p.y - area.center.y).abs() < area.half

# One part of a block's model as vertices and triangles: `origin` moves a land block's local
# positions, the land inside the loaded area is lowered by `drop`, an object whose triangle lies
# wholly in it is left out (its reference is loaded).
fn addLodPart(
	mut lod Lod,
	p nif.Part,
	origin Vec3,
	land bool,
	area LoadedArea,
	drop f32,
	maps Vec4
):
	first = u32(lod.vertices.len)
	positions = p.positions.map(it + origin)
	for k, at in positions:
		moved = at
		if land and area.holds(at): moved = Vec3(at.x, at.y, at.z - drop)
		n = p.normals[k] if k < p.normals.len else Vec3(0.0, 0.0, 1.0)
		lod.vertices.push(
			shaders.LodVertex(
				position = moved.toYUp(),
				normal = n.toYUp(),
				uv = p.uvs[k] if k < p.uvs.len else Vec2(0.0, 0.0),
				color = p.colors[k] if k < p.colors.len else Vec4(1.0, 1.0, 1.0, 1.0),
				maps
			)
		)
	for t in 0..p.indices.len / 3:
		a = p.indices[t * 3]
		b = p.indices[t * 3 + 1]
		c = p.indices[t * 3 + 2]
		if not land and area.holds(positions[a]) and area.holds(positions[b]) and
			area.holds(positions[c]):
			continue
		lod.indices.push(first + a)
		lod.indices.push(first + b)
		lod.indices.push(first + c)

# a block's distant water plane (the land model's part with no texture): its triangles outside the
# loaded area, where the near water is
fn addWaterPart(mut lod Lod, p nif.Part, origin Vec3, area LoadedArea):
	first = u32(lod.waterPositions.len)
	positions = p.positions.map(it + origin)
	for at in positions:
		lod.waterPositions.push(at.toYUp())
	for t in 0..p.indices.len / 3:
		a = p.indices[t * 3]
		b = p.indices[t * 3 + 1]
		c = p.indices[t * 3 + 2]
		if area.holds(positions[a]) and area.holds(positions[b]) and area.holds(positions[c]):
			continue
		lod.waterIndices.push(first + a)
		lod.waterIndices.push(first + b)
		lod.waterIndices.push(first + c)

# whether every cell of the block lies in the loaded area (the game shows no distant block there)
fn coveredBy(b LodBlock, area LoadedArea):
	west = f32(b.x) * cellUnits
	south = f32(b.y) * cellUnits
	side = f32(b.level) * cellUnits
	west >= area.center.x - area.half and south >= area.center.y - area.half and
		west + side <= area.center.x + area.half and south + side <= area.center.y + area.half

# The distant land and objects of the world seen from the eye, with the loaded area's cells left
# to the near land.
pub fn lodOf(
	install skyrim.Install,
	world str,
	eye Vec2,
	area LoadedArea,
	settings skyrim.IniSettings
) Lod:
	body = []
	table = newTextureTable(body)
	lod = Lod(vertices = [], indices = [], textures = [], body = [], blocks = [])
	mult = f32(settings.iniNumber(splitDistanceMult))
	maximum = f32(settings.iniNumber(blockMaximumDistance))
	drop = f32(settings.iniNumber(landDropAmount))
	noise = table.textureIndex(install, landNoise, flatDiffuse, body)
	for b in eye.lodBlocks(mult, maximum):
		if b.coveredBy(area): continue
		lod.blocks.push(b)
		for kind in ["btr", "bto"]:
			bytes = install.installRead(lodKey(world, kind, b)) ?? continue
			model = nif.readNif(bytes) ?? continue
			land = kind == "btr"
			origin = Vec3(f32(b.x) * cellUnits, f32(b.y) * cellUnits, 0.0) if land
				else Vec3(0.0, 0.0, 0.0)
			for part in model.drawParts():
				if part.diffuse.isEmpty:
					if land: lod.addWaterPart(part, origin, area)
					continue
				maps = Vec4(
					f32(table.textureIndex(install, part.diffuse, flatDiffuse, body)),
					f32(table.textureIndex(install, part.normal, flatNormal, body)),
					f32(noise) if land else -1.0,
					1.0 if land else 0.0
				)
				lod.addLodPart(part, origin, land, area, drop, maps)
	lod.textures = table.textures
	lod.body = body
	lod

# the distant land and objects in the scene: their textures sent to the GPU, drawn with the cell
pub fn showLod(mut sc world.CellScene, lod Lod):
	textures = lod.textures.map(world.gpuTexture(lod.body, it))
	sc.addLodMesh(lod.vertices, lod.indices, textures)
