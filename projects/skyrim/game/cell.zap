# A cell's references made into what the GPU draws: each model's parts read once (their tangents
# the file's, else computed from their uvs), placed by each reference that shows it into one list
# of vertices (y up), their indices kept apart by how they are drawn; its effects and particle
# systems, which run as time goes; the lights the references place, and the cell's ambient,
# directional light and fog.

import engine
import math
import skyrim
import skyrim.esm
import skyrim.nif
import game.stealth
import world
import world.shaders

# a part's (or a particle system's) textures in the cell's, and its effect in the cell's (-1 none)
pub type PartLook:
	diffuse i64
	normalMap i64   # an effect's palette
	effect i64
	look i64 = -1   # a lit part's in the cell's looks

# a model's parts ready to place: their normals (made when the model has none), tangents and
# looks; its particle systems and theirs
pub type ModelParts:
	parts nif.Part[] = []
	normals Vec3[,] = []
	tangents Vec4[,] = []
	looks PartLook[] = []
	systems nif.Particles[] = []
	systemLooks PartLook[] = []
	addOns nif.AddOn[] = []   # where the game attaches its ADDN models
	sequences nif.Sequence[] = []   # a NiControllerManager's, with the nodes they move
	frames nif.NodeFrame[] = []   # those nodes at rest
	partFrames i64[] = []   # by part: the frame it hangs from, -1 for none

pub type CellBuild:
	vertices shaders.CellVertex[] = []
	byState u32[,]   # state (kindNumber * 2, + 1 two-sided) -> its indices
	billboards shaders.Billboard[] = []
	effects nif.Effect[] = []
	surfaces nif.LitMaterial?[] = []
	emitters world.Emitter[] = []
	low Vec3 = Vec3(1.0e9, 1.0e9, 1.0e9)
	high Vec3 = Vec3(-1.0e9, -1.0e9, -1.0e9)
	parts i64 = 0

pub kinds world.Kind[] = [.Opaque, .Tested, .Blended, .Added]

pub fn newCellBuild() CellBuild:
	byState u32[,] = []
	loop kinds.len * 2:
		byState.push([])
	CellBuild(byState)

fn kindNumber(k world.Kind):
	match k:
		Opaque: 0
		Tested: 1
		Blended: 2
		Added: 3

# Skyrim's Z up made the engine's Y up: x stays, z goes up, y goes into the screen
pub yUp = Mat4.rotationX(-pi / 2.0)

# where a reference puts its model: scaled, turned as the game turns (clockwise, about z first,
# then y, then x), moved, then made y up
pub fn placementOf(r esm.Ref) Mat4:
	yUp @ Mat4.translation(r.position) @ Mat4.rotationX(-r.rotation.x) @
		Mat4.rotationY(-r.rotation.y) @ Mat4.rotationZ(-r.rotation.z) @
		Mat4.scaling(Vec3(r.scale, r.scale, r.scale))

# the textures (an effect's palette where a lit part's normal map is) and the effect of a part or
# a particle system, its effect added to the cell's
fn lookOf(
	i skyrim.Install,
	diffusePath str,
	normalPath str,
	effect nif.Effect?,
	mut table TextureTable,
	mut effects nif.Effect[],
	mut body u8[]
):
	diffuse = table.textureIndex(i, diffusePath, flatDiffuse, body)
	second = normalPath.copy()
	index = -1
	if effect is e:
		second = e.palette.copy()
		effects.push(e.copy())
		index = effects.len - 1
	PartLook(diffuse, normalMap = table.textureIndex(i, second, flatNormal, body), effect = index)

# the model's parts the game draws (a skinned one posed on its own bones, else an actor's and
# left out) and its particle systems (those of an effect), with their looks
pub fn modelPartsOf(
	i skyrim.Install,
	key str,
	mut table TextureTable,
	mut effects nif.Effect[],
	mut surfaces nif.LitMaterial?[],
	mut body u8[]
) ModelParts:
	out = ModelParts()
	model = match i.readModel(key):
		m: m
		error:
			eprint("skipped: {error}")
			return out
	drawn = model.drawModel()
	out.addOns = drawn.addOns.copy()
	frameOf {i64: i64} = {}
	out.sequences = model.sequencesOf()
	moved = []
	for q in out.sequences:
		for t in q.tracks:
			moved.push(t.node.copy())
	for b in 0..model.blocks.len:
		if model.blocks[b] is NodeBlock and model.blockName(b) in moved:
			frameOf[b] = out.frames.len
			out.frames.push(model.frameOf(drawn, b))
	for s in drawn.systems:
		e = (s.effect ?? continue).copy()
		# the color modifier's color is a particle's vertex color
		e.vertexColors = true
		e.vertexAlpha = true
		out.systemLooks.push(i.lookOf(s.diffuse, "", e, table, effects, body))
		out.systems.push(s.copy())
	for skinned in drawn.parts:
		if skinned.positions.isEmpty: continue
		p = skinned.copy() if not skinned.skinned
			else model.posedInPlace(drawn, skinned) ?? continue
		indices = p.indices.map(i64(it))
		whole = p.normals.len == p.positions.len
		normals = p.normals.copy() if whole else engine.vertexNormals(p.positions, indices)
		mapped = p.uvs.len == p.positions.len
		uvs = p.uvs.copy() if mapped else fill(p.positions.len, Vec2(0.0, 0.0))
		stored = p.storedTangents()
		kept = whole and stored.len == p.positions.len
		tangents = stored if kept else engine.vertexTangents(p.positions, normals, uvs, indices)
		out.tangents.push(tangents)
		out.normals.push(normals)
		look = i.lookOf(p.diffuse, p.normal, p.effect, table, effects, body)
		if p.effect == none:
			look.look = surfaces.len
			if p.lit is l: i.prepareLitMaps(l, table, body)
			surfaces.push(p.lit.copy())
		out.looks.push(look)
		out.partFrames.push(frameOf.get(model.controlledAncestor(skinned, moved) ?? -1) ?? -1)
		out.parts.push(p)
	out

# The maps a lit material's look may read laid in the table, whatever its flags turn on (its
# glow, back light and reflection mask slots, its reflected cube): a renderer that reads the
# flags differently needs no new prepare.
fn prepareLitMaps(i skyrim.Install, l nif.LitMaterial, mut table TextureTable, mut body u8[]):
	for k in [nif.slotGlow, nif.slotEnvironmentMask, nif.slotSpecular]:
		table.textureIndex(i, l.slotPath(k), -1, body)
	_ = table.cubeIndex(i, l.slotPath(nif.slotEnvironment), -1, body)

# the maps a shading reads laid in the table, then its look (an actor's, taken when prepared)
pub fn preparedLook(
	i skyrim.Install,
	s nif.Shading,
	specularStrength f32,
	glossiness f32,
	mut table TextureTable,
	mut body u8[]
) shaders.Look:
	for path in [
		s.glowMap.copy(),
		s.lightingMap.copy(),
		s.backMap.copy(),
		s.environmentMask.copy()
	]:
		table.textureIndex(i, path, -1, body)
	table.cubeIndex(i, s.environment, -1, body)
	s.lookOf(specularStrength, glossiness, table.byKey)

# how a part (or a particle system) of this alpha is drawn, and the alpha under which its texels
# are dropped
fn kindOf(a nif.Alpha) (world.Kind, f32):
	cutout f32 = f32(a.threshold) / 255.0 if a.test else 0.0
	# Gamebryo's destination factor 0 is one: light added
	if a.blend: return (.Added if a.destination == 0 else .Blended, cutout)
	if a.test: return (.Tested, cutout)
	(.Opaque, 0.0)

# an effect's material as the pixel stage reads it (shaders.CellVertex)
fn effectMaterial(effect i64, kind world.Kind, cutout f32):
	Vec4(f32(effect), 0.0, cutout, 2.0 if kind == .Added else 1.0)

# The billboard a part placed by `place` turns with, added to the cell's, and what takes its
# vertices from the model's space to its node's, scaled as the node is placed.
fn addBillboard(mut b CellBuild, bb nif.Billboard, place Mat4):
	node = place @ bb.pivot
	axis = Vec3(0.0, 0.0, 1.0) if bb.mode == nif.bsRotateAboutUp else Vec3(0.0, 1.0, 0.0)
	b.billboards.push(shaders.Billboard(
		pivot = node.applyPoint(Vec3(0.0, 0.0, 0.0)).withW(f32(bb.mode)),
		axis = node.applyDirection(axis).normalized().withW(0.0)
	))
	size = node.applyDirection(Vec3(1.0, 0.0, 0.0)).length()
	(i32(b.billboards.len - 1), Mat4.scaling(Vec3(size, size, size)) @ bb.pivot.inverseAffine())

fn addPart(mut b CellBuild, m ModelParts, k i64, place Mat4):
	p = m.parts[k]
	normals = m.normals[k]
	tangents = m.tangents[k]
	look = m.looks[k]
	kind, cutout = p.alpha.kindOf()
	state = kind.kindNumber() * 2 + (1 if p.twoSided else 0)
	first = b.vertices.len
	material = Vec4(f32(look.look), 0.0, cutout, 0.0)
	if look.effect >= 0: material = effectMaterial(look.effect, kind, cutout)
	# a billboard's vertices go along its node's axes, the rest into the cell
	billboard = -1
	toVertex = place
	if p.billboard is bb: billboard, toVertex = b.addBillboard(bb, place)
	for j, at in p.positions:
		world = place.applyPoint(at)
		b.low = b.low.min(world)
		b.high = b.high.max(world)
		t = tangents[j]
		tangent = toVertex.applyDirection(t.xyz).normalized().withW(t.w)
		color = p.colors[j] if j < p.colors.len else Vec4(1.0, 1.0, 1.0, 1.0)
		b.vertices.push(shaders.CellVertex(
			position = toVertex.applyPoint(at),
			normal = toVertex.applyDirection(normals[j]).normalized(),
			tangent,
			uv = p.uvs[j] if j < p.uvs.len else Vec2(0.0, 0.0),
			color,
			material,
			diffuse = i32(look.diffuse),
			normalMap = i32(look.normalMap),
			billboard))
	for index in p.indices:
		b.byState[state].push(u32(first) + index)
	b.parts += 1

# a model's parts and particle systems placed by a reference
pub fn placeModel(mut b CellBuild, m ModelParts, place Mat4):
	for k in 0..m.parts.len:
		b.addPart(m, k, place)
	for k, s in m.systems:
		look = m.systemLooks[k]
		kind, _ = s.alpha.kindOf()
		b.emitters.push(world.Emitter(
			system = s.copy(),
			place,
			effect = look.effect,
			diffuse = i32(look.diffuse),
			palette = i32(look.normalMap),
			added = kind == .Added
		))

# the indices laid one run after the other, the opaque first, and their runs
pub fn runsOf(b CellBuild) (u32[], world.Run[]):
	indices = []
	runs = []
	for state, list in b.byState:
		if list.isEmpty: continue
		runs.push(world.Run(
			kind = kinds[state / 2],
			twoSided = state % 2 == 1,
			first = indices.len,
			count = list.len
		))
		indices.extend(list)
	(indices, runs)

fn colorOf(c esm.Color):
	Vec3(f32(c.r), f32(c.g), f32(c.b)) / 255.0

# LIGH's flags: shining only when a script turns it on; taking light away; flickering; casting
# shadows (a spotlight's, a hemisphere's, every way's)
lightOffByDefault = 0x20
lightNegative = 0x4
lightFlickers = 0x8
lightShadows = 0x1C00

# the light a base record gives at `at` (y up), its radius and fade moved by a reference's offsets
# and its scale; none when it starts off
pub fn lightAt(
	l esm.Light,
	at Vec3,
	radiusOffset f32,
	fadeOffset f32,
	scale f32
) shaders.PointLight?:
	if (l.flags & lightOffByDefault) != 0: return none
	sign f32 = -1.0 if (l.flags & lightNegative) != 0 else 1.0
	fade = (l.fade if l.fade > 0.0 else 1.0) + fadeOffset
	shaders.PointLight(
		place = at.withW((f32(l.radius) + radiusOffset) * scale),
		color = (l.color.colorOf() * (fade * sign)).withW(1.0),
		flicker = Vec4(
			l.flickerPeriod if (l.flags & lightFlickers) != 0 else 0.0,
			l.flickerIntensity,
			l.flickerMovement,
			1.0 if (l.flags & lightShadows) != 0 else 0.0)
	)

# the light a reference places, none when it starts off
pub fn pointLightOf(r esm.Ref, l esm.Light) shaders.PointLight?:
	l.lightAt(yUp.applyPoint(r.position), r.radiusOffset, r.fadeOffset, r.scale)

fn toYUp(v Vec3):
	Vec3(v.x, v.z, -v.y)

# Where the cell's directional light comes from: its rotations give the way it shines, XY a
# heading counterclockwise from +x and Z a rise over the level (measured against compare.zap's
# poses: the inn's 0 and 150 light the surfaces facing east and down).
fn sunTowardOf(l esm.Lighting):
	xy = f32(l.directionalRotationXY).radians()
	z = f32(l.directionalRotationZ).radians()
	Vec3(-xy.cos() * z.cos(), -xy.sin() * z.cos(), -z.sin()).toYUp()

# The light on the actors of a cell as detection reads it (game/stealth/sight.zap): its lights as
# lamps in the game's units (their color already scaled by their fade), and its ambient and
# directional light as the means of the colors, the highest component of the ambient the ambient's
# top.
pub fn detectionLighting(lights shaders.PointLight[], cell world.CellLight) stealth.Lighting:
	back = yUp.inverseAffine()
	lamps = lights.map(
		stealth.Lamp(
			at = back.applyPoint(Vec3(it.place.x, it.place.y, it.place.z)),
			radius = it.place.w,
			color = Vec3(it.color.x, it.color.y, it.color.z)
		)
	)
	total = Vec3(0.0, 0.0, 0.0)
	for a in cell.ambient: total += a
	around = total / f32(cell.ambient.len.max(1))
	sun = cell.sunColor
	stealth.Lighting(
		lamps,
		ambient = (around.x + around.y + around.z) / 3.0,
		directional = (sun.x + sun.y + sun.z) / 3.0,
		ambientMax = around.x.max(around.y).max(around.z)
	)

# the same for the cell as the plugin has it: the lights its references place and its lighting
pub fn detectionLightingOf(mut plugin esm.Esm, cell esm.Cell) stealth.Lighting:
	lights = []
	for r in cell.refs:
		if r.disabled: continue
		b = plugin.baseRecord(r.base) ?? continue
		if b.light is l:
			if r.pointLightOf(l) is light: lights.push(light)
	detectionLighting(lights, cellLightOf(plugin.cellLighting(cell)))

# the cell's ambient, directional light and fog; none of them without a lighting
pub fn cellLightOf(lighting esm.Lighting?) world.CellLight:
	l = lighting ?? return world.CellLight(
		ambient = fill(6, Vec3(0.3, 0.3, 0.3)),
		sunColor = Vec3(0.0, 0.0, 0.0),
		sunToward = Vec3(0.0, 1.0, 0.0),
		fogNearColor = Vec3(0.0, 0.0, 0.0),
		fogFarColor = Vec3(0.0, 0.0, 0.0),
		fogNear = 0.0,
		fogFar = 1.0e6,
		fogPower = 1.0,
		fogMax = 0.0
	)
	world.CellLight(
		# the cell's cube (DALC) in y up: +x -x, up (the plugin's +z) down, then the plugin's -y +y
		ambient = [0, 1, 4, 5, 3, 2].map(l.ambientCube[it].colorOf()),
		sunToward = l.sunTowardOf(),
		# a fade of 0 is full, as a light's (pointLightOf)
		sunColor = l.directional.colorOf() * (l.directionalFade if l.directionalFade > 0.0 else 1.0),
		fogNearColor = l.fogNearColor.colorOf(),
		fogFarColor = l.fogFarColor.colorOf(),
		fogNear = l.fogNear,
		fogFar = l.fogFar.max(l.fogNear + 1.0),
		fogPower = l.fogPower if l.fogPower > 0.0 else 1.0,
		fogMax = l.fogMax if l.fogMax > 0.0 else 1.0
	)

# The source the cell's references light their externally lit parts by (the first XEMI of them; the
# inn's all name the region WeatherPineForest): a light's color, or a region's weathers' effect
# lighting by the time of day, the scene choosing the weather (world.capturedWeather).
pub fn emittanceOf(mut plugin esm.Esm, cell esm.Cell) world.Emittance:
	source = cell.refs.find(.emittance != 0) ?? return world.noEmittance
	if plugin.baseRecord(source.emittance) is b and b.light is l:
		return world.Emittance(
			weathers = [],
			colors = fill(4, l.color.colorOf()),
			hours = world.noEmittance.hours
		)
	region = plugin.regionOf(source.emittance) ?? return world.noEmittance
	weathers = []
	colors = []
	for w in region.weathers:
		c = plugin.weatherColors(w.weather, esm.effectLightingColor) ?? continue
		weathers.push(w.weather)
		colors.extend(c.map(.colorOf()))
	if weathers.isEmpty: return world.noEmittance
	climateId = plugin.worldClimate(region.world) ?? return world.noEmittance
	c = plugin.climateOf(climateId) ?? return world.noEmittance
	extension = f32(plugin.gameSettings().get("fdaytimecolorextension") ?? 0.5)
	world.Emittance(weathers, colors, hours = c.colorHours(extension))
