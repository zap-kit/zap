# The exterior sky of a place as the game runs it: the region the place lies in gives the weathers
# that can come (TESRegion's RDWT, the climate's WLST where it gives none), the climate the hours
# the sky turns at, and the clock rolls the next weather when one has lasted its time
# (world/sky.zap). The way in, for the cell agent:
#
#   clock = openSkyClock(plugin, worldId, x, y, hour, seed)     the weathers of a place
#   sc.showSky(install.newSkyDrawing(clock))                    once, with the scene (the GPU's)
#   clock.advance(hour)                                         each frame
#   sky = clock.skyAt(hour, 0.0)
#   sc.setSky(sky, clock.imageSpaceAt(sky), days)               and the scene takes it
#
# The scene then draws the sky first, lights its terrain and its exterior parts by the hour's
# sun and ambient, and fogs them with the weather's fog.

import skyrim
import skyrim.esm
import skyrim.nif
import world

# the weathers of a place and the clock that changes them
pub type SkyClock:
	weathers {i64: esm.Weather}   # every weather the place can bring, by form
	imageSpaces {i64: esm.ImageSpace}
	precipitations {i64: esm.Precipitation}   # the particles of each weather's MNAM, by form
	masser world.MoonSettings
	secunda world.MoonSettings
	climate esm.Climate
	entries esm.RegionWeather[]
	chances i64[]
	state world.WeatherState
	extension f32   # fDaytimeColorExtension
	rng Random

# the climate of a world and the weathers a place may bring: its region's, else its climate's
fn weatherList(
	mut plugin esm.Esm,
	worldId i64,
	x f32,
	y f32,
	climate esm.Climate
):
	regions = plugin.weatherRegionsAt(worldId, x, y)
	if not regions.isEmpty:
		if plugin.regionOf(regions[0]) is r: return r.weathers.copy()
	climate.weathers.copy()

fn loadWeathers(mut plugin esm.Esm, entries esm.RegionWeather[]):
	out {i64: esm.Weather} = {}
	for e in entries:
		if plugin.weatherOf(e.weather) is w: out[e.weather] = w
	out

# the particles the weathers let fall, each once
fn loadPrecipitations(mut plugin esm.Esm, weathers {i64: esm.Weather}):
	out {i64: esm.Precipitation} = {}
	for w in weathers.values():
		if w.precipitation == 0 or w.precipitation in out: continue
		if plugin.precipitationOf(w.precipitation) is p: out[w.precipitation] = p
	out

# the image spaces the weathers name, each once
fn loadSpaces(mut plugin esm.Esm, weathers {i64: esm.Weather}):
	out {i64: esm.ImageSpace} = {}
	for w in weathers.values():
		for s in w.imageSpaces:
			if s == 0 or s in out: continue
			if plugin.imageSpaceOf(s) is space: out[s] = space
	out

# The sky of the place (game units) in the world: its weathers read, its meshes and textures sent
# to the GPU, the first weather picked as the game picks it. None when the plugin has no climate
# for the world.
pub fn openSkyClock(
	mut plugin esm.Esm,
	worldId i64,
	x f32,
	y f32,
	hour f32,
	seed i64
) SkyClock?:
	climateId = try plugin.worldClimate(worldId)
	climate = try plugin.climateOf(climateId)
	entries = plugin.weatherList(worldId, x, y, climate)
	weathers = plugin.loadWeathers(entries)
	chances = plugin.weatherChances(entries)
	rng = Random(seed)
	first = try world.pickWeather(entries, chances, rng.nextInt(0, 2_000_000_000))
	settings = plugin.gameSettings()
	extension = f32(settings.get("fdaytimecolorextension") ?? 0.5)
	SkyClock(
		weathers,
		imageSpaces = plugin.loadSpaces(weathers),
		precipitations = plugin.loadPrecipitations(weathers),
		masser = world.moonSettings("Masser", world.masserDefaults(), settings),
		secunda = world.moonSettings("Secunda", world.secundaDefaults(), settings),
		climate,
		entries,
		chances,
		state = world.WeatherState(current = first, last = 0, changedAt = hour),
		extension,
		rng
	)

# the archive key of a sky model
fn skyModel(i skyrim.Install, name str):
	key = skyrim.modelKey(name)
	n = i.readModel(key) ?? fail("no {key}: {error}")
	n.drawParts()

# the textures of the cloud layers of the weathers
fn cloudPathsOf(weathers {i64: esm.Weather}):
	paths = []
	for w in weathers.values():
		for layer in w.layers:
			paths.push(layer.texture.copy())
	paths

# The clock's sky as the scene draws it: the game's meshes read and the textures of the cloud
# layers its weathers have, with the climate's sun and glare, sent to the GPU.
pub fn newSkyDrawing(i skyrim.Install, c SkyClock) world.SkyDraw:
	i.skyDrawing(cloudPathsOf(c.weathers), c.precipitations.values().map(.copy()), c.climate)

# the same for the cloud textures named and the precipitations that may fall
pub fn skyDrawing(
	i skyrim.Install,
	cloudPaths str[],
	precipitations esm.Precipitation[],
	climate esm.Climate
) world.SkyDraw:
	dome = i.skyModel("sky/atmosphere.nif")
	clouds = i.skyModel("sky/clouds.nif")
	stars = i.skyModel("sky/stars.nif")
	body = []
	table = newTextureTable(body)
	paths = [climate.sunTexture.copy(), climate.glareTexture.copy()]
	for p in clouds:
		paths.push(p.diffuse.copy())
	for p in stars:
		paths.push(p.diffuse.copy())
	paths.extend(cloudPaths.map(.copy()))
	for p in precipitations:
		paths.push(p.texture.copy())
	for moon in [world.masserDefaults(), world.secundaDefaults()]:
		if moon.name == "masser" and not climate.masser: continue
		if moon.name == "secunda" and not climate.secunda: continue
		for phase in 0..world.moonPhases.len:
			paths.push(world.moonTexture(moon.name, phase))
	for path in paths:
		if not path.isEmpty: table.textureIndex(i, path, flatDiffuse, body)
	textures = table.textures.map(world.gpuTexture(body, it))
	world.newSkyDraw(
		dome[0],
		clouds,
		stars,
		textures,
		slots = table.byKey.copy(),
		sunTexture = climate.sunTexture,
		glareTexture = climate.glareTexture,
		precipitations = precipitations
	)

# the weather in force
fn currentOf(c SkyClock):
	c.weathers.get(c.state.current) ?? fail("a weather the clock lacks")

# The weather steps on to the game hour: it lasts its time, then the region's list is rolled for the
# next, which comes in over the weather's transition.
pub fn advance(mut c SkyClock, hour f32):
	cur = c.currentOf()
	roll = c.rng.nextInt(0, 2_000_000_000)
	keep = f32(c.rng.nextFloat(0.0, 1.0))
	c.state = c.state.stepWeather(
		hour,
		c.climate.volatility,
		cur.transDelta,
		c.entries,
		c.chances,
		roll,
		false,
		keep
	)

# the sky at the game hour of the first day
pub fn skyAt(c SkyClock, hour f32, flash f32) world.Sky:
	c.skyOn(hour, flash, hour / 24.0)

# the sky at the game hour of `days` (the game's days passed, the fraction the hour) with the weather
# in force and, while one gives way, the last; the moons by the days, the rain or snow by the weather
pub fn skyOn(c SkyClock, hour f32, flash f32, days f32) world.Sky:
	cur = c.currentOf()
	share = c.state.shareAt(hour, cur.transDelta)
	time = world.SkyTime(hour, share, extension = c.extension, flash)
	# the last weather only while one gives way (a copy: the clock keeps the weathers)
	last esm.Weather? = none
	if c.state.last != 0 and c.weathers.get(c.state.last) is l: last = l.copy()
	sky = cur.skyAt(last, c.climate, time)
	hours = (days * 24.0 - world.startHour).max(0.0)
	sky.moons = c.climate.moonsAt(c.masser, c.secunda, hours, i64(days), sky.starsAlpha)
	curSpec esm.Precipitation? = none
	if c.precipitations.get(cur.precipitation) is p: curSpec = p.copy()
	lastSpec esm.Precipitation? = none
	if last is l and c.precipitations.get(l.precipitation) is p: lastSpec = p.copy()
	sky.precipitation = cur.precipitationsOf(curSpec, last, lastSpec, share)
	sky

# the image space of the sky's hour: the weather's four, blended as its colors are
pub fn imageSpaceAt(c SkyClock, sky world.Sky) esm.ImageSpace:
	spaces = []
	weights = []
	for k, form in sky.imageSpaces:
		if c.imageSpaces.get(form) is s:
			spaces.push(s.copy())
			weights.push(sky.imageWeights[k])
	if spaces.isEmpty:
		return (c.imageSpaces.values().first ?? fail("a clock with no image space")).copy()
	esm.mixedSpaces(spaces, weights)
