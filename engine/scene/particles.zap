# Particles run on the CPU, as Gamebryo's particle systems run them: born of an emission (a
# speed, a direction as a declination from the emitter's z turned about z by a planar angle, a
# radius and a life, each varying either side of its value) in a volume (a box, a cylinder, a
# sphere) or at a point given, pulled by gravity (along an axis, or toward a center) shaken by
# turbulence, slowed by drag, turning, aging until they die; their color and size over their
# life; drawn as quads facing the camera, each in its cell of a texture atlas. Which emitters
# and forces run, and when, is the caller's (its format's modifiers).

# what an emitter gives a particle born: its speed, its direction (a declination from the
# emitter's z, turned about z by the planar angle), color, radius and life, each with how far it
# varies
pub type Emission:
	speed f32
	speedVariation f32
	declination f32
	declinationVariation f32
	planarAngle f32
	planarAngleVariation f32
	color Vec4
	radius f32
	radiusVariation f32
	life f32
	lifeVariation f32

# an emitter's volume: a box, its size w h d
pub volumeBox = 0
# a cylinder up z, its radius and height
pub volumeCylinder = 1
# a sphere, its radius
pub volumeSphere = 2

# a particle as it runs
pub type Particle:
	position Vec3
	velocity Vec3
	age f32
	life f32
	radius f32
	angle f32
	spin f32
	cell i64   # its atlas's cell, -1 the whole texture

# an emitter's particles as they run
pub type Swarm:
	particles Particle[] = []
	owed f32 = 0.0   # particles due and not born yet
	random Random

# an empty swarm whose randomness starts from `seed`
pub fn newSwarm(seed i64) Swarm:
	Swarm(random = Random(seed))

# a number `by` either side of `around`
fn spread(mut r Random, around f32, by f32):
	around + by * f32(r.nextFloat(-1.0, 1.0))

# a place in the volume `shape` of `size`, about its middle (z up the cylinder)
pub fn volumePoint(mut r Random, shape i64, size Vec3) Vec3:
	if shape == volumeBox:
		return Vec3(r.spread(0.0, 0.5) * size.x, r.spread(0.0, 0.5) * size.y,
			r.spread(0.0, 0.5) * size.z)
	turn = f32(r.nextFloat(0.0, 2.0 * pi))
	if shape == volumeCylinder:
		d = size.x * f32(r.nextFloat(0.0, 1.0)).sqrt()
		return Vec3(turn.cos() * d, turn.sin() * d, r.spread(0.0, 0.5) * size.y)
	up = r.spread(0.0, 1.0)
	across = (1.0 - up * up).max(0.0).sqrt()
	d = size.x * f32(r.nextFloat(0.0, 1.0).pow(1.0 / 3.0))
	Vec3(turn.cos() * across, turn.sin() * across, up) * d

# A particle of the emission born at `at`, sent along the axes of `toWorld` (the emitter's
# object's), its speed and radius scaled by `scale`, in a cell of the atlas's `cells` (none: the
# whole texture) taken at random.
pub fn bornParticle(
	mut r Random,
	emission Emission,
	at Vec3,
	toWorld Mat4,
	scale f32,
	cells i64
) Particle:
	declination = r.spread(emission.declination, emission.declinationVariation)
	planar = r.spread(emission.planarAngle, emission.planarAngleVariation)
	along = Vec3(declination.sin() * planar.cos(), declination.sin() * planar.sin(),
		declination.cos())
	speed = r.spread(emission.speed, emission.speedVariation * 0.5) * scale
	Particle(
		position = at,
		velocity = toWorld.applyDirection(along).normalized() * speed,
		age = 0.0,
		life = r.spread(emission.life, emission.lifeVariation * 0.5).max(0.01),
		radius = r.spread(emission.radius, emission.radiusVariation * 0.5) * scale,
		angle = 0.0,
		spin = 0.0,
		cell = r.nextInt(0, cells) if cells > 0 else -1
	)

# the particle set turning: its angle and its spin (radians a second) taken either side of theirs,
# the spin's sign at random when `randomSign`
pub fn spinParticle(
	mut r Random,
	mut p Particle,
	speed f32,
	speedVariation f32,
	angle f32,
	angleVariation f32,
	randomSign bool
):
	p.angle = r.spread(angle, angleVariation)
	p.spin = r.spread(speed, speedVariation)
	if randomSign and r.nextInt(0, 2) == 0: p.spin = -p.spin

# The swarm's particles aged by dt and the dead gone; a shake for each of the rest (each axis
# -1 .. 1), the turbulence gravity adds.
pub fn ageSwarm(mut s Swarm, dt f32) Vec3[]:
	for mut p in s.particles:
		p.age += dt
	s.particles = s.particles.filter(.age < .life)
	shakes = []
	loop s.particles.len:
		shakes.push(Vec3(s.random.spread(0.0, 1.0), s.random.spread(0.0, 1.0),
			s.random.spread(0.0, 1.0)))
	shakes

# the pull toward `center` of a spherical gravity at the particle, weakened by `decay` with distance
pub fn pullToward(p Particle, center Vec3, decay f32) Vec3:
	toward = center - p.position
	toward.normalized() / (1.0 + decay * toward.length())

# gravity over dt: the particle sped along `force` by `strength` and along its `shake` by
# `turbulence`, both scaled by `scale`
pub fn pullParticle(
	mut p Particle,
	force Vec3,
	strength f32,
	shake Vec3,
	turbulence f32,
	scale f32,
	dt f32
):
	p.velocity += (force * strength + shake * turbulence) * scale * dt

# drag over dt: the particle's velocity less `percentage` of it a second
pub fn dragParticle(mut p Particle, percentage f32, dt f32):
	p.velocity *= (1.0 - percentage * dt).max(0.0)

# the particle moved and turned over dt
pub fn moveParticle(mut p Particle, dt f32):
	p.position += p.velocity * dt
	p.angle += p.spin * dt

# The color at f of a life going through three colors, as Skyrim's BSPSysSimpleColorModifier
# (SkyrimSE.exe 0x14157d420): `times` x to y the first to the second, z to w the second to the
# third (a span of 0 skips its blend); the alpha the second's, from the first's over the first
# `fadeIn` of the life and toward the third's after `fadeOut` (0: no fade).
pub fn colorOverLife(fadeIn f32, fadeOut f32, times Vec4, colors Vec4[], f f32) Vec4:
	first = times.y - times.x
	second = times.w - times.z
	c = colors[1].rgb
	if first != 0.0 and f < times.y:
		c = colors[0].rgb.lerp(colors[1].rgb, ((f - times.x) / first).max(0.0))
	elif second != 0.0 and f > times.z:
		c = colors[1].rgb.lerp(colors[2].rgb, ((f - times.z) / second).min(1.0))
	a = colors[1].a
	if fadeOut != 0.0 and f > fadeOut:
		a = colors[1].a.lerp(colors[2].a, (f - fadeOut) / (1.0 - fadeOut))
	elif fadeIn != 0.0 and f < fadeIn:
		a = colors[0].a.lerp(colors[1].a, f / fadeIn)
	c.withW(a)

# the size at f of a life whose `scales` lie evenly over it (1 with none)
pub fn scaleOverLife(scales f32[], f f32) f32:
	if scales.isEmpty: return 1.0
	at = f.clamp(0.0, 1.0) * f32(scales.len - 1)
	k = i64(at)
	if k + 1 >= scales.len: return scales[len - 1]
	scales[k].lerp(scales[k + 1], at - f32(k))

# a quad's two triangles' corners, -1 .. 1 across and up
pub particleCorners = [Vec2(-1.0, -1.0), Vec2(1.0, -1.0), Vec2(1.0, 1.0), Vec2(-1.0, -1.0),
	Vec2(1.0, 1.0), Vec2(-1.0, 1.0)]

# the half axes of the particle's quad of half size `size`, across and up, facing the camera (its
# right and up) and turned by the particle's angle: corner c (of particleCorners) lies at
# position + across * c.x + up * c.y
pub fn quadAxes(p Particle, size f32, right Vec3, up Vec3) (Vec3, Vec3):
	across = (right * p.angle.cos() + up * p.angle.sin()) * size
	upward = (up * p.angle.cos() - right * p.angle.sin()) * size
	(across, upward)

# corner c's texture coordinate in the atlas's cell (u and its width, v and its height)
pub fn atlasUv(cell Vec4, c Vec2) Vec2:
	Vec2(cell.x + (c.x + 1.0) * 0.5 * cell.y, cell.z + (1.0 - c.y) * 0.5 * cell.w)
