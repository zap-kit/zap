# Repeatable noise, for making worlds and textures: the same point and seed always give the
# same number. A hash of whole points, value noise blended smoothly between them, and several
# octaves of it.

# a number 0 .. 2^31 that looks random, the same for the same x, y and seed
pub fn hash2(x i64, y i64, seed i64) i64:
	h = (x * 374_761_393 + y * 668_265_263 + seed * 1_442_695_041) & 0x7fff_ffff
	h = ((h ^ (h >> 13)) * 1_274_126_177) & 0x7fff_ffff
	h ^ (h >> 16)

# 0 .. 1, from the hash
pub fn random01(x i64, y i64, seed i64) f32:
	f32(hash2(x, y, seed)) / 2147483648.0

# value noise: random heights at the whole points, blended smoothly between them (0 .. 1)
pub fn valueNoise(x f32, y f32, seed i64) f32:
	x0 = x.floor()
	y0 = y.floor()
	ix = i64(x0)
	iy = i64(y0)
	tx = (x - x0).smoothstep(0.0, 1.0)
	ty = (y - y0).smoothstep(0.0, 1.0)
	a = random01(ix, iy, seed).lerp(random01(ix + 1, iy, seed), tx)
	b = random01(ix, iy + 1, seed).lerp(random01(ix + 1, iy + 1, seed), tx)
	a.lerp(b, ty)

# noise of several octaves, each twice as fine and half as strong (0 .. 1)
pub fn fractalNoise(x f32, y f32, octaves i64, seed i64) f32:
	sum = 0.0
	weight = 0.0
	amplitude = 1.0
	frequency = 1.0
	for o in 0..octaves:
		sum += valueNoise(x * frequency, y * frequency, seed + o * 101) * amplitude
		weight += amplitude
		amplitude *= 0.5
		frequency *= 2.0
	sum / weight
