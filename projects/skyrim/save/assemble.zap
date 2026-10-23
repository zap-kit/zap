# The snapshot rebuilt from a save's two kinds of content: the entries of its change forms (over a
# new game's) and its global data blocks, each a whole part of the state with an id of its own:
#
#   3     Global Variables (UESP's layout: a count, then a form id and a float each)
#   1     Player Location (UESP's layout, written from the player's body and the cell)
#   1001  Papyrus: the VM (ours: a SavedVm)
#   2001  our own: the world's loose state (a SavedMisc), the crimes of the world aside
#   2002  our own: the dialogue's relations and alias fills
#   2003  our own: the player's body (a SavedBody)
#   2004  our own: the fight in progress (a SavedFight)
#   2005  our own: the physics world's loose ends (a SavedHavok)
#   2006  our own: the player's animator (a Walker)

import game
import game.combat
import game.sim

pub blockPlayerLocation = 1
pub blockGlobals = 3
pub blockPapyrus = 1001
pub blockMisc = 2001
pub blockDialogue = 2002
pub blockPlayerBody = 2003
pub blockFight = 2004
pub blockHavok = 2005
pub blockPlayerWalker = 2006

pub type Block:
	kind i64
	data u8[]

# the relations and the alias fills of the dialogue
type SavedDialogue:
	relations {i64: i64}
	fills {i64: i64}
	crimeFactions {i64: i64}

fn globalsBlock(s Snapshot):
	out = []
	out.pushVarint(s.globals.len)
	for id in s.globals.keys().sorted():
		out.pushU32le(id)
		out.pushF32le(s.globals[id])
	out

fn locationBlock(s Snapshot):
	out = []
	out.pushU32le(s.misc.cell)
	out.pushF32le(s.player.feet.x)
	out.pushF32le(s.player.feet.y)
	out.pushF32le(s.player.feet.z)
	out.pushF32le(s.player.heading)
	out

# The snapshot's whole parts as global data blocks.
pub fn blocksOf(s Snapshot) Block[]:
	dialogue = SavedDialogue(relations = s.relations.copy(), fills = s.fills.copy(),
		crimeFactions = s.crimeFactions.copy())
	[
		Block(kind = blockPlayerLocation, data = s.locationBlock()),
		Block(kind = blockGlobals, data = s.globalsBlock()),
		Block(kind = blockPapyrus, data = s.vm.toBytes()),
		Block(kind = blockMisc, data = s.misc.toBytes()),
		Block(kind = blockDialogue, data = dialogue.toBytes()),
		Block(kind = blockPlayerBody, data = s.player.toBytes()),
		Block(kind = blockFight, data = s.fight.toBytes()),
		Block(kind = blockHavok, data = s.havok.toBytes()),
		Block(kind = blockPlayerWalker, data = s.walker.toBytes())
	]

fn blockOf(blocks Block[], kind i64) u8[] ? str:
	(blocks.find(.kind == kind) ?? return "the save lacks its global data {kind}").data.copy()

fn globalsFrom(data u8[]) {i64: f32} ? str:
	r = Reader(data)
	out {i64: f32} = {}
	loop r.varint():
		id = i64(r.u32())
		out[id] = r.f32()
	if r.short: return "the global variables are cut short"
	out

fn blankSnapshot(blocks Block[]) Snapshot ? str:
	dialogue = SavedDialogue.fromBytes(try blockOf(blocks, blockDialogue)) ??
		return "the dialogue block is damaged"
	Snapshot(
		forms = {},
		actors = {},
		inventories = {},
		residents = {},
		player = SavedBody.fromBytes(try blockOf(blocks, blockPlayerBody)) ?? return "the player's body is damaged",
		walker = game.Walker.fromBytes(try blockOf(blocks, blockPlayerWalker)) ??
			return "the player's animator is damaged",
		clutter = {},
		fallen = {},
		fighters = {},
		fight = SavedFight.fromBytes(try blockOf(blocks, blockFight)) ?? return "the fight is damaged",
		havok = SavedHavok.fromBytes(try blockOf(blocks, blockHavok)) ??
			return "the physics block is damaged",
		stages = {},
		stagesDone = {},
		running = {},
		globals = try globalsFrom(try blockOf(blocks, blockGlobals)),
		furniture = {},
		said = {},
		talkedTo = {},
		relations = dialogue.relations.copy(),
		fills = dialogue.fills.copy(),
		booksRead = {},
		crimeValues = {},
		crimeFactions = dialogue.crimeFactions.copy(),
		misc = SavedMisc.fromBytes(try blockOf(blocks, blockMisc)) ?? return "the world's block is damaged",
		vm = SavedVm.fromBytes(try blockOf(blocks, blockPapyrus)) ??
			return "the Papyrus block is damaged"
	)

fn damaged(e Entry):
	"the change form {e.refId:08X} of type {e.kind} has a damaged part {e.part}"

# one entry's value put in its map of the snapshot
fn place(mut s Snapshot, e Entry) ? str:
	id = e.refId
	if e.part == partForm:
		s.forms[id] = sim.WorldForm.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partActor:
		s.actors[id] = sim.ActorState.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partInventory:
		s.inventories[id] = sim.Inventory.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partResident:
		s.residents[id] = SavedResident.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partTalked:
		s.talkedTo[id] = (Flag.fromBytes(e.data) ?? return e.damaged()).on
	elif e.part == partStage:
		s.stages[id] = (Number.fromBytes(e.data) ?? return e.damaged()).n
	elif e.part == partRunning:
		s.running[id] = (Flag.fromBytes(e.data) ?? return e.damaged()).on
	elif e.part == partDone:
		for stage in (Numbers.fromBytes(e.data) ?? return e.damaged()).list:
			s.stagesDone[id * 65_536 + stage] = true
	elif e.part == partSaid:
		s.said[id] = (Moment.fromBytes(e.data) ?? return e.damaged()).days
	elif e.part == partRead:
		s.booksRead[id] = (Flag.fromBytes(e.data) ?? return e.damaged()).on
	elif e.part == partMarkers:
		s.furniture[id] = (Number.fromBytes(e.data) ?? return e.damaged()).n
	elif e.part == partFighter:
		s.fighters[id] = combat.Fighter.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partFallen:
		s.fallen[id] = SavedFallen.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partPose:
		s.clutter[id - havokRefs] = SavedPose.fromBytes(e.data) ?? return e.damaged()
	elif e.part == partCrime:
		s.crimeValues[id] = sim.CrimeValues.fromBytes(e.data) ?? return e.damaged()
	else:
		"the change form {id:08X} has a part {e.part} this game does not know"

# The snapshot of a save: its blocks and its entries (those of a new game under its changes).
pub fn snapshotFrom(blocks Block[], entries {i64: Entry}) Snapshot ? str:
	s = try blankSnapshot(blocks)
	for key in entries.keys().sorted():
		try s.place(entries[key])
	s
