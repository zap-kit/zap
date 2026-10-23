# Shadows as shadow.c casts them: a square of 9 or 4 vertices laid on the floor under an object,
# its texture a circle (or square) and its alpha the shadow's solidity, dimmed and shrunk as the
# object rises up to 600 units over the floor. A 9-vertex shadow sets each vertex on the floor
# below it, and one off the center's floor plane is hidden (alpha 0) and moved onto that plane.

pub shadowCircle9 = 0
pub shadowCircle4 = 1
pub shadowCircleFlat = 2
pub shadowSquarePermanent = 10
pub shadowSquareScalable = 11
pub shadowSquareTogglable = 12
pub shadowCirclePlayer = 99

surfaceIce = 0x2E

# the floor a shadow lies on
type ShadowFloor:
	x f32   # the object's place
	y f32
	z f32
	height f32
	normal Vec3
	offset f32
	scale f32
	solidity i64
	downward f32   # the way down the slope, in degrees
	tilt f32   # the slope, in degrees
	overWater bool

# The vertices (n64.vertexFloats each, in the world's space) of the shadow of an object at
# (x, y, z), appended to `out`, and the layer it is drawn in; -1 when it casts none.
pub fn castShadow(
	s Surfaces,
	x f32,
	y f32,
	z f32,
	kind i64,
	solidity i64,
	scale f32,
	mut out f32[]
) i64:
	_, below = s.findFloor(x, y, z)
	onIce = below >= 0 and s.all[below].kind == surfaceIce
	nine = kind == shadowCircle9 or kind == shadowCirclePlayer
	if not nine and kind != shadowCircle4:
		return -1   # the square ones: none cast in the levels drawn
	sh = s.shadowFloor(x, y, z, scale, solidity) ?? return -1
	n = 9 if nine else 4
	verts = []
	for i in 0..n:
		verts.push(s.shadowVertex(sh, i, nine))
	order = [0, 3, 4, 0, 4, 1, 1, 4, 2, 2, 4, 5, 3, 6, 4, 4, 6, 7, 4, 7, 8, 4, 8, 5] if nine
		else [0, 2, 1, 1, 2, 3]
	for i in order:
		vx, vy, vz, alpha = verts[i]
		# the texture: -15, 0 or 15 texels (s10.5) scaled by gsSPTexture's 0xFFFF, bilinear's half texel
		tx = i % 3 * 15 - 15 if nine else i % 2 * 30 - 15
		ty = i / 3 * 15 - 15 if nine else i / 2 * 30 - 15
		u = f32((tx * 32 * 0xFFFF) >> 16) / 32.0 + 0.5
		w = f32((ty * 32 * 0xFFFF) >> 16) / 32.0 + 0.5
		for v in [vx, vy, vz, 1.0, 1.0, 1.0, u / 16.0, w / 16.0, f32(alpha) / 255.0, 0.0]:
			out.push(v)
	if sh.overWater: return 4
	5 if onIce else 6

# init_shadow: the floor under the object (or the water over it), the shadow's size and alpha
fn shadowFloor(s Surfaces, x f32, y f32, z f32, scale f32, solidity i64) ShadowFloor?:
	floorY, floor = s.findFloor(x, y, z)
	height = floorY + 0.4   # shadow.c lifts every floor height it finds
	water = s.waterLevel(x, z)
	overWater = water >= -10000.0 and y >= water and height <= water
	normal = Vec3(0.0, 1.0, 0.0)
	offset = 0.0
	if overWater:
		height = water
		offset = -water
	else:
		if height < -10000.0 or floor < 0 or s.all[floor].normal.y <= 0.0: return none
		normal = s.all[floor].normal
		offset = s.all[floor].offset
	rise = y - height
	steep = (normal.x * normal.x + normal.z * normal.z).sqrt()
	ShadowFloor(x, y, z, height, normal, offset, scale = scaledWithRise(scale, rise),
		solidity = dimmedWithRise(solidity, rise),
		downward = angleDegrees(normal.z, normal.x),
		tilt = 0.0 if steep == 0.0 else 90.0 - angleDegrees(steep, normal.y),
		overWater)

fn scaledWithRise(scale f32, rise f32):
	if rise <= 0.0: return scale
	if rise >= 600.0: return scale * 0.5
	scale * (1.0 - 0.5 * rise / 600.0)

fn dimmedWithRise(solidity i64, rise f32) i64:
	if solidity < 121 or rise <= 0.0: return solidity
	if rise >= 600.0: return 120
	i64(f32(120 - solidity) * rise / 600.0 + f32(solidity))

# atan2_deg: the game's atan2s(a, b) (the angle of (b, a) from the z axis, 0x10000 a turn) in degrees
fn angleDegrees(a f32, b f32):
	units = i64(i16.wrap(i64(f64(b).atan2(f64(a)) * 32768.0 / pi)))
	f32(units / 65535.0 * 360.0)

# make_shadow_vertex: vertex i's place in the world and its alpha
fn shadowVertex(s Surfaces, sh ShadowFloor, i i64, nine bool):
	ux = i % 3 - 1 if nine else i % 2 - 1
	uz = i / 3 - 1 if nine else i / 2 - 1
	if not nine:
		ux = 1 if ux == 0 else ux
		uz = 1 if uz == 0 else uz
	k = pi / 180.0
	tilted = (sh.tilt * k).cos() * sh.scale
	down = sh.downward * k
	half = f32(ux) * sh.scale / 2.0
	halfTilted = f32(uz) * tilted / 2.0
	x = halfTilted * down.sin() + half * down.cos() + sh.x
	z = halfTilted * down.cos() - half * down.sin() + sh.z
	alpha = 200 if sh.overWater else sh.solidity
	y = sh.height
	if not sh.overWater:
		if nine:
			floorY, _ = s.findFloor(x, sh.y, z)
			y = floorY + 0.4
			# floor_local_tilt, kept as an s16: off the center's plane, onto it and hidden
			tilt = (x - sh.x) * sh.normal.x + (y - sh.height) * sh.normal.y +
				(z - sh.z) * sh.normal.z
			if i16.wrap(i64(tilt)) != 0:
				y = sh.planeHeight(x, z)
				alpha = 0
		else:
			y = sh.planeHeight(x, z)
	# placed by s16 offsets from the object (round_float)
	(sh.x + rounded(x - sh.x), sh.y + rounded(y - sh.y), sh.z + rounded(z - sh.z), alpha)

# extrapolate_vertex_y_position: the height of the center's floor plane at (x, z)
fn planeHeight(sh ShadowFloor, x f32, z f32):
	-(sh.normal.x * x + sh.normal.z * z + sh.offset) / sh.normal.y

fn rounded(v f32):
	f32(i16.wrap(i64(v + 0.5 if v >= 0.0 else v - 0.5)))
