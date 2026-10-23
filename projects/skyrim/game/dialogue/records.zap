# The dialogue of a plugin as its records hold it (layouts after UESP's Skyrim Mod File Format
# pages DIAL, DLBR, INFO and QUST, and xEdit's wbDefinitionsTES5). A topic (DIAL) belongs to a
# quest, has a priority, a branch and a subtype (SNAM: HELO the hello, GBYE the goodbye, CUST a
# topic the player picks, RUMO the rumors, IDAT and IDLE the idles...); its children group (type
# 7) holds its responses (INFO) in the order the game tries them. A branch (DLBR) starts at a
# topic and is top-level (shown in the menu), blocking (said before the hello) or exclusive (only
# its own topics shown). An INFO has flags (goodbye, random, say once...), the hours before it is
# said again, the topics it links to (TCLT), the responses (TRDT: emotion, number, sound; NAM1:
# the line's id in the .ILSTRINGS), the conditions, the prompt (RNAM), a speaker and its scripts.

import skyrim.esm

# an INFO's flags (ENAM, or DATA in the older layout)
pub flagGoodbye = 0x1
pub flagRandom = 0x2
pub flagSayOnce = 0x4
pub flagRandomEnd = 0x20
pub flagInvisibleContinue = 0x40
pub flagWalkAway = 0x80

# a branch's flags (DNAM)
pub branchTopLevel = 0x1
pub branchBlocking = 0x2
pub branchExclusive = 0x4

pub type Topic:
	formId i64
	editorId str
	quest i64
	branch i64   # 0 for none
	priority f32
	category i64   # DATA's second byte: 0 a topic, 1 a favor, 2 a scene, 3 combat, 5 detection, 6 a service, 7 misc
	subtype str   # SNAM
	nameId i64   # FULL: the prompt's id in the .STRINGS, 0 for none
	infos i64[]   # in the order the game tries them

# one line of a response (TRDT then NAM1)
pub type Response:
	number i64
	emotion i64   # 0 neutral, 1 anger, 2 disgust, 3 fear, 4 sad, 5 happy, 6 surprise, 7 puzzled
	emotionValue i64
	sound i64   # a SNDR the line plays in place of its voice file, 0 for none
	textId i64

pub type Info:
	formId i64
	topic i64
	quest i64   # the topic's
	flags i64
	resetHours f32   # 0: said again at once
	links i64[]   # TCLT: the topics it leads to
	sharedInfo i64   # DNAM: the INFO whose responses it says, 0 for its own
	responses Response[]
	conditions esm.Condition[]
	promptId i64   # RNAM: the prompt in place of the topic's, 0 for none
	speaker i64   # ANAM: the actor base that says it, 0 for any
	vmad u8[]   # the VMAD field's bytes, empty for none

pub type Branch:
	formId i64
	editorId str
	quest i64
	flags i64
	start i64   # the topic it starts at

pub type Dialogue:
	topics {i64: Topic}
	infos {i64: Info}
	branches {i64: Branch}
	quests {i64: Quest}

fn hasFlag(flags i64, flag i64):
	(flags & flag) != 0

pub fn isGoodbye(i Info) bool:
	hasFlag(i.flags, flagGoodbye)

pub fn isRandom(i Info) bool:
	hasFlag(i.flags, flagRandom)

pub fn isSayOnce(i Info) bool:
	hasFlag(i.flags, flagSayOnce)

pub fn isInvisibleContinue(i Info) bool:
	hasFlag(i.flags, flagInvisibleContinue)

pub fn isTopLevel(b Branch) bool:
	hasFlag(b.flags, branchTopLevel)

pub fn isBlocking(b Branch) bool:
	hasFlag(b.flags, branchBlocking)

pub fn isExclusive(b Branch) bool:
	hasFlag(b.flags, branchExclusive)

fn u32Of(r esm.Record, tag str) i64:
	at = esm.dataOf(r.fields, tag) ?? return 0
	r.body.u32le(at)

# SNAM's four letters
fn subtypeOf(r esm.Record):
	at = esm.dataOf(r.fields, "SNAM") ?? return ""
	str(r.body[at..at + 4])

fn topicOf(r esm.Record):
	data = esm.dataOf(r.fields, "DATA") ?? 0
	priority = esm.dataOf(r.fields, "PNAM")
	Topic(
		formId = r.formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		quest = r.u32Of("QNAM"),
		branch = r.u32Of("BNAM"),
		priority = r.body.f32le(priority ?? 0) if priority != none else 50.0,
		category = r.body[data + 1] if r.body.len > data + 1 else 0,
		subtype = r.subtypeOf(),
		nameId = r.u32Of("FULL"),
		infos = []
	)

fn responseAt(r esm.Record, at i64):
	Response(
		number = r.body[at + 12],
		emotion = r.body.u32le(at),
		emotionValue = r.body.u32le(at + 4),
		sound = r.body.u32le(at + 16),
		textId = 0
	)

# ENAM's flags and hours (0xFFFF is 24), or the older DATA's flags and days
fn timing(r esm.Record) (i64, f32):
	if esm.dataOf(r.fields, "ENAM") is at:
		return (r.body.u16le(at), f32(r.body.u16le(at + 2)) * 24.0 / 65_535.0)
	at = esm.dataOf(r.fields, "DATA") ?? return (0, 0.0)
	(r.body.u16le(at + 2), r.body.f32le(at + 4) * 24.0)

fn infoOf(r esm.Record, t Topic):
	flags, hours = r.timing()
	responses = []
	for f in r.fields:
		match f.tag:
			"TRDT": responses.push(r.responseAt(f.at))
			"NAM1":
				if not responses.isEmpty: responses[len - 1].textId = r.body.u32le(f.at)
			_: pass
	Info(
		formId = r.formId,
		topic = t.formId,
		quest = t.quest,
		flags,
		resetHours = hours,
		links = esm.formsOf(r.body, r.fields, "TCLT"),
		sharedInfo = r.u32Of("DNAM"),
		responses,
		conditions = esm.conditionsIn(r.body, r.fields),
		promptId = r.u32Of("RNAM"),
		speaker = r.u32Of("ANAM"),
		vmad = esm.bytesOf(r.body, r.fields, "VMAD")
	)

fn branchOf(r esm.Record):
	Branch(
		formId = r.formId,
		editorId = esm.textOf(r.body, r.fields, "EDID"),
		quest = r.u32Of("QNAM"),
		flags = r.u32Of("DNAM"),
		start = r.u32Of("SNAM")
	)

# the record whose header is at `at` in the group's bytes d
fn recordIn(d u8[], h esm.Head):
	body = esm.recordBody(d, h.at, h.flags, h.span) ?? fail("{h.kind} {h.formId:08X}: {error}")
	esm.Record(
		kind = h.kind.copy(),
		formId = h.formId,
		flags = h.flags,
		fields = esm.fieldsOf(body),
		body
	)

# the INFOs of a topic's children group (between from and end of d)
fn readInfos(mut out Dialogue, d u8[], from i64, end i64, mut t Topic):
	at = from
	while at < end:
		h = esm.headAt(d, at)
		at += h.span
		if h.isGroup or h.kind != "INFO" or (h.flags & 0x20) != 0: continue
		h.at = at - h.span
		out.infos[h.formId] = d.recordIn(h).infoOf(t)
		t.infos.push(h.formId)

# every topic of the DIAL group with its INFOs
fn readTopics(mut out Dialogue, mut plugin esm.Esm):
	g = plugin.topGroup("DIAL") ?? return
	d = plugin.file.readAt(g.at, g.span) ?? fail("{plugin.path}: DIAL is cut short")
	at = 24
	while at < d.len:
		h = esm.headAt(d, at)
		h.at = at
		if h.isGroup and h.groupType == 7 and out.topics.get(h.label) != none:
			t = out.topics[h.label].copy()
			out.readInfos(d, at + 24, at + h.span, t)
			out.topics[h.label] = t
		elif not h.isGroup and h.kind == "DIAL":
			out.topics[h.formId] = d.recordIn(h).topicOf()
		at += h.span

# every record of a top group of the plugin
pub fn groupRecords(mut plugin esm.Esm, kind str) esm.Record[]:
	g = plugin.topGroup(kind) ?? return []
	d, heads = plugin.topRecords(g)
	heads.map(d.recordIn(it))

# The dialogue of the plugin: its topics with their INFOs, its branches and its quests.
pub fn readDialogue(mut plugin esm.Esm) Dialogue:
	out = Dialogue(topics = {}, infos = {}, branches = {}, quests = {})
	out.readTopics(plugin)
	for r in plugin.groupRecords("DLBR"):
		out.branches[r.formId] = r.branchOf()
	for r in plugin.groupRecords("QUST"):
		out.quests[r.formId] = r.questOf()
	out

# the INFO whose responses an INFO says: itself, or the one it shares them with
pub fn spokenId(d Dialogue, i Info) i64:
	if i.sharedInfo != 0 and d.infos.get(i.sharedInfo) != none: return i.sharedInfo
	i.formId
