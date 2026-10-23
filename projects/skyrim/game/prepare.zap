# Preparing a cell from the player's Skyrim install: its references, every model they show and
# the textures those name read once out of Skyrim.esm and the BSA archives, and written ready to
# draw into projects/skyrim/assets/prepared/<cell>/, which the game then only reads (see
# world/prepared.zap).

import skyrim
import skyrim.bsa
import skyrim.esm
import world
import world.shaders
import engine

# the cell the game opens in
pub defaultCell = "RiverwoodSleepingGiantInn"

# the place the camera starts looking at: the fire pit when the cell has one
fn isFocus(b esm.Base):
	b.editorId.lower().indexOf("firepit") != none

# the lights that cast shadows first, as the shader reads them
fn shadowsFirst(lights shaders.PointLight[]):
	out = lights.filter(.flicker.w > 0.5)
	out.extend(lights.filter(.flicker.w < 0.5))
	out

# the archive key of the model at `path` (under meshes/), its parts read into `models` once
fn loadModel(
	install skyrim.Install,
	path str,
	mut models {str: ModelParts},
	mut build CellBuild,
	mut table TextureTable,
	mut body u8[]
):
	key = bsa.bsaKey("meshes/{path}".bytes())
	if key not in models:
		models[key.copy()] = install.modelPartsOf(key, table, build.effects, build.surfaces, body)
	key

# the cell `id` prepared from the install in `dir`
pub fn prepareCell(dir str, id str):
	esm.requireRepoRoot()
	started = clockSeconds()
	install = skyrim.openInstall(dir) ?? fail
	esmPath = install.installPlugin("Skyrim.esm")
	plugin = esm.openEsm(esmPath.copy()) ?? fail
	cell = plugin.findCell(id) ?? fail("no interior cell {id} in {esmPath}")
	body = []
	table = newTextureTable(body)
	table.cache = newTextureCache()
	build = newCellBuild()
	models {str: ModelParts} = {}
	addOns = plugin.addOnModels()
	art = install.prepareSpellArt(plugin, models, build, table, body)
	lights = []
	movables = []
	focus Vec3? = none
	refs = 0
	for r in cell.refs:
		if r.disabled: continue
		b = plugin.baseRecord(r.base) ?? continue
		if focus == none and b.isFocus(): focus = yUp.applyPoint(r.position)
		if b.light is l:
			if r.pointLightOf(l) is light: lights.push(light)
		if b.model.isEmpty or b.marker: continue
		placement = r.placementOf()
		key = install.loadModel(b.model, models, build, table, body)
		if b.kind == "DOOR" and models[key].isMovable():
			movables.push(models[key].movableOf(r.formId, placement))
			refs += 1
			continue
		build.placeModel(models[key], placement)
		for a in models[key].addOns.copy():
			if addOns.get(a.index) is addOnPath:
				extra = install.loadModel(addOnPath, models, build, table, body)
				build.placeModel(models[extra], placement @ a.place)
		refs += 1
	middle = focus ?? (build.low + build.high) * 0.5
	cast = install.prepareCast(
		plugin,
		cell,
		yUp.inverseAffine().applyPoint(middle),
		table.cache,
		body
	)
	for m in movables:
		if cast.doors.findIndex(.refId == m.refId) is d: cast.doors[d].halfWidth = m.halfWidth
	indices, runs = build.runsOf()
	space = cell.imageSpace if cell.imageSpace != 0 else esm.defaultImageSpace
	vertices = body.append(build.vertices.rawBytes())
	indexSpan = body.append(indices.rawBytes())
	head = world.CellHead(
		cell = cell.editorId.copy(),
		refs,
		models = models.len,
		parts = build.parts,
		vertices,
		indices = indexSpan,
		runs,
		textures = table.textures.copy(),
		lights = shadowsFirst(lights),
		billboards = build.billboards.copy(),
		effects = build.effects.copy(),
		surfaces = build.surfaces.copy(),
		textureKeys = table.byKey.copy(),
		emitters = build.emitters.copy(),
		spellArt = art,
		movables,
		light = cellLightOf(plugin.cellLighting(cell)),
		emittance = plugin.emittanceOf(cell),
		imageSpace = plugin.imageSpaceOf(space) ?? fail("no image space {space:08X} in {esmPath}"),
		focus = middle,
		low = build.low,
		high = build.high,
		cast
	)
	path = world.cellPath(id)
	world.writeCell(path, head, body) ?? fail("cannot write {path}: {error}")
	table.writeNames("{world.preparedDir}/{id.lower()}/textures.txt")
	install.preparePhysics(plugin, cell, id)
	for m in table.missing:
		eprint("no texture: {m}")
	print("prepared {cell.editorId} from {dir} into {path} in {(clockSeconds() - started):.1} s: {build.vertices.len} vertices, {indices.len / 3} triangles, {table.textures.len} textures ({table.missing.len} missing), {head.lights.len} lights")
