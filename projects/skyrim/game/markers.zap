# The places of the cell an actor's sandbox uses: each furniture's markers in use (a chair's or a
# bench's seats, a bed's place to sleep, a lean marker's) and each idle marker (IDLM: where an
# actor plays its idles for IDLT seconds), with the clips an actor enters, loops and leaves them
# by. The game picks those by its behavior graph from the idle the marker plays: the clips and the
# events are the graph's own for every kind (markerClipsOf).

import skyrim
import skyrim.esm
import skyrim.nif
import skyrim.hkx
import game.sim
import world

# The kinds of marker the behavior graph animates, by the IDLE records the game plays at them: the
# records a marker is entered by, in turn (a chair from behind is entered as from its front, then
# instantly), and the one it is left by. An IDLE record names the event it sends the graph (ENAM);
# one that names none (a sweep has no leaving idle) is left by the graph's own stop. The clips they
# play are the graph's (markerClipsOf).
pub type GraphMarker:
	kind str
	enter str[]
	leave str

# long: one row a kind of marker
pub graphMarkers = [
	GraphMarker(kind = "chair", enter = ["EnterChairFront"], leave = "ExitChairFront"),
	GraphMarker(kind = chairBehind, enter = ["EnterChairFront", "EnterChairInstant"],
		leave = "ExitChairBack"),
	GraphMarker(kind = "bed", enter = ["LeftBedEnter"], leave = "ExitBed"),
	GraphMarker(kind = "leantable", enter = ["IdleLeanTableEnter"], leave = "IdleLeanTableExit"),
	GraphMarker(kind = "counter", enter = ["IdleCounterStart"], leave = "IdleCounterExit"),
	GraphMarker(kind = "sweep", enter = ["IdleLooseSweepingStart"], leave = "")
]
# the kind of a seat entered from behind (a bench at a table)
pub chairBehind = "chair behind"
idleStop = "IdleStop"

# the event an IDLE record sends the graph, by its editor id
fn eventOf(mut plugin esm.Esm, idle str):
	form = plugin.formByEditorId("IDLE", idle) ?? return ""
	r = plugin.recordOf(form) ?? return ""
	esm.textOf(r.body, r.fields, "ENAM")

# Every kind's clips and events: the clips the graph plays when the kind's enter events are sent
# (the one they bring, the one it settles on), then the leave event's; a way in that is the loop
# itself is no way in. `seen` takes every clip the runs passed through.
pub fn markerClipsOf(
	g hkx.Graph,
	mut plugin esm.Esm,
	durations {str: f32},
	mut seen str[]
) world.MarkerClips[]:
	out = []
	for m in graphMarkers:
		enters = m.enter.map(plugin.eventOf(it))
		leave = plugin.eventOf(m.leave) if not m.leave.isEmpty else idleStop
		played = g.playedBy(durations, enters, leave, seen)
		out.push(
			world.MarkerClips(
				kind = m.kind.copy(),
				enter = "" if played.enter == played.looping else played.enter.copy(),
				looping = played.looping.copy(),
				leave = played.leave.copy(),
				enterEvents = enters,
				leaveEvent = leave
			)
		)
	out

fn editorIdOf(mut plugin esm.Esm, form i64):
	r = plugin.recordOf(form) ?? return ""
	esm.textOf(r.body, r.fields, "EDID")

# the kind of a furniture's marker: a lean marker's (a counter's or a table's, by its model,
# whatever its marker's type), else a seat a chair's, a sleep a bed's
fn furnitureKind(marker nif.FurnitureMarker, model str):
	name = model.lower()
	if name.indexOf("counterlean") != none: return "counter"
	if name.indexOf("leantable") != none: return "leantable"
	match marker.kind:
		1: "chair"
		2: "bed"
		_: ""

# a furniture's markers in use, placed where the reference r puts its model; none for a
# workbench, whose markers its own menus use
fn furnitureMarkers(
	install skyrim.Install,
	mut plugin esm.Esm,
	r esm.Ref,
	base esm.Record
):
	f = install.furnitureOf(plugin, r.base) ?? return []
	if f.bench != 0: return []
	model = esm.textOf(base.body, base.fields, "MODL")
	special = esm.formsOf(base.body, base.fields, "KWDA").any(plugin.editorIdOf(it) ==
			"FurnitureSpecial")
	place = r.placement()
	out = []
	for k, m in f.markers:
		if k < 24 and (f.active >> k) & 1 == 0: continue
		kind = furnitureKind(m, model)
		if kind.isEmpty: continue
		out.push(world.MarkerHead(refId = r.formId, kind, special,
			position = place.applyPoint(m.offset), heading = m.heading + r.rotation.z,
			entries = m.entries, dwell = 0.0))
	out

# an idle marker: a sweep where its idles sweep, else a plain stand
fn idleMarker(mut plugin esm.Esm, r esm.Ref, base esm.Record):
	idles = esm.formsOf(base.body, base.fields, "IDLA").map(plugin.editorIdOf(it).lower())
	timer = esm.dataOf(base.fields, "IDLT")
	world.MarkerHead(
		refId = r.formId,
		kind = "sweep" if idles.any(.indexOf("sweep") != none) else "idle",
		special = false,
		position = r.position,
		heading = r.rotation.z,
		entries = 1,
		dwell = base.body.f32le(timer ?? 0) if timer != none else 0.0
	)

# Every marker of the cell's enabled furniture and idle markers.
pub fn prepareMarkers(install skyrim.Install, mut plugin esm.Esm, cell esm.Cell) world.MarkerHead[]:
	out = []
	for r in cell.refs:
		if r.disabled: continue
		base = plugin.recordOf(r.base) ?? continue
		if base.kind == "FURN": out.extend(install.furnitureMarkers(plugin, r, base))
		if base.kind == "IDLM": out.push(plugin.idleMarker(r, base))
	out

# Every enabled door the cell places.
pub fn prepareDoors(mut plugin esm.Esm, cell esm.Cell) world.DoorHead[]:
	out = []
	for r in cell.refs:
		if r.disabled: continue
		base = plugin.recordOf(r.base) ?? continue
		if base.kind != "DOOR": continue
		out.push(world.DoorHead(r.formId, r.base, r.position, r.rotation.z, r.teleports))
	out
