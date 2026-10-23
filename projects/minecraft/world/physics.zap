# What moves through the world: the ray of a look that finds the block aimed at, and a body
# (the player) that falls, jumps and is stopped by solid blocks.

# the block a ray reaches, and the face it enters through (its normal)
pub type Hit:
	found bool
	x i64
	y i64
	z i64
	nx i64
	ny i64
	nz i64

# The first block other than air and water that the ray from `origin` along `dir` reaches within
# `reach` blocks, crossing the grid one cell at a time (Amanatides and Woo).
pub fn raycast(w World, origin Vec3, dir Vec3, reach f32) Hit:
	d = dir.normalized()
	cell i64[3]   # the cell the ray is in
	step i64[3]   # its direction along each axis: -1 or +1
	next = Vec3(0.0, 0.0, 0.0)   # the distance along the ray to the next boundary on each axis
	across = Vec3(0.0, 0.0, 0.0)   # and between two boundaries
	for a in 0..3:
		cell[a] = i64(origin[a].floor())
		step[a] = 1 if d[a] > 0.0 else -1
		next[a] = boundary(origin[a], d[a])
		across[a] = 1.0e30 if d[a] == 0.0 else 1.0 / d[a].abs()
	normal i64[3]   # the face the ray entered the cell through
	t = 0.0
	while t <= reach:
		b = w.at(cell[0], cell[1], cell[2])
		if b != air and b != water:
			return Hit(
				found = true,
				x = cell[0],
				y = cell[1],
				z = cell[2],
				nx = normal[0],
				ny = normal[1],
				nz = normal[2]
			)
		# across the nearest boundary
		a = 0 if next[0] < next[1] and next[0] < next[2] else 1 if next[1] < next[2] else 2
		t = next[a]
		next[a] += across[a]
		cell[a] += step[a]
		for k in 0..3:
			normal[k] = -step[a] if k == a else 0
	Hit(found = false, x = 0, y = 0, z = 0, nx = 0, ny = 0, nz = 0)

# how far along a ray of direction d (one axis of it) from p the next whole coordinate lies
fn boundary(p f32, d f32) f32:
	if d == 0.0: return 1.0e30
	cell = p.floor()
	(cell + 1.0 - p if d > 0.0 else p - cell) / d.abs()

# ---------- a body ----------

pub bodyHalfWidth f32 = 0.3
pub bodyHeight f32 = 1.8
pub eyeHeight f32 = 1.62
gravity f32 = 28.0
jumpSpeed f32 = 8.6

pub type Body:
	feet Vec3   # the middle of its soles
	velocity Vec3
	onGround bool

pub fn newBody(feet Vec3) Body:
	Body(feet, velocity = Vec3(0.0, 0.0, 0.0), onGround = false)

# Moves the body over dt seconds: walking at `walk` (blocks per second, along the ground),
# jumping when asked and standing, falling, stopped by solid blocks one axis at a time.
pub fn stepBody(w World, mut b Body, walk Vec3, jump bool, dt f32):
	b.velocity.x = walk.x
	b.velocity.z = walk.z
	if jump and b.onGround:
		b.velocity.y = jumpSpeed
	b.velocity.y = (b.velocity.y - gravity * dt).max(-50.0)
	# in steps short enough that no block is passed over
	steps = i64(((b.velocity.length() * dt) / 0.25).ceil()).max(1)
	h = dt / f32(steps)
	b.onGround = false
	loop steps:
		for axis in 0..3:
			w.moveAxis(b, axis, b.velocity[axis] * h)

# the extent of a body along an axis, from its feet: x and z half its width each way, y its height up
fn reachBelow(axis i64) f32:
	0.0 if axis == 1 else bodyHalfWidth

fn reachAbove(axis i64):
	bodyHeight if axis == 1 else bodyHalfWidth

# the body moved by `delta` along an axis (0 x, 1 y, 2 z), held back at a solid block's side
fn moveAxis(w World, mut b Body, axis i64, delta f32):
	if delta == 0.0: return
	p = b.feet
	p[axis] += delta
	if not w.overlapsSolid(p):
		b.feet = p
		return
	# against the block: as close as the step allows, without touching
	e f32 = 0.001
	if delta > 0.0:
		b.feet[axis] = (p[axis] + reachAbove(axis)).floor() - reachAbove(axis) - e
	else:
		b.feet[axis] = (p[axis] - reachBelow(axis)).floor() + 1.0 + reachBelow(axis) + e
		if axis == 1:
			b.onGround = true
	b.velocity[axis] = 0.0

# whether a body with its feet at p would stand inside a solid block
pub fn overlapsSolid(w World, p Vec3) bool:
	lo i64[3]
	hi i64[3]
	for a in 0..3:
		lo[a] = i64((p[a] - reachBelow(a)).floor())
		hi[a] = i64((p[a] + reachAbove(a)).floor())
	for y in lo[1]..=hi[1]:
		for z in lo[2]..=hi[2]:
			for x in lo[0]..=hi[0]:
				if isSolid(w.at(x, y, z)): return true
	false

# whether the block x, y, z would overlap a body with its feet at p (no placing a block on it)
pub fn blockTouchesBody(x i64, y i64, z i64, p Vec3) bool:
	block = Vec3(f32(x), f32(y), f32(z))
	for a in 0..3:
		if block[a] >= p[a] + reachAbove(a) or block[a] + 1.0 <= p[a] - reachBelow(a): return false
	true
