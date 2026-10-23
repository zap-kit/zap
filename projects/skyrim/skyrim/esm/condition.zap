# Conditions (CTDA, 32 bytes): the operator in the top three bits of the first byte (== != > >= <
# <=) and flags in the low ones (1: OR with the next, 2: the parameters are the quest's aliases, 4:
# the value is a global's, 8: they are the package's data, 16: subject and target swapped), the
# value (a float or a GLOB), the function's index (functions.zap), two parameters, what it runs on,
# a reference and a third parameter (a quest alias, a linked ref's keyword, an event's member). A
# parameter that is text (a script's variable) follows in CIS1 or CIS2. Conditions in a row
# joined by OR form a group; the groups are joined by AND. Layout after UESP's Skyrim Mod File
# Format (CTDA) and xEdit's wbConditions.

pub type Condition:
	op i64
	orNext bool
	useGlobal bool
	value f32
	global i64   # the GLOB holding the value when useGlobal
	function i64
	param1 i64
	param2 i64
	runOn i64   # 0 the subject, 1 the target, 2 a reference, 3 the combat target, 4 a linked ref, 5 a quest alias, 6 package data, 7 event data
	reference i64
	param3 i64 = -1
	useAliases bool = false
	usePackData bool = false
	swap bool = false
	text1 str = ""   # CIS1
	text2 str = ""   # CIS2

# what a condition runs on
pub runSubject = 0
pub runTarget = 1
pub runReference = 2
pub runCombatTarget = 3
pub runLinkedRef = 4
pub runQuestAlias = 5
pub runPackageData = 6
pub runEventData = 7

operators = ["==", "!=", ">", ">=", "<", "<="]

pub fn conditionAt(body u8[], at i64, size i64) Condition:
	head = i64(body[at])
	Condition(
		op = head >> 5,
		orNext = (head & 1) != 0,
		useGlobal = (head & 4) != 0,
		value = body.f32le(at + 4),
		global = body.u32le(at + 4),
		function = body.u16le(at + 8),
		param1 = body.u32le(at + 12),
		param2 = body.u32le(at + 16),
		runOn = body.u32le(at + 20),
		reference = body.u32le(at + 24),
		param3 = body.i32le(at + 28) if size >= 32 else -1,
		useAliases = (head & 2) != 0,
		usePackData = (head & 8) != 0,
		swap = (head & 16) != 0
	)

# the conditions among fields, in order, each with the text parameters that follow it
pub fn conditionsIn(body u8[], fields Field[]) Condition[]:
	out = []
	for f in fields:
		if f.tag == "CTDA" and f.size >= 28: out.push(conditionAt(body, f.at, f.size))
		elif f.tag == "CIS1" and not out.isEmpty: out[len - 1].text1 = body.cStringAt(f.at)
		elif f.tag == "CIS2" and not out.isEmpty: out[len - 1].text2 = body.cStringAt(f.at)
	out

pub fn conditionText(c Condition) str:
	name = conditionFunctions.get(c.function) ?? "function {c.function}"
	value = "global {c.global:08X}" if c.useGlobal else "{c.value}"
	op = operators[c.op] if c.op < operators.len else "?"
	"{name}({c.param1:X}) {op} {value}{" OR" if c.orNext else ""}"

# whether x stands in the condition's relation to value
pub fn holds(c Condition, x f32, value f32) bool:
	match c.op:
		0: x == value
		1: x != value
		2: x > value
		3: x >= value
		4: x < value
		_: x <= value

# a quest's DNAM flag: the game starts it with a new game (Start Game Enabled)
pub questStartGameEnabled = 0x1

# whether the quest record's DNAM says the game starts it with a new game
pub fn startsWithGame(r Record) bool:
	at = dataOf(r.fields, "DNAM") ?? return false
	(r.body.u16le(at) & questStartGameEnabled) != 0

# a quest record's stages (INDX: the stage, then flags, 2 the start-up stage) and its start-up
# stage, 0 for none
pub fn questStages(r Record) (i64[], i64):
	stages = []
	start = -1
	for f in r.fields:
		if f.tag != "INDX" or f.size < 3: continue
		stage = i64(r.body.u16le(f.at))
		stages.push(stage)
		if (r.body[f.at + 2] & 2) != 0 and start < 0: start = stage
	(stages, start)

fn questStarted(mut e Esm, quest i64):
	(e.recordOf(quest) ?? return false).startsWithGame()

# the stage a quest is at when a new game starts: its start-up stage when the game starts it, else 0
fn startStage(mut e Esm, quest i64):
	r = e.recordOf(quest) ?? return 0
	if not r.startsWithGame(): return 0
	_, start = r.questStages()
	start.max(0)

fn globalValue(mut e Esm, global i64) f32:
	r = e.recordOf(global) ?? return 0.0
	at = dataOf(r.fields, "FLTV") ?? return 0.0
	r.body.f32le(at)

# What a condition's function gives when a new game starts, for an actor at `location`; none for
# a function that needs the running game.
fn newGameValue(mut e Esm, c Condition, location i64) f32?:
	match c.function:
		58: f32(e.startStage(c.param1))
		59: 1.0 if c.param2 == e.startStage(c.param1) and e.questStarted(c.param1) else 0.0
		56: 1.0 if e.questStarted(c.param1) else 0.0
		74: e.globalValue(c.param1)
		46, 62, 75, 448: 0.0
		359: 1.0 if c.param1 == location else 0.0
		_: none

# Whether the conditions hold when a new game starts for an actor at `location` (a LCTN), ORs
# binding first; none when one of them needs the running game.
pub fn newGameHolds(mut e Esm, conditions Condition[], location i64) bool?:
	all = true
	group = false
	for c in conditions:
		x = try e.newGameValue(c, location)
		value = e.globalValue(c.global) if c.useGlobal else c.value
		group = group or c.holds(x, value)
		if c.orNext: continue
		all = all and group
		group = false
	all

# Whether the conditions hold as the game reads them while it runs: the ORs binding first, each
# group asked in order and the first group that fails ending the reading (the conditions after it
# are never asked).
pub fn groupsHold(conditions Condition[], holds fn(Condition) bool) bool:
	group = false
	open = false
	for c in conditions:
		group = group or holds(c)
		open = c.orNext
		if open: continue
		if not group: return false
		group = false
	group or not open
