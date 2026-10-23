# The land of the exterior cells (LAND), after UESP's Skyrim Mod File Format and the executable's
# TESObjectLAND::LoadVertices (0x1402ad5c0). A cell's land is a 33 x 33 grid of vertices 128 units
# apart (VHGT: an offset, then each row's first height as a step from the row before and the rest
# as steps along the row, all in 8 units), with a normal (VNML, signed bytes) and a color (VCLR) per
# vertex. Its four quadrants (0 south west, 1 south east, 2 north west, 3 north east) of 17 x 17
# vertices each have a base texture (BTXT) and up to five layers (ATXT, whose VTXT gives their
# opacity at the vertices they cover). A texture (LTEX) names a texture set (TXST) and the grass
# that grows on it.

pub landSide = 33
pub quadrantSide = 17
pub vertexStep f32 = 128.0

# the most layers a quadrant draws over its base (the executable reads no more)
pub maxLayers = 5

# a layer of a quadrant: its texture and its opacity at each of the quadrant's 17 x 17 vertices
# (row by row from the south), 0 where VTXT lists none
pub type LandLayer:
	texture i64   # LTEX
	quadrant i64
	order i64
	opacity f32[]

pub type Land:
	formId i64
	x i64
	y i64
	flags i64
	heights f32[]   # 33 x 33, row by row from the south, in units
	normals Vec3[]   # unit, as VNML holds them
	colors Vec3[]   # VCLR, 0 to 1
	base i64[]   # the four quadrants' BTXT, 0 for none
	layers LandLayer[]

pub type LandTexture:
	formId i64
	editorId str
	set i64   # TXST, 0 for none
	diffuse str   # paths under textures/, "" for none
	normal str
	grass i64[]   # GRAS

pub type WorldLand:
	defaultHeight f32   # DNAM: the land height where a cell has no land
	waterHeight f32

# the height a stored offset and the running steps give, whole units as the executable truncates
fn heightsOf(body u8[], from i64?) f32[]:
	at = from ?? return fill(landSide * landSide, 0.0)
	out = []
	start = body.f32le(at)
	column = 0
	for row in 0..landSide:
		column += i8(body[at + 4 + row * landSide])
		run = column
		for col in 0..landSide:
			if col > 0: run += i8(body[at + 4 + row * landSide + col])
			out.push(f32(i64(start + f32(run)) * 8))
	out

fn normalsOf(body u8[], from i64?):
	at = from ?? return fill(landSide * landSide, Vec3(0.0, 0.0, 1.0))
	out = []
	for k in 0..landSide * landSide:
		n = Vec3(
			f32(i8(body[at + k * 3])) / 127.0,
			f32(i8(body[at + k * 3 + 1])) / 127.0,
			f32(i8(body[at + k * 3 + 2])) / 127.0
		)
		out.push(n.normalized())
	out

fn colorsOf(body u8[], from i64?):
	at = from ?? return fill(landSide * landSide, Vec3(1.0, 1.0, 1.0))
	(0..landSide * landSide).map(
		Vec3(
			f32(body[at + it * 3]) / 255.0,
			f32(body[at + it * 3 + 1]) / 255.0,
			f32(body[at + it * 3 + 2]) / 255.0
		)
	)

fn flagsAt(body u8[], at i64?) i64:
	body.u32le(at ?? return 0)

# the layers of a LAND record: each ATXT starts one, the VTXT after it fills its opacities
fn layersOf(body u8[], fields Field[]):
	out = []
	for f in fields:
		if f.tag == "ATXT":
			out.push(
				LandLayer(
					texture = body.u32le(f.at),
					quadrant = body[f.at + 4],
					order = body.u16le(f.at + 6),
					opacity = fill(quadrantSide * quadrantSide, 0.0)
				)
			)
		elif f.tag == "VTXT" and not out.isEmpty:
			for k in 0..f.size / 8:
				place = i64(body.u16le(f.at + k * 8))
				if place < quadrantSide * quadrantSide:
					out[len - 1].opacity[place] = body.f32le(f.at + k * 8 + 4)
	out

# the LAND record in the children of the cell record at `at` in a sub-block's bytes d
fn landIn(d u8[], cell Head) Land?:
	children = try childrenOf(d, cell)
	records = []
	recordsIn(d, children.at + headerSize, children.at + children.span, 0, records)
	for h in records:
		if h.kind != "LAND" or (h.flags & flagDeleted) != 0: continue
		body = recordBody(d, h.at, h.flags, h.span) ?? fail("LAND {h.formId:08X}: {error}")
		fields = fieldsOf(body)
		base = fill(4, 0)
		for f in fields:
			if f.tag == "BTXT" and body[f.at + 4] < 4:
				base[i64(body[f.at + 4])] = body.u32le(f.at)
		return Land(
			formId = h.formId,
			x = 0,
			y = 0,
			flags = flagsAt(body, dataOf(fields, "DATA")),
			heights = heightsOf(body, dataOf(fields, "VHGT")),
			normals = normalsOf(body, dataOf(fields, "VNML")),
			colors = colorsOf(body, dataOf(fields, "VCLR")),
			base,
			layers = layersOf(body, fields)
		)
	none

fn landInPlugin(e Esm, world i64, x i64, y i64) Land?:
	d = try e.exteriorSubBlock(world, x, y)
	cell = try exteriorHeadIn(d, x, y)
	land = try landIn(d, cell)
	land.x = x
	land.y = y
	land

# The land of the exterior cell at grid place (x, y) of the world, as the last plugin that has one
# sets it; none when the world has no land there (the sea, the unloaded edge).
pub fn landOf(e Esm, world i64, x i64, y i64) Land?:
	n = e.overlays.len
	for k in 0..n:
		if e.overlays[n - 1 - k].landInPlugin(world, x, y) is land: return land
	e.landInPlugin(world, x, y)

# The land texture with this form id, none when no plugin has it.
pub fn landTexture(mut e Esm, formId i64) LandTexture?:
	r = try e.recordOf(formId)
	if r.kind != "LTEX": return none
	set = r.formOf("TNAM") ?? 0
	diffuse = ""
	normal = ""
	if set != 0 and e.recordOf(set) is txst:
		diffuse = textOf(txst.body, txst.fields, "TX00")
		normal = textOf(txst.body, txst.fields, "TX01")
	LandTexture(
		formId,
		editorId = textOf(r.body, r.fields, "EDID"),
		set,
		diffuse,
		normal,
		grass = formsOf(r.body, r.fields, "GNAM")
	)

# the WRLD record with this form id, as the last plugin that has it sets it
fn worldRecordIn(e Esm, formId i64) Record?:
	top = try e.topGroup("WRLD")
	at = top.at + headerSize
	while at < top.at + top.span:
		raw = e.file.readAt(at, headerSize) ?? fail("{e.path}: WRLD is cut short")
		h = headAt(raw, 0)
		if not h.isGroup and h.formId == formId:
			d = e.file.readAt(at, h.span) ?? fail("{e.path}: a WRLD is cut short")
			body = recordBody(d, 0, h.flags, h.span) ?? fail("WRLD {formId:08X}: {error}")
			return Record(kind = "WRLD", formId, flags = h.flags, body, fields = fieldsOf(body))
		at += h.span
	none

# the world's land defaults (WRLD DNAM), none when the plugin has no such world
pub fn worldLand(e Esm, formId i64) WorldLand?:
	r = try e.worldRecordIn(formId)
	at = try dataOf(r.fields, "DNAM")
	WorldLand(defaultHeight = r.body.f32le(at), waterHeight = r.body.f32le(at + 4))

# The positions of the references of the record type `kind` (TREE, STAT) placed in the exterior
# cell, to check what stands on the land against it.
pub fn placedOfKind(mut e Esm, world i64, x i64, y i64, kind str) Vec3[]:
	d = e.exteriorSubBlock(world, x, y) ?? return []
	cell = exteriorHeadIn(d, x, y) ?? return []
	children = childrenOf(d, cell) ?? return []
	out = []
	for r in refsIn(d, children):
		if (e.baseRecord(r.base) ?? continue).kind == kind: out.push(r.position)
	out
