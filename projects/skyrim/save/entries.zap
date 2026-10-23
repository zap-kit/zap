# The keyed part of a snapshot as entries: one per form, actor, inventory, resident, quest, line
# said and so on, each the bytes of that value. Against the entries of a new game they give the
# change forms a save writes (those that differ, and those that are gone), and the entries of a
# save over a new game's give the snapshot back.
#
# An entry belongs to a change form (its type and its form id) and is one part of it; a change
# form's flags have a bit for each part it holds. The change form types are UESP's ("Skyrim Mod:
# Save File Format"): the parts of each type are ours.
#
#   REFR 0, ACHR 1:  partForm (a WorldForm), partActor (an ActorState), partInventory,
#                    partResident (a SavedResident, its animator with it), partTalked (a bool: it
#                    has talked to the player), partFighter (a Fighter: its state in the fight),
#                    partFallen (a SavedFallen: its ragdoll), partPose (a Havok body of the
#                    clutter, which no reference names: the REFR is havokRefs plus its place in
#                    the world, UESP's Havok move)
#   QUST 8:          partStage (the current stage), partRunning, partDone (the stages done)
#   INFO 7:          partSaid (when a response was said last, in game days)
#   BOOK 13:         partRead
#   FURN 22:         partMarkers (the markers in use, as bits)
#   FACT 31:         partCrime (the faction's CrimeValues)

pub typeRefr = 0
pub typeAchr = 1
pub typeInfo = 7
pub typeQust = 8
pub typeBook = 13
pub typeFurn = 22
pub typeFact = 31

pub partForm = 0
pub partActor = 1
pub partInventory = 2
pub partResident = 3
pub partTalked = 4
pub partStage = 5
pub partRunning = 6
pub partDone = 7
pub partSaid = 8
pub partRead = 9
pub partMarkers = 10
pub partCrime = 11
pub partFighter = 12
pub partFallen = 13
pub partPose = 14

# the first of the form ids a clutter body goes by
pub havokRefs = 0xFE00_0000

# the plain values a part holds, in a struct each so that they read back by their type
pub type Flag:
	on bool

pub type Number:
	n i64

pub type Moment:
	days f64

pub type Numbers:
	list i64[]

pub type Entry:
	kind i64
	refId i64
	part i64
	data u8[]
	gone bool = false   # the value is not there any more (against a new game's)

# the key of an entry in a map of them: its change form and its part
pub fn keyOf(kind i64, refId i64, part i64) i64:
	((kind << 32) | refId) * 64 + part

fn typeOfKind(kind str):
	match kind:
		"ACHR": typeAchr
		"QUST": typeQust
		_: typeRefr

# the change form a reference's parts go to: by the form's record type, an actor's when it has
# values and no form
fn typeOfRef(s Snapshot, refId i64):
	if s.forms.get(refId) is f: return typeOfKind(f.kind)
	typeAchr if s.actors.get(refId) != none else typeRefr

fn put(mut out {i64: Entry}, kind i64, refId i64, part i64, data u8[]):
	out[keyOf(kind, refId, part)] = Entry(kind, refId, part, data = data.copy())

fn putRefs(mut out {i64: Entry}, s Snapshot):
	for id, f in s.forms:
		out.put(s.typeOfRef(id), id, partForm, f.toBytes())
	for id, a in s.actors:
		out.put(s.typeOfRef(id), id, partActor, a.toBytes())
	for id, inv in s.inventories:
		out.put(s.typeOfRef(id), id, partInventory, inv.toBytes())
	for id, r in s.residents:
		out.put(s.typeOfRef(id), id, partResident, r.toBytes())
	for id, talked in s.talkedTo:
		out.put(s.typeOfRef(id), id, partTalked, Flag(talked).toBytes())
	for id, x in s.fighters:
		out.put(s.typeOfRef(id), id, partFighter, x.toBytes())
	for id, f in s.fallen:
		out.put(s.typeOfRef(id), id, partFallen, f.toBytes())
	for i, pose in s.clutter:
		out.put(typeRefr, havokRefs + i, partPose, pose.toBytes())

# the stages done of the quest, the numbers
fn doneOf(s Snapshot, quest i64):
	out = []
	for key in s.stagesDone.keys().sorted():
		if key >> 16 == quest: out.push(key & 0xFFFF)
	out

fn putQuests(mut out {i64: Entry}, s Snapshot):
	quests {i64: bool} = {}
	for q, _ in s.stages:
		quests[q] = true
	for q, _ in s.running:
		quests[q] = true
	for key, _ in s.stagesDone:
		quests[key >> 16] = true
	for q in quests.keys().sorted():
		if s.stages.get(q) is stage: out.put(typeQust, q, partStage, Number(stage).toBytes())
		if s.running.get(q) is on: out.put(typeQust, q, partRunning, Flag(on).toBytes())
		out.put(typeQust, q, partDone, Numbers(s.doneOf(q)).toBytes())

# The keyed values of the snapshot as entries.
pub fn entriesOf(s Snapshot) {i64: Entry}:
	out {i64: Entry} = {}
	out.putRefs(s)
	out.putQuests(s)
	for id, when in s.said:
		out.put(typeInfo, id, partSaid, Moment(when).toBytes())
	for id, read in s.booksRead:
		out.put(typeBook, id, partRead, Flag(read).toBytes())
	for id, active in s.furniture:
		out.put(typeFurn, id, partMarkers, Number(active).toBytes())
	for id, values in s.crimeValues:
		out.put(typeFact, id, partCrime, values.toBytes())
	out

# the entries of a save: those of a new game under the save's changes
pub fn overlay(base {i64: Entry}, changes Entry[]) {i64: Entry}:
	out = base.copy()
	for e in changes:
		key = keyOf(e.kind, e.refId, e.part)
		if e.gone:
			out.remove(key)
		else:
			out[key] = e.copy()
	out

# What differs in `now` from `base`: the entries that are new or other, and tombstones for those
# that are gone.
pub fn changesOf(base {i64: Entry}, now {i64: Entry}) Entry[]:
	out = []
	for key in now.keys().sorted():
		e = now[key]
		if base.get(key) is old and old.data == e.data: continue
		out.push(e.copy())
	for key in base.keys().sorted():
		if now.get(key) != none: continue
		e = base[key]
		out.push(Entry(kind = e.kind, refId = e.refId, part = e.part, data = [], gone = true))
	out
