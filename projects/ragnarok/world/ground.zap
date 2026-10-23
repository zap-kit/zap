# A GND made into triangles for the GPU, the way the client builds its ground (BrowEdit 3's
# reading of it): per cube its top tile and its walls toward x + 1 and y + 1, each vertex with
# the tile's texture place, its place in an atlas of the lightmaps (the 6 x 6 inner texels of
# each 8 x 8 one), and the color of the tile it touches lit by the sun through the client's
# smoothed corner normals, and the scene's texture of the tile. Triangles are grouped by texture.
# The water is a sheet at the water's level over every cube the ground dips under it.

import engine
import world.shaders
import image
import ragnarok.gnd
import ragnarok.rsw

pub type GroundMesh:
	byTexture shaders.GroundVertex[,]   # by the GND's texture index
	lightmaps image.Image   # the atlas: baked light's color, shadow in alpha
	water shaders.WaterVertex[]

# the corner normals of every cube (four each, by corner: x, y; x + 1, y; x, y + 1; x + 1, y + 1),
# in the file's axes (y down, z toward y + 1)
fn cornerNormals(gnd gnd.Gnd):
	forCalc = Grid<Vec3[4]>(gnd.cubes.width, gnd.cubes.height)
	defaults = Grid<Vec3[4]>(gnd.cubes.width, gnd.cubes.height)
	for (x, y), c in gnd.cubes:
		h = c.heights
		v1 = Vec3(0.0, h[0], 0.0)
		v2 = Vec3(10.0, h[1], 0.0)
		v3 = Vec3(0.0, h[2], 10.0)
		v4 = Vec3(10.0, h[3], 10.0)
		n1 = (v2 - v1).cross(v3 - v1).normalized()
		n2 = (v3 - v4).cross(v2 - v4).normalized()
		both = n1 + n2
		mid = both.normalized()
		forCalc[x, y] = [n1, both, both, n2]
		defaults[x, y] = [n1, mid, mid, n1]
	out = Grid<Vec3[4]>(gnd.cubes.width, gnd.cubes.height)
	for y in 0..out.height:
		for x in 0..out.width:
			cube = gnd.cube(x, y)
			normals = defaults[x, y]
			for i in 0..4:
				sum = normals[i]
				for ii in 1..4:
					xx = (ii % 2) * (-1 if i % 2 == 0 else 1)
					yy = (ii / 2) * (-1 if i < 2 else 1)
					if not gnd.inside(x + xx, y + yy): continue
					ci = (i + ii * (1 - 2 * (i & 1))) & 3
					if gnd.cube(x + xx, y + yy).heights[ci] != cube.heights[i]: continue
					sum += forCalc[x + xx, y + yy][ci]
				normals[i] = sum.normalized()
			out[x, y] = normals
	out

# a normal of the file's axes in the world's
fn worldNormal(n Vec3):
	Vec3(n.x, -n.y, -n.z)

# the color of the top tile of cube (x, y): 0 where there is none, white past the map's edge
fn topColor(gnd gnd.Gnd, x i64, y i64):
	if not gnd.inside(x, y): return engine.white
	up = gnd.cube(x, y).up
	Vec4(0.0, 0.0, 0.0, 0.0) if up < 0 else gnd.tiles[up].color

fn corner(x i64, y i64, height f32):
	Vec3(2.0 * f32(x), -height * 0.2, -2.0 * f32(y))

type LightmapPlace:
	u1 f32
	v1 f32
	u2 f32
	v2 f32

# one vertex: place, texture place, lightmap place, the tile's color lit by `light`, its texture
fn groundVertex(
	p Vec3,
	u f32,
	v f32,
	lu f32,
	lv f32,
	color Vec4,
	light Vec3,
	texture i64
):
	shaders.GroundVertex(
		position = p,
		texturePlace = Vec3(u, v, lu),
		lightmapAndColor = Vec3(lv, color.r * light.x, color.g * light.y),
		blue = color.b * light.z, texture = i32(texture))

# the ground's triangles; the GND's texture i is the scene's textures[i]
pub fn buildGround(
	gnd gnd.Gnd,
	sun rsw.Sun,
	water rsw.Water,
	textures i64[]
) GroundMesh:
	toward = sun.sunDirection()
	normals = gnd.cornerNormals()
	atlas, perRow = gnd.buildGroundAtlas()
	atlasW = atlas.width
	atlasH = atlas.height
	byTexture shaders.GroundVertex[,] = fill(gnd.textures.len.max(1), [])
	sheet = []
	level = water.level
	for y in 0..gnd.cubes.height:
		for x in 0..gnd.cubes.width:
			cube = gnd.cube(x, y)
			if cube.up >= 0:
				gnd.buildGroundTop(
					sun,
					textures,
					toward,
					normals,
					perRow,
					atlasW,
					atlasH,
					x,
					y,
					level,
					water,
					byTexture,
					sheet
				)
			if cube.side >= 0 and x + 1 < gnd.cubes.width:
				gnd.buildGroundSide(sun, textures, toward, perRow, atlasW, atlasH, x, y, byTexture)
			if cube.front >= 0 and y + 1 < gnd.cubes.height:
				gnd.buildGroundFront(sun, textures, toward, perRow, atlasW, atlasH, x, y, byTexture)
	GroundMesh(
		byTexture,
		lightmaps = atlas,
		water = sheet
	)

fn buildGroundAtlas(
	gnd gnd.Gnd
):
	# the lightmap atlas
	lw = gnd.lightmapWidth
	lh = gnd.lightmapHeight
	perRow = i64(f64(gnd.lightmapCount).sqrt().ceil()).max(1)
	rows = (gnd.lightmapCount + perRow - 1) / perRow
	atlasW = perRow * lw
	atlasH = rows.max(1) * lh
	atlas = image.Image(atlasW, atlasH, fill = image.Rgba8(0, 0, 0, 0))
	per = lw * lh
	for i in 0..gnd.lightmapCount:
		base = i * per * 4
		ox = (i % perRow) * lw
		oy = (i / perRow) * lh
		for ty in 0..lh:
			for tx in 0..lw:
				k = ty * lw + tx
				atlas[ox + tx, oy + ty] = image.Rgba8(
					gnd.lightmaps[base + per + k * 3] >> 4 << 4,
					gnd.lightmaps[base + per + k * 3 + 1] >> 4 << 4,
					gnd.lightmaps[base + per + k * 3 + 2] >> 4 << 4,
					gnd.lightmaps[base + k]
				)
	(atlas, perRow)

fn buildGroundLightmapPlace(
	gnd gnd.Gnd,
	perRow i64,
	atlasW i64,
	atlasH i64,
	i i64
):
	lw = gnd.lightmapWidth
	lh = gnd.lightmapHeight
	u1 = f32((i % perRow) * lw + 1) / f32(atlasW)
	v1 = f32((i / perRow) * lh + 1) / f32(atlasH)
	LightmapPlace(
		u1,
		v1,
		u2 = u1 + f32(lw - 2) / f32(atlasW),
		v2 = v1 + f32(lh - 2) / f32(atlasH)
	)

fn buildGroundTop(
	gnd gnd.Gnd,
	sun rsw.Sun,
	textures i64[],
	toward Vec3,
	normals Grid<Vec3[4]>,
	perRow i64,
	atlasW i64,
	atlasH i64,
	x i64,
	y i64,
	level f32,
	water rsw.Water,
	mut byTexture shaders.GroundVertex[,],
	mut sheet shaders.WaterVertex[]
):
	cube = gnd.cube(x, y)
	h = cube.heights
	t = gnd.tiles[cube.up]
	lm = gnd.buildGroundLightmapPlace(perRow, atlasW, atlasH, t.lightmap)
	ns = normals[x, y]
	c1 = groundVertex(
		corner(x, y, h[0]),
		t.u[0],
		t.v[0],
		lm.u1,
		lm.v1,
		t.color,
		sun.sunlight(toward, ns[0].worldNormal()),
		textures[t.texture]
	)
	c2 = groundVertex(
		corner(x + 1, y, h[1]),
		t.u[1],
		t.v[1],
		lm.u2,
		lm.v1,
		gnd.topColor(x + 1, y),
		sun.sunlight(toward, ns[1].worldNormal()),
		textures[t.texture]
	)
	c3 = groundVertex(
		corner(x, y + 1, h[2]),
		t.u[2],
		t.v[2],
		lm.u1,
		lm.v2,
		gnd.topColor(x, y + 1),
		sun.sunlight(toward, ns[2].worldNormal()),
		textures[t.texture]
	)
	c4 = groundVertex(
		corner(x + 1, y + 1, h[3]),
		t.u[3],
		t.v[3],
		lm.u2,
		lm.v2,
		gnd.topColor(x + 1, y + 1),
		sun.sunlight(toward, ns[3].worldNormal()),
		textures[t.texture]
	)
	out = mut ref byTexture[t.texture]
	out.extend([c2, c4, c3, c2, c3, c1])
	# the water over a cube that dips below its level (y down: a larger height is lower)
	if h[0] > level - water.waveHeight or h[1] > level - water.waveHeight or
		h[2] > level - water.waveHeight or h[3] > level - water.waveHeight:
		for (dx, dy) in [(1, 0), (1, 1), (0, 1), (1, 0), (0, 1), (0, 0)]:
			p = corner(x + dx, y + dy, level)
			sheet.push(shaders.WaterVertex(
				position = p,
				uvPlace = Vec3(f32(x + dx) / 5.0, f32(y + dy) / 5.0, 0.0),
				unused = Vec3(0.0, 0.0, 0.0), spare = 0.0))

fn buildGroundSide(
	gnd gnd.Gnd,
	sun rsw.Sun,
	textures i64[],
	toward Vec3,
	perRow i64,
	atlasW i64,
	atlasH i64,
	x i64,
	y i64,
	mut byTexture shaders.GroundVertex[,]
):
	cube = gnd.cube(x, y)
	h = cube.heights
	t = gnd.tiles[cube.side]
	lm = gnd.buildGroundLightmapPlace(perRow, atlasW, atlasH, t.lightmap)
	adj = gnd.cube(x + 1, y)
	n = Vec3(-1.0, 0.0, 0.0)
	if h[2] < adj.heights[0]:
		n *= -1.0
	light = sun.sunlight(toward, n)
	near = gnd.topColor(x + 1, y)
	far = gnd.topColor(x + 1, y + 1)
	v1 = groundVertex(
		corner(x + 1, y, h[1]),
		t.u[1],
		t.v[1],
		lm.u2,
		lm.v1,
		near,
		light,
		textures[t.texture]
	)
	v2 = groundVertex(
		corner(x + 1, y + 1, h[3]),
		t.u[0],
		t.v[0],
		lm.u1,
		lm.v1,
		far,
		light,
		textures[t.texture]
	)
	v3 = groundVertex(
		corner(x + 1, y, adj.heights[0]),
		t.u[3],
		t.v[3],
		lm.u2,
		lm.v2,
		near,
		light,
		textures[t.texture]
	)
	v4 = groundVertex(
		corner(x + 1, y + 1, adj.heights[2]),
		t.u[2],
		t.v[2],
		lm.u1,
		lm.v2,
		far,
		light,
		textures[t.texture]
	)
	out = mut ref byTexture[t.texture]
	out.extend([v1, v3, v4, v4, v2, v1])

fn buildGroundFront(
	gnd gnd.Gnd,
	sun rsw.Sun,
	textures i64[],
	toward Vec3,
	perRow i64,
	atlasW i64,
	atlasH i64,
	x i64,
	y i64,
	mut byTexture shaders.GroundVertex[,]
):
	cube = gnd.cube(x, y)
	h = cube.heights
	t = gnd.tiles[cube.front]
	lm = gnd.buildGroundLightmapPlace(perRow, atlasW, atlasH, t.lightmap)
	adj = gnd.cube(x, y + 1)
	n = Vec3(0.0, 0.0, -1.0)
	if h[2] < adj.heights[0]:
		n *= -1.0
	light = sun.sunlight(toward, n)
	west = gnd.topColor(x, y + 1)
	east = gnd.topColor(x + 1, y + 1)
	v1 = groundVertex(
		corner(x, y + 1, h[2]),
		t.u[0],
		t.v[0],
		lm.u1,
		lm.v1,
		west,
		light,
		textures[t.texture]
	)
	v2 = groundVertex(
		corner(x + 1, y + 1, h[3]),
		t.u[1],
		t.v[1],
		lm.u2,
		lm.v1,
		east,
		light,
		textures[t.texture]
	)
	v3 = groundVertex(
		corner(x, y + 1, adj.heights[0]),
		t.u[2],
		t.v[2],
		lm.u1,
		lm.v2,
		west,
		light,
		textures[t.texture]
	)
	v4 = groundVertex(
		corner(x + 1, y + 1, adj.heights[1]),
		t.u[3],
		t.v[3],
		lm.u2,
		lm.v2,
		east,
		light,
		textures[t.texture]
	)
	out = mut ref byTexture[t.texture]
	out.extend([v1, v2, v3, v3, v2, v4])
