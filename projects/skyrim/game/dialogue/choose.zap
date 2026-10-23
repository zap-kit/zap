# What an actor says, chosen as the game chooses it. A quest's topics are open while the quest
# runs and its dialogue conditions hold for the speaker. Topics of a kind (the hello, a branch's
# start) are tried by their quest's priority then their own, highest first; within a topic the
# INFOs in the order the plugin keeps them, the first that may be said winning: its speaker (ANAM)
# is the actor or none, it is not a say-once line already said nor one said within its reset
# hours, and its conditions hold. A random INFO that wins draws among it and the random ones that
# may be said after it, up to the one flagged random-end. Activating an actor greets: a blocking
# top-level branch whose start topic has a line starts the conversation, else the hello. The menu
# lists the top-level branches whose start topic has a line, by the topic's priority, each with
# the line's prompt (RNAM) or the topic's name.

import papyrus
import skyrim.esm

# a response chosen: its topic and its INFO
pub type Line:
	topic i64
	info i64

# a topic the menu offers: the response it would give and the prompt shown
pub type MenuTopic:
	topic i64
	info i64
	prompt str

fn questOpen(mut t Talk, quest i64, speaker i64) bool:
	if not (t.vm.rt.world.runningQuests.get(quest) ?? false): return false
	q = t.dialogue.quests.get(quest) ?? return false
	t.conditionsHold(q.conditions, Scope(subject = speaker, target = t.vm.rt.world.player, quest))

# whether the INFO may be said now by the speaker
fn mayBeSaid(mut t Talk, i Info, speaker i64) bool:
	if i.speaker != 0 and i.speaker != t.baseOf(speaker): return false
	if t.said.get(i.formId) is when:
		if i.isSayOnce(): return false
		if f64(i.resetHours) / 24.0 > t.vm.rt.world.daysPassed - when: return false
	t.conditionsHold(
		i.conditions,
		Scope(subject = speaker, target = t.vm.rt.world.player, quest = i.quest)
	)

# the INFO of the topic the speaker would say, none when none may be said
pub fn chooseInfo(mut t Talk, topic i64, speaker i64) i64?:
	infos = (try t.dialogue.topics.get(topic)).infos.copy()
	for k, id in infos:
		i = t.dialogue.infos[id].copy()
		if not t.mayBeSaid(i, speaker): continue
		if not i.isRandom(): return id
		draw = [id]
		for m in k + 1..infos.len:
			j = t.dialogue.infos[infos[m]].copy()
			if not j.isRandom(): break
			if t.mayBeSaid(j, speaker): draw.push(infos[m])
			if (j.flags & flagRandomEnd) != 0: break
		return draw[t.vm.rt.rng.next(0..draw.len)]
	none

# the topics of this subtype (SNAM) open to the speaker, in the order they are tried
fn topicsTried(mut t Talk, subtype str, speaker i64):
	open {i64: bool} = {}
	out = []
	for id in t.dialogue.topics.keys().sorted():
		tp = t.dialogue.topics[id]
		if tp.subtype != subtype: continue
		if open.get(tp.quest) == none: open[tp.quest] = t.questOpen(tp.quest, speaker)
		if open[tp.quest]: out.push(id)
	out.sortedBy(-t.topicRank(it))

# a topic's place in the order: its quest's priority, then its own
fn topicRank(t Talk, topic i64) f64:
	tp = t.dialogue.topics[topic]
	(t.dialogue.quests.get(tp.quest)?.priority ?? 0) * 1000.0 + f64(tp.priority)

# the first of the topics with a line the speaker may say
fn firstLine(mut t Talk, topics i64[], speaker i64) Line?:
	for topic in topics:
		if t.chooseInfo(topic, speaker) is info: return Line(topic, info)
	none

# the start topics of the open top-level branches, blocking ones or the others
fn branchStarts(mut t Talk, speaker i64, blocking bool):
	out = []
	for id in t.dialogue.branches.keys().sorted():
		b = t.dialogue.branches[id].copy()
		if not b.isTopLevel() or b.isBlocking() != blocking: continue
		if t.dialogue.topics.get(b.start) == none or not t.questOpen(b.quest, speaker): continue
		out.push(b.start)
	out.sortedBy(-t.topicRank(it))

# The line the speaker greets the player with as the conversation starts: a blocking branch's,
# else the hello; none when it has none.
pub fn greeting(mut t Talk, speaker i64) Line?:
	t.partner = speaker
	t.greeting = true
	line = t.firstLine(t.branchStarts(speaker, true), speaker) ??
		t.firstLine(t.topicsTried("HELO", speaker), speaker)
	t.greeting = false
	line

# the prompt the menu shows for the topic and the INFO it would give, a global's value in place of
# each <Global=editor id>
fn promptOf(mut t Talk, topic i64, info i64) str:
	id = t.dialogue.infos[info].promptId
	nameId = id if id != 0 else t.dialogue.topics[topic].nameId
	t.withGlobals(t.names.texts.get(nameId) ?? "")

pub fn withGlobals(mut t Talk, text str) str:
	out = text.copy()
	loop 8:
		at = out.indexOf("<Global=") ?? return out
		end = out.indexOf(">", at) ?? return out
		name = out[at + 8..end].copy()
		global = t.plugin.formByEditorId("GLOB", name) ?? 0
		value = i64(t.vm.rt.world.globals.get(global) ?? 0.0)
		out = "{out[..at]}{value}{out[end + 1..]}"
	out

fn menuOf(mut t Talk, topics i64[], speaker i64):
	out = []
	for topic in topics:
		info = t.chooseInfo(topic, speaker) ?? continue
		out.push(MenuTopic(topic, info, prompt = t.promptOf(topic, info)))
	out

# a topic's place in the menu: by its own priority, highest first, then by its quest's, lowest
# first
fn menuRank(t Talk, topic i64) (f64, f64, i64):
	tp = t.dialogue.topics[topic]
	(-f64(tp.priority), t.dialogue.quests.get(tp.quest)?.priority ?? 0, topic)

# The topics the dialogue menu offers the player with the speaker, in the menu's order: by the
# topic's priority, then its quest's, lowest first, as the game's captures show Orgnar's (the
# alchemy lab at 60 over his goods, the rumors and the College at 50, of quests at 0, 69 and 70).
# Of the rumors (RUMO) only the first that may be said is offered, the highest quest's: the game
# shows the Dark Brotherhood's (69), then MS13's (60) once the first moved its quest on.
pub fn topics(mut t Talk, speaker i64) MenuTopic[]:
	out = []
	rumors = false
	for m in t.menuOf(t.branchStarts(speaker, false), speaker):
		if t.dialogue.topics[m.topic].subtype == "RUMO":
			if rumors: continue
			rumors = true
		out.push(m)
	out.sortedBy(t.menuRank(.topic))

# The response the speaker gives to the topic, none when it has none.
pub fn respond(mut t Talk, speaker i64, topic i64) Line?:
	info = try t.chooseInfo(topic, speaker)
	Line(topic, info)

# Whether none of the topic's lines was said yet: the menu writes such a topic white, a heard one
# grey.
pub fn isNewTopic(t Talk, topic i64) bool:
	not (t.dialogue.topics.get(topic)?.infos ?? []).any(t.said.get(it) != none)

# The topics the INFO leads to (TCLT), in its order.
pub fn linked(t Talk, info i64) i64[]:
	(t.dialogue.infos.get(info)?.links ?? []).copy()

# whether the topic belongs to an exclusive branch
fn isExclusiveTopic(t Talk, topic i64):
	b = t.dialogue.topics.get(topic)?.branch ?? 0
	t.dialogue.branches.get(b)?.isExclusive() ?? false

# The menu after the speaker said the INFO: the topics it leads to that have a line, then, unless
# its branch is exclusive, the top-level ones.
pub fn menuAfter(mut t Talk, speaker i64, line Line) MenuTopic[]:
	out = t.menuOf(t.linked(line.info), speaker)
	if t.isExclusiveTopic(line.topic): return out
	for m in t.topics(speaker):
		if not out.any(.topic == m.topic): out.push(m)
	out

# Activates the actor as the player: the line it greets with, none when the activation is not a
# conversation or the actor has nothing to say.
pub fn activateActor(mut t Talk, actor i64) Line?:
	a, _ = t.vm.activateRef(actor, t.vm.rt.world.player)
	match a:
		Talked: t.greeting(actor)
		_: none

# Every line the speaker may say now in its hellos and its top-level topics, each topic's in its
# order (more than the one the game would pick: those it picks among over time).
pub fn sayable(mut t Talk, speaker i64) Line[]:
	t.partner = speaker
	t.greeting = true
	tried = t.topicsTried("HELO", speaker)
	tried.extend(t.branchStarts(speaker, true))
	tried.extend(t.branchStarts(speaker, false))
	out = []
	for topic in tried:
		for info in t.dialogue.topics[topic].infos.copy():
			if t.mayBeSaid(t.dialogue.infos[info].copy(), speaker): out.push(Line(topic, info))
	t.greeting = false
	out
