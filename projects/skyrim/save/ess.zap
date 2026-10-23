# The .ess file, after UESP's "Skyrim Mod:Save File Format" for Special Edition (form version 78,
# checked against a real save of the player's): "TESV_SAVEGAME", the header (name, level,
# location, play time, race, time written, screenshot size), the screenshot (RGBA), then the body
# as one LZ4 block behind its two lengths: the plugins, the file location table, the global data
# tables (types below 100, 100 to 999, from 1000), the change forms, the form id array, the
# worlds visited and a third table. A table's offsets count from the end of the screenshot.
# Change forms are UESP's records (a 3-byte RefID, flags, type, version, lengths, data) with data
# of ours: for each flag set, ascending, the length of one part's bytes (all ones for a part that
# is gone) and the bytes (see entries.zap for the parts, assemble.zap for the global data).

import engine
import lz4

magic = "TESV_SAVEGAME"
formVersion = 78
saveVersion = 12
compressionLz4 = 2
# the form id array's value for a RefID that names no id by itself
gonePart = 0xFFFF_FFFF
# ids below this fit a RefID of type 1 (default plugin) or 2 (created)
refIdLimit = 0x40_0000

pub type Header:
	saveNumber i64
	name str
	level i64
	location str
	playTime str   # "days.hours.minutes" played
	race str
	female bool
	curExp f32 = 0.0
	levelUpExp f32 = 100.0
	filetime i64 = 0
	shotWidth i64 = 0
	shotHeight i64 = 0

pub type Ess:
	header Header
	shot u8[]   # RGBA, shotWidth x shotHeight
	plugins str[]
	blocks Block[]
	changes Entry[]
	visited i64[] = []   # the worldspaces visited

# the form ids a RefID names by index, in the order they are first met
type FormIds:
	list i64[] = []

fn indexOf(mut ids FormIds, id i64):
	k = ids.list.indexOf(id) ?? ids.list.push(id)
	k + 1

# the 3 bytes of a RefID: its type in the high 2 bits, its value in the rest
fn pushRefId(mut out u8[], mut ids FormIds, id i64):
	if id >> 24 == 0xFF and (id & 0xFF_FFFF) < refIdLimit:
		out.pushU24be((2 << 22) | (id & 0xFF_FFFF))
	elif id < refIdLimit:
		out.pushU24be((1 << 22) | id)
	else:
		out.pushU24be(ids.indexOf(id))

fn refIdOf(raw i64, ids i64[]) i64 ? str:
	value = raw & 0x3F_FFFF
	match raw >> 22:
		0:
			if value < 1 or value > ids.len: return "a RefID names form id {value}, past the array"
			ids[value - 1]
		1: value
		2: 0xFF00_0000 | value
		_: return "a RefID of type 3"

# one change form: the entries of a form id and type, as UESP's record
fn pushChangeForm(mut out u8[], mut ids FormIds, group Group):
	flags = 0
	data = []
	for e in group.entries:
		flags |= 1 << e.part
	for part in 0..32:
		for e in group.entries:
			if e.part != part: continue
			data.pushU32le(gonePart if e.gone else e.data.len)
			if not e.gone: data.extend(e.data)
	out.pushRefId(ids, group.entries[0].refId)
	out.pushU32le(flags)
	code = data.len.widthCode()
	out.push(u8(group.entries[0].kind | code << 6))
	out.push(formVersion)
	out.pushWidth(data.len, code)
	out.pushWidth(0, code)
	out.extend(data)

pub type Group:
	entries Entry[]

# the change forms in groups of one id and type, in the order the entries come
fn groupsOf(changes Entry[]):
	order = []
	groups {i64: Group} = {}
	for e in changes:
		key = keyOf(e.kind, e.refId, 0)
		if groups.get(key) == none:
			groups[key] = Group(entries = [])
			order.push(key)
		groups[key].entries.push(e.copy())
	order.map(groups[it].copy())

fn pushBlocks(mut out u8[], blocks Block[]):
	for b in blocks:
		out.pushU32le(b.kind)
		out.pushU32le(b.data.len)
		out.extend(b.data)

pub fn headerBytes(h Header) u8[]:
	out = []
	out.pushU32le(saveVersion)
	out.pushU32le(h.saveNumber)
	out.pushString16(h.name)
	out.pushU32le(h.level)
	out.pushString16(h.location)
	out.pushString16(h.playTime)
	out.pushString16(h.race)
	out.pushU16le(1 if h.female else 0)
	out.pushF32le(h.curExp)
	out.pushF32le(h.levelUpExp)
	out.pushU64le(h.filetime)
	out.pushU32le(h.shotWidth)
	out.pushU32le(h.shotHeight)
	out.pushU16le(compressionLz4)
	out

fn pluginInfo(plugins str[]):
	out = []
	out.push(u8(plugins.len))
	for p in plugins:
		out.pushString16(p)
	out

# where the tables lie and how many entries they hold: the 10 numbers of the file location table
type Locations:
	formIds i64 = 0
	unknownTable i64 = 0
	globals1 i64 = 0
	globals2 i64 = 0
	changeForms i64 = 0
	globals3 i64 = 0
	count1 i64 = 0
	count2 i64 = 0
	count3 i64 = 0
	countForms i64 = 0

pub fn pushLocations(mut out u8[], l Locations):
	for v in [l.formIds, l.unknownTable, l.globals1, l.globals2, l.changeForms, l.globals3,
		l.count1, l.count2, l.count3, l.countForms]:
		out.pushU32le(v)
	loop 15:
		out.pushU32le(0)

# the body: its tables laid out, the offsets counted from `base`
fn bodyBytes(e Ess, base i64):
	ids = FormIds()
	body u8[] = []
	body.push(formVersion)
	info = pluginInfo(e.plugins)
	body.pushU32le(info.len)
	body.extend(info)
	table = body.len
	body.pushLocations(Locations())
	l = Locations()
	first = e.blocks.filter(.kind < 100)
	second = e.blocks.filter(.kind >= 100 and .kind < 1000)
	third = e.blocks.filter(.kind >= 1000)
	groups = groupsOf(e.changes)
	l.globals1 = base + body.len
	body.pushBlocks(first)
	l.globals2 = base + body.len
	body.pushBlocks(second)
	l.changeForms = base + body.len
	for g in groups:
		body.pushChangeForm(ids, g)
	l.globals3 = base + body.len
	body.pushBlocks(third)
	l.formIds = base + body.len
	body.pushU32le(ids.list.len)
	for id in ids.list:
		body.pushU32le(id)
	body.pushU32le(e.visited.len)
	for id in e.visited:
		body.pushU32le(id)
	l.unknownTable = base + body.len
	body.pushU32le(0)
	l.count1 = first.len
	l.count2 = second.len
	l.count3 = third.len
	l.countForms = groups.len
	patch u8[] = []
	patch.pushLocations(l)
	for k in 0..patch.len:
		body[table + k] = patch[k]
	body

# The file's bytes.
pub fn writeEss(e Ess) u8[]:
	head = e.header.headerBytes()
	out = []
	for c in magic.bytes():
		out.push(c)
	out.pushU32le(head.len)
	out.extend(head)
	out.extend(e.shot)
	body = e.bodyBytes(out.len)
	packed = lz4.encodeBlock(body)
	out.pushU32le(body.len)
	out.pushU32le(packed.len)
	out.extend(packed)
	out

# a file's header, its screenshot, and its body unpacked, with the offset the body's tables count from
pub type Container:
	header Header
	shot u8[]
	body u8[]
	base i64

fn readHeader(mut r Reader) Header ? str:
	version = r.u32()
	if version != saveVersion: return "save version {version}, not {saveVersion}"
	number = i64(r.u32())
	name = r.string16()
	level = i64(r.u32())
	location = r.string16()
	played = r.string16()
	race = r.string16()
	female = r.u16() != 0
	exp = r.f32()
	needed = r.f32()
	filetime = i64(r.u64())
	w = i64(r.u32())
	h = i64(r.u32())
	compression = r.u16()
	if compression != compressionLz4: return "compression type {compression} is not read"
	if r.short: return "the header is cut short"
	Header(
		saveNumber = number,
		name,
		level,
		location,
		playTime = played,
		race,
		female,
		curExp = exp,
		levelUpExp = needed,
		filetime,
		shotWidth = w,
		shotHeight = h
	)

# the file's parts: header, screenshot, the body unpacked
pub fn containerOf(d u8[]) Container ? str:
	if not d.startsWith(magic): return "not a Skyrim save"
	r = Reader(d, at = magic.bytes().len + 4)
	header = try r.readHeader()
	shotBytes = header.shotWidth * header.shotHeight * 4
	if not r.has(shotBytes + 8): return "the screenshot is cut short"
	shot = r.bytes(shotBytes)
	base = r.at
	unpacked = i64(r.u32())
	packed = i64(r.u32())
	if not r.has(packed): return "the body is cut short"
	body = try lz4.decodeBlock(r.bytes(packed), unpacked)
	Container(header, shot, body, base)

# the header of a file, read without unpacking its body (what a list of saves shows)
pub fn headerOf(d u8[]) Header ? str:
	if not d.startsWith(magic): return "not a Skyrim save"
	r = Reader(d, at = magic.bytes().len + 4)
	r.readHeader()

fn readLocations(mut r Reader):
	l = Locations(
		formIds = r.u32(),
		unknownTable = r.u32(),
		globals1 = r.u32(),
		globals2 = r.u32(),
		changeForms = r.u32(),
		globals3 = r.u32(),
		count1 = r.u32(),
		count2 = r.u32(),
		count3 = r.u32(),
		countForms = r.u32()
	)
	r.skip(60)
	l

# the body's plugin names and its file location table
pub type BodyHead:
	plugins str[]
	tableAt i64   # where the file location table starts in the body
	locations Locations

pub fn headOf(c Container) BodyHead ? str:
	r = Reader(c.body)
	version = r.u8()
	if version != formVersion: return "form version {version}, not {formVersion}"
	size = i64(r.u32())
	start = r.at
	plugins = []
	loop r.u8():
		plugins.push(r.string16())
	r.at = start + size
	table = r.at
	l = r.readLocations()
	if r.short: return "the file location table is cut short"
	BodyHead(plugins, tableAt = table, locations = l)

# a table of global data of `count` blocks from `at`
pub fn blocksFrom(c Container, at i64, count i64) Block[] ? str:
	r = Reader(c.body, at = at - c.base)
	out = []
	loop count:
		kind = i64(r.u32())
		size = i64(r.u32())
		if not r.has(size): return "a global data block is cut short"
		out.push(Block(kind, data = r.bytes(size)))
	out

# one change form as the file holds it
pub type RawChange:
	refId i64
	kind i64
	flags i64
	version i64
	data u8[]
	packed bool   # its data is compressed (the game's own saves': not read)

# the change forms of the file, with the form ids their RefIDs may name
pub fn changeFormsFrom(c Container, l Locations) RawChange[] ? str:
	r = Reader(c.body, at = l.formIds - c.base)
	ids = []
	loop r.u32():
		ids.push(i64(r.u32()))
	r.at = l.changeForms - c.base
	out = []
	loop l.countForms:
		raw = r.u24be()
		flags = i64(r.u32())
		typeByte = i64(r.u8())
		version = i64(r.u8())
		code = typeByte >> 6
		size = r.readWidth(code)
		unpacked = r.readWidth(code)
		if not r.has(size): return "a change form is cut short"
		out.push(RawChange(
			refId = try refIdOf(raw, ids),
			kind = typeByte & 63,
			flags,
			version,
			data = r.bytes(size),
			packed = unpacked != 0
		))
	out

# the parts of a change form of ours, as entries
fn partsOf(c RawChange) Entry[] ? str:
	r = Reader(c.data)
	out = []
	for part in 0..32:
		if c.flags & (1 << part) == 0: continue
		size = i64(r.u32())
		if size == gonePart:
			out.push(Entry(kind = c.kind, refId = c.refId, part, data = [], gone = true))
			continue
		if not r.has(size): return "the change form {c.refId:08X} is cut short"
		out.push(Entry(kind = c.kind, refId = c.refId, part, data = r.bytes(size)))
	out

# The file read whole, or why it cannot be.
pub fn readEss(d u8[]) Ess ? str:
	c = try containerOf(d)
	head = try c.headOf()
	l = head.locations
	blocks = try c.blocksFrom(l.globals1, l.count1)
	blocks.extend(try c.blocksFrom(l.globals2, l.count2))
	blocks.extend(try c.blocksFrom(l.globals3, l.count3))
	changes = []
	for raw in try c.changeFormsFrom(l):
		if raw.packed: return "the change form {raw.refId:08X} is compressed"
		changes.extend(try raw.partsOf())
	r = Reader(c.body, at = l.formIds - c.base)
	loop r.u32():
		r.skip(4)
	visited = []
	loop r.u32():
		visited.push(i64(r.u32()))
	Ess(
		header = c.header.copy(),
		shot = c.shot.copy(),
		plugins = head.plugins.copy(),
		blocks,
		changes,
		visited
	)
