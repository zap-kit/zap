# The game's angles and the arithmetic it does on them (math_util.c): 0x10000 a turn, stored
# in 16 bits (s16) where the game stores them; the sine and cosine looked up in its table
# (n64.sins), the arctangent in gArctanTable (1025 steps over an eighth of a turn) the way
# atan2s folds every direction into that eighth.

import n64

# gArctanTable: the angle of (1024, i), rounded; these are the cartridge's values
arctanTable = makeArctans()

fn makeArctans():
	out = []
	for i in 0..0x401:
		out.push(i64((f64(i).atan2(1024.0) * 32768.0 / pi).round()))
	out

pub fn sins(a i64) f32:
	n64.sins(a)

pub fn coss(a i64) f32:
	n64.coss(a)

# atan2_lookup: the angle of y / x for one in 0..1
fn atan2Lookup(y f32, x f32):
	if x == 0.0: return arctanTable[0]
	arctanTable[i64(y / x * 1024.0 + 0.5)]

# atan2s: the angle from (0, 0) to (x, y); with (z, x) it is a yaw
pub fn atan2s(y0 f32, x0 f32) i64:
	y = y0
	x = x0
	ret = 0
	if x >= 0.0:
		if y >= 0.0:
			if y >= x:
				ret = atan2Lookup(x, y)
			else:
				ret = 0x4000 - atan2Lookup(y, x)
		else:
			y = -y
			if y < x:
				ret = 0x4000 + atan2Lookup(y, x)
			else:
				ret = 0x8000 - atan2Lookup(x, y)
	else:
		x = -x
		if y < 0.0:
			y = -y
			if y >= x:
				ret = 0x8000 + atan2Lookup(x, y)
			else:
				ret = 0xC000 - atan2Lookup(y, x)
		else:
			if y < x:
				ret = 0xC000 + atan2Lookup(y, x)
			else:
				ret = -atan2Lookup(x, y)
	i16.wrap(ret)

# the yaw of the direction (x, z): sins of it is x's share, coss z's
pub fn yawOf(x f32, z f32) i64:
	atan2s(z, x)

# approach_f32 and approach_s32: `v` toward `target`, up by `up` or down by `down` at most
fn approach<T Num>(v0 T, target T, up T, down T) T:
	v = v0
	if v < target:
		v += up
		if v > target:
			v = target
	else:
		v -= down
		if v < target:
			v = target
	v

# vec3f_get_dist_and_angle: how far `to` is from `from`, and the pitch and yaw toward it
pub fn vec3fGetDistAndAngle(from Vec3, to Vec3) (f32, i64, i64):
	x = to.x - from.x
	y = to.y - from.y
	z = to.z - from.z
	((x * x + y * y + z * z).sqrt(), atan2s((x * x + z * z).sqrt(), y), atan2s(z, x))

# vec3f_set_dist_and_angle: the point `dist` away from `from` at that pitch and yaw
pub fn vec3fSetDistAndAngle(from Vec3, dist f32, pitch i64, yaw i64) Vec3:
	Vec3(
		from.x + dist * coss(pitch) * sins(yaw),
		from.y + dist * sins(pitch),
		from.z + dist * coss(pitch) * coss(yaw)
	)

test "the arctangent table holds the cartridge's values":
	expect (
		arctanTable[1] == 0x000A and arctanTable[100] == 0x03F7 and arctanTable[500] == 0x1282 and
			arctanTable[1000] == 0x1F84 and arctanTable[1024] == 0x2000
	)
	expect atan2s(-64.0, 0.0) == -0x8000 and atan2s(1.0, 0.0) == 0 and atan2s(0.0, 1.0) == 0x4000

test "the sine table holds the cartridge's values":
	expect (
		sins(16) == 0.0015339801320806146 and sins(1000 * 16) == 0.9993223547935486 and
			sins(0x8000) == 0.0 and coss(0x8000) == -1.0
	)
