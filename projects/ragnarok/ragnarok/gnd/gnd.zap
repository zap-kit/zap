# GND, a map's ground: "GRGN", a version, its size in cubes (each 10 units square, two cells of
# the GAT), the textures its tiles use (names under data\texture\), the lightmaps (8 x 8 texels
# each: the baked shadow as one byte a texel, then the baked light's color as three), the tiles
# (a texture's four corners, a lightmap, a color in BGRA) and the cubes: four corner heights
# (y down; 1 at x, y; 2 at x + 1, y; 3 at x, y + 1; 4 at x + 1, y + 1) and the tiles on top,
# on the side facing y + 1 (front) and the side facing x + 1, -1 for none. From 1.8 the water
# is the GND's: a level and waves for the whole map, then per zone of a grid.

import ragnarok.rsw

pub type Tile:
	u f32[4]
	v f32[4]
	texture i64   # an index into the GND's texture names
	lightmap i64
	color Vec4   # the tile's color, 0..1

pub type Cube:
	heights f32[4]
	up i64
	front i64
	side i64

# a tile and a cube as the file holds them
type TileRecord:
	u f32[4]
	v f32[4]
	texture u16
	lightmap u16
	bgra u8[4]

type CubeRecord:
	heights f32[4]
	up i32
	front i32
	side i32

pub type Gnd:
	version i64
	textures u8[,]
	lightmapWidth i64
	lightmapHeight i64
	lightmapCount i64
	lightmaps u8[]   # lightmapCount blocks of w * h shadow bytes then w * h * 3 color bytes
	tiles Tile[]
	cubes Grid<Cube>   # by their place: x across, y along
	water rsw.Water?   # from 1.8: the water of the map, replacing the RSW's

	fn cube(x i64, y i64):
		cubes[x, y]

	fn inside(x i64, y i64):
		x >= 0 and y >= 0 and x < cubes.width and y < cubes.height

# the ground of a GND file, or why it cannot be read
pub fn parseGnd(d u8[]) Gnd ? str:
	if d.len < 6 or not d.startsWith("GRGN"): return "not a GND file"
	version = i64(d[4]) * 256 + i64(d[5])
	if version < 0x106:
		return "GND version {version >> 8}.{version & 255} is not read (1.6 and later are)"
	r = Reader(d, at = 6)
	width = r.recordCount(1)
	height = r.recordCount(1)
	r.f32()   # the cube's size, always 10
	textureCount = r.recordCount(1)
	nameLength = r.u32()
	textures = []
	loop textureCount:
		textures.push(r.cStringBytes(nameLength))
	lightmapCount = i64(r.u32())
	lightmapWidth = i64(r.i32())
	lightmapHeight = i64(r.i32())
	r.i32()   # cells a lightmap covers, always 1
	if lightmapWidth <= 0 or lightmapHeight <= 0:
		lightmapWidth = 8
		lightmapHeight = 8
	size = lightmapCount * lightmapWidth * lightmapHeight * 4
	if r.at + size > d.len: return "the GND's lightmaps run past the end"
	lightmaps = []
	lightmaps.extend(d[r.at..r.at + size])
	r.skip(size)
	tileCount = r.recordCount(40)
	tiles Tile[] = []
	tiles.reserve(tileCount)
	loop tileCount:
		t = TileRecord.fromBytes(r)
		tiles.push(Tile(
			u = t.u,
			v = t.v,
			texture = 0 if t.texture >= textureCount else t.texture,
			lightmap = 0 if t.lightmap >= lightmapCount else t.lightmap,
			color = Vec4(t.bgra[2], t.bgra[1], t.bgra[0], t.bgra[3]) / 255.0
		))
	if width * height > (d.len - r.at) / 28: return "the GND's cubes run past the end"
	cubes = Grid<Cube>(width, height)
	for y in 0..cubes.height:
		for x in 0..cubes.width:
			c = CubeRecord.fromBytes(r)
			cubes[x, y] = Cube(
				heights = c.heights,
				up = c.up if c.up < tileCount else -1,
				front = c.front if c.front < tileCount else -1,
				side = c.side if c.side < tileCount else -1
			)
	if r.short: return "the GND's cubes run past the end"
	water rsw.Water? = none
	if version >= 0x108:
		w = rsw.Water.fromBytes(r)
		zonesX = r.i32()
		zonesY = i64(r.i32())
		# the zones of the grid; the first one's stands for the whole map
		for k in 0..zonesX * zonesY:
			if version >= 0x109:
				zone = rsw.Water.fromBytes(r)
				if k == 0:
					w = zone
			elif k == 0:
				w.level = r.f32()
			else:
				r.f32()
		water = w
	Gnd(
		version,
		textures,
		lightmapWidth,
		lightmapHeight,
		lightmapCount,
		lightmaps,
		tiles,
		cubes,
		water
	)
