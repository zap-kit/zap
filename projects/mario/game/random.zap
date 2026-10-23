# The game's random numbers (random_u16): a 16-bit state stirred by shifts and xors, 0 at boot.

pub type Random:
	seed i64

# the state the objects of a level find when they first run, the game started afresh (one
# number already drawn)
pub fn levelRandom() Random:
	r = Random(seed = 0)
	r.randomU16()
	r

pub fn randomU16(mut r Random) i64:
	if r.seed == 22_026:
		r.seed = 0
	t1 = ((r.seed & 0xFF) << 8) ^ r.seed
	r.seed = ((t1 & 0xFF) << 8) + ((t1 & 0xFF00) >> 8)
	t1 = (((t1 & 0xFF) << 1) ^ r.seed) & 0xFFFF
	t2 = (t1 >> 1) ^ 0xFF80
	if (t1 & 1) == 0:
		r.seed = 0 if t2 == 43_605 else t2 ^ 0x1FF4
	else:
		r.seed = t2 ^ 0x8180
	r.seed

# random_float: 0 to 1, 65536 steps
pub fn randomFloat(mut r Random) f32:
	f32(r.randomU16() / 65536.0)
