# Water: the water types (WATR) and where the cells have water. A type's DNAM is the 232 bytes of
# TESWaterForm's shader data (CommonLibSSE-NG's WaterShaderData, the executable reads the same
# bytes at TESWaterForm+0xd0); its NAM2 to NAM5 are the paths of the three normal maps and the
# flow map's normals, FNAM the flags (8: the flow map is on), ANAM the opacity, GNAM the types the
# weather swaps it for. A cell has water when its DATA says so (2); XCLW is the water's height and
# XCWT its type, the world's WRLD NAM2 and its default water height (DNAM) where it names none.

# a cell's XCLW from here up is "the world's default" (the executable's 0x14182481c)
unsetHeight f32 = 2147483648.0

pub flagFlowMap = 8
pub flagBlendNormals = 16

pub type WaterType:
	formId i64
	editorId str
	flags i64
	alpha f32   # ANAM / 255, the opacity
	normals str[]   # NAM2 to NAM4's paths, then NAM5's the flow map's normals
	shallow Vec3   # the colors as 0 to 1 (DNAM +0x28, +0x2c, +0x30)
	deep Vec3
	reflection Vec3
	shallowAlpha f32
	deepAlpha f32   # the fourth byte: the sun's share through the water (1 - exp(-w))
	sunSpecularPower f32
	reflectionAmount f32
	fresnelAmount f32
	aboveFogNear f32
	aboveFogFar f32
	aboveFogAmount f32
	underwaterFogNear f32
	underwaterFogFar f32
	underwaterFogAmount f32
	refractionMagnitude f32
	specularPower f32
	specularRadius f32
	specularBrightness f32
	noiseFalloff f32
	windDirection f32[]   # the three layers' degrees
	windSpeed f32[]
	uvScale f32[]   # the layers' sizes in units
	amplitude f32[]
	reflectionMagnitude f32
	sunSparkleMagnitude f32
	sunSpecularMagnitude f32
	depthReflections f32   # how much the depth fades each part
	depthRefraction f32
	depthNormals f32
	depthSpecular f32
	sunSparklePower f32
	flowmapScale f32
	imageSpace i64
	weatherWater i64[]   # GNAM: for the day, the night and under water

pub type CellWater:
	height f32
	waterType i64   # WATR, 0 for none

fn colorOf(d u8[], at i64):
	Vec3(f32(d[at]) / 255.0, f32(d[at + 1]) / 255.0, f32(d[at + 2]) / 255.0)

fn floats(d u8[], at i64, count i64):
	(0..count).map(d.f32le(at + it * 4))

# the water type with this form id, none when it is no WATR
pub fn waterTypeOf(mut e Esm, formId i64) WaterType?:
	r = try e.recordOf(formId)
	if r.kind != "WATR": return none
	at = try dataOf(r.fields, "DNAM")
	d = r.body
	flagsAt = try dataOf(r.fields, "FNAM")
	WaterType(
		formId,
		editorId = textOf(d, r.fields, "EDID"),
		flags = d[flagsAt],
		alpha = f32(d[dataOf(r.fields, "ANAM") ?? 0]) / 255.0,
		normals = ["NAM2", "NAM3", "NAM4", "NAM5"].map(textOf(d, r.fields, it)),
		shallow = colorOf(d, at + 0x28),
		deep = colorOf(d, at + 0x2c),
		reflection = colorOf(d, at + 0x30),
		shallowAlpha = f32(d[at + 0x2b]) / 255.0,
		deepAlpha = f32(d[at + 0x2f]) / 255.0,
		sunSpecularPower = d.f32le(at + 0x10),
		reflectionAmount = d.f32le(at + 0x14),
		fresnelAmount = d.f32le(at + 0x18),
		aboveFogNear = d.f32le(at + 0x20),
		aboveFogFar = d.f32le(at + 0x24),
		aboveFogAmount = d.f32le(at + 0x84),
		underwaterFogNear = d.f32le(at + 0x90),
		underwaterFogFar = d.f32le(at + 0x94),
		underwaterFogAmount = d.f32le(at + 0x8c),
		refractionMagnitude = d.f32le(at + 0x98),
		specularPower = d.f32le(at + 0x9c),
		specularRadius = d.f32le(at + 0xa4),
		specularBrightness = d.f32le(at + 0xa8),
		noiseFalloff = d.f32le(at + 0x60),
		windDirection = floats(d, at + 0x64, 3),
		windSpeed = floats(d, at + 0x70, 3),
		uvScale = floats(d, at + 0xac, 3),
		amplitude = floats(d, at + 0xb8, 3),
		reflectionMagnitude = d.f32le(at + 0xc4),
		sunSparkleMagnitude = d.f32le(at + 0xc8),
		sunSpecularMagnitude = d.f32le(at + 0xcc),
		depthReflections = d.f32le(at + 0xd0),
		depthRefraction = d.f32le(at + 0xd4),
		depthNormals = d.f32le(at + 0xd8),
		depthSpecular = d.f32le(at + 0xdc),
		sunSparklePower = d.f32le(at + 0xe0),
		flowmapScale = d.f32le(at + 0xe4),
		imageSpace = r.formOf("INAM") ?? 0,
		weatherWater = formsOf(d, r.fields, "GNAM")
	)

# the water of the exterior cell at grid place (x, y), none when the cell has none: its height and
# type (the world's where the cell names none)
pub fn cellWaterAt(mut e Esm, world i64, x i64, y i64) CellWater?:
	r = try e.exteriorCellRecord(world, x, y)
	flagsAt = try dataOf(r.fields, "DATA")
	if (i64(r.body[flagsAt]) & 2) == 0: return none
	height = unsetHeight
	if dataOf(r.fields, "XCLW") is at: height = r.body.f32le(at)
	if height >= unsetHeight:
		height = (try e.worldLand(world)).waterHeight
	CellWater(height, waterType = r.formOf("XCWT") ?? (e.worldWaterType(world) ?? 0))

# the world's water type, WRLD's NAM2
pub fn worldWaterType(mut e Esm, world i64) i64?:
	r = try e.worldRecordIn(world)
	r.formOf("NAM2")

# the water of the world's distant planes: WRLD's NAM3 (the type; the world's own where it names
# none) and NAM4 (the height the distant planes of cells without land are drawn at)
pub fn worldLodWater(mut e Esm, world i64) CellWater?:
	r = try e.worldRecordIn(world)
	height = (try e.worldLand(world)).waterHeight
	if r.fields.find(.tag == "NAM4") is f: height = r.body.f32le(f.at)
	CellWater(height, waterType = r.formOf("NAM3") ?? (e.worldWaterType(world) ?? 0))

# the height the water of the cell stands at for what grows by it (TESObjectCELL 0x1402bee00): the
# cell's, the world's where it names none, and the lowest float for a cell without water
pub fn waterHeightOf(mut e Esm, world i64, x i64, y i64) f32:
	(e.cellWaterAt(world, x, y) ?? return -3.4028235e38).height
