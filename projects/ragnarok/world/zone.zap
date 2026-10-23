# A map prepared once from the install and read from its prepared file each time the game opens.
# Preparing reads its RSW, GND and GAT and the textures its ground and models use (decoded,
# magenta made see-through), builds the ground's triangles and lightmap atlas, bakes every still
# model into the world, keeps the files of the models that move, the frames of its water and the
# ground's shadow map (roBrowser's, the lightmaps' shadow, 8 x 8 texels a cube); the game then
# only reads the file (prepared.zap) and hands its bytes to the GPU.

import engine
import ragnarok
import image
import image.jpeg
import ragnarok.gnd
import ragnarok.rsm
import ragnarok.rsw
import ragnarok.gat
import ragnarok.grf

pub type PreparedMoving:
	kind i64   # in ZoneHead.movingKinds
	placed f32[]   # from the model's space to the world (a Mat4's 16)

# what a prepared map holds besides the bytes of its body
pub type ZoneHead:
	map str
	placedModels i64   # the RSW's placed models
	modelKinds i64   # the model files they use
	gat gat.Gat
	sun rsw.Sun
	water rsw.Water
	textures PreparedTexture[]   # the scene's textures, by index
	ground PreparedBatch[]   # the ground by texture (ground.zap's vertices)
	statics PreparedBatch[]   # the still models by texture and sidedness
	waterSheet engine.Span   # the water's vertices, none: no water
	lightmap PreparedTexture
	waterFrames PreparedTexture[]   # 32 frames of the water's texture, none: no water
	movingKinds engine.Span[]   # the RSM files of the models that move
	movingTextures i64[,]   # per moving kind: its texture index -> the scene's
	moving PreparedMoving[]
	shadowWidth i64   # the shadow map's texels a row (8 a cube)
	shadow engine.Span

pub type MovingModel:
	model i64   # in Zone.models
	placed Mat4   # from the model's space to the world

# a prepared map, read
pub type Zone:
	head ZoneHead
	gat gat.Gat
	file engine.Prepared   # the prepared file: its body holds the spans
	models rsm.Rsm[]   # the models that move, by kind
	normals ModelNormals[]   # theirs, by kind
	moving MovingModel[]
	shadow Grid<u8>   # the ground's shadow map, 8 x 8 texels a cube (255: no ground)

pub fn zonePath(name str) str:
	"{preparedDir}/{name}.zone"

# the map `name` read from its prepared file, none when it is missing or of another version
pub fn openZone(name str) Zone?:
	file = try readPrepared(zonePath(name))
	head = try ZoneHead.fromBytes(file.headOf())
	models = []
	for s in head.movingKinds:
		match rsm.parseRsm(file.bodyOf().bytesAt(s)):
			rsm: models.push(rsm)
			error: fail("a prepared model of {name}: {error}")
	moving = []
	for m in head.moving:
		placed = Mat4(1.0)
		for k in 0..16:
			placed.m[k] = m.placed[k]
		moving.push(MovingModel(model = m.kind, placed))
	gat = move head.gat
	normals = models.map(.normalsOf())
	rows = head.shadow.len / head.shadowWidth if head.shadowWidth > 0 else 0
	shadow = Grid(
		head.shadowWidth.max(0),
		rows,
		cells = file.bodyOf().bytesAt(head.shadow).copy()
	)
	Zone(head, gat, file, models, normals, moving, shadow)

fn bytesOf(s str):
	out = []
	out.extend(s.bytes())
	out

fn need(i ragnarok.Install, path u8[]):
	key = grf.grfKey(path)
	i.installRead(key) ?? fail("{key} is not in the install")

# the texture at data\texture\{name}, decoded by its extension (a grey texel when it is missing)
fn decodeTexture(i ragnarok.Install, name u8[]):
	path = bytesOf("data\\texture\\")
	path.extend(name)
	key = grf.grfKey(path)
	bytes = i.installRead(key) ?? return missingTexture()
	decoded = ragnarok.decodeTga(bytes) if key.endsWith(".tga")
		else jpeg.decodeJpeg(bytes) if key.endsWith(".jpg")
		else ragnarok.decodeBmp(bytes)
	match move decoded:
		img:
			keyed = move img
			if not key.endsWith(".tga"):
				keyed.keyMagenta()
			keyed
		error:
			eprint("{key}: {error}")
			missingTexture()

# a grey texel, for a texture the install does not have
fn missingTexture():
	grey u8 = 160
	image.fromBytes(1, 1, [grey, grey, grey, 255])

# the scene's textures as they are found, each kept once, written into the body
type TextureTable:
	textures PreparedTexture[]
	byKey {str: i64}

fn textureOf(mut t TextureTable, mut body u8[], i ragnarok.Install, name u8[]):
	key = grf.grfKey(name)
	if t.byKey.get(key) is k: return k
	img = i.decodeTexture(name)
	at = t.textures.len
	t.textures.push(appendTexture(body, img, img.isPartlyTransparent()))
	t.byKey[key] = at
	at

# a model file at the key with its bytes, none (and a note) when the install lacks it or it
# cannot be read
fn readModel(i ragnarok.Install, key str) (rsm.Rsm, u8[])?:
	bytes = try i.installRead(key)
	match rsm.parseRsm(bytes):
		v: (v, bytes)
		error:
			eprint("{key}: {error}")
			none

# the shadow of the ground's lightmaps, 8 x 8 texels a cube (roBrowser's shadow map): none
# (255) where a cube has no ground
fn shadowMap(gnd gnd.Gnd):
	lw = gnd.lightmapWidth
	lh = gnd.lightmapHeight
	per = lw * lh
	out = Grid<u8>(gnd.cubes.width * 8, gnd.cubes.height * 8, fill = 255)
	for y in 0..gnd.cubes.height:
		for x in 0..gnd.cubes.width:
			up = gnd.cube(x, y).up
			if up < 0: continue
			base = gnd.tiles[up].lightmap * per * 4
			for j in 0..8.min(lh):
				for i in 0..8.min(lw):
					out[x * 8 + i, y * 8 + j] = gnd.lightmaps[base + i + j * lw]
	out

# The map `name` (data\{name}.rsw and the files it names) read from the install, built and
# written to its prepared file.
pub fn prepareZone(i ragnarok.Install, name str):
	rsw, gnd, gat = i.prepareZoneLoad(name)
	water = gnd.water ?? rsw.water
	body = []
	table = TextureTable(textures = [], byKey = {})
	built, ground = i.prepareZoneGround(rsw, gnd, water, body, table)
	modelCount, statics, movingKinds, movingTextures, moving = i.prepareZoneModels(
		rsw,
		gnd,
		body,
		table
	)
	staticBatches = []
	for b in statics.batches:
		if not b.vertices.isEmpty:
			staticBatches.push(appendBatch(body, b.texture, b.twoSided, b.vertices))
	waterFrames = i.prepareZoneWater(water, built, body)
	waterSheet = body.append(built.water.rawBytes())
	lightmap = appendTexture(body, built.lightmaps, false)
	shadowMap = gnd.shadowMap()
	shadow = body.append(shadowMap.cells)
	head = ZoneHead(
		map = name.copy(),
		placedModels = rsw.models.len,
		modelKinds = modelCount,
		gat,
		sun = rsw.sun,
		water,
		textures = table.textures,
		ground, statics = staticBatches, waterSheet, lightmap, waterFrames, movingKinds,
		movingTextures, moving, shadowWidth = shadowMap.width, shadow)
	writePrepared(zonePath(name), head.toBytes(), body) ??
		fail("cannot write {zonePath(name)}: {error}")

fn prepareZoneLoad(
	i ragnarok.Install,
	name str
):
	rsw = rsw.parseRsw(i.need(bytesOf("data\\{name}.rsw"))) ??
		fail("{name}.rsw: {error}")
	gndPath = bytesOf("data\\")
	gndPath.extend(rsw.gnd)
	gnd = gnd.parseGnd(i.need(gndPath)) ?? fail("{name}'s GND: {error}")
	gatPath = bytesOf("data\\")
	gatPath.extend(rsw.gat)
	gat = gat.parseGat(i.need(gatPath)) ?? fail("{name}'s GAT: {error}")
	(rsw, gnd, gat)

fn prepareZoneGround(
	i ragnarok.Install,
	rsw rsw.Rsw,
	gnd gnd.Gnd,
	water rsw.Water,
	mut body u8[],
	mut table TextureTable
):
	groundTextures = []
	for t in gnd.textures:
		groundTextures.push(table.textureOf(body, i, t))
	built = gnd.buildGround(rsw.sun, water, groundTextures)
	ground = []
	for k in 0..built.byTexture.len:
		if not built.byTexture[k].isEmpty:
			ground.push(appendBatch(body, groundTextures[k], true, built.byTexture[k]))
	(built, ground)

fn prepareZoneModels(
	i ragnarok.Install,
	rsw rsw.Rsw,
	gnd gnd.Gnd,
	mut body u8[],
	mut table TextureTable
):
	# the models: each file read once, each placement baked (or kept to move)
	toward = rsw.sun.sunDirection()
	models = []
	normals = []
	modelTextures = []
	modelFiles = []
	poses = []
	byFile {str: i64} = {}
	statics = ModelBatches()
	movingKinds = []
	movingTextures = []
	movingKindOf {i64: i64} = {}
	moving = []
	for m in rsw.models:
		path = bytesOf("data\\model\\")
		path.extend(m.file)
		key = grf.grfKey(path)
		k = -1
		match byFile.get(key):
			found: k = found
			none:
				rsm, bytes = i.readModel(key) ?? continue
				ids = []
				for t in rsm.textures:
					ids.push(table.textureOf(body, i, t))
				k = models.len
				poses.push(rsm.poseNodes(0))
				normals.push(rsm.normalsOf())
				models.push(rsm)
				modelTextures.push(ids)
				modelFiles.push(bytes)
				byFile[key] = k
		placed = models[k].placement(poses[k], m, gnd.cubes.width, gnd.cubes.height)
		if models[k].isAnimated():
			if k not in movingKindOf:
				movingKindOf[k] = movingKinds.len
				movingKinds.push(body.append(modelFiles[k]))
				movingTextures.push(move modelTextures[k])
			m16 = []
			for v in placed.m:
				m16.push(v)
			moving.push(PreparedMoving(kind = movingKindOf.get(k) ?? 0, placed = m16))
		else:
			bakeModel(
				models[k],
				normals[k],
				poses[k],
				placed,
				modelTextures[k],
				rsw.sun,
				toward,
				statics
			)
	(models.len, statics, movingKinds, movingTextures, moving)

fn prepareZoneWater(
	i ragnarok.Install,
	water rsw.Water,
	built GroundMesh,
	mut body u8[]
):
	# the water's 32 frames: data\texture\워터\water{kind}{frame}.jpg
	waterFrames = []
	if not built.water.isEmpty:
		for f in 0..32:
			frame = "0{f}" if f < 10 else "{f}"
			waterFrames.push(
				appendTexture(
					body,
					i.decodeTexture(ragnarok.cp949Path("워터\\water{water.kind}{frame}.jpg")),
					false
				)
			)
	waterFrames

# How lit the ground is where a figure stands at (x, y) in cells (its cell's centre at + 0.5),
# as roBrowser shades a figure: the shadow map averaged over the 6 x 6 texels about it, 1 where
# there is no ground.
pub fn shadowAt(z Zone, x f32, y f32) f32:
	if z.shadow.width <= 0: return 1.0
	px = i64((x / 2.0).floor()) * 8 +
		((i64(x.floor()) & 1) * 4 + i64(((x - x.floor()) * 4.0).floor())).min(6)
	py = i64((y / 2.0).floor()) * 8 +
		((i64(y.floor()) & 1) * 4 + i64(((y - y.floor()) * 4.0).floor())).min(6)
	sum = 0
	for dy in -3..3:
		for dx in -3..3:
			tx = px + dx
			ty = py + dy
			sum += 255 if tx < 0 or ty < 0 or tx >= z.shadow.width or ty >= z.shadow.height
				else z.shadow[tx, ty]
	f32(sum) / 36.0 / 255.0
