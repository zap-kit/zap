# The world of an interior cell as a new game finds it, headless: every reference the cell places
# with its state (position, count, owner, links, lock, the teleport of a load door with the cell it
# leads to), the data of every item, harvestable and furniture they are of, the containers'
# contents, the actors with their values, inventories and outfits, the player standing where the
# door from outside lets one in, the game settings, the globals' values and the crime factions a
# theft from each owner is reported to.

import skyrim
import skyrim.esm
import skyrim.actor

# the player's placed reference (PlayerRef)
pub playerRef = 0x14

fn u32At(r esm.Record, tag str, offset i64) i64:
	at = esm.dataOf(r.fields, tag) ?? return 0
	r.body.u32le(at + offset)

fn vec3At(d u8[], at i64):
	Vec3(d.f32le(at), d.f32le(at + 4), d.f32le(at + 8))

fn linksOf(r esm.Record):
	r.fields.filter(.tag == "XLKR" and .size >= 4).map(
		Link(keyword = r.body.u32le(.at), refId = r.body.u32le(.at + 4)) if .size >= 8
		else Link(keyword = 0, refId = r.body.u32le(.at))
	)

fn lockOf(r esm.Record) Lock?:
	at = try esm.dataOf(r.fields, "XLOC")
	Lock(level = r.body[at], key = r.body.u32le(at + 4), locked = true)

# where the door's XTEL leads: the door at the other side, and the exterior cell that holds it
fn teleportOf(
	mut plugin esm.Esm,
	names skyrim.Strings,
	r esm.Record,
	resolveInterior bool
) Teleport?:
	at = try esm.dataOf(r.fields, "XTEL")
	t = Teleport(
		door = r.body.u32le(at),
		position = vec3At(r.body, at + 4),
		rotation = vec3At(r.body, at + 16),
		world = 0,
		cell = 0
	)
	if plugin.persistentRef(t.door) is placed:
		world, _ = placed
		return plugin.exteriorTeleport(names, t, world)
	if resolveInterior and plugin.interiorCellOf(t.door) is inside:
		t.cell = inside
		if plugin.interiorCellRecord(inside) is c:
			t.cellEditorId = esm.textOf(c.body, c.fields, "EDID")
			t.placeName = names.localText(c, "FULL")
	t

# the teleport t into the world's exterior: the cell at its place, named by its own name or its
# location's
fn exteriorTeleport(mut plugin esm.Esm, names skyrim.Strings, door Teleport, world i64):
	t = door.copy()
	t.world = world
	x, y = t.position.gridOf()
	c = plugin.exteriorCell(world, x, y) ?? return t
	t.cell = c.formId
	t.cellEditorId = c.editorId.copy()
	if c.nameId != 0: t.placeName = (names.texts.get(c.nameId) ?? "").copy()
	if plugin.masterRecordOf(c.location) is l:
		t.location = "{esm.textOf(l.body, l.fields, "EDID")} ({names.localText(l, "FULL")})"
		if t.placeName.isEmpty: t.placeName = names.localText(l, "FULL")
	t

# the reference r as the world keeps it
fn placedForm(
	mut plugin esm.Esm,
	names skyrim.Strings,
	r esm.Record,
	cell i64,
	baseKind str,
	resolveInterior bool
):
	at = esm.dataOf(r.fields, "DATA") ?? 0
	scaleAt = esm.dataOf(r.fields, "XSCL")
	countAt = esm.dataOf(r.fields, "XCNT")
	WorldForm(
		formId = r.formId,
		kind = r.kind.copy(),
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		base = r.formOf("NAME") ?? 0,
		enabled = (r.flags & 0x800) == 0,
		x = r.body.f32le(at),
		y = r.body.f32le(at + 4),
		z = r.body.f32le(at + 8),
		baseKind = baseKind.copy(),
		rotation = vec3At(r.body, at + 12),
		scale = r.body.f32le(scaleAt ?? 0) if scaleAt != none else 1.0,
		cell,
		count = r.body.i32le(countAt ?? 0) if countAt != none else 1,
		owner = r.formOf("XOWN") ?? 0,
		links = r.linksOf(),
		teleport = plugin.teleportOf(names, r, resolveInterior),
		lock = r.lockOf(),
		location = r.formOf("XLCN") ?? 0
	)

# learns what the world needs of a base record: an item's data, a furniture's markers, keywords
fn learnBase(
	mut w GameWorld,
	install skyrim.Install,
	mut plugin esm.Esm,
	names skyrim.Strings,
	base esm.Record
):
	if w.learnItem(plugin, names, base.formId): return
	if base.kind == "FURN":
		if install.furnitureOf(plugin, base.formId) is fu: w.furniture[base.formId] = fu
	keywords = esm.formsOf(base.body, base.fields, "KWDA")
	if not keywords.isEmpty: w.keywords[base.formId] = keywords

# every global variable's value (GLOB's FLTV)
fn loadGlobals(mut w GameWorld, mut plugin esm.Esm):
	for id in plugin.formsOfKind("GLOB"):
		r = plugin.recordOf(id) ?? continue
		at = esm.dataOf(r.fields, "FLTV") ?? continue
		w.globals[id] = r.body.f32le(at)

# the player at the place a load door's other side lets one into the cell, its record's
# inventory and the prisoner's clothes on
fn addPlayer(mut w GameWorld, mut plugin esm.Esm, names skyrim.Strings):
	spot = Vec3(0, 0, 0)
	for f in w.forms.values():
		t = f.teleport ?? continue
		_, outside = plugin.persistentRef(t.door) ?? continue
		at = esm.dataOf(outside.fields, "XTEL") ?? continue
		spot = vec3At(outside.body, at + 4)
		break
	w.forms[playerRef] = WorldForm(
		formId = playerRef,
		kind = "ACHR",
		editorId = "PlayerRef",
		base = playerBase,
		enabled = true,
		x = spot.x,
		y = spot.y,
		z = spot.z,
		baseKind = "NPC_",
		cell = w.cell
	)
	w.player = playerRef
	outfit = plugin.formByEditorId("OTFT", startOutfit) ?? 0
	w.addActor(plugin, names, playerRef, playerBase, outfit)

# the crime faction each owner's thefts are reported to, and those factions' crime values
fn learnCrime(mut w GameWorld, mut plugin esm.Esm, owners i64[]):
	for owner in owners:
		faction = 0
		if plugin.npcOf(owner) is npc: faction = npc.crimeFaction
		else:
			for a in w.actors.values():
				if a.crimeFaction != 0 and (faction == 0 or a.isInFaction(owner)):
					faction = a.crimeFaction
		w.crimeFactions[owner] = faction
		if faction != 0 and w.crimeValues.get(faction) == none:
			if plugin.crimeValuesOf(faction) is v: w.crimeValues[faction] = v

# The world of the interior cell with this editor id as a new game finds it, or why the plugin
# cannot give it.
pub fn worldOfCell(
	install skyrim.Install,
	mut plugin esm.Esm,
	names skyrim.Strings,
	cellId str
) GameWorld ? str:
	cell = plugin.findCell(cellId) ?? return "no cell {cellId}"
	w = newWorld()
	w.cell = cell.formId
	w.cellOwner = cell.owner
	w.cellLocation = cell.location
	if plugin.recordOf(cell.location) is place:
		keywords = esm.formsOf(place.body, place.fields, "KWDA")
		if not keywords.isEmpty: w.keywords[cell.location] = keywords
	w.settings = plugin.gameSettings()
	w.loadGlobals(plugin)
	w.loadSkillUses(plugin, names)
	owners = [cell.owner]
	for r in plugin.cellRecords(cellId) ?? []:
		base = plugin.recordOf(r.formOf("NAME") ?? 0) ?? continue
		f = plugin.placedForm(names, r, cell.formId, base.kind, cell.exterior)
		if f.owner != 0 and f.owner not in owners: owners.push(f.owner)
		w.learnBase(install, plugin, names, base)
		w.forms[r.formId] = f
		if base.kind == "CONT":
			w.fillInventory(plugin, names, r.formId, plugin.startingContents(base, w.dice))
			w.forms[r.formId].respawns = base.respawns()
		if r.kind == "ACHR":
			outfit = (plugin.npcOf(base.formId) ?? continue).outfit
			w.addActor(plugin, names, r.formId, base.formId, outfit)
	w.addPlayer(plugin, names)
	w.learnCrime(plugin, owners)
	w
