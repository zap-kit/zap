# The worldspaces (WRLD): each WRLD record is followed by its children group (type 1, labelled with
# the world's form id), which holds the world's persistent cell with its references first, then
# exterior blocks (type 4) of sub-blocks (5) of cells, each cell followed by its own children. An
# exterior cell's XCLC gives its place on the grid of 4096 units. Layout after UESP's Skyrim Mod
# File Format (Groups, CELL).

groupWorldChildren = 1
groupBlock = 4
groupSubBlock = 5
pub cellSize f32 = 4096.0

# an exterior cell: its record and its place on the world's grid
pub type ExteriorCell:
	world i64
	formId i64
	editorId str
	x i64
	y i64
	location i64   # XLCN, 0 for none
	nameId i64   # FULL, 0 for none

# the world children groups of the plugin, with the world each belongs to
fn worldGroups(e Esm):
	top = e.topGroup("WRLD") ?? return []
	out = []
	at = top.at + headerSize
	while at < top.at + top.span:
		raw = e.file.readAt(at, headerSize) ?? fail("{e.path}: WRLD is cut short")
		h = headAt(raw, 0)
		h.at = at
		if h.isGroup and h.groupType == groupWorldChildren: out.push(h.copy())
		at += h.span
	out

# a world's persistent references: the bytes of its persistent cell's children group, read from
# `from` in the file, and the headers of the records in it
type PersistentRefs:
	world i64
	from i64
	d u8[]
	heads Head[]

fn persistentGroups(e Esm):
	out = []
	for g in e.worldGroups():
		raw = e.file.readAt(g.at + headerSize, headerSize) ?? continue
		cell = headAt(raw, 0)
		if cell.isGroup or cell.kind != "CELL": continue
		from = g.at + headerSize + cell.span
		childRaw = e.file.readAt(from, headerSize) ?? continue
		children = headAt(childRaw, 0)
		if not children.isGroup: continue
		d = e.file.readAt(from, children.span) ??
			fail("{e.path}: a world's references are cut short")
		heads = []
		recordsIn(d, headerSize, d.len, from, heads)
		out.push(PersistentRefs(world = g.label, from, d, heads))
	out

# a persistent record and, for a REFR, the reference it makes
pub type PersistentRecord:
	placed Ref?
	record Record

# the world's persistent records (doors, markers, a few statics, the towns' actors) lying in the
# grid places `cells`, with the reference each REFR makes
pub fn persistentIn(e Esm, world i64, cells (i64, i64)[]) PersistentRecord[]:
	out = []
	for p in e.persistentGroups():
		if p.world != world: continue
		for h in p.heads:
			if h.kind != "REFR" and h.kind != "ACHR": continue
			if (h.flags & flagDeleted) != 0: continue
			r = p.recordOfHead(h)
			at = dataOf(r.fields, "DATA") ?? continue
			if Vec3(
				r.body.f32le(at),
				r.body.f32le(at + 4),
				r.body.f32le(at + 8)
			).gridOf() not in cells:
				continue
			out.push(
				PersistentRecord(
					placed = refAt(r.body, h, true) if h.kind == "REFR" else none,
					record = r
				)
			)
	out

# the references of the world's persistent records lying in the grid places `cells`
pub fn persistentRefsIn(e Esm, world i64, cells (i64, i64)[]) Ref[]:
	out = []
	for placed in e.persistentIn(world, cells):
		if placed.placed is r: out.push(r.copy())
	out

fn recordOfHead(p PersistentRefs, h Head):
	local = p.d[h.at - p.from..h.at - p.from + h.span].copy()
	body = recordBody(local, 0, h.flags, h.span) ?? fail("{h.kind} {h.formId:08X}: {error}")
	Record(kind = h.kind.copy(), formId = h.formId, flags = h.flags, fields = fieldsOf(body), body)

# the placed record with this form id among a world's persistent references (doors that lead
# outside, markers), with the world's form id; none when no world has it
pub fn persistentRef(e Esm, formId i64) (i64, Record)?:
	for p in e.persistentGroups():
		for h in p.heads:
			if h.formId == formId: return (p.world, p.recordOfHead(h))
	none

# the header of the exterior cell at grid place (x, y) in a sub-block's bytes
fn exteriorHeadIn(d u8[], x i64, y i64) Head?:
	at = headerSize
	while at < d.len:
		h = headAt(d, at)
		if not h.isGroup and h.kind == "CELL":
			body = recordBody(d, at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
			grid = dataOf(fieldsOf(body), "XCLC")
			if grid is g and body.i32le(g) == x and body.i32le(g + 4) == y: return h
		at += h.span
	none

# The exterior cell at grid place (x, y) with its references (those the cell's own groups place,
# not the world's persistent ones), none when the world has none there.
pub fn exteriorCellData(e Esm, world i64, x i64, y i64) Cell?:
	d = try e.exteriorSubBlock(world, x, y)
	h = try exteriorHeadIn(d, x, y)
	body = recordBody(d, h.at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
	cellFrom(d, h, body)

fn exteriorIn(d u8[], world i64, x i64, y i64) ExteriorCell?:
	h = try exteriorHeadIn(d, x, y)
	body = recordBody(d, h.at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
	r = Record(kind = "CELL", formId = h.formId, flags = h.flags, body, fields = fieldsOf(body))
	ExteriorCell(
		world,
		formId = h.formId,
		editorId = textOf(r.body, r.fields, "EDID"),
		x,
		y,
		location = r.formOf("XLCN") ?? 0,
		nameId = r.formOf("FULL") ?? 0
	)

# The bytes of the sub-block of the world's cells that holds grid place (x, y), none when the
# world has none there. A block's label holds its y then its x (block = cell / 32, sub-block =
# cell / 8, rounded down).
pub fn exteriorSubBlock(e Esm, world i64, x i64, y i64) u8[]?:
	for g in e.worldGroups():
		if g.label != world: continue
		raw = e.file.readAt(g.at + headerSize, headerSize) ?? return none
		first = headAt(raw, 0)
		from = g.at + headerSize
		if not first.isGroup:
			childRaw = e.file.readAt(from + first.span, headerSize) ?? return none
			from += first.span + headAt(childRaw, 0).span
		blocks = e.file.groupsIn(from, g.at + g.span) ?? fail("{e.path}: {error}")
		for block in blocks.filter(
			.groupType == groupBlock and .label == gridLabel(x.floorDiv(32), y.floorDiv(32))
		):
			subs = e.file.groupsIn(block.at + headerSize, block.at + block.span) ??
				fail("{e.path}: {error}")
			for sub in subs.filter(.label == gridLabel(floorDiv(x, 8), floorDiv(y, 8))):
				return e.file.readAt(sub.at, sub.span) ?? fail("{e.path}: a sub-block is cut short")
	none

# The exterior cell of the world at grid place (x, y), none when the world has none there.
pub fn exteriorCell(e Esm, world i64, x i64, y i64) ExteriorCell?:
	d = try e.exteriorSubBlock(world, x, y)
	exteriorIn(d, world, x, y)

fn ownCellRecord(e Esm, world i64, x i64, y i64) Record?:
	d = try e.exteriorSubBlock(world, x, y)
	h = try exteriorHeadIn(d, x, y)
	body = recordBody(d, h.at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
	Record(kind = "CELL", formId = h.formId, flags = h.flags, body, fields = fieldsOf(body))

# The record of the exterior cell at grid place (x, y), as the last plugin that has it sets it.
pub fn exteriorCellRecord(e Esm, world i64, x i64, y i64) Record?:
	n = e.overlays.len
	for k in 0..n:
		if e.overlays[n - 1 - k].ownCellRecord(world, x, y) is r: return r
	e.ownCellRecord(world, x, y)

fn floorDiv(a i64, b i64):
	(a - ((a % b) + b) % b) / b

# a block's label: y in its low 16 bits and x in its high ones, each signed
fn gridLabel(x i64, y i64):
	((x & 0xFFFF) << 16) | (y & 0xFFFF)

# the grid place of the exterior cell a point lies in
pub fn gridOf(p Vec3) (i64, i64):
	(i64((p.x / cellSize).floor()), i64((p.y / cellSize).floor()))

# The actors placed in interior cells and in the worlds' persistent cells (the towns' people):
# each actor base's first placed reference, by the base's form id.
pub fn placedActors(e Esm) {i64: i64}:
	out = e.interiorActors()
	for p in e.persistentGroups():
		for h in p.heads:
			if h.kind != "ACHR": continue
			base = p.recordOfHead(h).formOf("NAME") ?? continue
			if out.get(base) == none: out[base] = h.formId
	out
