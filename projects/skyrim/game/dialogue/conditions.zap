# Conditions evaluated as the game does while it picks what an actor says: in order, each OR
# group read to its end and the first group that fails ending the reading (the conditions after
# it never asked). A condition runs on its subject (the speaker), the target (the player), a
# reference, the subject's linked reference or one of the quest's aliases (CTDA's run-on), with
# subject and target swapped when its flag says; parameters are aliases of the quest when its
# flag says. A function without an implementation (checks.zap) gives 0, and is counted.

import skyrim.esm
import game.sim

# whom the conditions are asked about: the speaker, the one spoken to, the quest whose aliases
# the conditions name
pub type Scope:
	subject i64
	target i64
	quest i64

# the reference the condition's function runs on, 0 for none
fn runsOn(t Talk, c esm.Condition, s Scope):
	subject = s.target if c.swap else s.subject
	match c.runOn:
		0: subject
		1: s.subject if c.swap else s.target
		2: c.reference
		4: t.vm.rt.world.linkedRef(subject, c.param3.max(0))
		5: t.filled(s.quest, c.param3)
		_: 0

# a parameter that names a reference: itself, or the reference filling the quest's alias when the
# condition's parameters are aliases
fn paramRef(t Talk, c esm.Condition, s Scope, param i64):
	if c.useAliases: return t.filled(s.quest, param)
	param

# whether the condition holds for the scope
pub fn conditionHolds(mut t Talk, c esm.Condition, s Scope) bool:
	refId = t.runsOn(c, s)
	x = t.functionValue(c, s, refId) ?? t.unknownFunction(c)
	value = (t.vm.rt.world.globals.get(c.global) ?? 0.0) if c.useGlobal else c.value
	c.holds(x, value)

fn unknownFunction(mut t Talk, c esm.Condition) f32:
	t.unknown[c.function] = (t.unknown.get(c.function) ?? 0) + 1
	0.0

# Whether the conditions all hold, read as the game reads them.
pub fn conditionsHold(mut t Talk, conditions esm.Condition[], s Scope) bool:
	esm.groupsHold(conditions, t.conditionHolds(it, s))

# the actor base of a reference: an actor's, else the reference's base; the form itself when the
# world holds no reference of it (a condition can ask about a base)
pub fn baseOf(t Talk, refId i64) i64:
	if t.vm.rt.world.actors.get(refId) is a: return a.npc
	match t.vm.rt.world.forms.get(refId):
		f: f.base if f.base != 0 else refId
		none: refId

# the actor's rank in the faction, none when it is not in it
fn rankIn(t Talk, refId i64, faction i64) i64?:
	a = try t.vm.rt.world.actors.get(refId)
	m = try a.factions.find(.faction == faction)
	m.rank if m.rank >= 0 else none

# whether the form is the one named or in the form list named (lists inside lists followed)
fn isOrIn(mut t Talk, form i64, named i64) bool:
	if form == named: return true
	r = t.plugin.recordOf(named) ?? return false
	if r.kind != "FLST": return false
	for inner in esm.formsOf(r.body, r.fields, "LNAM"):
		if inner == form or (inner != named and t.isOrIn(form, inner)): return true
	false

# the location's parents, the location first (LCTN's PNAM)
fn locationChain(mut t Talk, location i64):
	out i64[] = []
	at = location
	while at != 0 and at not in out:
		out.push(at)
		r = t.plugin.recordOf(at) ?? break
		at = r.formOf("PNAM") ?? 0
	out

# the location the reference is in: its cell's
fn locationOf(t Talk, refId i64):
	f = t.vm.rt.world.forms.get(refId) ?? return 0
	t.location if f.cell == t.vm.rt.world.cell else 0

# the hour of the game's day, 0 to 24
pub fn gameHour(w sim.GameWorld) f32:
	f32((w.daysPassed - w.daysPassed.floor()) * 24.0)

# the day of the week, 0 Sundas to 6 Loredas: the game starts on a Morndas
pub fn dayOfWeek(w sim.GameWorld) i64:
	(1 + i64(w.daysPassed.floor())) % 7

fn truth(b bool) f32:
	1.0 if b else 0.0
