# Bethesda's plugin files (Skyrim.esm, Update.esm), read where they lie. A file is a TES4 header
# record then top groups (GRUP, labelled by the record type they hold). A record has a 24-byte
# header (type, data size, flags, form id, stamp, version) then its data, which is a u32 size and
# a zlib stream when flag 0x40000 is set; a group has a 24-byte header (GRUP, size including the
# header, label, group type, stamp, version) then records and groups. Only the table of top
# groups is kept; a group is read when it is asked for.

import fs
import deflate

# The game's Data dir as fetch.zap copies it into the repository (never committed): the project
# reads the game from there alone.
pub defaultData = "projects/skyrim/assets/game/Data"

# Stops a tool that writes under projects/skyrim/assets when it runs outside the repository's
# root: the asset dirs are relative to it, and from elsewhere they would land outside .gitignore.
pub fn requireRepoRoot():
	if not fs.exists("projects/skyrim/main.zap"):
		fail("run from the repository's root: the game's files go under projects/skyrim/assets")

# the path of the plugin `name` ("Skyrim.esm") in the Data dir `dir`
pub fn pluginPath(dir str, name str) str:
	"{dir}/{name}"

# Skyrim.esm of the game's fetched Data dir
pub fn defaultEsm() str:
	pluginPath(defaultData, "Skyrim.esm")

headerSize = 24
pub flagCompressed = 0x4_0000

# One record or group header. `span` is the bytes it takes with its data, and for a group with
# everything inside it; `at` is the offset in the bytes the header was read from. A group's `kind`
# is its label as text (a record type for a top group) and `label` the same four bytes as a number
# (a cell's form id for the children of a cell).
pub type Head:
	isGroup bool
	kind str
	label i64
	groupType i64
	formId i64
	flags i64
	at i64
	span i64

pub type Esm:
	path str
	file fs.File
	tops Head[]   # the top groups, in file order
	bases {i64: BaseSlot}   # filled on first use (base.zap)
	overlays Esm[]   # the plugins loaded after it, whose records replace its own, last winning
	refCells {i64: i64} = {}   # the interior cell each placed reference is in, read on first use (cell.zap)
	cellAts {i64: i64} = {}   # the file offset of each interior cell's record, by its form id
	refCellsRead bool = false

# the header at `at` in bytes d
pub fn headAt(d u8[], at i64) Head:
	if d.matchesAt(at, "GRUP"):
		return Head(
			isGroup = true,
			kind = str(d[at + 8..at + 12]),
			label = d.u32le(at + 8),
			groupType = d.i32le(at + 12),
			formId = 0,
			flags = 0,
			at,
			span = d.u32le(at + 4)
		)
	Head(
		isGroup = false,
		kind = str(d[at..at + 4]),
		label = 0,
		groupType = 0,
		formId = d.u32le(at + 12),
		flags = d.u32le(at + 8),
		at,
		span = headerSize + d.u32le(at + 4)
	)

# the groups side by side between `from` and `end` of the file (levels that hold only groups:
# the top, a block of cells), their headers read without their contents
pub fn groupsIn(f fs.File, from i64, end i64) Head[] ? str:
	out = []
	at = from
	while at < end:
		raw = f.readAt(at, headerSize) ?? return "the file is cut short at {at}"
		h = headAt(raw, 0)
		if not h.isGroup: return "a record where a group is expected, at {at}"
		span = h.span
		h.at = at
		out.push(h)
		at += span
	out

# The masters the game loads after Skyrim.esm, in its load order. Each one's master list is the
# start of this order, so a form id means the same record in every one of them and in the game.
pub followingMasters = ["Update.esm", "Dawnguard.esm", "HearthFires.esm", "Dragonborn.esm"]

fn openPluginFile(move path str) Esm ? str:
	f = fs.open(path) ?? return "cannot open {path}"
	raw = f.readAt(0, headerSize) ?? return "{path} is too short for a plugin"
	if not raw.matchesAt(0, "TES4"): return "{path} is not a plugin (no TES4 record)"
	groups = try f.groupsIn(headerSize + raw.u32le(4), f.len)
	Esm(path, file = f, tops = groups, bases = {}, overlays = [])

# The plugin at path with its top groups listed, or why it cannot be read. Skyrim.esm comes with
# the following masters beside it as its overlays (Update.esm sets SkyrimClear's colors the game
# shows); a missing one is skipped.
pub fn openEsm(move path str) Esm ? str:
	dir = fs.dirOf(path).copy()
	isSkyrim = fs.fileName(path).lower() == "skyrim.esm"
	e = try openPluginFile(path)
	if isSkyrim:
		for name in followingMasters:
			next = "{dir}/{name}"
			if fs.exists(next): e.overlays.push(try openPluginFile(next))
	e

# the top group of this record type, none when the file has none
pub fn topGroup(e Esm, kind str) Head?:
	for g in e.tops:
		if g.kind == kind: return g.copy()
	none

# every record under the groups between `from` and `end` of bytes d, at any depth, in order;
# `origin` is added to each `at`, for bytes that were read from further into the file
pub fn recordsIn(d u8[], from i64, end i64, origin i64, mut out Head[]):
	at = from
	while at < end:
		h = headAt(d, at)
		span = h.span
		if h.isGroup:
			recordsIn(d, at + headerSize, at + span, origin, out)
		else:
			h.at += origin
			out.push(h)
		at += span

# the bytes of the top group `g` without its header, and every record in them at any depth
pub fn topRecords(e Esm, g Head) (u8[], Head[]):
	d = e.file.readAt(g.at + headerSize, g.span - headerSize) ??
		fail("{e.path}: the {g.kind} group is cut short")
	records = []
	recordsIn(d, 0, d.len, 0, records)
	(d, records)

# the data of the record whose header is at `at` in bytes d, inflated when it is compressed
pub fn recordBody(d u8[], at i64, flags i64, span i64) u8[] ? str:
	data = d[at + headerSize..at + span]
	if (flags & flagCompressed) == 0: return data.copy()
	expected = d.u32le(at + headerSize)
	out = try deflate.inflateZlib(d[at + headerSize + 4..at + span], expected)
	if out.len != expected: return "a record does not inflate ({out.len} of {expected} bytes)"
	out
