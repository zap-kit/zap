# An interior cell. The top group CELL holds blocks (group type 2) of sub-blocks (3), and a
# sub-block holds cell records, each followed by a group of type 6 (labelled with the cell's form
# id) of persistent (8) and temporary (9) groups of the references placed in it. Cell records are
# usually compressed, so finding one by editor id reads each sub-block and opens each cell record.
import math

pub type Color:
	r i64
	g i64
	b i64

# XCLL: the cell's light. Distances are in game units; the ambient cube is the six directions
# +x -x +y -y +z -z; `inherits` flags the fields taken from the lighting template instead.
pub type Lighting:
	ambient Color
	directional Color
	fogNearColor Color
	fogNear f32
	fogFar f32
	directionalRotationXY i64
	directionalRotationZ i64
	directionalFade f32
	fogClip f32
	fogPower f32
	ambientCube Color[]
	specular Color
	fresnelPower f32
	fogFarColor Color
	fogMax f32
	lightFadeBegin f32
	lightFadeEnd f32
	inherits i64

# a placed object: its base record's form id, and where (rotation in radians)
pub type Ref:
	formId i64
	base i64
	position Vec3
	rotation Vec3
	scale f32
	persistent bool
	disabled bool   # initially disabled: a script or a quest places it
	teleports bool   # XTEL: a load door's, leading to another cell
	radiusOffset f32 = 0.0   # XRDS: a light's radius over its base record's
	fadeOffset f32 = 0.0   # XLIG's second float: a light's fade over its base record's
	emittance i64 = 0   # XEMI: the light or region whose color its externally lit parts take, 0 for none

# where a ref puts its model: scaled, then turned by its angles as Gamebryo's FromEulerAnglesXYZ
# does (rotations clockwise seen from each axis's end, z's applied first), then moved
pub fn placement(r Ref) Mat4:
	turn = Mat4.rotationX(-r.rotation.x) @ Mat4.rotationY(-r.rotation.y) @
		Mat4.rotationZ(-r.rotation.z)
	Mat4.translation(r.position) @ turn @ Mat4.scaling(Vec3(r.scale, r.scale, r.scale))

pub type Cell:
	editorId str
	formId i64
	flags i64   # DATA: 1 interior, 2 has water, 4 cannot travel from here, 0x80 shows the sky
	lighting Lighting?
	template i64   # LTMP: the lighting template's form id, 0 when none
	imageSpace i64   # XCIM: its image space's form id, 0 when none
	acoustics i64   # XCAS: its acoustic space's form id (ASPC), 0 when none
	music i64   # XCMO: its music type's form id (MUSC), 0 when none
	water f32?   # XCLW: the water's height, none when the cell has no water
	refs Ref[]
	owner i64 = 0   # XOWN: the actor base or faction that owns what the cell holds, 0 for none
	location i64 = 0   # XLCN: the location (LCTN) it belongs to, 0 for none
	exterior bool = false   # the loaded grid around an exterior cell (area.zap), not an interior

pub flagDeleted = 0x20
flagDisabled = 0x800
groupChildren = 6
groupPersistent = 8

pub fn colorAt(d u8[], at i64) Color:
	Color(r = d[at], g = d[at + 1], b = d[at + 2])

fn lightingAt(d u8[], at i64, withInherits bool):
	Lighting(
		ambient = colorAt(d, at),
		directional = colorAt(d, at + 4),
		fogNearColor = colorAt(d, at + 8),
		fogNear = d.f32le(at + 12),
		fogFar = d.f32le(at + 16),
		directionalRotationXY = d.i32le(at + 20),
		directionalRotationZ = d.i32le(at + 24),
		directionalFade = d.f32le(at + 28),
		fogClip = d.f32le(at + 32),
		fogPower = d.f32le(at + 36),
		ambientCube = (0..6).map(colorAt(d, at + 40 + it * 4)),
		specular = colorAt(d, at + 64),
		fresnelPower = d.f32le(at + 68),
		fogFarColor = colorAt(d, at + 72),
		fogMax = d.f32le(at + 76),
		lightFadeBegin = d.f32le(at + 80),
		lightFadeEnd = d.f32le(at + 84),
		inherits = d.u32le(at + 88) if withInherits else 0
	)

# the lighting in the field `tag` (a cell's XCLL, a template's DATA), none when it is missing or
# too short; a template's has no inherit flags
fn lightingIn(body u8[], fields Field[], tag str) Lighting?:
	for f in fields:
		if f.tag == tag and f.size >= 88:
			l = lightingAt(body, f.at, f.size >= 92)
			# a template keeps its ambient cube in DALC, not in its DATA
			for c in fields:
				if c.tag == "DALC" and c.size >= 24:
					l.ambientCube = (0..6).map(colorAt(body, c.at + it * 4))
			return l
	none

# The light a cell is drawn with: its own, each field its inherit flags name taken from its
# lighting template (LTMP) instead; the template's alone when the cell has none.
pub fn cellLighting(mut e Esm, cell Cell) Lighting?:
	template Lighting? = none
	if cell.template != 0:
		if e.baseRecord(cell.template) is b: template = b.lighting
	own = cell.lighting ?? return template
	from = template ?? return own.copy()
	bits = own.inherits
	l = own.copy()
	if (bits & 0x1) != 0:
		l.ambient = from.ambient.copy()
		l.ambientCube = from.ambientCube.copy()
	if (bits & 0x2) != 0: l.directional = from.directional.copy()
	if (bits & 0x4) != 0:
		l.fogNearColor = from.fogNearColor.copy()
		l.fogFarColor = from.fogFarColor.copy()
	if (bits & 0x8) != 0: l.fogNear = from.fogNear
	if (bits & 0x10) != 0: l.fogFar = from.fogFar
	if (bits & 0x20) != 0:
		l.directionalRotationXY = from.directionalRotationXY
		l.directionalRotationZ = from.directionalRotationZ
	if (bits & 0x40) != 0: l.directionalFade = from.directionalFade
	if (bits & 0x80) != 0: l.fogClip = from.fogClip
	if (bits & 0x100) != 0: l.fogPower = from.fogPower
	if (bits & 0x200) != 0: l.fogMax = from.fogMax
	if (bits & 0x400) != 0:
		l.lightFadeBegin = from.lightFadeBegin
		l.lightFadeEnd = from.lightFadeEnd
	l.inherits = 0
	l

# XCLW holds a huge magnitude (the most negative integer, or the largest float) for no water
fn waterAt(d u8[], at i64) f32?:
	h = d.f32le(at)
	none if h.abs() > 1.0e9 else h

pub fn refAt(body u8[], h Head, persistent bool) Ref?:
	fields = fieldsOf(body)
	name = try dataOf(fields, "NAME")
	place = try dataOf(fields, "DATA")
	scaleAt = dataOf(fields, "XSCL")
	radiusAt = dataOf(fields, "XRDS")
	lightAt = dataOf(fields, "XLIG")
	emittanceAt = dataOf(fields, "XEMI")
	Ref(
		formId = h.formId,
		base = body.u32le(name),
		position = Vec3(body.f32le(place), body.f32le(place + 4), body.f32le(place + 8)),
		rotation = Vec3(body.f32le(place + 12), body.f32le(place + 16), body.f32le(place + 20)),
		scale = body.f32le(scaleAt ?? 0) if scaleAt != none else 1.0,
		persistent,
		disabled = (h.flags & flagDisabled) != 0,
		teleports = dataOf(fields, "XTEL") != none,
		radiusOffset = body.f32le(radiusAt ?? 0) if radiusAt != none else 0.0,
		fadeOffset = body.f32le((lightAt ?? 0) + 4) if lightAt != none else 0.0,
		emittance = body.u32le(emittanceAt ?? 0) if emittanceAt != none else 0
	)

# the records placed in a cell's children group (REFR, ACHR, ...), deleted ones left out, each
# with the type of the group that holds it (persistent or temporary) as its groupType
fn placedIn(d u8[], children Head):
	placed = []
	at = children.at + 24
	end = children.at + children.span
	while at < end:
		sub = headAt(d, at)
		span = sub.span
		if sub.isGroup:
			records = []
			recordsIn(d, at + 24, at + span, 0, records)
			for mut h in records:
				if (h.flags & flagDeleted) != 0: continue
				h.groupType = sub.groupType
				placed.push(h.copy())
		at += span
	placed

# the REFR records of a cell's children group, deleted ones left out
fn refsIn(d u8[], children Head):
	refs = []
	for h in placedIn(d, children):
		if h.kind != "REFR": continue
		body = recordBody(d, h.at, h.flags, h.span) ?? fail("REFR {h.formId:08X}: {error}")
		r = refAt(body, h, h.groupType == groupPersistent) ?? continue
		refs.push(r)
	refs

# the children group that follows the cell record h in d, none when it has none
fn childrenOf(d u8[], h Head) Head?:
	at = h.at + h.span
	if at >= d.len: return none
	next = headAt(d, at)
	if next.isGroup and next.groupType == groupChildren and next.label == h.formId: return next
	none

pub fn cellFrom(d u8[], h Head, body u8[]) Cell:
	fields = fieldsOf(body)
	refs = []
	if childrenOf(d, h) is children: refs = refsIn(d, children)
	flagsAt = dataOf(fields, "DATA")
	waterField = dataOf(fields, "XCLW")
	templateAt = dataOf(fields, "LTMP")
	imageSpaceAt = dataOf(fields, "XCIM")
	acousticsAt = dataOf(fields, "XCAS")
	musicAt = dataOf(fields, "XCMO")
	ownerAt = dataOf(fields, "XOWN")
	locationAt = dataOf(fields, "XLCN")
	Cell(
		editorId = textOf(body, fields, "EDID"),
		formId = h.formId,
		flags = body.u16le(flagsAt ?? 0) if flagsAt != none else 0,
		lighting = lightingIn(body, fields, "XCLL"),
		template = body.u32le(templateAt ?? 0) if templateAt != none else 0,
		imageSpace = body.u32le(imageSpaceAt ?? 0) if imageSpaceAt != none else 0,
		acoustics = body.u32le(acousticsAt ?? 0) if acousticsAt != none else 0,
		music = body.u32le(musicAt ?? 0) if musicAt != none else 0,
		water = waterAt(body, waterField ?? 0) if waterField != none else none,
		refs,
		owner = body.u32le(ownerAt ?? 0) if ownerAt != none else 0,
		location = body.u32le(locationAt ?? 0) if locationAt != none else 0
	)

# the offset of the cell record with this editor id (lower case) in one sub-block's bytes
fn cellIn(d u8[], want str) i64?:
	at = 24
	while at < d.len:
		h = headAt(d, at)
		if not h.isGroup and h.kind == "CELL":
			body = recordBody(d, at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
			if textOf(body, fieldsOf(body), "EDID").lower() == want: return at
		at += h.span
	none

# the bytes of the sub-block that holds the interior cell with this editor id (any case), and the
# cell record's offset in them; the program stops on a damaged file
fn cellBlock(e Esm, editorId str) (u8[], i64)?:
	top = try e.topGroup("CELL")
	want = editorId.lower()
	blocks = e.file.groupsIn(top.at + 24, top.at + top.span) ?? fail("{e.path}: {error}")
	for block in blocks:
		subs = e.file.groupsIn(block.at + 24, block.at + block.span) ?? fail("{e.path}: {error}")
		for sub in subs:
			d = e.file.readAt(sub.at, sub.span) ?? fail("{e.path}: a sub-block is cut short")
			at = cellIn(d, want) ?? continue
			return (d, at)
	none

# The interior cell with this editor id (any case) or the exterior area of that id (area.zap), or none; the program stops on a damaged file.
pub fn findCell(e Esm, editorId str) Cell?:
	if areaOf(editorId) is a: return e.areaCell(a)
	d, at = try e.cellBlock(editorId)
	h = headAt(d, at)
	body = recordBody(d, at, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
	cellFrom(d, h, body)

# every record placed in the cell whose record is at `at` in the sub-block's bytes d (REFR, ACHR,
# ...), deleted ones left out, with its data
pub fn recordsOfCell(d u8[], at i64) Record[]:
	out = []
	children = childrenOf(d, headAt(d, at)) ?? return out
	for h in placedIn(d, children):
		body = recordBody(d, h.at, h.flags, h.span) ?? fail("{h.kind} {h.formId:08X}: {error}")
		out.push(
			Record(
				kind = h.kind.copy(),
				formId = h.formId,
				flags = h.flags,
				fields = fieldsOf(body),
				body
			)
		)
	out

# Every record placed in the interior cell with this editor id (REFR, ACHR, ...), deleted ones
# left out, with its data; none when there is no such cell. An exterior area's id (area.zap) gives
# the records of its whole grid.
pub fn cellRecords(e Esm, editorId str) Record[]?:
	if areaOf(editorId) is a: return e.areaRecords(a)
	d, at = try e.cellBlock(editorId)
	recordsOfCell(d, at)

# The interior cell (its form id) the placed reference is in, none for one that is in no interior.
# The first use reads every interior's reference headers.
pub fn interiorCellOf(mut e Esm, refId i64) i64?:
	if not e.refCellsRead:
		e.refCellsRead = true
		top = try e.topGroup("CELL")
		blocks = e.file.groupsIn(top.at + 24, top.at + top.span) ?? fail("{e.path}: {error}")
		for block in blocks:
			subs = e.file.groupsIn(block.at + 24, block.at + block.span) ??
				fail("{e.path}: {error}")
			for sub in subs:
				d = e.file.readAt(sub.at, sub.span) ?? fail("{e.path}: a sub-block is cut short")
				at = 24
				cellAt = 0
				while at < d.len:
					h = headAt(d, at)
					if not h.isGroup and h.kind == "CELL": cellAt = at
					if h.isGroup and h.groupType == groupChildren:
						e.cellAts[h.label] = sub.at + cellAt
						heads = []
						recordsIn(d, at + 24, at + h.span, 0, heads)
						for placed in heads:
							e.refCells[placed.formId] = h.label
					at += h.span
	e.refCells.get(refId)

# The record of the interior cell with this form id (found by interiorCellOf), none for no such cell.
pub fn interiorCellRecord(mut e Esm, cellId i64) Record?:
	e.interiorCellOf(0)
	at = try e.cellAts.get(cellId)
	d = e.file.readAt(at, headerSize) ?? fail("{e.path}: a cell is cut short")
	h = headAt(d, 0)
	whole = e.file.readAt(at, h.span) ?? fail("{e.path}: a cell is cut short")
	body = recordBody(whole, 0, h.flags, h.span) ?? fail("CELL {h.formId:08X}: {error}")
	Record(kind = "CELL", formId = h.formId, flags = h.flags, fields = fieldsOf(body), body)

# The actors placed in interior cells: each actor base's first placed reference (ACHR), by the
# base's form id.
pub fn interiorActors(e Esm) {i64: i64}:
	out {i64: i64} = {}
	top = e.topGroup("CELL") ?? return out
	blocks = e.file.groupsIn(top.at + 24, top.at + top.span) ?? fail("{e.path}: {error}")
	for block in blocks:
		subs = e.file.groupsIn(block.at + 24, block.at + block.span) ?? fail("{e.path}: {error}")
		for sub in subs:
			d = e.file.readAt(sub.at, sub.span) ?? fail("{e.path}: a sub-block is cut short")
			heads = []
			recordsIn(d, 24, d.len, 0, heads)
			for h in heads:
				if h.kind != "ACHR" or (h.flags & flagDeleted) != 0: continue
				body = recordBody(d, h.at, h.flags, h.span) ?? fail("ACHR {h.formId:08X}: {error}")
				at = dataOf(fieldsOf(body), "NAME") ?? continue
				base = i64(body.u32le(at))
				if out.get(base) == none: out[base] = h.formId
	out
