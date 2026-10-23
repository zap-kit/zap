# Regions, weathers and climates: what the exterior sky is made of. A region's RDWT lists its
# weathers (form id, chance, global), each 12 bytes; a weather's NAM0 holds 17 colors of 4 times of
# day (sunrise, day, sunset, night) as RGBA bytes, color by color; a climate's TNAM starts with the
# sunrise's and the sunset's begin and end in tens of minutes; a world's CNAM names its climate.
# Layout after UESP's Skyrim Mod File Format (REGN, WTHR, CLMT, WRLD) and CommonLibSSE-NG's
# TESWeather and TESClimate; the executable reads the same bytes (TESWeather+0x660..0x7f8,
# TESClimate+0x48..0x7c).

# NAM0's colors, in the executable's order (Sky's skyColor)
pub colorKinds = [
	"skyUpper",
	"fogNear",
	"unknown",
	"ambient",
	"sunlight",
	"sun",
	"stars",
	"skyLower",
	"horizon",
	"effectLighting",
	"cloudLodDiffuse",
	"cloudLodAmbient",
	"fogFar",
	"skyStatics",
	"waterMultiplier",
	"sunGlare",
	"moonGlare"
]
pub skyUpper = 0
pub fogNearColor = 1
pub ambientColor = 3
pub sunlightColor = 4
pub sunColor = 5
pub starsColor = 6
pub skyLower = 7
pub horizonColor = 8
# NAM0's color of what a region lights (Sky's kEffectLighting, the executable's index 9)
pub effectLightingColor = 9
pub fogFarColor = 12
pub sunGlareColor = 15
pub moonGlareColor = 16
pub timesOfDay = 4

pub type RegionWeather:
	weather i64
	chance i64
	global i64   # a global whose value is the chance instead, 0 for none

pub type Region:
	world i64   # WNAM
	weathers RegionWeather[]
	priority i64   # the weather data's (RDAT): the higher wins where regions overlap

# a region's world and weathers, none when the form is no region
pub fn regionOf(mut e Esm, formId i64) Region?:
	r = try e.recordOf(formId)
	if r.kind != "REGN": return none
	weathers = []
	priority = 0
	for f in r.fields:
		if f.tag == "RDAT" and f.size >= 6: priority = r.body[f.at + 5]
		if f.tag != "RDWT": continue
		for k in 0..f.size / 12:
			at = f.at + k * 12
			weathers.push(
				RegionWeather(
					weather = r.body.u32le(at),
					chance = r.body.u32le(at + 4),
					global = r.body.u32le(at + 8)
				)
			)
	world = dataOf(r.fields, "WNAM")
	Region(world = r.body.u32le(world ?? 0) if world != none else 0, weathers, priority)

# whether the point lies inside the polygon (the even-odd rule)
fn inside(points Vec2[], x f32, y f32):
	hit = false
	j = points.len - 1
	for i in 0..points.len:
		a = points[i]
		b = points[j]
		if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
			hit = not hit
		j = i
	hit

# the regions of the world whose areas (RPLD polygons, in game units) hold the point and that give
# the weather, the highest priority first
pub fn weatherRegionsAt(mut e Esm, world i64, x f32, y f32) i64[]:
	found = []
	for form in e.formsOfKind("REGN"):
		r = e.recordOf(form) ?? continue
		region = e.regionOf(form) ?? continue
		if region.world != world or region.weathers.isEmpty: continue
		for f in r.fields:
			if f.tag != "RPLD": continue
			points = (0..f.size / 8).map(
				Vec2(r.body.f32le(f.at + it * 8), r.body.f32le(f.at + it * 8 + 4))
			)
			if points.inside(x, y):
				found.push(region.priority << 32 | form)
				break
	found.sort()
	found.reverse()
	found.map(it & 0xFFFF_FFFF)

# FNAM: the fog by day and night
pub type WeatherFog:
	dayNear f32
	dayFar f32
	nightNear f32
	nightFar f32
	dayPower f32
	nightPower f32
	dayMax f32
	nightMax f32

# One layer of clouds: its texture, how it scrolls (RNAM and QNAM bytes, 127 standing still), its
# color and its alpha at each time of day
pub type CloudLayer:
	texture str
	speedX f32
	speedY f32
	colors Color[]
	alpha f32[]
	enabled bool

# a weather: DATA, FNAM, NAM0, the clouds, IMSP and the four DALC (the ambient cube of each time of
# day, in the order +x -x +y -y +z -z, then the specular tint and its fresnel)
pub type Weather:
	editorId str
	windSpeed i64
	transDelta i64
	sunGlare i64
	sunDamage i64
	precipitationBegin i64
	precipitationEnd i64
	thunderBegin i64
	thunderEnd i64
	thunderFrequency i64
	flags i64
	windDirection i64   # DATA's byte 17, the wind's direction in 360/256 degrees
	windRange i64   # and how far it may stray either side, in 180/256 degrees
	lightning Color
	fog WeatherFog
	colors Color[]
	imageSpaces i64[]
	layers CloudLayer[]
	ambient Color[]
	ambientSpecular Color[]
	ambientFresnel f32[]
	precipitation i64
	disabledLayers i64

# the layers' texture fields are 00TX, 10TX, ... with the first character climbing from '0'
maxCloudLayers = 29

fn cloudLayerAt(r Record, k i64, speedY i64, speedX i64, colors i64, alphas i64, disabled i64):
	tag = "{str.fromCode(0x30 + k)}0TX"
	texture = textOf(r.body, r.fields, tag)
	CloudLayer(
		texture,
		speedX = r.body[speedX + k],
		speedY = r.body[speedY + k],
		colors = (0..timesOfDay).map(colorAt(r.body, colors + (k * timesOfDay + it) * 4)),
		alpha = (0..timesOfDay).map(r.body.f32le(alphas + (k * timesOfDay + it) * 4)),
		enabled = (disabled >> k) & 1 == 0
	)

fn formAt(body u8[], at i64?, k i64) i64:
	if at is a: return body.u32le(a + k * 4)
	0

# the weather with this form id, none when the form is no weather
pub fn weatherOf(mut e Esm, formId i64) Weather?:
	r = try e.recordOf(formId)
	if r.kind != "WTHR": return none
	data = try dataOf(r.fields, "DATA")
	nam0 = try dataOf(r.fields, "NAM0")
	fnam = try dataOf(r.fields, "FNAM")
	f = r.body
	disabled = i64(f.u32le(dataOf(r.fields, "NAM1") ?? 0)) if dataOf(r.fields, "NAM1") != none
		else 0
	layers = []
	rnam = dataOf(r.fields, "RNAM")
	qnam = dataOf(r.fields, "QNAM")
	pnam = dataOf(r.fields, "PNAM")
	jnam = dataOf(r.fields, "JNAM")
	if rnam != none and qnam != none and pnam != none and jnam != none:
		for k in 0..maxCloudLayers:
			if dataOf(r.fields, "{str.fromCode(0x30 + k)}0TX") == none: continue
			layers.push(r.cloudLayerAt(k, rnam ?? 0, qnam ?? 0, pnam ?? 0, jnam ?? 0, disabled))
	dalc = r.fields.filter(.tag == "DALC")
	imsp = dataOf(r.fields, "IMSP")
	Weather(
		editorId = textOf(f, r.fields, "EDID"),
		windSpeed = f[data],
		transDelta = f[data + 3],
		sunGlare = f[data + 4],
		sunDamage = f[data + 5],
		precipitationBegin = f[data + 6],
		precipitationEnd = f[data + 7],
		thunderBegin = f[data + 8],
		thunderEnd = f[data + 9],
		thunderFrequency = f[data + 10],
		flags = f[data + 11],
		windDirection = f[data + 17],
		windRange = f[data + 18],
		lightning = colorAt(f, data + 12),
		fog = WeatherFog(
			dayNear = f.f32le(fnam),
			dayFar = f.f32le(fnam + 4),
			nightNear = f.f32le(fnam + 8),
			nightFar = f.f32le(fnam + 12),
			dayPower = f.f32le(fnam + 16),
			nightPower = f.f32le(fnam + 20),
			dayMax = f.f32le(fnam + 24),
			nightMax = f.f32le(fnam + 28)
		),
		colors = (0..colorKinds.len * timesOfDay).map(colorAt(f, nam0 + it * 4)),
		imageSpaces = (0..timesOfDay).map(formAt(f, imsp, it)),
		layers,
		ambient = (0..timesOfDay * 6).map(colorAt(f, dalc[it / 6].at + (it % 6) * 4)),
		ambientSpecular = (0..timesOfDay).map(colorAt(f, dalc[it].at + 24)),
		ambientFresnel = (0..timesOfDay).map(f.f32le(dalc[it].at + 28)),
		precipitation = r.formOf("MNAM") ?? 0,
		disabledLayers = disabled
	)

# a weather's color `color` at each time of day, none when the form is no weather
pub fn weatherColors(mut e Esm, formId i64, color i64) Color[]?:
	r = try e.recordOf(formId)
	if r.kind != "WTHR": return none
	at = try dataOf(r.fields, "NAM0")
	(0..timesOfDay).map(colorAt(r.body, at + (color * timesOfDay + it) * 4))

# a climate: its sunrise and sunset in hours, the volatility and moon phases (TNAM), the sun and glare textures
# (FNAM, GNAM) and its weathers (WLST: form, chance, global)
pub type Climate:
	sunriseBegin f32
	sunriseEnd f32
	sunsetBegin f32
	sunsetEnd f32
	volatility i64
	phaseLength i64   # TNAM's last byte: days a moon phase lasts (low six bits)
	masser bool   # its bit 7: the climate has Masser, bit 6 Secunda
	secunda bool
	sunTexture str
	glareTexture str
	weathers RegionWeather[]

pub fn climateOf(mut e Esm, formId i64) Climate?:
	r = try e.recordOf(formId)
	if r.kind != "CLMT": return none
	at = try dataOf(r.fields, "TNAM")
	weathers = []
	for f in r.fields:
		if f.tag != "WLST": continue
		for k in 0..f.size / 12:
			w = f.at + k * 12
			weathers.push(
				RegionWeather(
					weather = r.body.u32le(w),
					chance = r.body.u32le(w + 4),
					global = r.body.u32le(w + 8)
				)
			)
	Climate(
		sunriseBegin = f32(r.body[at]) / 6.0,
		sunriseEnd = f32(r.body[at + 1]) / 6.0,
		sunsetBegin = f32(r.body[at + 2]) / 6.0,
		sunsetEnd = f32(r.body[at + 3]) / 6.0,
		volatility = r.body[at + 4],
		phaseLength = r.body[at + 5] & 0x3f,
		masser = r.body[at + 5] & 0x80 != 0,
		secunda = r.body[at + 5] & 0x40 != 0,
		sunTexture = textOf(r.body, r.fields, "FNAM"),
		glareTexture = textOf(r.body, r.fields, "GNAM"),
		weathers
	)

# The hours the sky's colors turn at (the executable's sunrise begin, sunrise end, sunset begin and
# sunset end): the first and last widened by fDaytimeColorExtension (Sky 0x140419ab0, 0x140419bb0).
pub fn colorHours(c Climate, extension f32) Vec4:
	Vec4(
		(c.sunriseBegin - extension).max(0.0),
		c.sunriseEnd,
		c.sunsetBegin,
		(c.sunsetEnd + extension).min(23.99)
	)

# the climate (CNAM) of the world with this form id, none when the plugin has no such world
pub fn worldClimate(e Esm, world i64) i64?:
	top = try e.topGroup("WRLD")
	at = top.at + headerSize
	while at < top.at + top.span:
		raw = e.file.readAt(at, headerSize) ?? return none
		h = headAt(raw, 0)
		if not h.isGroup and h.formId == world:
			d = e.file.readAt(at, h.span) ?? return none
			body = recordBody(d, 0, h.flags, h.span) ?? return none
			fields = fieldsOf(body)
			cnam = try dataOf(fields, "CNAM")
			return i64(body.u32le(cnam))
		at += h.span
	none

# The chances a list of weathers gives, whole numbers: an entry's own, or its global's value cut to
# one (0x14030a3c0).
pub fn weatherChances(mut e Esm, entries RegionWeather[]) i64[]:
	entries.map(i64(e.globalValue(.global)) if .global != 0 else .chance)

# A precipitation (SPGD, a weather's MNAM): how its particles fall and how big they are, as the
# executable builds the emitter from it (0x14029f4e0)
pub type Precipitation:
	editorId str
	gravity f32   # the fall speed, game units a second
	rotationVelocity f32   # degrees a second
	sizeX f32
	sizeY f32
	centerMin f32
	centerMax f32
	rotationRange f32
	columns i64   # the texture's cells across and down
	rows i64
	snow bool
	boxSize f32   # the cube of particles about the eye
	density f32
	texture str

pub fn precipitationOf(mut e Esm, formId i64) Precipitation?:
	r = try e.recordOf(formId)
	if r.kind != "SPGD": return none
	at = try dataOf(r.fields, "DATA")
	b = r.body
	Precipitation(
		editorId = textOf(b, r.fields, "EDID"),
		gravity = b.f32le(at),
		rotationVelocity = b.f32le(at + 4),
		sizeX = b.f32le(at + 8),
		sizeY = b.f32le(at + 12),
		centerMin = b.f32le(at + 16),
		centerMax = b.f32le(at + 20),
		rotationRange = b.f32le(at + 24),
		columns = b.u32le(at + 28),
		rows = b.u32le(at + 32),
		snow = b.u32le(at + 36) == 1,
		boxSize = f32(b.u32le(at + 40)),
		density = b.f32le(at + 44),
		texture = textOf(b, r.fields, "ICON")
	)
