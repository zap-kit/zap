# Saying a response, with what it does: each line's text and voice file, the INFO marked said (a
# say-once line never again, another not within its reset hours) and the actor as having talked
# to the player, the scripts of the INFO run (its VMAD binds the fragment script TIF__<form id>
# to the INFO with its properties, the quest's own scripts bound first; the begin fragment runs as
# the line starts, the end fragment as it ends, each given the speaker as akSpeakerRef, the quest
# of TopicInfo.GetOwningQuest the INFO's; a stage they set runs its quest's fragment), and a
# goodbye ending the conversation. What changed in
# the world is read back: the quests' stages, the player's gold, the locks and the owners.

import game.sim
import papyrus

# one line said: its text and where its voice lies
pub type Spoken:
	text str
	voice str   # the archive key of its FUZ, "" when the line plays a sound of its own
	emotion i64
	emotionValue i64

pub type Said:
	info i64
	lines Spoken[]
	stages str[]   # "<quest> <stage>" for each stage the scripts set
	gold i64   # the player's gold gained (less than 0 for spent)
	unlocked i64[]   # the references whose lock opened
	owners str[]   # "<reference> <owner>" for each reference whose owner changed
	goodbye bool
	log str[]   # what the scripts traced and the natives they called that do nothing yet

# the lines of the INFO as the speaker says them
pub fn spokenLines(mut t Talk, speaker i64, info i64) Spoken[]:
	i = t.dialogue.infos[info].copy()
	said = t.dialogue.infos[t.dialogue.spokenId(i)].copy()
	said.responses.map(
		Spoken(
			text = (t.lines.texts.get(it.textId) ?? "").copy(),
			voice = t.responseKey(speaker, i, it) if it.sound == 0 else "",
			emotion = it.emotion,
			emotionValue = it.emotionValue
		)
	)

# Binds the scripts of the quests the speaker's scripts and the INFO's name in their properties,
# and the INFO's own quest, before the fragment runs: a quest's script seen through a property
# then holds the values its record gives it.
fn bindNamedQuests(mut t Talk, i Info, v papyrus.Vmad, speaker i64):
	quests = [i.quest]
	for s in v.scripts:
		for p in s.properties:
			for x in p.values:
				if x is Object(form, _) and t.dialogue.quests.get(form) != none: quests.push(form)
	for k in 1..t.vm.rt.objects.len:
		if t.vm.rt.objects[k].form != speaker: continue
		for x in t.vm.rt.objects[k].vars.values():
			if x is Object(id) and id > 0 and
				t.dialogue.quests.get(t.vm.rt.objects[id].form) != none:
				quests.push(t.vm.rt.objects[id].form)
	for q in quests:
		t.vm.bindQuestScripts(t.plugin, q)

# the fragment script's object bound to the INFO and the fragments, none when it has none
fn infoScript(mut t Talk, i Info, speaker i64) (i64, papyrus.InfoFragments)?:
	if i.vmad.isEmpty: return none
	v = papyrus.readVmad(i.vmad) ?? return none
	f = try papyrus.infoFragments(i.vmad, v)
	t.bindNamedQuests(i, v, speaker)
	t.vm.rt.world.addForm(i.formId)
	t.vm.rt.world.dialogueQuests[i.formId] = i.quest
	if t.vm.boundObject(i.formId, f.script) is bound: return (bound, f)
	s = v.scripts.find(.name.lower() == f.script.lower())
	object = try t.vm.bindScript(i.formId, f.script, s?.properties ?? [])
	(object, f)

fn runFragment(mut t Talk, object i64, script str, function str, speaker i64):
	if function.isEmpty: return
	me = t.vm.lib.objectFor(t.vm.rt, speaker, "objectreference")
	t.vm.callFunction(script, object, function, [.Object(me)])
	t.vm.runThreads()

fn isLockedNow(f sim.WorldForm):
	lock = f.lock ?? return false
	lock.locked

# Runs the quest's fragments of the stage (its VMAD's fragment data: QF_<quest>_<form id>'s
# function for the stage, bound to the quest with its other scripts), as setting the stage runs
# them in the game.
fn runStageFragments(mut t Talk, quest i64, stage i64):
	q = t.dialogue.quests.get(quest) ?? return
	if q.vmad.isEmpty: return
	v = papyrus.readVmad(q.vmad) ?? return
	f = papyrus.questFragments(q.vmad, v) ?? return
	object = (t.vm.bindQuestScripts(t.plugin, quest)).find(
		t.vm.rt.objects[it].script == f.script.lower()
	) ??
		return
	for s in f.stages:
		if s.stage == stage:
			t.vm.callFunction(f.script, object, s.function, [])
			t.vm.runThreads()

# runs the fragments of the stages set since `before`, and of those they set in turn
fn runNewStages(mut t Talk, before {i64: i64}):
	ran {i64: i64} = before.copy()
	loop 16:
		fresh = []
		for quest, stage in t.vm.rt.world.stages:
			if (ran.get(quest) ?? -1) != stage: fresh.push((quest, stage))
		if fresh.isEmpty: return
		for pair in fresh:
			quest, stage = pair
			ran[quest] = stage
			t.runStageFragments(quest, stage)

# the references' locks and owners, to compare after the scripts ran
fn locksAndOwners(w sim.GameWorld):
	out {i64: (bool, i64)} = {}
	for id, f in w.forms:
		out[id] = f.lock?.locked ?? false, f.owner
	out

fn changes(t Talk, mut s Said, stages {i64: i64}, before {i64: (bool, i64)}):
	w = t.vm.rt.world
	for quest, stage in w.stages:
		if (stages.get(quest) ?? -1) != stage:
			s.stages.push("{t.dialogue.quests.get(quest)?.editorId ?? "{quest:08X}"} {stage}")
	for id, f in w.forms:
		locked, owner = before.get(id) ?? (false, 0)
		if locked and not isLockedNow(f): s.unlocked.push(id)
		if owner != f.owner: s.owners.push("{id:08X} {f.owner:08X}")

# The speaker says the INFO: what it said and did.
pub fn say(mut t Talk, speaker i64, info i64) Said:
	i = t.dialogue.infos[info].copy()
	s = Said(
		info,
		lines = t.spokenLines(speaker, info),
		stages = [],
		gold = 0,
		unlocked = [],
		owners = [],
		goodbye = i.isGoodbye(),
		log = []
	)
	t.said[info] = t.vm.rt.world.daysPassed
	t.talkedTo[speaker] = true
	player = t.vm.rt.world.player
	gold = t.vm.rt.world.inventories.get(player)?.countOf(0xF) ?? 0
	stages = t.vm.rt.world.stages.copy()
	before = t.vm.rt.world.locksAndOwners()
	logged = t.vm.rt.log.len
	if t.infoScript(i, speaker) is (object, f):
		t.runFragment(object, f.script, f.begin, speaker)
		t.runFragment(object, f.script, f.end, speaker)
		t.runNewStages(stages)
	t.changes(s, stages, before)
	s.gold = (t.vm.rt.world.inventories.get(player)?.countOf(0xF) ?? 0) - gold
	s.log = t.vm.rt.log[logged..].copy()
	if s.goodbye: t.partner = 0
	s
