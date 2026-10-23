# Furniture (FURN) as the game uses it: the model's markers (where an actor sits, sleeps or leans,
# facing which way: nif.furnitureMarkers), the record's MNAM (bit k: marker k is in use; the high
# bits the furniture's flags), FNPR (each marker's kind and entry sides, read when the model has no
# markers), WBDT (a workbench's type and skill) and its keywords. Layout after UESP's FURN page and
# xEdit's definitions. A bed (a marker to sleep) is slept in only by the actor who may take what
# its owner owns: the game refuses an owned bed with sNoSleepInOwnedBed until the bed is rented,
# when RentRoomScript makes the player its owner for a day.

import skyrim
import skyrim.esm
import skyrim.nif

# WBDT's workbench types
pub benchTypes = [
	"none", "create object", "smithing weapon", "enchanting", "enchanting experiment", "alchemy",
	"alchemy experiment", "smithing armor"
]

pub type Furniture:
	markers nif.FurnitureMarker[]
	active i64   # MNAM: bit k for marker k in use
	bench i64   # WBDT's type, 0 for a plain furniture
	benchSkill i64   # the actor value it uses, -1 for none

# where an actor using a furniture goes: the marker, placed in the world
pub type Seat:
	kind i64   # nif.furnitureSit, furnitureSleep or furnitureLean
	marker i64   # its index in the model's markers
	position Vec3
	heading f32   # radians about z, the furniture's turn added

# the record's own list of marker kinds (FNPR: a kind and the entry sides per marker)
fn recordMarkers(r esm.Record):
	r.fields.filter(.tag == "FNPR" and .size >= 4).map(
		nif.FurnitureMarker(
			offset = Vec3(0, 0, 0),
			heading = 0.0,
			kind = r.body.u16le(.at),
			entries = r.body.u16le(.at + 2)
		)
	)

# The furniture with this base form id: its record's data and its model's markers; none when it
# is no furniture.
pub fn furnitureOf(install skyrim.Install, mut plugin esm.Esm, base i64) Furniture?:
	r = try plugin.recordOf(base)
	if r.kind != "FURN": return none
	markers = []
	model = esm.textOf(r.body, r.fields, "MODL")
	if not model.isEmpty:
		if install.readModel(skyrim.modelKey(model)) is n: markers = n.furnitureMarkers()
	if markers.isEmpty: markers = r.recordMarkers()
	bench = esm.dataOf(r.fields, "WBDT")
	Furniture(
		markers,
		active = r.body.u32le(esm.dataOf(r.fields, "MNAM") ?? 0) if esm.dataOf(r.fields, "MNAM") !=
			none
		else 0xFF_FFFF,
		bench = r.body[bench ?? 0] if bench != none else 0,
		benchSkill = i8(r.body[(bench ?? 0) + 1]) if bench != none else -1
	)

# the first marker in use, placed where the reference f puts the model; none for a furniture
# with no marker in use
pub fn seatOf(fu Furniture, f WorldForm) Seat?:
	place = esm.placement(esm.Ref(
		formId = f.formId,
		base = f.base,
		position = f.positionOf(),
		rotation = f.rotation,
		scale = f.scale,
		persistent = false,
		disabled = false,
		teleports = false
	))
	for k, m in fu.markers:
		if k < 24 and (fu.active >> k) & 1 == 0: continue
		return Seat(
			kind = m.kind,
			marker = k,
			position = place.applyPoint(m.offset),
			heading = m.heading + f.rotation.z
		)
	none

pub fn seatKindName(kind i64) str:
	match kind:
		1: "sit"
		2: "sleep"
		4: "lean"
		_: "marker {kind}"
