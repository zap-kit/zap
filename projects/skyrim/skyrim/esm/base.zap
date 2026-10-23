# Base records: what a reference (REFR) names with its NAME. Those with a model are kept by
# top groups of one record type each, flat lists of records, indexed by form id on first use.
# Skyrim.esm is localized, so names (FULL) are string ids and are not read.

# the record types a reference to which can show a model, and the lighting templates a cell names
baseKinds = [
	"STAT", "MSTT", "FURN", "DOOR", "CONT", "ACTI", "LIGH", "TREE", "FLOR", "MISC", "WEAP",
	"ARMO", "BOOK", "INGR", "ALCH", "KEYM", "SLGM", "SOUL", "TACT", "AMMO", "APPA", "SCRL", "LGTM"
]

# a base record's flag of a marker
flagMarker = 0x80_0000
# the other record types looked up by form id: what an actor is made of, the image spaces, the
# sounds (markers, descriptors, acoustic spaces, music types and tracks, regions, categories,
# output models, materials, impacts and footsteps), the default objects
formKinds = [
	"NPC_", "RACE", "ARMA", "HDPT", "IMGS", "SOUN", "SNDR", "ASPC", "MUSC", "MUST", "REGN", "LVLN",
	"OTFT",
	"CLFM",
	"PACK",
	"FACT",
	"VTYP",
	"CLAS",
	"LCTN",
	"TXST",
	"LTEX",
	"IDLE",
	"IDLM",
	"QUST",
	"GLOB",
	"LVLI",
	"FLST",
	"GMST",
	"KYWD",
	"MGEF",
	"SPEL",
	"SHOU",
	"WOOP",
	"PROJ",
	"EFSH",
	"ARTO",
	"ENCH",
	"AVIF",
	"PERK",
	"EQUP",
	"CSTY",
	"RELA",
	"MOVT",
	"SNCT",
	"SOPM",
	"MATT",
	"IPDS",
	"IPCT",
	"FSTP",
	"FSTS",
	"DOBJ",
	"WTHR",
	"CLMT",
	"SPGD",
	"WATR",
	"GRAS"
]

pub type BaseSlot:
	kind str
	at i64
	flags i64
	span i64

# LIGH's DATA, the light a base record gives (the color is as stored: red, green, blue)
pub type Light:
	time i64   # seconds it lasts, 0 forever
	radius i64
	color Color
	flags i64
	falloff f32
	fov f32
	nearClip f32
	flickerPeriod f32   # seconds
	flickerIntensity f32   # how far the flicker takes the intensity, 0..1
	flickerMovement f32   # how far the flicker moves the light, in units
	fade f32   # FNAM
	value i64
	weight f32

pub type Base:
	kind str
	formId i64
	editorId str
	model str   # MODL: a path under meshes/, "" when it has none
	marker bool   # the editor's alone (an X marker, a heading): the game draws nothing
	light Light?
	lighting Lighting?   # a lighting template's DATA, laid out as a cell's XCLL

fn indexGroup(e Esm, g Head, mut index {i64: BaseSlot}):
	d = e.file.readAt(g.at + 24, g.span - 24) ?? fail("{e.path}: a {g.kind} group is cut short")
	records = []
	recordsIn(d, 0, d.len, g.at + 24, records)
	for h in records:
		index[h.formId] = BaseSlot(kind = h.kind.copy(), at = h.at, flags = h.flags, span = h.span)

fn indexBases(e Esm):
	index {i64: BaseSlot} = {}
	for kinds in [baseKinds, formKinds]:
		for kind in kinds:
			g = e.topGroup(kind) ?? continue
			e.indexGroup(g, index)
	index

fn lightFrom(body u8[], fields Field[]) Light?:
	at = try dataOf(fields, "DATA")
	fadeAt = dataOf(fields, "FNAM")
	Light(
		time = body.i32le(at),
		radius = body.i32le(at + 4),
		color = colorAt(body, at + 8),
		flags = body.u32le(at + 12),
		falloff = body.f32le(at + 16),
		fov = body.f32le(at + 20),
		nearClip = body.f32le(at + 24),
		flickerPeriod = body.f32le(at + 28),
		flickerIntensity = body.f32le(at + 32),
		flickerMovement = body.f32le(at + 36),
		fade = body.f32le(fadeAt ?? 0) if fadeAt != none else 0.0,
		value = body.u32le(at + 40),
		weight = body.f32le(at + 44)
	)

# a record's data, inflated, and its fields
pub type Record:
	kind str
	formId i64
	flags i64
	body u8[]
	fields Field[]

# the form id of the record's first field with this tag, none when it has none
pub fn formOf(r Record, tag str) i64?:
	forms = formsOf(r.body, r.fields, tag)
	forms[0] if not forms.isEmpty else none

# the reference the placed record is linked to under the keyword (XLKR), none when it has none
pub fn linkedRef(r Record, keyword i64) i64?:
	for f in r.fields:
		if f.tag == "XLKR" and f.size >= 8 and r.body.u32le(f.at) == keyword:
			return i64(r.body.u32le(f.at + 4))
	none

# the record with this form id among the indexed types, as the last overlay that has it sets it;
# none when no indexed group has it
pub fn recordOf(mut e Esm, formId i64) Record?:
	n = e.overlays.len
	for k in 0..n:
		r = e.overlays[n - 1 - k].ownRecord(formId)
		if r != none: return r
	e.ownRecord(formId)

# the record as the plugin itself has it, without the overlays': the one whose localized fields
# are in the plugin's own strings tables
pub fn masterRecordOf(mut e Esm, formId i64) Record?:
	e.ownRecord(formId)

fn ownRecord(mut e Esm, formId i64) Record?:
	if e.bases.isEmpty: e.bases = e.indexBases()
	slot = try e.bases.get(formId)
	d = e.file.readAt(slot.at, slot.span) ?? fail("{e.path}: a record is cut short")
	body = recordBody(d, 0, slot.flags, slot.span) ?? fail("{slot.kind} {formId:08X}: {error}")
	Record(kind = slot.kind.copy(), formId, flags = slot.flags, fields = fieldsOf(body), body)

# The add-on nodes' models (ADDN: a candle's flame, a torch's fire) by the index a model's
# BSValueNode names, as paths under meshes/.
pub fn addOnModels(mut e Esm) {i64: str}:
	out {i64: str} = {}
	g = e.topGroup("ADDN") ?? return out
	d, records = e.topRecords(g)
	for h in records:
		body = recordBody(d, h.at, h.flags, h.span) ?? fail("ADDN {h.formId:08X}: {error}")
		fields = fieldsOf(body)
		at = dataOf(fields, "DATA") ?? continue
		out[i64(body.i32le(at))] = textOf(body, fields, "MODL")
	out

# The base record with this form id: its type, editor id, model and, for a light, its data;
# none when no indexed group has it (an actor, a form of another plugin).
pub fn baseRecord(mut e Esm, formId i64) Base?:
	r = try e.recordOf(formId)
	Base(
		kind = r.kind.copy(),
		formId,
		editorId = textOf(r.body, r.fields, "EDID"),
		model = textOf(r.body, r.fields, "MODL"),
		marker = (r.flags & flagMarker) != 0,
		light = lightFrom(r.body, r.fields) if r.kind == "LIGH" else none,
		lighting = lightingIn(r.body, r.fields, "DATA") if r.kind == "LGTM" else none
	)

# the form ids of every record of this type among the indexed types (formKinds, baseKinds)
pub fn formsOfKind(mut e Esm, kind str) i64[]:
	if e.bases.isEmpty: e.bases = e.indexBases()
	out = []
	for id, slot in e.bases:
		if slot.kind == kind: out.push(id)
	out.sorted()

# the form id of the record of this type with this editor id (any case), none when there is none
pub fn formByEditorId(mut e Esm, kind str, editorId str) i64?:
	want = editorId.lower()
	for id in e.formsOfKind(kind):
		r = e.recordOf(id) ?? continue
		if textOf(r.body, r.fields, "EDID").lower() == want: return id
	none
