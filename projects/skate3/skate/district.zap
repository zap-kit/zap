# A district of the world made ready to draw and to touch, from the user's disc: every model of
# its Pres stream decoded into batches of triangles that share their textures and way of being
# drawn, the textures those batches use (from Pres and Tex), and the collision triangles of its
# Sim stream. Decoding takes a while, so it is done once into prepared files
# (projects/skate3/assets/<district>/world.bin and collision.bin, not committed) that the game loads.
#
# Both are bytes.pack files with an empty head. world.bin ("ZK3W"): the textures (count; each:
# id, width, height, RGBA rows), the batches (count; each: color, lightmap and extra texture
# ids, kind, vertex count, then the vertices as the shader's WorldVertex lays them out:
# position; u, v, lightmap u; lightmap v, decal u, v; the normal packed in one float, all
# little-endian). collision.bin ("ZK3C"): the triangle count, nine floats and a surface word
# each.

import ea
import graphics.shaders
import rw4
import xbox
import fs
import image

pub kindOpaque = 0
pub kindCutout = 1   # texels with little alpha are dropped
pub kindBlended = 2   # see-through (water, glass)
pub kindDecal = 3   # a decal's texture over the color, by the decal UVs

worldVersion = 3
collisionVersion = 3
# the largest side a color texture is kept at (larger ones are halved until they fit)
largestColor = 512

pub type WorldTexture:
	id i64
	image image.Image

pub type WorldBatch:
	color i64
	lightmap i64
	extra i64
	kind i64
	vertices u8[]   # the bytes of graphics.shaders.WorldVertex values

pub type World:
	textures WorldTexture[]
	batches WorldBatch[]
	collision rw4.CollisionSoup

type BatchKey:
	color i64
	lightmap i64
	extra i64
	kind i64

# how a material is drawn, and its extra texture, from its shader and its channels
fn kindOf(m rw4.Material, hasDecalUvs bool):
	shader = m.shader.lower()
	transparent = m.materialTexture("transparent")
	if shader.startsWith("environment.decal") and hasDecalUvs and
		m.materialTexture("decal") != 0:
		return (kindDecal, m.materialTexture("decal"))
	if shader.startsWith("water") or shader.startsWith("ocean") or
		shader == "environment.transparent" or shader == "environment.reflective_trans":
		return (kindBlended, transparent)
	if transparent != 0 or "alphatest" in shader or "tree" in shader:
		return (kindCutout, transparent)
	(kindOpaque, 0)

# the BIG archive of a district's streams on the disc, or why it cannot be opened
pub fn openDistrictBig(disc xbox.Disc, district str) ea.Big ? str:
	disc.openBig("data/content/world{district}.big")

# The district's world decoded from the disc (its Pres and Tex streams), or why it cannot be.
pub fn decodeWorld(disc xbox.Disc, district str, report fn(str)) World ? str:
	big = try disc.openDistrictBig(district)
	pres = try big.openStream(district, "Pres")
	batches = []
	byKey {BatchKey: i64} = {}
	wanted {i64: bool} = {}
	entry = EntryCache()
	models = 0
	for asset in pres.assets:
		if asset.kind != assetModel: continue
		arena = try big.assetArena(asset, entry)
		model = try arena.readModel()
		models += 1
		for m in model.meshes:
			if m.material < 0: continue
			mat = model.materials[m.material]
			color = mat.materialTexture("diffuse")
			if color == 0:
				color = mat.materialTexture("transparent")
			lightmap = mat.materialTexture("lightmap")
			kind, extra = mat.kindOf(m.hasDecal)
			key = BatchKey(color, lightmap, extra, kind)
			b = byKey.get(key) ?? -1
			if b < 0:
				b = batches.len
				byKey[key] = b
				batches.push(
					WorldBatch(
						color,
						lightmap,
						extra = 0 if extra == color else extra,
						kind,
						vertices = []
					)
				)
			for id in [color, lightmap, extra]:
				if id != 0:
					wanted[id] = true
			m.addMesh(model.transform, batches[b].vertices)
	report("{district}: {models} models in {batches.len} batches")
	textures = []
	found {i64: bool} = {}
	for name in ["Pres", "Tex"]:
		s = Stream(assets = [])
		match big.openStream(district, name):
			st: s = st
			error:
				if name == "Pres": return error
				continue
		for asset in s.assets:
			if asset.kind != assetTexture: continue
			arena = try big.assetArena(asset, entry)
			decoded = arena.arenaTextures()
			for i in 0..decoded.len:
				id = decoded[i].id
				if id not in wanted or id in found: continue
				if move decoded[i].image is img:
					found[id] = true
					textures.push(WorldTexture(id, image = fitTexture(img, largestColor)))
	report("{district}: {textures.len} of {wanted.len} textures found")
	sim = try big.openStream(district, "Sim")
	collision = rw4.CollisionSoup(corners = [], surfaces = [])
	for asset in sim.assets:
		arena = try big.assetArena(asset, entry)
		_ = try arena.addCollision(collision)
	report("{district}: {collision.surfaces.len} collision triangles")
	World(textures, batches, collision)

# the BIG entry read last: the assets that lie in it reuse its bytes
type EntryCache:
	index i64 = -1
	bytes u8[] = []

# an asset's arena, its BIG entry read when it is not the one read last
fn assetArena(big ea.Big, asset StreamAsset, mut entry EntryCache):
	if asset.entry != entry.index:
		entry.index = asset.entry
		entry.bytes = try big.readBigEntry(big.entries.items[asset.entry])
	rw4.openArena(try assetBytes(entry.bytes, asset))

# the image halved until neither side is over `largest`

fn fitTexture(move img image.Image, largest i64):
	out = img
	while out.width > largest or out.height > largest:
		out = out.halve()
	out

# the image at half its size, each texel the average of four
pub fn halve(img image.Image) image.Image:
	w = (img.width / 2).max(1)
	h = (img.height / 2).max(1)
	out = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..h:
		y0 = (y * 2).min(img.height - 1)
		y1 = (y * 2 + 1).min(img.height - 1)
		for x in 0..w:
			x0 = (x * 2).min(img.width - 1)
			x1 = (x * 2 + 1).min(img.width - 1)
			for c in 0..4:
				sum = i64(img[x0, y0][c]) + i64(img[x1, y0][c]) + img[x0, y1][c] + img[x1, y1][c]
				out[x, y][c] = (sum + 2) / 4
	out

# The triangles of a mesh, placed by the instance's matrix (rows, the translation in the last),
# as the shader's vertices, their bytes at the end of `out`.
fn addMesh(m rw4.ModelMesh, t f32[], mut out u8[]):
	v = m.vertices
	vertices = []
	for i in m.indices:
		p = v.position[i]
		position = Vec3(
			p.x * t[0] + p.y * t[4] + p.z * t[8] + t[12],
			p.x * t[1] + p.y * t[5] + p.z * t[9] + t[13],
			p.x * t[2] + p.y * t[6] + p.z * t[10] + t[14]
		)
		uv = v.uv[i]
		light = v.lightmapUv[i]
		decal = v.decalUv[i]
		n = v.normal[i]
		vertices.push(shaders.WorldVertex(
			position,
			uvAndLightU = Vec3(uv.x, uv.y, light.x),
			lightVAndDecal = Vec3(light.y, decal.x, decal.y),
			packedNormal = packNormal(n.x, n.y, n.z)
		))
	out.extend(vertices.rawBytes())

# A unit normal in one float the shader takes apart again: x and y in steps of 1/1000 (0..2000),
# the sign of z in the float's sign: (x + 1) * 1000 * 2048 + (y + 1) * 1000, negative when z < 0.
pub fn packNormal(x f32, y f32, z f32) f32:
	qx = ((x.clamp(-1.0, 1.0) + 1.0) * 1000.0).round()
	qy = ((y.clamp(-1.0, 1.0) + 1.0) * 1000.0).round()
	v = qx * 2048.0 + qy + 1.0
	-v if z < 0.0 else v

# ---------- prepared files ----------

# a texture as the prepared files keep it
type TextureFile:
	id i64
	width i64
	height i64
	pixels u8[]

fn textureFiles(textures WorldTexture[]):
	textures.map(
		TextureFile(
			id = .id,
			width = .image.width,
			height = .image.height,
			pixels = .image.cells.bytes().copy()
		)
	)

# the textures of a prepared file at the reader, empty when it is cut short
fn readTextures(mut u Reader):
	files = TextureFile[].fromBytes(u)
	if u.short: return []
	files.map(WorldTexture(id = .id, image = image.fromBytes(.width, .height, .pixels)))

# The world written into the dir (world.bin, collision.bin).
pub fn saveWorld(w World, dir str) ? fs.Error:
	try fs.createDir(dir)
	out = PackedParts.pack("ZK3W", worldVersion, [], [])
	out.extend(textureFiles(w.textures).toBytes())
	out.extend(w.batches.toBytes())
	try fs.writeBytes("{dir}/world.bin", out)
	c = PackedParts.pack("ZK3C", collisionVersion, [], [])
	c.extend(w.collision.toBytes())
	try fs.writeBytes("{dir}/collision.bin", c)

# a world's prepared files read back: the textures and batches, and the collision
pub type PreparedWorld:
	textures WorldTexture[]
	batches WorldBatch[]
	collision rw4.CollisionSoup

# a prepared file's text and where its body starts, or why it cannot be read
fn packedFile(path str, magic str, version i64) (str, i64) ? str:
	text = fs.readFile(path) ?? return "{path} is missing"
	parts = text.bytes().unpack(magic, version) ??
		return "{path} is another program's or an older version's"
	(text, parts.bodyAt)

# The prepared world in the dir, or why it cannot be read (missing, or of an older version).
pub fn loadWorld(dir str) PreparedWorld ? str:
	text, bodyAt = try packedFile("{dir}/world.bin", "ZK3W", worldVersion)
	u = Reader(d = text.bytes(), at = bodyAt)
	textures = u.readTextures()
	batches = WorldBatch[].fromBytes(u)
	if u.short: return "{dir}/world.bin is cut short"
	ctext, cAt = try packedFile("{dir}/collision.bin", "ZK3C", collisionVersion)
	c = Reader(d = ctext.bytes(), at = cAt)
	soup = rw4.CollisionSoup.fromBytes(c)
	if c.short: return "{dir}/collision.bin is cut short"
	PreparedWorld(textures, batches, collision = soup)
