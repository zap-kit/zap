# Particle systems as Special Edition keeps them: NiParticleSystem (a shape whose particles the game
# makes: its shader, its data, whether they live in the world, its modifiers), NiPSysData (how many
# at most, the atlas's cells), and the modifiers that run them each frame: the emitters (a volume:
# a box, a cylinder, a sphere about an object; or a mesh's vertices), age and death, gravity, drag,
# color and size over the particle's life, its turn; run by the engine's particles
# (engine/scene/particles.zap).

import engine

pub type ParticleSystem:
	av Av
	shader i64
	alpha i64
	data i64
	worldSpace bool
	modifiers i64[]

pub type ParticleData:
	maxCount i64
	subtextures Vec4[]   # the atlas's cells: u and its width, v and its height
	aspect Aspect = Aspect()

# NiParticlesData's aspect: with flag 0x1 a quad's width over its height (drawn as its height
# growing), and with flag 0x100 that ratio moving from `ratio` at `speed1` to `ratio2` at `speed2`
# by the particle's speed
pub type Aspect:
	ratio f32 = 1.0
	flags i64 = 0
	ratio2 f32 = 1.0
	speed1 f32 = 0.0
	speed2 f32 = 0.0

pub type ModifierKind:
	VolumeEmitter(emission engine.Emission, object i64, shape i64, size Vec3)   # box w h d, radius height
	MeshEmitter(emission engine.Emission, meshes i64[])
	AgeDeath
	Gravity(object i64, axis Vec3, decay f32, strength f32, spherical bool, turbulence f32)
	Drag(object i64, axis Vec3, percentage f32)
	SimpleColor(fadeIn f32, fadeOut f32, times Vec4, colors Vec4[])   # colors 1 to 2 to 3
	Rotation(speed f32, speedVariation f32, angle f32, angleVariation f32, randomSign bool)
	Scale(scales f32[])   # over the life, evenly apart
	Unread

pub type Modifier:
	name str
	active bool
	kind ModifierKind

# NiParticleSystem as Special Edition's BSGeometry: the bound, the skin, the shader and alpha,
# the vertex description and the LOD distances, the data, then the world space and modifiers
fn readParticleSystem(mut s Reader, names str[]):
	av = s.readAv(names)
	s.skip(20)   # the bounding sphere, the skin
	shader = s.i32()
	alpha = s.i32()
	s.skip(16)   # the vertex description, the far and near distances
	data = s.i32()
	worldSpace = s.u8() != 0
	ParticleSystem(av, shader, alpha, data, worldSpace, modifiers = s.readRefs())

# NiPSysData as Special Edition keeps it: NiGeometryData's fields without arrays, then
# NiParticlesData's flags and the atlas's cells
fn readParticleData(mut s Reader):
	s.skip(4)   # the group id
	maxCount = s.u16()
	s.skip(3)   # the keep and compress flags, whether it has vertices
	s.skip(7)   # the data flags, the material's CRC, whether it has normals
	s.skip(17)   # the bounding sphere, whether it has vertex colors
	s.skip(6)   # the consistency flags, the additional data
	s.skip(8)   # whether it has radii, the active count, sizes, rotations, angles, axes, indices
	cells = s.u32()
	subtextures = []
	if s.has(cells * 16):
		loop cells:
			subtextures.push(s.vec4())
	aspect = Aspect()
	if s.has(18):
		aspect = Aspect(
			ratio = s.f32(),
			flags = s.u16(),
			ratio2 = s.f32(),
			speed1 = s.f32(),
			speed2 = s.f32()
		)
	ParticleData(maxCount, subtextures, aspect)

fn readEmission(mut s Reader):
	speed = s.f32()
	speedVariation = s.f32()
	declination = s.f32()
	declinationVariation = s.f32()
	planarAngle = s.f32()
	planarAngleVariation = s.f32()
	color = s.vec4()
	radius = s.f32()
	radiusVariation = s.f32()
	life = s.f32()
	engine.Emission(
		speed, speedVariation, declination, declinationVariation, planarAngle,
		planarAngleVariation, color, radius, radiusVariation, life, lifeVariation = s.f32()
	)

fn readVolumeEmitter(mut s Reader, kind str) ModifierKind:
	emission = s.readEmission()
	object = s.i32()
	match kind:
		"NiPSysBoxEmitter":
			w = s.f32()
			h = s.f32()
			.VolumeEmitter(emission, object, engine.volumeBox, Vec3(w, h, s.f32()))
		"NiPSysCylinderEmitter":
			r = s.f32()
			.VolumeEmitter(emission, object, engine.volumeCylinder, Vec3(r, s.f32(), 0.0))
		_: .VolumeEmitter(emission, object, engine.volumeSphere, Vec3(s.f32(), 0.0, 0.0))

fn readGravity(mut s Reader) ModifierKind:
	object = s.i32()
	axis = s.vec3()
	decay = s.f32()
	strength = s.f32()
	spherical = s.u32() == 1
	turbulence = s.f32()
	.Gravity(object, axis, decay, strength, spherical, turbulence * s.f32())

fn readSimpleColor(mut s Reader) ModifierKind:
	fadeIn = s.f32()
	fadeOut = s.f32()
	times = s.vec4()
	colors = []
	loop 3:
		colors.push(s.vec4())
	.SimpleColor(fadeIn, fadeOut, times, colors)

fn readRotation(mut s Reader) ModifierKind:
	speed = s.f32()
	speedVariation = s.f32()
	angle = s.f32()
	angleVariation = s.f32()
	.Rotation(speed, speedVariation, angle, angleVariation, s.u8() != 0)

# what a modifier of this kind adds after NiPSysModifier's fields
fn readModifierKind(mut s Reader, kind str) ModifierKind:
	match kind:
		"NiPSysBoxEmitter", "NiPSysCylinderEmitter", "NiPSysSphereEmitter":
			s.readVolumeEmitter(kind)
		"NiPSysMeshEmitter":
			emission = s.readEmission()
			.MeshEmitter(emission, s.readRefs())
		"NiPSysAgeDeathModifier": .AgeDeath
		"NiPSysGravityModifier": s.readGravity()
		"NiPSysDragModifier":
			object = s.i32()
			axis = s.vec3()
			.Drag(object, axis, s.f32())
		"BSPSysSimpleColorModifier": s.readSimpleColor()
		"NiPSysRotationModifier": s.readRotation()
		"BSPSysScaleModifier":
			n = s.u32()
			.Scale(s.numbers(n, f32(0)))
		_: .Unread

# a particle system's modifier: its name, its order, its system, whether active, then its kind's
# fields; none for a block that is no modifier
fn readModifier(mut s Reader, names str[], kind str) Modifier?:
	if not (kind.startsWith("NiPSys") or kind.startsWith("BSPSys")) or kind.endsWith("Ctlr") or
		kind == "NiPSysData":
			return none
	name = s.readName(names)
	s.skip(8)   # the order, the system
	active = s.u8() != 0
	Modifier(name, active, kind = s.readModifierKind(kind))

# A modifier as a model places it: the transform of the object it names (an emitter's, a
# gravity's: the system's when none), a mesh emitter's vertices, and what its controllers play:
# an emitter's birth rate (particles a second), whether it runs (a bool, above one half).
pub type PlacedModifier:
	modifier Modifier
	object Mat4
	points Vec3[]
	rate Track?
	running Track?

# a particle system ready to run, in the model's space: its material, the most particles it holds,
# its atlas's cells, its modifiers
pub type Particles:
	name str
	transform Mat4
	diffuse str
	effect Effect?
	alpha Alpha
	twoSided bool
	maxCount i64
	subtextures Vec4[]
	aspect Aspect
	modifiers PlacedModifier[]

fn objectOf(m ModifierKind):
	match m:
		VolumeEmitter(_, object, _, _): object
		Gravity(object, _, _, _, _, _): object
		Drag(object, _, _): object
		_: -1

# the vertices of a mesh emitter's shapes, in the model's space
fn meshPoints(n Nif, m ModifierKind, worlds {i64: Mat4}):
	out = []
	if m is MeshEmitter(_, meshes):
		for i in meshes:
			if i < 0 or i >= n.blocks.len: continue
			if n.blocks[i] is ShapeBlock(shape):
				world = worlds.get(i) ?? Mat4(1.0)
				out.extend(n.geometryOf(shape).positions.map(world.applyPoint(it)))
	out

# the tracks of the system's controllers that name the modifier: its birth rate, whether it runs
fn modifierTracks(n Nif, controllers Controller[], name str):
	rate Track? = none
	running Track? = none
	for c in controllers:
		if c.modifier != name: continue
		if c.kind in emitterControllers:
			rate = n.trackOf(c.interpolator, 0, c.timing)
			running = n.trackOf(c.visibility, 0, c.timing)
		if c.kind == "NiPSysModifierActiveCtlr": running = n.trackOf(c.interpolator, 0, c.timing)
	(rate, running)

# The particle system p, `world` its transform in the model's space; `worlds` holds every object's
# the model draws.
fn particlesOf(n Nif, p ParticleSystem, world Mat4, worlds {i64: Mat4}):
	m = n.materialOf(p.shader)
	data = ParticleData(maxCount = 0, subtextures = [])
	if p.data >= 0 and p.data < n.blocks.len:
		if n.blocks[p.data] is ParticleDataBlock(d): data = d.copy()
	controllers = n.controllerChain(p.av.controller)
	modifiers = []
	for i in p.modifiers:
		if i < 0 or i >= n.blocks.len: continue
		if n.blocks[i] is ModifierBlock(mod):
			object = worlds.get(mod.kind.objectOf()) ?? world
			rate, running = n.modifierTracks(controllers, mod.name)
			modifiers.push(PlacedModifier(
				modifier = mod.copy(),
				object,
				points = n.meshPoints(mod.kind, worlds),
				rate,
				running
			))
	Particles(
		name = p.av.name.copy(),
		transform = world,
		diffuse = m.diffuse.copy(),
		effect = m.effect,
		alpha = n.alphaOf(p.alpha),
		twoSided = m.twoSided,
		maxCount = data.maxCount,
		subtextures = data.subtextures.copy(),
		aspect = data.aspect.copy(),
		modifiers
	)
