# An actor's AI packages (PACK): what it does, when and where. PKDT's flags and type (0x12 a
# package, 0x13 a template), PSDT's schedule (month, day of the week, date, hour, minute, the
# duration in minutes), PKCU's template (the package a template's procedures come from: Sandbox,
# Sleep, Eat, UseIdleMarker, Travel, Patrol...), the data inputs (PLDT a location, PTDA a target)
# and the conditions. The game tries an actor's packages in its list's order and runs the first
# whose conditions hold and whose schedule takes in the hour. Layout after UESP's Skyrim Mod File
# Format (PACK) and xEdit's definitions.

import skyrim.esm

# PLDT's kinds of location, by number
pub locationKinds = [
	"near reference", "in cell", "near current location", "near editor location", "object id",
	"object type", "near linked reference", "at package location", "alias reference",
	"alias location", "kind 10", "kind 11", "near self"
]

# PTDA's kinds of target, by number
pub targetKinds = [
	"specific reference", "object id", "object type", "linked reference", "alias reference",
	"interrupt data", "self", "keyword"
]

# PSDT: -1 (0 for the date) where it takes any
pub type Schedule:
	month i64
	dayOfWeek i64   # 0 Sunday to 6 Saturday, 7 weekdays, 8 weekends, 9 Monday Wednesday Friday, 10 Tuesday Thursday
	date i64
	hour i64
	minute i64
	duration i64   # minutes

# a place a package names: what kind, the form (or object type) and the radius around it
pub type Place:
	kind i64
	form i64
	radius i64

pub type Package:
	formId i64
	editorId str
	flags i64
	template str   # the editor id of the template the procedures come from, its own when it is one
	procedures str[]   # the template's procedures in the order the tree names them
	schedule Schedule
	location Place?
	target Place?
	conditions esm.Condition[]
	inputs {str: f32}   # its template's bool, int and float inputs by name in lower case

fn signedByte(b u8):
	i64(b) - 256 if b > 127 else b

fn scheduleOf(r esm.Record):
	at = esm.dataOf(r.fields, "PSDT") ??
		return Schedule(month = -1, dayOfWeek = -1, date = 0, hour = -1, minute = -1, duration = 0)
	Schedule(
		month = signedByte(r.body[at]),
		dayOfWeek = signedByte(r.body[at + 1]),
		date = r.body[at + 2],
		hour = signedByte(r.body[at + 3]),
		minute = signedByte(r.body[at + 4]),
		duration = r.body.i32le(at + 8)
	)

fn placeOf(r esm.Record, tag str) Place?:
	at = try esm.dataOf(r.fields, tag)
	Place(kind = r.body.i32le(at), form = r.body.u32le(at + 4), radius = r.body.i32le(at + 8))

# whether the package's place is an alias (a quest's reference or location): it runs only while
# that quest fills the alias, which a new game's cells do not have
pub fn isPlacedByAlias(p Package) bool:
	(p.location?.kind) == 8 or (p.location?.kind) == 9

# the package's own conditions: those before its data inputs and procedure tree
fn ownConditions(r esm.Record):
	end = r.fields.findIndex(.tag == "PKCU") ?? r.fields.len
	esm.conditionsIn(r.body, r.fields[..end])

# the procedures a template's tree names: the first PNAM after each ANAM "Procedure"
fn proceduresOf(r esm.Record):
	out = []
	inProcedure = false
	for f in r.fields:
		if f.tag == "ANAM": inProcedure = r.body.cStringAt(f.at) == "Procedure"
		if inProcedure and f.tag == "PNAM":
			out.push(r.body.cStringAt(f.at))
			inProcedure = false
	out

# the template a package's procedures come from: PKCU's, followed to a template that names none
fn templateOf(mut plugin esm.Esm, r esm.Record):
	at = r.copy()
	loop 8:
		pk = esm.dataOf(at.fields, "PKCU") ?? return at
		next = i64(at.body.u32le(pk + 4))
		if next == 0: return at
		at = plugin.recordOf(next) ?? return at
	at

# the values of the package's data inputs (ANAM a type, CNAM its value: a byte for a bool, an
# int or a float) by their names in the template (its UNAM's index followed by BNAM's name), the
# package's own UNAMs giving each input's index in order
fn inputsOf(r esm.Record, template esm.Record):
	names {i64: str} = {}
	for k in 0..template.fields.len - 1:
		f = template.fields[k]
		if f.tag == "UNAM" and template.fields[k + 1].tag == "BNAM":
			names[i64(template.body[f.at])] = template.body
				.cStringAt(template.fields[k + 1].at)
				.lower()
	start = (r.fields.findIndex(.tag == "PKCU") ?? r.fields.len) + 1
	values = []
	indices = []
	for k in start..r.fields.len:
		f = r.fields[k]
		if f.tag == "UNAM": indices.push(i64(r.body[f.at]))
		if f.tag != "ANAM" or not indices.isEmpty: continue
		kind = r.body.cStringAt(f.at)
		next = r.fields[k + 1] if k + 1 < r.fields.len else f
		values.push(r.body.inputValue(kind, next))
	out {str: f32} = {}
	for k in 0..values.len.min(indices.len):
		if values[k] is v: out[(names.get(indices[k]) ?? "input {indices[k]}").copy()] = v
	out

# a bool's, an int's or a float's value in its CNAM
fn inputValue(body u8[], kind str, f esm.Field) f32?:
	if f.tag != "CNAM": return none
	match kind:
		"Bool": f32(body[f.at])
		"Int": f32(body.i32le(f.at))
		"Float": body.f32le(f.at)
		_: none

# the package with this form id read, none when the plugin has no such package
pub fn packageOf(mut plugin esm.Esm, formId i64) Package?:
	r = try plugin.recordOf(formId)
	if r.kind != "PACK": return none
	pk = try esm.dataOf(r.fields, "PKDT")
	template = plugin.templateOf(r)
	Package(
		formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		flags = r.body.u32le(pk),
		template = esm.textOf(template.body, template.fields, "EDID"),
		procedures = template.proceduresOf(),
		schedule = r.scheduleOf(),
		location = r.placeOf("PLDT"),
		target = r.placeOf("PTDA"),
		conditions = r.ownConditions(),
		inputs = r.inputsOf(template)
	)

# the actor's packages, in the order the game tries them
pub fn packagesOf(mut plugin esm.Esm, npc Npc) Package[]:
	out = []
	for id in npc.packages:
		if plugin.packageOf(id) is p: out.push(p)
	out

# The packages of the actor a placed actor (ACHR) is of, in the order the game tries them, its
# templates followed for its AI packages.
pub fn npcPackages(mut plugin esm.Esm, achr esm.Record) Package[]:
	npc = plugin.npcOf(achr.achrBase()) ?? return []
	plugin.packagesOf(npc)

fn dayMatches(day i64, want i64):
	match want:
		-1: true
		7: day >= 1 and day <= 5
		8: day == 0 or day == 6
		9: day in [1, 3, 5]
		10: day == 2 or day == 4
		_: day == want

# whether the schedule takes in the hour (0 to 24) of the day of the week (0 Sunday); a window
# that passes midnight goes on into the next day
pub fn scheduleMatches(s Schedule, gameHour f32, dayOfWeek i64) bool:
	if not dayMatches(dayOfWeek, s.dayOfWeek): return false
	if s.hour < 0: return true
	start = f32(s.hour) + f32(s.minute.max(0)) / 60.0
	since = (gameHour - start + 24.0) % 24.0
	since < f32(s.duration) / 60.0

# the first package whose schedule takes in the hour and day, of those `allowed` lets run
fn firstScheduled(packages Package[], allowed bool[], gameHour f32, dayOfWeek i64) Package?:
	for k, p in packages:
		if allowed[k] and p.schedule.scheduleMatches(gameHour, dayOfWeek): return p.copy()
	none

# The package the game runs at this hour and day by the schedules alone: the first in the list
# that takes in the hour, a package with conditions passed over (their truth needs the running
# game; activePackageAtStart reads a new game's).
pub fn activePackage(packages Package[], gameHour f32, dayOfWeek i64) Package?:
	packages.firstScheduled(packages.map(.conditions.isEmpty), gameHour, dayOfWeek)

# The package the game runs at this hour and day of a new game for an actor at `location` (its
# ACHR's XLCN): the conditions read as a new game has them, those that need the running game
# taken as false.
pub fn activePackageAtStart(
	mut plugin esm.Esm,
	packages Package[],
	gameHour f32,
	dayOfWeek i64,
	location i64
) Package?:
	allowed = []
	for p in packages:
		allowed.push(plugin.newGameHolds(p.conditions, location) ?? false)
	packages.firstScheduled(allowed, gameHour, dayOfWeek)

pub fn scheduleText(s Schedule) str:
	if s.hour < 0: return "any time"
	end = (s.hour * 60 + s.minute.max(0) + s.duration) % 1440
	days = "" if s.dayOfWeek < 0 else " day {s.dayOfWeek}"
	"{s.hour:02}:{s.minute.max(0):02} to {end / 60:02}:{end % 60:02}{days}"
