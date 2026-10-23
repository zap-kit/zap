# Grass (GRAS): the plant a landscape texture grows (LTEX's GNAM lists them) and how it is placed on
# the land. DATA is the 32 bytes of TESGrass' GRASS_DATA (CommonLibSSE-NG; the executable reads them
# at TESGrass+0x58): the density in percent, the slope range in degrees, the distance from the
# water level, how the water state limits it, the position, height and color ranges, the wave
# period and the flags. MODL is the mesh of one plant, a path under meshes/.

pub flagVertexLighting = 1
pub flagUniformScale = 2
pub flagFitSlope = 4

pub type Grass:
	formId i64
	editorId str
	model str
	density f32   # percent
	minSlope f32   # degrees
	maxSlope f32
	waterDistance f32   # units from the water level
	waterState i64   # how the water limits it (0 above at least ... 7), see game/grass.zap
	positionRange f32   # the closest two plants may stand: the least spacing, in units
	heightRange f32   # how much the plants' heights differ
	colorRange f32   # how much their shades differ
	wavePeriod f32   # of the wind's sway
	flags i64

# the grass with this form id, none when it is no GRAS
pub fn grassOf(mut e Esm, formId i64) Grass?:
	r = try e.recordOf(formId)
	if r.kind != "GRAS": return none
	at = try dataOf(r.fields, "DATA")
	d = r.body
	Grass(
		formId,
		editorId = textOf(d, r.fields, "EDID"),
		model = textOf(d, r.fields, "MODL"),
		density = d[at],
		minSlope = d[at + 1],
		maxSlope = d[at + 2],
		waterDistance = d.u16le(at + 4),
		waterState = d.u32le(at + 8),
		positionRange = d.f32le(at + 0xc),
		heightRange = d.f32le(at + 0x10),
		colorRange = d.f32le(at + 0x14),
		wavePeriod = d.f32le(at + 0x18),
		flags = d[at + 0x1c]
	)
