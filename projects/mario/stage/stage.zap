# A level made ready to draw from what the cartridge holds: its area's geometry, one mesh for
# each model something places (trees, signs, doors, objects), the places themselves, the sky's
# picture and the water's surfaces. Meshes are in their model's space; an instance places one.

import game
import image
import n64

pub type Instance:
	mesh i64
	transform Mat4

# a placed model that is not always drawn: its behavior hides it when Mario is far
pub type Thing:
	mesh i64
	transform Mat4
	x f32
	y f32
	z f32
	behavior n64.Behavior
	shadow n64.GeoShadow   # kind -1: none

# a model kept as a tree of parts: its nodes and each node's mesh (-1 none)
pub type Rig:
	nodes n64.RigNode[]
	meshes i64[]

# a placed model that moves: its rig posed by its animation, from frame `first`
pub type Puppet:
	rig i64
	transform Mat4
	x f32
	y f32
	z f32
	behavior n64.Behavior
	animation n64.Animation
	first i64
	shadow n64.GeoShadow

# a billboard batch drawn once for every place it stands (the anchors: x, y, z and a spare each)
pub type Billboards:
	batch n64.Batch
	anchors f32[]

pub type Stage:
	textures image.Image[]
	meshes n64.Batch[,]
	instances Instance[]
	still n64.Batch[]   # everything that does not move, in the world's space, a batch a material
	things Thing[]
	puppets Puppet[]
	rigs Rig[]
	billboards Billboards[]
	collision n64.Collision
	water WaterQuad[]
	waterfall n64.MovTris
	waterMaterial n64.Material   # the quads' (transparent)
	waterfallMaterial n64.Material   # the waterfall's (transparent, drawn after)
	sky i64   # the sky's picture: an index of textures, -1 none
	hud image.Image[]   # the HUD's glyphs: digits 0..9, then x, Mario's head, star, camera, Lakitu
	rig n64.RigNode[]   # Mario's model as a tree of parts
	rigMeshes i64[]   # per node: its mesh, -1 none
	marioShadow n64.GeoShadow
	shadowMaterial n64.Material   # the round shadow's (its layer set where it is drawn)
	ground game.Surfaces
	actors game.Object[]   # the placed objects Mario can meet, in the order they spawn

marioModel = 1

# the sky's picture: 8 x 8 tiles of 32 x 32 texels, laid out by a table of 80 tile addresses
# (8 rows of 10, the last two columns repeating the first) at the end of segment 0x0A
skyTile = 32

# the water's texture in segment 2
waterTexture = 0x0201_4AB8
# the round shadow's quarter (IA8, 16 x 16, mirrored both ways) in segment 2
shadowTexture = 0x0201_20B8
# Castle Grounds' moving textures in the US cartridge (moving_texture.c's tables live in the
# game's code): the water quads by water box, the waterfall's triangles and their display list
castleGroundsWater = 0x0701_1738
castleGroundsWaterfall = 0x0701_1750
castleGroundsWaterfallDl = 0x0701_17E8
waterfallVertices = 15
pub waterfallAlpha = 0xB4

# a moving water quad at its box's height
pub type WaterQuad:
	quad n64.MovQuad
	y f32

pub fn buildStage(rom n64.Rom, lv n64.Level) Stage:
	f = n64.newF3d()
	meshes = []
	instances = []
	# the area's own geometry
	area = lv.segments.walkGeo(lv.areaGeo, Mat4(1.0))
	for d in area.draws:
		f.convertList(lv.segments, d.dl, d.layer, d.transform, d.billboard)
	meshes.push(f.takeBatches())
	instances.push(Instance(mesh = 0, transform = Mat4(1.0)))
	col, ground, placed0, actors = lv.buildStagePlaced(rom)
	placed = placed0
	things, puppets, rigs = f.buildStageObjects(lv, placed, meshes, instances)
	rig, rigMeshes, marioShadow = f.buildStageMario(lv, meshes)
	waterMaterial, waterfallMaterial, shadowMaterial = f.buildStageMaterials(lv)
	water = lv.segments.waterQuads(col)
	waterfall = n64.readMovTris(
		lv.segments,
		castleGroundsWaterfall,
		waterfallVertices,
		castleGroundsWaterfallDl
	)
	sky = f.skyPicture(lv.segments)
	hud = lv.segments.hudGlyphs()
	still, billboards = bake(meshes, instances)
	Stage(
		textures = f.out.textures,
		meshes,
		instances,
		still,
		things,
		puppets,
		rigs,
		billboards,
		collision = col,
		water,
		waterfall, waterMaterial, waterfallMaterial, sky, hud, rig,
		rigMeshes, marioShadow, shadowMaterial, ground, actors)

fn buildStagePlaced(lv n64.Level, rom n64.Rom) (
	n64.Collision,
	game.Surfaces,
	PlacedObject[],
	game.Object[]
):
	# what the level places: special objects (with its ground), macro objects, objects
	col = lv.segments.readCollision(rom, lv.terrain)
	# (a model whose behavior faces the camera is read as a billboard about its origin; one it
	# animates as a rig; one it hides when Mario is far is drawn on its own)
	ground = col.buildSurfaces()
	placed = []
	for p in col.specials:
		placeObject(
			placed,
			lv.segments,
			ground,
			p.model,
			p.behavior,
			at(p.x, p.y, p.z),
			Vec3(0.0, f32(p.yaw), 0.0)
		)
	if lv.macros >= 0:
		for p in lv.segments.readMacroObjects(rom, lv.macros):
			placeObject(
				placed,
				lv.segments,
				ground,
				p.model,
				p.behavior,
				at(p.x, p.y, p.z),
				Vec3(0.0, f32(p.yaw), 0.0)
			)
	# (the level script's objects are each put at the head of the area's list: they spawn, and
	# first run, last one first)
	for i in 0..lv.objects.len:
		o = lv.objects[len - 1 - i]
		placeObject(
			placed,
			lv.segments,
			ground,
			o.model,
			o.behavior,
			at(o.x, o.y, o.z),
			at(o.rx, o.ry, o.rz)
		)
	actors = []
	for PlacedObject(_, _, b, p) in placed:
		if b.gameObjectOf(p) is o:
			actors.push(o)
	(col, ground, placed, actors)

fn buildStageObjects(
	mut f n64.F3d,
	lv n64.Level,
	mut placed PlacedObject[],
	mut meshes n64.Batch[,],
	mut instances Instance[]
):
	meshOf {i64: i64} = {}
	rigOf {i64: i64} = {}
	things = []
	puppets = []
	rigs = []
	random = game.levelRandom()
	for k in 0..placed.len:
		PlacedObject(model, transform0, _, p) = placed[k]
		if model <= 0 or placed[k].behavior.hidden: continue
		# what the object's own code sets up, in the order the objects first run
		start = placed[k].behavior.startObject(random)
		behavior = move placed[k].behavior
		if start.animation >= 0:
			behavior.animation = start.animation
		if start.shownWithin >= 0.0:
			behavior.flags |= n64.flagComputeDistance
			behavior.drawingDistance = start.shownWithin
		transform = transform0
		transform.m[13] += behavior.graphLift
		def = lv.modelNamed(model) ?? continue
		shadow = (lv.segments.geoShadow(def.geo) ?? noShadow()) if def.geo >= 0 else noShadow()
		if behavior.animations >= 0 and def.geo >= 0:
			r = rigOf.get(model) ?? -1
			if r < 0:
				rigs.push(f.rigOfModel(lv, def.geo, meshes, false))
				r = rigs.len - 1
				rigOf[model] = r
			if n64.readObjectAnimation(
				lv.segments,
				behavior.animations,
				behavior.animation,
				animatedParts(rigs[r].nodes)
			) is a:
					# ANIMATE sets the frame before the start (it steps forward on the first frame drawn); its code may set another
				first = start.frame - a.startFrame if start.frame >= 0 else -1
				puppets.push(Puppet(
					rig = r,
					transform,
					x = p.x,
					y = p.y,
					z = p.z,
					behavior = move behavior,
					animation = a,
					first,
					shadow))
				continue
		key = model * 2 + (1 if behavior.facesCamera else 0)
		mesh = meshOf.get(key) ?? -2
		if mesh == -2:
			mesh = f.modelMesh(lv, model, behavior.facesCamera)
			if mesh >= 0:
				mesh = meshes.len
				meshes.push(f.takeBatches())
			meshOf[key] = mesh
		if mesh < 0: continue
		if behavior.hidesFar() or shadow.kind >= 0:
			things.push(Thing(mesh, transform, x = p.x, y = p.y, z = p.z, behavior, shadow))
		else:
			instances.push((mesh, transform))
	(things, puppets, rigs)

fn buildStageMario(
	mut f n64.F3d,
	lv n64.Level,
	mut meshes n64.Batch[,]
):
	# Mario (model 1); the wing cap's wings (under the only translate-rotate nodes) show only when
	# it is worn
	rig = []
	rigMeshes = []
	marioShadow = noShadow()
	if lv.modelNamed(marioModel) is def:
		marioShadow = lv.segments.geoShadow(def.geo) ?? noShadow()
		mario = f.rigOfModel(lv, def.geo, meshes, true)
		rig = mario.nodes
		rigMeshes = mario.meshes
	(rig, rigMeshes, marioShadow)

fn buildStageMaterials(mut f n64.F3d, lv n64.Level):
	# the water's moving surfaces, then the sky's picture
	texture = n64.decodeTexels(
		lv.segments.banks[n64.segmentOf(waterTexture)],
		n64.offsetOf(waterTexture),
		32,
		32,
		n64.fmtRgba,
		2,
		[],
		0
	)
	f.out.textures.push(texture)
	waterMaterial = movingMaterial(f.out.textures.len - 1, 7)   # the water regions: transparent, after the waterfall
	waterfallMaterial = movingMaterial(f.out.textures.len - 1, 7)
	shadowTexels = n64.decodeTexels(
		lv.segments.banks[n64.segmentOf(shadowTexture)],
		n64.offsetOf(shadowTexture),
		16,
		16,
		n64.fmtIa,
		1,
		[],
		0
	)
	f.out.textures.push(shadowTexels)
	shadowMaterial = movingMaterial(f.out.textures.len - 1, 6)
	shadowMaterial.wrapS = 1
	shadowMaterial.wrapT = 1
	(waterMaterial, waterfallMaterial, shadowMaterial)

fn noShadow():
	n64.GeoShadow(kind = -1, solidity = 0, scale = 0)

# What does not move made ready to draw in few calls: each batch of every placed mesh moved
# into the world's space and joined to the others of its material, and each billboard batch
# kept once with the places it stands at.
fn bake(meshes n64.Batch[,], instances Instance[]):
	still = []
	stillOf {n64.Material: i64} = {}
	boards = []
	boardOf {i64: i64} = {}   # mesh * 1000 + batch -> its billboards
	n = n64.vertexFloats
	for inst in instances:
		t = inst.transform
		for bi in 0..meshes[inst.mesh].len:
			b = meshes[inst.mesh][bi]
			if b.material.billboard:
				key = inst.mesh * 1000 + bi
				at = boardOf.get(key) ?? -1
				if at < 0:
					boards.push(Billboards(batch = b.copy(), anchors = []))
					at = boards.len - 1
					boardOf[key] = at
				p = t.project(
					Vec3(
						f32(b.material.anchorX),
						f32(b.material.anchorY),
						f32(b.material.anchorZ)
					)
				)
				boards[at].anchors.extend([p.x, p.y, p.z, 0.0, 0.0])
				continue
			at = stillOf.get(b.material) ?? -1
			if at < 0:
				still.push(n64.Batch(material = b.material, vertices = []))
				at = still.len - 1
				stillOf[b.material] = at
			out = mut ref still[at].vertices
			for i in 0..b.vertices.len / n:
				k = i * n
				p = t.project(Vec3(b.vertices, k))
				out.push(p.x)
				out.push(p.y)
				out.push(p.z)
				if b.material.lit:
					# a normal turned with the place (the places are turned and moved, not stretched)
					nx, ny, nz = b.vertices[k + 3], b.vertices[k + 4], b.vertices[k + 5]
					out.push(t.m[0] * nx + t.m[4] * ny + t.m[8] * nz)
					out.push(t.m[1] * nx + t.m[5] * ny + t.m[9] * nz)
					out.push(t.m[2] * nx + t.m[6] * ny + t.m[10] * nz)
				else:
					out.push(b.vertices[k + 3])
					out.push(b.vertices[k + 4])
					out.push(b.vertices[k + 5])
				for j in 6..n:
					out.push(b.vertices[k + j])
	(still, boards)

# An object placed as its behavior sets it up: raised or lowered, set on the floor below, its
# children spawned where it was put (before it moved).
# an object put in the level: its model, its transform, its behavior and its place
type PlacedObject:
	model i64
	transform Mat4
	behavior n64.Behavior
	at Vec3

fn placeObject(
	mut placed PlacedObject[],
	s n64.Segments,
	ground game.Surfaces,
	model i64,
	behavior i64,
	p0 Vec3,
	turn Vec3):
		b = s.readBehavior(behavior)
		for child in b.children:
			placeObject(placed, s, ground, child.model, child.behavior, p0, turn)
		p = p0
		p.y += b.raise
		if b.dropsToFloor:
			floor, _ = ground.findFloor(p.x, p.y, p.z)
			if floor > game.floorLowerLimit:
				p.y = floor
		placed.push((model, p.rotateZxyTranslate(turn), b, p))

fn at(x i64, y i64, z i64):
	Vec3(f32(x), f32(y), f32(z))

# A model kept as a tree of parts: each part's mesh in its own space, the lists read in the order
# the game draws them (the state one leaves is the next one's). `noWings` leaves out what is under
# translate-rotate nodes (Mario's wing cap).
fn rigOfModel(
	mut f n64.F3d,
	lv n64.Level,
	geo i64,
	mut meshes n64.Batch[,],
	noWings bool
):
	nodes = lv.segments.walkRig(geo)
	out = []
	fresh = true
	hidden bool[] = []
	for node in nodes:
		hidden.push(noWings and (node.kind == 0x10 or node.parent >= 0 and hidden[node.parent]))
		if node.dl == 0 or hidden[len - 1]:
			out.push(-1)
			continue
		if fresh:
			f.convertList(lv.segments, node.dl, node.layer, Mat4(1.0), node.billboard)
			fresh = false
		else:
			f.continueList(lv.segments, node.dl, node.layer, Mat4(1.0), node.billboard)
		out.push(meshes.len)
		meshes.push(f.takeBatches())
	Rig(nodes, meshes = out)

# the animated parts of a rig (what its animations move)
fn animatedParts(nodes n64.RigNode[]):
	nodes.count(.animated)

# the place of an object (degrees turned about x, y, z)
fn place(x i64, y i64, z i64, rx i64, ry i64, rz i64):
	n64.rotateZxyTranslate(
		Vec3(f32(x), f32(y), f32(z)),
		Vec3(f32(rx), f32(ry), f32(rz))
	)

# a model of the level's table read into f's batches: 0 when it has any, -1 when it has none
fn modelMesh(mut f n64.F3d, lv n64.Level, model i64, facing bool):
	def = lv.modelNamed(model) ?? return -1
	if def.geo >= 0:
		if not lv.segments.holds(def.geo, 4): return -1
		scene = lv.segments.walkGeo(def.geo, Mat4(1.0))
		for d in scene.draws:
			f.convertList(lv.segments, d.dl, d.layer, d.transform, d.billboard or facing)
	elif def.dl >= 0:
		f.convertList(lv.segments, def.dl, def.layer, Mat4(1.0), facing)
	0 if not f.out.batches.isEmpty else -1

# The HUD's glyphs (16 x 16 RGBA16 each) from segment 2's tables: the font's (main_hud_lut: its
# digits, then at 50 the x, 52 Mario's head, 53 the star) and the camera's (main_hud_camera_lut:
# the camera, then at 2 Lakitu).
hudFont = 0x0200_7700
hudCamera = 0x0200_7C7C

pub hudMultiply = 10
pub hudMarioHead = 11
pub hudStar = 12
pub hudCameraIcon = 13
pub hudLakitu = 14

fn hudGlyphs(s n64.Segments):
	addresses = (0..10).map(s.u32At(hudFont + it * 4))
	for k in [50, 52, 53]:
		addresses.push(s.u32At(hudFont + k * 4))
	addresses.push(s.u32At(hudCamera))
	addresses.push(s.u32At(hudCamera + 8))
	addresses.map(a:
		n64.decodeTexels(s.banks[n64.segmentOf(a)], n64.offsetOf(a), 16, 16, n64.fmtRgba, 2, [], 0)
	)

# the material of a moving texture: (texel - 0) * shade + 0 for color and alpha, smoothed, repeating
fn movingMaterial(texture i64, layer i64):
	codes = n64.selTexel | n64.selZero << 8 | n64.selShade << 16 | n64.selZero << 24
	n64.Material(
		texture,
		layer,
		cullBack = false,
		lit = false,
		colorSel = codes,
		alphaSel = codes,
		prim = -1,
		env = -1,
		wrapS = 0,
		wrapT = 0,
		smooth = true, ambient = 0, diffuse = 0, direction = 0, billboard = false, anchorX = 0, anchorY = 0, anchorZ = 0)

# The level's water quads, each at the height of the water box of its id: the collection is
# {id, its quad list} pairs ending with id -1.
fn waterQuads(s n64.Segments, col n64.Collision):
	out = []
	at = castleGroundsWater
	while s.s16At(at) >= 0:
		id = s.s16At(at)
		for w in col.water:
			if w.id == id:
				for q in s.readMovQuads(s.u32At(at + 4)):
					out.push(WaterQuad(quad = q, y = f32(w.y)))
		at += 8
	out

# The sky's picture made of its tiles (an index of f's textures), -1 when segment 0x0A holds none.
fn skyPicture(mut f n64.F3d, s n64.Segments):
	bank = s.banks[0x0A]
	if bank.len < 320: return -1
	table = bank.len - 320
	size = skyTile * 8
	picture = image.Image(size, size, fill = image.Rgba8(0, 0, 0, 0))
	for row in 0..8:
		for colIndex in 0..8:
			tile = n64.offsetOf(bank.u32be(table + (row * 10 + colIndex) * 4))
			texels = n64.decodeTexels(bank, tile, skyTile, skyTile, n64.fmtRgba, 2, [], 0)
			picture.paste(texels, colIndex * skyTile, row * skyTile)
	f.out.textures.push(picture)
	f.out.textures.len - 1
