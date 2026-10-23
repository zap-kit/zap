# The dialogue as the game runs it: the plugin's topics, responses and quests, the strings their
# texts are in, the world and its scripts (the Papyrus VM, whose world is the game's), the people
# who can speak (an actor's base, voice type, sex, race and class), and what was said and to
# whom. A new game starts the quests the plugin starts (DNAM's Start Game Enabled) at their
# start-up stage and fills their aliases that name a reference or a unique actor.

import skyrim
import skyrim.esm
import skyrim.actor
import game.sim
import papyrus

pub type Person:
	refId i64
	npc i64
	editorId str
	name str
	voice i64   # VTYP
	female bool
	race i64
	class i64

pub type Talk:
	plugin esm.Esm
	vm papyrus.Vm
	dialogue Dialogue
	names skyrim.Strings
	lines skyrim.Strings
	people {i64: Person}   # by the actor's reference
	location i64   # the location (LCTN) of the cell the world holds
	said {i64: f64} = {}   # when each INFO was last said, in the game's days
	talkedTo {i64: bool} = {}   # the actors that have talked to the player
	fills {i64: i64} = {}   # the reference filling each alias, by quest * 65536 + alias
	unknown {i64: i64} = {}   # the condition functions met without an implementation, by index: how often
	partner i64 = 0   # the actor in dialogue with the player, 0 for none
	greeting bool = false   # whether the actor's hello is being chosen
	relations {i64: i64} = {}   # RELA's ranks (4 lover to -4 archnemesis), by npc * 2^32 + npc

fn fillKey(quest i64, alias i64):
	quest * 65_536 + alias

# the reference that fills the quest's alias, 0 for none
pub fn filled(t Talk, quest i64, alias i64) i64:
	t.fills.get(fillKey(quest, alias)) ?? 0

pub fn personOf(mut plugin esm.Esm, names skyrim.Strings, refId i64, base i64) Person?:
	npc = plugin.npcOf(base) ?? return none
	Person(
		refId,
		npc = base,
		editorId = npc.editorId.copy(),
		name = (names.texts.get(npc.nameId) ?? "").copy(),
		voice = npc.voice,
		female = npc.female,
		race = npc.race,
		class = npc.class
	)

# The quests a new game starts, at their start-up stages, those stages' fragments run (stage 0's
# too: PlayerSleepQuest's registers it for the player's sleep).
fn startQuests(mut t Talk):
	started = []
	for id, q in t.dialogue.quests:
		if (q.flags & esm.questStartGameEnabled) == 0: continue
		t.vm.rt.world.runningQuests[id] = true
		if q.startStage >= 0 and t.vm.rt.world.stages.get(id) == none:
			t.vm.rt.world.setStage(id, q.startStage)
			started.push((id, q.startStage))
	for pair in started:
		quest, stage = pair
		t.runStageFragments(quest, stage)

# the actor reference of this base the world holds, 0 for none
fn actorRefOf(t Talk, base i64):
	for refId, a in t.vm.rt.world.actors:
		if a.npc == base: return refId
	0

# fills the running quests' aliases that name their reference or actor, then those that name
# another quest's alias
fn fillAliases(mut t Talk):
	for id, q in t.dialogue.quests:
		if not (t.vm.rt.world.runningQuests.get(id) ?? false): continue
		for a in q.aliases:
			refId = a.refId if a.refId != 0
				else t.actorRefOf(a.uniqueActor) if a.uniqueActor != 0
				else 0
			if refId != 0: t.fills[fillKey(id, a.id)] = refId
	for id, q in t.dialogue.quests:
		for a in q.aliases:
			if a.externalQuest == 0: continue
			refId = t.filled(a.externalQuest, a.externalAlias)
			if refId != 0: t.fills[fillKey(id, a.id)] = refId

# RELA: the parent actor, the child, the rank (0 lover to 8 archnemesis)
fn readRelations(mut t Talk):
	for r in t.plugin.groupRecords("RELA"):
		at = esm.dataOf(r.fields, "DATA") ?? continue
		a = i64(r.body.u32le(at))
		b = i64(r.body.u32le(at + 4))
		rank = 4 - i64(r.body.u16le(at + 8))
		t.relations[a * 4_294_967_296 + b] = rank
		t.relations[b * 4_294_967_296 + a] = rank

# Dialogue over the VM's world (its actors become people), the cell's location given.
pub fn newTalk(
	move plugin esm.Esm,
	move vm papyrus.Vm,
	move names skyrim.Strings,
	move lines skyrim.Strings,
	location i64
) Talk:
	dialogue = plugin.readDialogue()
	t = Talk(plugin, vm, dialogue, names, lines, people = {}, location)
	for refId, a in t.vm.rt.world.actors:
		if t.plugin.personOf(t.names, refId, a.npc) is p: t.people[refId] = p
	t.startQuests()
	t.fillAliases()
	t.readRelations()
	t

# the actors the cell's packages bring there, placed in it at their own references so they can
# be spoken to
fn addVisitors(mut w sim.GameWorld, mut plugin esm.Esm, names skyrim.Strings, cellId str):
	placed = plugin.placedActors()
	for a in plugin.cellActors(cellId) ?? []:
		if a.achr != none: continue
		refId = placed.get(a.npc) ?? continue
		w.forms[refId] = sim.WorldForm(
			formId = refId,
			kind = "ACHR",
			editorId = "",
			base = a.npc,
			enabled = true,
			x = 0.0,
			y = 0.0,
			z = 0.0,
			baseKind = "NPC_",
			cell = w.cell
		)
		outfit = (plugin.npcOf(a.npc) ?? continue).outfit
		w.addActor(plugin, names, refId, a.npc, outfit)

# The dialogue of the interior cell as a new game finds it: its world with its scripts bound
# (papyrus.cellVm) and the actors its packages bring; or why the install cannot give it.
pub fn talkInCell(move install skyrim.Install, move plugin esm.Esm, cellId str) Talk ? str:
	names = try install.readNames("Skyrim.esm")
	lines = try install.readLines("Skyrim.esm")
	cell = plugin.findCell(cellId) ?? return "no cell {cellId}"
	vm = try papyrus.cellVm(install, plugin, names, cellId)
	vm.rt.world.addVisitors(plugin, names, cellId)
	newTalk(plugin, vm, names, lines, cell.location)

# The dialogue of the interior cell over the install's archives and its Skyrim.esm, none (and a
# line saying so) without the install: where a check of what is said starts.
pub fn talkOfArchives(cellId str) Talk?:
	install = try skyrim.installOfArchives()
	plugin = esm.openEsm(install.installPlugin("Skyrim.esm")) ?? fail
	talkInCell(install, plugin, cellId) ?? fail
