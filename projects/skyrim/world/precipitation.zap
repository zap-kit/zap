# What falls from the sky as SkyrimSE.exe 1.7.104 makes it: Precipitation::Update 0x14040eed0 shows
# the current weather's particles as the weather comes in past its precipitation begin (how many of
# them, `amount`) and the last weather's as it gives way before its precipitation end, each a cube
# about the eye of 10 x 10 x 10 particles built from the weather's SPGD (0x14029f4e0: one particle
# a jittered cell of the cube, its corners offset in clip space, its texture a random cell of the
# particle texture) that the fall and the wind carry along and the cube wraps
# (FUN_1402a0440). The wind is fPrecipWindMult times the weather's wind speed toward its
# direction (0x140413f10). The exe applies no wetness to the world: the snow's look is the lighting
# shader's own.
#
# Not ported: the precipitation occlusion map (no rain under a roof), the raindrop splashes of the
# weather's other effects, the amount's use past 1 (the pool holds two cubes and a density of 2 draws
# both).

import engine
import skyrim.esm
import world.shaders

# the cube's particles on each axis, and the cubes a mesh holds (the weathers' densities reach 3)
cells = 10
cubeParticles = 1000
cubes = 3
# the precipitations that fall at once: the current weather's and the last's
precipSlots = 2

# fPrecipWindMult
precipWindMult f32 = 500.0
# a streak's tail is the head less the velocity over this: DAT_14181dfe4, 1 / 15
streakShare f32 = 1.0 / 15.0
# the end of a fading weather's rain, over its byte (DAT_141b5bdc4)
endFloor f32 = 0.001

# what falls from one weather this frame: its particles, how many cubes' worth of them (0 hides
# them) and the wind that carries them (game units a second, z up)
pub type PrecipitationNow:
	spec esm.Precipitation
	amount f32
	wind Vec3

# the particles a current weather shows: nothing until its share passes its begin, then up to its
# density as the weather comes in whole
pub fn currentAmount(share f32, begin i64, density f32) f32:
	b = f32(begin) * byteScale
	if share <= b: return 0.0
	(share - b) * density / (1.0 - b)

# the particles the last weather still shows while it gives way: all its density at the start, none
# by its end
pub fn lastAmount(share f32, end i64, density f32) f32:
	e = f32(end) * byteScale + endFloor
	if e <= share: return 0.0
	(1.0 - share / e) * density

# The wind's speed from the weather's byte and the last one's (Sky+0x18c: the current times how far
# it has come in, plus the last's times the rest) and its direction in radians from the weather's bytes
# (0x140413f10, the midpoint: the game strays up to the range either side)
pub fn windSpeedOf(current esm.Weather, last esm.Weather?, share f32) f32:
	now = f32(current.windSpeed) * byteScale
	if last is l: return share * now + f32(l.windSpeed) * (1.0 - share) * byteScale
	now

pub fn windDirectionOf(w esm.Weather) f32:
	(f32(w.windDirection) * 360.0 / 256.0).radians()

# the wind a weather's particles are carried by
pub fn windOf(speed f32, direction f32) Vec3:
	Vec3(direction.cos(), direction.sin(), 0.0) * (precipWindMult * speed)

# what falls in this sky: the current weather's, then the last's, those with something to show
pub fn precipitationsOf(
	current esm.Weather,
	currentSpec esm.Precipitation?,
	last esm.Weather?,
	lastSpec esm.Precipitation?,
	share f32
) PrecipitationNow[]:
	wind = windOf(current.windSpeedOf(last, share), current.windDirectionOf())
	out = []
	if currentSpec is s:
		amount = currentAmount(share, current.precipitationBegin, s.density)
		if amount > 0.0: out.push(PrecipitationNow(spec = s.copy(), amount, wind))
	if last is l and lastSpec is s:
		amount = lastAmount(share, l.precipitationEnd, s.density)
		if amount > 0.0: out.push(PrecipitationNow(spec = s.copy(), amount, wind))
	out

# how fast the cube's particles go (game units a second, z up): the wind and the fall
pub fn velocityOf(n PrecipitationNow) Vec3:
	n.wind + Vec3(0.0, 0.0, -n.spec.gravity)

# the cube's offset `dt` seconds on: carried by the velocity, wrapped to the box (FUN_1402a0440)
pub fn carried(n PrecipitationNow, offset Vec3, dt f32) Vec3:
	moved = offset + n.velocityOf() * dt
	box = n.spec.boxSize
	Vec3(wrapBox(moved.x, box), wrapBox(moved.y, box), wrapBox(moved.z, box))

fn wrapBox(x f32, box f32):
	(x % box + box) % box

# One precipitation's particles on the GPU: the quads of `cubes` cubes
pub type PrecipitationMesh:
	model engine.Model
	indices engine.IndexBuffer

fn rotated(x f32, y f32, angle f32):
	s = angle.sin()
	c = angle.cos()
	Vec2(x * c + y * s, y * c - x * s)

# the four corners of one particle: the quad's corners (size x, y) turned by a random angle within
# the range, and a random cell of the texture
fn particleAt(
	spec esm.Precipitation,
	place Vec3,
	angle f32,
	cell i64,
	mut vertices shaders.PrecipVertex[]
):
	columns = f32(spec.columns.max(1))
	rows = f32(spec.rows.max(1))
	u0 = f32(cell % spec.columns.max(1)) / columns
	v0 = f32(cell / spec.columns.max(1)) / rows
	u1 = u0 + 1.0 / columns
	v1 = v0 + 1.0 / rows
	offsets = [
		rotated(spec.sizeX, spec.sizeY, angle),
		rotated(spec.sizeX, -spec.sizeY, angle),
		rotated(-spec.sizeX, -spec.sizeY, angle),
		rotated(-spec.sizeX, spec.sizeY, angle)
	]
	uvs = [Vec2(u1, v1), Vec2(u1, v0), Vec2(u0, v0), Vec2(u0, v1)]
	for k in 0..4:
		vertices.push(shaders.PrecipVertex(position = place, corner = offsets[k], uv = uvs[k]))

# a precipitation's cubes of particles: each a cell of a 10 x 10 x 10 lattice over the cube (its
# border cells wrapped), jittered by up to half a cell
pub fn newPrecipitationMesh(spec esm.Precipitation, seed i64) PrecipitationMesh:
	rng = Random(seed)
	vertices = []
	indices = []
	cell = spec.boxSize / 9.0
	for n in 0..cubes * cubeParticles:
		i = (n / (cells * cells)) % cells
		j = (n / cells) % cells
		k = n % cells
		jitter = Vec3(
			f32(rng.nextFloat(-1.0, 1.0)),
			f32(rng.nextFloat(-1.0, 1.0)),
			f32(rng.nextFloat(-1.0, 1.0))
		) * (cell * 0.5)
		place = Vec3(f32(i) * cell, f32(j) * cell, f32(k) * cell) + jitter
		angle = f32(rng.nextFloat(-0.5, 0.5)) * spec.rotationRange.radians()
		first = u32(vertices.len)
		particleAt(
			spec,
			place.yUp(),
			angle,
			rng.nextInt(0, spec.columns.max(1) * spec.rows.max(1)),
			vertices
		)
		indices.extend([first + 1, first, first + 2, first + 2, first, first + 3])
	PrecipitationMesh(model = engine.newModel(vertices), indices = engine.newIndexBuffer(indices))
