# RSW, a map's world: "GRSW", a version (major, minor), the names of its ground (GND) and
# altitude (GAT) files, its water (before 2.6; later it is the GND's), the sun (a longitude and
# a latitude in degrees, the diffuse and ambient colors, the opacity of the shadows), then its
# objects: placed models (RSM files under data\model\), point lights, sounds and effects. Values
# are kept in the file's own units and axes (y down, a cell 10 units wide); names are their CP949
# bytes. What follows the objects (a quadtree of bounding boxes) is not read.

pub type Water:
	level f32
	kind i32   # its textures: data\texture\워터\water{kind}{frame}.jpg
	waveHeight f32
	waveSpeed f32
	wavePitch f32
	animSpeed i32   # frames of the game (60 a second) per texture

pub type Sun:
	longitude i64
	latitude i64
	diffuse Vec3
	ambient Vec3
	opacity f32   # how dark the lightmaps' shadows are drawn

pub type Model:
	name u8[]
	animType i64
	animSpeed f32
	blockType i64
	file u8[]   # under data\model\
	node u8[]
	position Vec3
	rotation Vec3   # degrees
	scale Vec3

pub type Light:
	name u8[]
	position Vec3
	color Vec3
	range f32

pub type Sound:
	file u8[]   # under data\wav\
	position Vec3
	volume f32
	range f32
	cycle f32

pub type Effect:
	name u8[]
	position Vec3
	id i64
	delay f32
	params Quat   # four numbers of the effect

pub type Rsw:
	version i64   # major * 256 + minor
	gnd u8[]
	gat u8[]
	water Water
	sun Sun
	models Model[]
	lights Light[]
	sounds Sound[]
	effects Effect[]

# the world of an RSW file, or why it cannot be read
pub fn parseRsw(d u8[]) Rsw ? str:
	if d.len < 6 or not d.startsWith("GRSW"): return "not an RSW file"
	version = i64(d[4]) * 256 + i64(d[5])
	r = Reader(d, at = 6)
	build = 0
	if version >= 0x205:
		build = r.i32()
	if version >= 0x202:
		r.skip(1)
	r.skip(40)   # the .ini file
	gnd = r.cStringBytes(40)
	gat = r.cStringBytes(40) if version >= 0x105 else gnd.copy()
	if version >= 0x104:
		r.skip(40)   # the .src file
	water = parseRswWater(version, r)
	sun = parseRswSun(version, r)
	if version >= 0x106:
		r.skip(16)   # the ground's bounds, unused
	if version >= 0x207:
		r.skip(i64(r.u32()) * 4)
	count = i64(r.u32())
	models = []
	lights = []
	sounds = []
	effects = []
	loop count:
		kind = r.i32()
		if kind == 1:
			m = parseRswModel(version, build, r)
			models.push(m)
		elif kind == 2:
			name = r.cStringBytes(80)
			position = Vec3.fromBytes(r)
			color = Vec3.fromBytes(r)
			lights.push(Light(name, position, color, range = r.f32()))
		elif kind == 3:
			r.skip(80)
			file = r.cStringBytes(80)
			position = Vec3.fromBytes(r)
			volume = r.f32()
			r.skip(8)
			range = r.f32()
			cycle = r.f32() if version >= 0x200 else 0.0
			sounds.push(Sound(file, position, volume, range, cycle))
		elif kind == 4:
			name = r.cStringBytes(80)
			position = Vec3.fromBytes(r)
			id = r.i32()
			delay = r.f32()
			effects.push(Effect(name, position, id, delay, params = Quat.fromBytes(r)))
		else:
			return "an RSW object of unknown kind {kind}"
		if r.short: return "the RSW's objects run past the end"
	Rsw(version, gnd, gat, water, sun, models, lights, sounds, effects)

fn parseRswWater(
	version i64,
	mut r Reader
):
	water = Water(
		level = 0.0,
		kind = 0,
		waveHeight = 1.0,
		waveSpeed = 2.0,
		wavePitch = 50.0,
		animSpeed = 3
	)
	if version < 0x206:
		if version >= 0x103:
			water.level = r.f32()
		if version >= 0x108:
			water.kind = r.i32()
			water.waveHeight = r.f32()
			water.waveSpeed = r.f32()
			water.wavePitch = r.f32()
		if version >= 0x109:
			water.animSpeed = r.i32()
	water

fn parseRswSun(
	version i64,
	mut r Reader
):
	sun = Sun(
		longitude = 45,
		latitude = 45,
		diffuse = Vec3(1.0, 1.0, 1.0),
		ambient = Vec3(0.3, 0.3, 0.3),
		opacity = 1.0
	)
	if version >= 0x105:
		sun.longitude = r.i32()
		sun.latitude = r.i32()
		sun.diffuse = Vec3.fromBytes(r)
		sun.ambient = Vec3.fromBytes(r)
	if version >= 0x107:
		sun.opacity = r.f32()
	sun

fn parseRswModel(
	version i64,
	build i64,
	mut r Reader
):
	m = Model(
		name = [],
		animType = 0,
		animSpeed = 1.0,
		blockType = 0,
		file = [],
		node = [],
		position = Vec3(0.0, 0.0, 0.0),
		rotation = Vec3(0.0, 0.0, 0.0), scale = Vec3(1.0, 1.0, 1.0))
	if version >= 0x103:
		m.name = r.cStringBytes(40)
		m.animType = r.i32()
		m.animSpeed = r.f32()
		m.blockType = r.i32()
	if version >= 0x206 and build >= 186:
		r.skip(1)
	if version >= 0x207:
		r.skip(4)
	m.file = r.cStringBytes(80)
	m.node = r.cStringBytes(80)
	m.position = Vec3.fromBytes(r)
	m.rotation = Vec3.fromBytes(r)
	m.scale = Vec3.fromBytes(r)
	m
