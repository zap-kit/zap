# Riverwood's people across its cells, as the plugin gives them: who lives in the exterior area and
# in the interiors its load doors lead to, where each one's packages put it by the hour, and the
# doors it goes through to get there (the pathing to the door, the teleport, the arrival at the
# other side). Cells that are not loaded are advanced as the game advances them: UpdateNonHighActors
# (SkyrimSE.exe 0x14077bbc0) runs the actors out of the high list each frame in slices, so at any
# hour such an actor is at its package's place, and one whose package just changed is on its way,
# walking the doors' route at its gait's speed until it arrives.

import skyrim.esm
import skyrim.actor
import game.sim

# a place in the town: the cell (an interior's editor id or the exterior area's id) and a point
pub type Spot:
	cell str
	at Vec3
	heading f32 = 0.0

# a load door: where it stands, the cell it leads to, where who goes through appears there (its
# XTEL) and the door at the other side
pub type TownDoor:
	refId i64
	spot Spot
	to str
	arrival Spot
	other i64

# a package of a dweller: when it runs, whether its conditions hold at a new game, and its place
# (none when the package names none the plugin resolves: an alias, an object type)
pub type DwellerPlan:
	editorId str
	schedule actor.Schedule
	holds bool
	spot Spot?
	radius f32

# an actor of the town: where its reference stands (none for one only its packages bring) and
# its packages in the order the game tries them
pub type Dweller:
	npc i64
	editorId str
	home Spot?
	plans DwellerPlan[]

# the town: the exterior area and the interiors its doors lead to, every reference placed in them,
# the doors between them and the people
pub type Town:
	area esm.Area
	cells str[]
	cellIds {i64: str}   # a cell's form id to its id
	refs {i64: Spot}
	doors TownDoor[]
	dwellers Dweller[]

# a stretch of a walk inside one cell, ending at the door that leads on (0 for the last)
pub type Leg:
	cell str
	from Vec3
	to Vec3
	door i64

# where a dweller is: standing at its place, or walking between two points of a cell
pub type Whereabouts:
	spot Spot
	walking bool

# units a second at a walk, the gaits' (game/control.zap's measured speeds are the same order)
walkSpeed f32 = 130.0

fn vec3At(d u8[], at i64):
	Vec3(d.f32le(at), d.f32le(at + 4), d.f32le(at + 8))

fn spotOfRecord(r esm.Record, cell str):
	at, heading = r.placeOf()
	Spot(cell.copy(), at, heading)

fn isPlaced(r esm.Record):
	r.kind == "REFR" or r.kind == "ACHR"

# the cell registered: its references' places and its form id
fn addCell(mut t Town, id str, formId i64, records esm.Record[]):
	t.cells.push(id.copy())
	t.cellIds[formId] = id.copy()
	for r in records:
		if r.isPlaced(): t.refs[r.formId] = r.spotOfRecord(id)

# the id of the cell a load door's destination door stands in, and its form id
fn destinationOf(mut plugin esm.Esm, area esm.Area, door i64) (str, i64)?:
	if plugin.persistentRef(door) is placed:
		world, r = placed
		at, _ = r.placeOf()
		x, y = at.gridOf()
		if (x, y) in esm.loadedGrid(area.x, area.y, 5): return (area.areaId(), 0)
		return (esm.areaAround(world, at).areaId(), 0)
	cell = try plugin.interiorCellOf(door)
	c = try plugin.interiorCellRecord(cell)
	(esm.textOf(c.body, c.fields, "EDID"), cell)

# the load doors among a cell's records, with where each leads
fn doorsOf(mut plugin esm.Esm, area esm.Area, id str, records esm.Record[]):
	out = []
	for r in records:
		if r.kind != "REFR": continue
		x = esm.dataOf(r.fields, "XTEL") ?? continue
		other = i64(r.body.u32le(x))
		to, _ = plugin.destinationOf(area, other) ?? continue
		arrival = Spot(to.copy(), vec3At(r.body, x + 4), r.body.f32le(x + 20))
		out.push(TownDoor(refId = r.formId, spot = r.spotOfRecord(id), to, arrival, other))
	out

# The interiors the exterior's doors lead to, registered, then the doors of every cell: the town's
# map. The first use reads every interior's reference headers.
fn mapTown(mut plugin esm.Esm, area esm.Area):
	t = Town(area, cells = [], cellIds = {}, refs = {}, doors = [], dwellers = [])
	outside = area.areaId()
	records = plugin.cellRecords(outside) ?? []
	t.addCell(outside, (plugin.findCell(outside)?.formId) ?? 0, records)
	records_of {str: esm.Record[]} = {outside.copy(): records.copy()}
	for d in plugin.doorsOf(area, outside, records):
		if d.to in t.cells: continue
		inside = plugin.cellRecords(d.to) ?? continue
		t.addCell(d.to, (plugin.findCell(d.to)?.formId) ?? 0, inside)
		records_of[d.to.copy()] = inside
	for id in t.cells:
		t.doors.extend(plugin.doorsOf(area, id, records_of.get(id) ?? []))
	t

# the cell a form id names, as a spot: the interior's way in, an exterior cell's middle
fn cellSpot(t Town, form i64) Spot?:
	id = try t.cellIds.get(form)
	d = try t.doors.find(.to == id)
	d.arrival.copy()

# a spot of its own from one kept elsewhere
fn copied(s Spot?) Spot?:
	if s is x: return x.copy()
	none

# where a reference of the town stands
fn refSpot(t Town, form i64) Spot?:
	if t.refs.get(form) is s: return s.copy()
	none

# where a package puts the dweller: its location read as the AI reads it
fn spotOf(t Town, home Spot?, linked i64, p actor.Package):
	place = p.location ?? return copied(home)
	match place.kind:
		0: t.refSpot(place.form)
		1: t.cellSpot(place.form)
		2, 3, 12: copied(home)
		6: t.refSpot(linked)
		_: none

fn dwellerPlanOf(
	mut plugin esm.Esm,
	t Town,
	placed Placement,
	p actor.Package
):
	linked = 0
	if placed.achr is r and p.location is place: linked = r.linkedRef(place.form) ?? 0
	spot = copied(t.spotOf(placed.home, linked, p))
	DwellerPlan(
		editorId = p.editorId.copy(),
		schedule = p.schedule.copy(),
		holds = not p.isPlacedByAlias() and (plugin.newGameHolds(p.conditions, placed.location) ?? false),
		spot,
		radius = f32((p.location?.radius) ?? 0)
	)

# where an actor stands, its location (XLCN) and the record that places it, none for a visitor
type Placement:
	home Spot?
	location i64
	achr esm.Record?

# the actors the town's cells place: each actor base's first reference
fn townActors(mut plugin esm.Esm, t Town):
	out {i64: Placement} = {}
	for id in t.cells:
		for r in plugin.cellRecords(id) ?? []:
			if r.kind != "ACHR": continue
			base = r.achrBase()
			if out.get(base) == none:
				out[base] = Placement(r.spotOfRecord(id), r.formOf("XLCN") ?? 0, r.copy())
	out

# the forms a package can name to send an actor into the town
fn townForms(t Town):
	forms {i64: bool} = {}
	for formId, _ in t.refs:
		forms[formId] = true
	for formId, _ in t.cellIds:
		forms[formId] = true
	forms

# the actors whose packages bring them into the town without a reference in it
fn visitors(mut plugin esm.Esm, t Town):
	into = plugin.packagesInto(t.townForms())
	out = []
	for id in plugin.formsOfKind("NPC_"):
		r = plugin.recordOf(id) ?? continue
		if esm.formsOf(r.body, r.fields, "PKID").any(it in into): out.push(id)
	out

fn dwellerOf(mut plugin esm.Esm, t Town, id i64, placed Placement) Dweller?:
	npc = plugin.npcOf(id) ?? return none
	Dweller(
		npc = id,
		editorId = npc.editorId.copy(),
		home = copied(placed.home),
		plans = plugin.packagesOf(npc).map(plugin.dwellerPlanOf(t, placed, it))
	)

# The town around the exterior area: its cells, doors and people (those the cells place, then
# those their packages bring), each with its packages' places resolved.
pub fn townAround(mut plugin esm.Esm, area esm.Area) Town:
	t = plugin.mapTown(area)
	placed = plugin.townActors(t)
	for id, a in placed:
		if plugin.dwellerOf(t, id, a) is d: t.dwellers.push(d)
	for id in plugin.visitors(t):
		if placed.get(id) != none: continue
		if plugin.dwellerOf(t, id, Placement(home = none, location = 0, achr = none)) is d:
			t.dwellers.push(d)
	t

# the dweller with this editor id
pub fn dwellerNamed(t Town, editorId str) Dweller?:
	t.dwellers.find(.editorId == editorId)?.copy()

# the package the dweller runs at the hour of a day of the week: the first whose conditions held at
# a new game and whose schedule takes the hour in
pub fn planAtHour(d Dweller, hour f32, day i64) DwellerPlan?:
	d.plans.find(.holds and .schedule.scheduleMatches(hour, day))?.copy()

# where the dweller is at the hour: its package's place, else where its reference stands
pub fn spotAt(d Dweller, hour f32, day i64) Spot?:
	if d.planAtHour(hour, day) is p: return copied(p.spot) ?? copied(d.home)
	copied(d.home)

# The doors from one cell to another, fewest first (a breadth-first search of the doors); none
# when they are the same cell, and none when no doors join them.
pub fn route(t Town, from str, to str) TownDoor[]:
	if from == to: return []
	came {str: TownDoor} = {}
	queue = [from.copy()]
	seen {str: bool} = {from.copy(): true}
	k = 0
	while k < queue.len:
		here = queue[k]
		k += 1
		for d in t.doors.filter(.spot.cell == here):
			if seen.get(d.to) != none: continue
			seen[d.to.copy()] = true
			came[d.to.copy()] = d.copy()
			queue.push(d.to.copy())
	out TownDoor[] = []
	at = to.copy()
	while at != from:
		d = came.get(at) ?? return []
		out.insert(0, d.copy())
		at = d.spot.cell.copy()
	out

# The walk from one spot to another: in each cell to the door that leads on, then, appearing at
# its arrival, on to the next, the last leg to the spot itself.
pub fn legs(t Town, from Spot, to Spot) Leg[]:
	out = []
	here = from.copy()
	for d in t.route(from.cell, to.cell):
		out.push(Leg(cell = here.cell.copy(), from = here.at, to = d.spot.at, door = d.refId))
		here = d.arrival.copy()
	out.push(Leg(cell = here.cell.copy(), from = here.at, to = to.at, door = 0))
	out

# seconds a walk of legs takes at the walking speed
pub fn walkSeconds(path Leg[]) f32:
	total = 0.0
	for l in path:
		total += (l.to - l.from).length() / walkSpeed
	total

# the hours of the day the dweller's packages begin or end at, in order
fn changeHours(d Dweller):
	out = []
	for p in d.plans:
		if p.schedule.hour < 0: continue
		start = f32(p.schedule.hour) + f32(p.schedule.minute.max(0)) / 60.0
		out.push(start)
		out.push((start + f32(p.schedule.duration) / 60.0) % 24.0)
	out.sort()
	out

# the last hour at or before `hour` (cyclic) at which the dweller's package could change
fn lastChange(d Dweller, hour f32) f32?:
	changes = d.changeHours()
	if changes.isEmpty: return none
	before = changes.filter(it <= hour)
	before.last ?? ((changes.last ?? 0.0) - 24.0)

# Where the dweller is at the hour of a day, the cell not loaded: at its place, or, when its
# package changed `timeScale` game seconds a real second ago in a way that takes it between
# places, on the route's way (the walk at the gait's speed, then the doors).
pub fn whereAt(t Town, d Dweller, hour f32, day i64, timeScale f32) Whereabouts?:
	now = try d.spotAt(hour, day)
	changed = d.lastChange(hour) ?? return Whereabouts(spot = now, walking = false)
	before = d.spotAt((changed - 0.001 + 24.0) % 24.0, day) ?? now
	if before.cell == now.cell and (before.at - now.at).length() < 1.0:
		return Whereabouts(spot = now, walking = false)
	path = t.legs(before, now)
	walked = ((hour - changed + 24.0) % 24.0) * 3600.0 / timeScale.max(1.0) * walkSpeed
	for l in path:
		length = (l.to - l.from).length()
		if walked <= length:
			along = l.from + (l.to - l.from) * (walked / length.max(1.0))
			return Whereabouts(spot = Spot(l.cell, along, now.heading), walking = true)
		walked -= length
	Whereabouts(spot = now, walking = false)

# the dweller with this base
fn dwellerBase(t Town, npc i64):
	t.dwellers.find(.npc == npc)?.copy()

# where the dweller's package number `plan` puts it (its place, else its reference's), none for no
# such package or no place
fn planSpot(d Dweller, plan i64):
	if plan < 0 or plan >= d.plans.len: return copied(d.home)
	copied(d.plans[plan].spot) ?? copied(d.home)

# The load door of cell `here` the dweller goes through to reach its package number `plan`'s
# place when that is in another cell, none when the place is here, unknown or not joined by doors.
pub fn exitDoor(t Town, here str, npc i64, plan i64) TownDoor?:
	d = try t.dwellerBase(npc)
	spot = try d.planSpot(plan)
	first = try t.route(here, spot.cell).first
	first.copy()

# a dweller coming into a cell through a load door: where it appears, and the seconds it walks
# before it gets there
pub type Coming:
	at Spot
	seconds f32

# How the dweller comes into cell `here` for its package number `plan` after package `was`: none
# when it was already here, or its place is elsewhere. It walks the earlier cells' legs, then
# appears at the arrival of the last door.
pub fn comingFrom(t Town, here str, npc i64, was i64, plan i64) Coming?:
	d = try t.dwellerBase(npc)
	to = try d.planSpot(plan)
	from = try d.planSpot(was)
	if to.cell != here or from.cell == here: return none
	doors = t.route(from.cell, here)
	last = try doors.last
	path = t.legs(from, to)
	Coming(at = last.arrival.copy(), seconds = path[..path.len - 1].walkSeconds())
