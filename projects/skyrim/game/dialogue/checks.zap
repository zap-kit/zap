# long: the table of the condition functions, one arm per function
# The condition functions the inn's dialogue calls, over the game's world: what each gives for the
# reference it runs on (the indices and meanings after UESP's Skyrim Mod:Condition Functions and
# the Creation Kit wiki's pages of each). The functions of states the inn at a new game never has
# (combat, sneaking, spells and perks, weather in a cell under a roof, a scene, a location's
# keyword data or a variable no script has set, an unfilled location alias) give what that state
# gives. Every other function is unknown: none, which conditions.zap counts.

import skyrim.esm
import skyrim.actor
import game.sim
import papyrus

fn actorValue(t Talk, refId i64, index i64, part i64) f32:
	a = t.vm.rt.world.actors.get(refId) ?? return 0.0
	if index < 0 or index >= sim.actorValueNames.len: return 0.0
	name = sim.actorValueNames[index]
	match part:
		0: a.valueOf(name)
		1: a.baseValueOf(name)
		_: a.percentOf(name) * 100.0

fn itemCount(t Talk, refId i64, item i64) f32:
	inv = t.vm.rt.world.inventories.get(refId) ?? return 0.0
	f32(inv.countOf(item))

fn distance(t Talk, a i64, b i64) f32:
	fa = t.vm.rt.world.forms.get(a) ?? return 0.0
	fb = t.vm.rt.world.forms.get(b) ?? return 0.0
	(fa.positionOf() - fb.positionOf()).length()

fn sexOf(t Talk, refId i64) f32:
	truth((t.people.get(refId) ?? return 0.0).female)

fn voiceIs(mut t Talk, refId i64, named i64) f32:
	voice = (t.people.get(refId) ?? return 0.0).voice
	truth(t.isOrIn(voice, named))

fn raceIs(t Talk, refId i64, race i64):
	match t.vm.rt.world.actors.get(refId):
		a: truth(a.race == race)
		none: 0.0

fn factionRank(t Talk, refId i64, faction i64) f32:
	f32(t.rankIn(refId, faction) ?? -1)

fn relationship(t Talk, a i64, b i64) f32:
	f32(t.relations.get(t.baseOf(a) * 4_294_967_296 + t.baseOf(b)) ?? 0)

fn isLocked(t Talk, refId i64):
	f = t.vm.rt.world.forms.get(refId) ?? return false
	lock = f.lock ?? return false
	lock.locked

fn isDead(t Talk, refId i64):
	truth(t.vm.rt.world.actors.get(refId)?.dead ?? false)

fn questStage(t Talk, quest i64) f32:
	f32(t.vm.rt.world.stages.get(quest) ?? 0)

fn questRunning(t Talk, quest i64):
	truth(t.vm.rt.world.runningQuests.get(quest) ?? false)

fn stageDone(t Talk, quest i64, stage i64):
	truth(t.vm.rt.world.isStageDone(quest, stage))

fn questDone(t Talk, quest i64) f32:
	q = t.dialogue.quests.get(quest) ?? return 0.0
	truth((q.flags & questCompleted) != 0)

fn inLocation(mut t Talk, refId i64, location i64):
	truth(location in t.locationChain(t.locationOf(refId)))

fn inCell(t Talk, refId i64, cell i64):
	truth((t.vm.rt.world.forms.get(refId)?.cell ?? 0) == cell)

fn hasKeyword(t Talk, refId i64, keyword i64):
	truth(keyword in t.vm.rt.world.keywordsOf(t.baseOf(refId)))

fn isEquipped(t Talk, refId i64, item i64) f32:
	inv = t.vm.rt.world.inventories.get(refId) ?? return 0.0
	truth(inv.isWorn(item))

# whether an item the actor wears has the keyword
fn wornHasKeyword(t Talk, refId i64, keyword i64) f32:
	inv = t.vm.rt.world.inventories.get(refId) ?? return 0.0
	truth(inv.wornForms().any(keyword in t.vm.rt.world.keywordsOf(it)))

fn level(t Talk, refId i64) f32:
	f32(t.vm.rt.world.actors.get(refId)?.level ?? 0)

fn crimeGold(t Talk, refId i64, faction i64) f32:
	f32(
		t.vm.rt.world.crimes
			.filter(.actor == refId and (faction == 0 or .faction == faction))
			.map(.bounty)
			.sum()
	)

fn randomPercent(mut t Talk) f32:
	f32(t.vm.rt.rng.next(0..100))

# a variable of a script bound to the form, by the condition's text parameter ("::name_var")
fn scriptVariable(mut t Talk, form i64, name str):
	if t.dialogue.quests.get(form) != none: t.vm.bindQuestScripts(t.plugin, form)
	key = name.lower()
	for k in 1..t.vm.rt.objects.len:
		if t.vm.rt.objects[k].form != form: continue
		if t.vm.rt.objects[k].vars.get(key) is v: return v.asFloat()
	0.0

# whether an actor of a vendor faction keeps its shop open at this hour (FACT's VENV: the hours)
fn offersServices(mut t Talk, refId i64) f32:
	a = t.vm.rt.world.actors.get(refId) ?? return 0.0
	hour = t.vm.rt.world.gameHour()
	for m in a.factions.filter(.rank >= 0):
		r = t.plugin.recordOf(m.faction) ?? continue
		at = esm.dataOf(r.fields, "VENV") ?? continue
		start = f32(r.body.u16le(at))
		end = f32(r.body.u16le(at + 2))
		if hour >= start and hour < end: return 1.0
	0.0

fn isPlayableRace(mut t Talk, refId i64) f32:
	r = t.plugin.recordOf(t.vm.rt.world.actors.get(refId)?.race ?? 0) ?? return 0.0
	at = esm.dataOf(r.fields, "DATA") ?? return 0.0
	truth((r.body.u32le(at + 32) & 1) != 0)

fn isChild(mut t Talk, refId i64) f32:
	r = t.plugin.recordOf(t.vm.rt.world.actors.get(refId)?.race ?? 0) ?? return 0.0
	at = esm.dataOf(r.fields, "DATA") ?? return 0.0
	truth((r.body.u32le(at + 32) & 4) != 0)

# whether the package is the one the actor runs now: the first whose schedule takes in the hour
# and whose conditions a new game satisfies (actor.activePackageAtStart)
fn isCurrentPackage(mut t Talk, refId i64, package i64) f32:
	npc = t.plugin.npcOf(t.baseOf(refId)) ?? return 0.0
	packages = t.plugin.packagesOf(npc)
	w = t.vm.rt.world
	p = t.plugin.activePackageAtStart(packages, w.gameHour(), w.dayOfWeek(), t.location) ??
		return 0.0
	truth(p.formId == package)

fn locationHasKeyword(mut t Talk, refId i64, keyword i64) f32:
	for l in t.locationChain(t.locationOf(refId)):
		r = t.plugin.recordOf(l) ?? continue
		if keyword in esm.formsOf(r.body, r.fields, "KWDA"): return 1.0
	0.0

# The value of the condition's function for the reference it runs on; none for a function
# without an implementation.
fn functionValue(mut t Talk, c esm.Condition, s Scope, refId i64) f32?:
	w = t.vm.rt.world
	p1 = c.param1
	match c.function:
		1: t.distance(refId, t.paramRef(c, s, p1))
		5: truth(t.isLocked(refId))
		14: t.actorValue(refId, p1, 0)
		18: w.gameHour()
		32: truth(
			(w.forms.get(refId)?.cell ?? 0) == (w.forms.get(t.paramRef(c, s, p1))?.cell ?? -1)
		)
		35: truth(not (w.forms.get(refId)?.enabled ?? true))
		39: 0.0
		45: 1.0
		46: t.isDead(refId)
		47: t.itemCount(refId, p1)
		48: t.itemCount(refId, 0xF)
		49, 61, 62, 75, 101, 145, 159, 214, 246, 248, 263, 264, 286, 289, 312: 0.0
		50: truth(t.talkedTo.get(refId) ?? false)
		56: t.questRunning(p1)
		58: t.questStage(p1)
		59: t.stageDone(p1, c.param2)
		67: t.inCell(refId, p1)
		68: truth((t.people.get(refId)?.class ?? 0) == p1)
		69: t.raceIs(refId, p1)
		70: truth(t.sexOf(refId) == f32(p1))
		71: truth(t.rankIn(refId, p1) != none)
		72: truth(t.baseOf(refId) == p1)
		73: t.factionRank(refId, p1)
		74: w.globals.get(p1) ?? 0.0
		77: t.randomPercent()
		80: t.level(refId)
		84, 108, 117, 149, 402, 408, 453, 491, 596, 632, 644, 654, 655, 700: 0.0
		123: truth(t.greeting and refId == t.partner)
		130: t.raceIs(w.player, p1)
		131: truth(t.sexOf(w.player) == f32(p1))
		132: truth(t.rankIn(w.player, p1) != none)
		136: truth(refId == t.paramRef(c, s, p1))
		170: f32(w.dayOfWeek())
		182: t.isEquipped(refId, p1)
		249: truth(refId != 0 and refId == t.partner)
		254: t.isPlayableRace(refId)
		255: t.offersServices(refId)
		277: t.actorValue(refId, p1, 1)
		300: 1.0
		310: 0.0
		359: t.inLocation(refId, t.paramRef(c, s, p1))
		365: t.isChild(refId)
		372: truth(t.isOrIn(t.baseOf(refId), p1))
		403: t.relationship(refId, t.paramRef(c, s, p1))
		426: t.voiceIs(refId, p1)
		430: t.actorValue(refId, 24, 2) / 100.0
		448: 0.0
		459: t.crimeGold(refId, p1)
		497: truth(t.itemCount(w.player, 0xF) >= t.crimeGold(w.player, 0))
		543: t.questDone(p1)
		560: t.hasKeyword(refId, p1)
		562: t.locationHasKeyword(refId, p1)
		566: truth(refId != 0 and refId == t.filled(s.quest, p1))
		629: t.scriptVariable(p1, c.text2)
		630: t.scriptVariable(t.paramRef(c, s, p1), c.text2)
		640: t.actorValue(refId, p1, 2)
		79, 360, 606, 624: 0.0
		161: t.isCurrentPackage(refId, p1)
		503: 1.0
		682: t.wornHasKeyword(refId, p1)
		699: 0.0
		638: truth(t.relationship(refId, w.player) >= 1.0)
		_: none
