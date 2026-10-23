# The geometry a 2D or a 3D scene computes over the language's types (Vec3, Mat4, Quat): the
# projections and views a camera takes, the matrices that move, turn and scale a model
# (column-major, as a shader reads them), turns as quaternions, and what a camera sees. A module
# of the standard library: `import math`, then Mat4.perspective(...), Quat.about(axis, angle),
# q.rotate(v).

# ---------- projections and views ----------

# The projection of the rectangle left..right x top..bottom onto the screen (y grows downward,
# as in a window), depth -1..1.
pub fn ortho(left f32, right f32, bottom f32, top f32) Mat4:
	m f32[16]
	m[0] = 2.0 / (right - left)
	m[5] = 2.0 / (top - bottom)
	m[10] = -1.0
	m[12] = -(right + left) / (right - left)
	m[13] = -(top + bottom) / (top - bottom)
	m[15] = 1.0
	Mat4(m)

# The perspective of a camera whose view spans fovY radians from bottom to top, on a screen of
# width / height `aspect`; what lies between near and far (distances in front of it) is seen,
# mapped to depth -1..1.
pub fn perspective(fovY f32, aspect f32, near f32, far f32) Mat4:
	f = 1.0 / (fovY * 0.5).tan()
	m f32[16]
	m[0] = f / aspect
	m[5] = f
	m[10] = (far + near) / (near - far)
	m[11] = -1.0
	m[14] = 2.0 * far * near / (near - far)
	Mat4(m)

# The projection of the box left..right x bottom..top x near..far (distances in front of the
# eye, y up) onto the screen, without perspective: a sun's view, for its shadows.
pub fn orthoBox(left f32, right f32, bottom f32, top f32, near f32, far f32) Mat4:
	m f32[16]
	m[0] = 2.0 / (right - left)
	m[5] = 2.0 / (top - bottom)
	m[10] = -2.0 / (far - near)
	m[12] = -(right + left) / (right - left)
	m[13] = -(top + bottom) / (top - bottom)
	m[14] = -(far + near) / (far - near)
	m[15] = 1.0
	Mat4(m)

# The direction a camera looks when turned `yaw` radians from -z toward +x and tilted `pitch`
# radians up (a first-person camera's two angles).
pub fn lookDirection(yaw f32, pitch f32) Vec3:
	Vec3(x = yaw.sin() * pitch.cos(), y = pitch.sin(), z = -yaw.cos() * pitch.cos())

# The view of a camera at `eye` looking along `forward`, up being +y: the world moved so the eye
# is at the origin looking down -z.
pub fn lookAlong(eye Vec3, forward Vec3) Mat4:
	f = forward.normalized()
	s = f.cross(Vec3(0.0, 1.0, 0.0)).normalized()
	u = s.cross(f)
	m f32[16]
	m[0] = s.x
	m[4] = s.y
	m[8] = s.z
	m[1] = u.x
	m[5] = u.y
	m[9] = u.z
	m[2] = -f.x
	m[6] = -f.y
	m[10] = -f.z
	m[12] = -(s @ eye)
	m[13] = -(u @ eye)
	m[14] = f @ eye
	m[15] = 1.0
	Mat4(m)

# ---------- placing models ----------

# the move by `by` (a 2D one's z 0)
pub fn translation(by Vec3) Mat4:
	t = Mat4(1.0)
	t.m[12] = by.x
	t.m[13] = by.y
	t.m[14] = by.z
	t

# the scale by `by`'s x, y and z along the axes (a 2D one's z 1)
pub fn scaling(by Vec3) Mat4:
	s = Mat4(1.0)
	s.m[0] = by.x
	s.m[5] = by.y
	s.m[10] = by.z
	s

# A turn of `angle` radians about x, y or z, counter-clockwise seen from the axis's positive end
# (right-handed): rotationY(a) turns -z toward -x, so a model turned `yaw` faces as
# lookDirection(-yaw, 0) would have it. rotationAbout turns about any axis.
pub fn rotationX(angle f32) Mat4:
	c = angle.cos()
	s = angle.sin()
	r = Mat4(1.0)
	r.m[5] = c
	r.m[6] = s
	r.m[9] = -s
	r.m[10] = c
	r

pub fn rotationY(angle f32) Mat4:
	c = angle.cos()
	s = angle.sin()
	r = Mat4(1.0)
	r.m[0] = c
	r.m[2] = -s
	r.m[8] = s
	r.m[10] = c
	r

pub fn rotationZ(angle f32) Mat4:
	c = angle.cos()
	s = angle.sin()
	r = Mat4(1.0)
	r.m[0] = c
	r.m[1] = s
	r.m[4] = -s
	r.m[5] = c
	r

# a turn of `angle` radians about `axis` (made unit), as glm::rotate makes it
pub fn rotationAbout(axis Vec3, angle f32) Mat4:
	a = axis.normalized()
	c = angle.cos()
	s = angle.sin()
	k = 1.0 - c
	r = Mat4(1.0)
	r.m[0] = c + k * a.x * a.x
	r.m[1] = k * a.x * a.y + s * a.z
	r.m[2] = k * a.x * a.z - s * a.y
	r.m[4] = k * a.y * a.x - s * a.z
	r.m[5] = c + k * a.y * a.y
	r.m[6] = k * a.y * a.z + s * a.x
	r.m[8] = k * a.z * a.x + s * a.y
	r.m[9] = k * a.z * a.y - s * a.x
	r.m[10] = c + k * a.z * a.z
	r

# the turn q stands for, made unit first; none (the identity) for a q of length 0
pub fn rotationOf(q Quat) Mat4:
	Mat4.transformOf(Vec3(0.0, 0.0, 0.0), q, Vec3(1.0, 1.0, 1.0))

# A model's placement from its parts, as glTF gives a node's: scaled along its axes, turned by
# `rotation` (made unit first), then moved to `at`. Written out, not multiplied, since a skinned
# crowd makes one per node per frame.
pub fn transformOf(at Vec3, rotation Quat, scale Vec3) Mat4:
	n = rotation.length()
	q = Quat(0.0, 0.0, 0.0, 1.0) if n == 0.0 else rotation / n
	x, y, z, w = q.x, q.y, q.z, q.w
	r f32[16]
	r[0] = (1.0 - 2.0 * (y * y + z * z)) * scale.x
	r[1] = 2.0 * (x * y + w * z) * scale.x
	r[2] = 2.0 * (x * z - w * y) * scale.x
	r[4] = 2.0 * (x * y - w * z) * scale.y
	r[5] = (1.0 - 2.0 * (x * x + z * z)) * scale.y
	r[6] = 2.0 * (y * z + w * x) * scale.y
	r[8] = 2.0 * (x * z + w * y) * scale.z
	r[9] = 2.0 * (y * z - w * x) * scale.z
	r[10] = (1.0 - 2.0 * (x * x + y * y)) * scale.z
	r[12] = at.x
	r[13] = at.y
	r[14] = at.z
	r[15] = 1.0
	Mat4(m = r)

# a model stood at `at`, turned `yaw` radians about y (rotationY) and scaled by `size`
pub fn placement(at Vec3, yaw f32, size f32 = 1.0) Mat4:
	c = yaw.cos() * size
	s = yaw.sin() * size
	r = Mat4(1.0)
	r.m[0] = c
	r.m[2] = -s
	r.m[5] = size
	r.m[8] = s
	r.m[10] = c
	r.m[12] = at.x
	r.m[13] = at.y
	r.m[14] = at.z
	r

# The share of the way to a goal covered in dt seconds when what is left shrinks as e^(-rate t):
# a value eased by it moves the same at any frame rate.
pub fn easeShare(rate f32, dt f32) f32:
	1.0 - (-rate * dt).exp()

# ---------- turns ----------

# the shorter signed turn from the angle `from` to the angle `to` (radians), in -pi..pi
pub fn angleBetween(from f32, to f32) f32:
	d = to - from
	d - (d / (2.0 * pi) + 0.5).floor() * 2.0 * pi

# the angle `from` turned toward `to` by at most `most` radians, the shorter way round
pub fn turnToward(from f32, to f32, most f32) f32:
	from + angleBetween(from, to).clamp(-most, most)

# the turn of `angle` radians about the unit `axis`
pub fn about(axis Vec3, angle f32) Quat:
	s = (angle * 0.5).sin()
	Quat(axis.x * s, axis.y * s, axis.z * s, (angle * 0.5).cos())

# the turn back of the unit q
pub fn inverse(q Quat) Quat:
	Quat(-q.x, -q.y, -q.z, q.w)

# v turned by the unit q
pub fn rotate(q Quat, v Vec3) Vec3:
	u = q.xyz
	t = u.cross(v) * 2.0
	v + t * q.w + u.cross(t)

# the shortest turn that takes the direction `from` to the direction `to`
pub fn between(from Vec3, to Vec3) Quat:
	a = from.normalized()
	b = to.normalized()
	d = a @ b
	if d < -0.9999:
		# opposite: half a turn about any axis square to them
		side = Vec3(1.0, 0.0, 0.0) if a.x.abs() < 0.9 else Vec3(0.0, 1.0, 0.0)
		return Quat.about(a.cross(side).normalized(), pi)
	c = a.cross(b)
	q = Quat(c.x, c.y, c.z, 1.0 + d)
	q / q.length()

# The turn t of the way from the unit q to the unit `to` (0 is q, 1 is `to`), the shorter way
# round and made unit again: a normalized lerp, which for the small steps between keys and
# blended poses turns as a slerp does, without its trigonometry.
pub fn nlerp(q Quat, to Quat, t f32) Quat:
	d = q.x * to.x + q.y * to.y + q.z * to.z + q.w * to.w
	sign f32 = -1.0 if d < 0.0 else 1.0
	r = q * (1.0 - t) + to * (sign * t)
	n = r.length()
	r / n if n > 0.0 else r

# ---------- boxes and directions ----------

# the corners of the box around the points, (0 0 0) twice for none
pub fn boundsOf(points Vec3[]) (Vec3, Vec3):
	if points.isEmpty: return (Vec3(0, 0, 0), Vec3(0, 0, 0))
	lo = points[0]
	hi = points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	(lo, hi)

# two unit directions square to the unit `axis` and to each other, the second axis x the first
pub fn sideways(axis Vec3) (Vec3, Vec3):
	other = Vec3(1, 0, 0) if axis.x.abs() < 0.9 else Vec3(0, 1, 0)
	u = axis.cross(other).normalized()
	(u, axis.cross(u))

# ---------- what a camera sees ----------

# The six planes that bound what the view-projection m shows (left, right, bottom, top, near,
# far), each as a, b, c, d with the inside where a x + b y + c z + d >= 0.
pub fn frustumPlanes(m Mat4) f32[24]:
	p f32[24]
	for i in 0..6:
		row = i / 2
		sign f32 = 1.0 if i % 2 == 0 else -1.0
		for k in 0..4:
			# the plane is the matrix's last row plus or minus one of its first three
			p[i * 4 + k] = m.m[k * 4 + 3] + sign * m.m[k * 4 + row]
	p

# whether any of the box lo..hi may lie inside the planes (false: all of it is outside one)
pub fn isBoxInFrustum(planes f32[24], lo Vec3, hi Vec3) bool:
	for i in 0..6:
		a = planes[i * 4]
		b = planes[i * 4 + 1]
		c = planes[i * 4 + 2]
		# the corner of the box farthest along the plane's normal
		x = hi.x if a >= 0.0 else lo.x
		y = hi.y if b >= 0.0 else lo.y
		z = hi.z if c >= 0.0 else lo.z
		if a * x + b * y + c * z + planes[i * 4 + 3] < 0.0: return false
	true

# ---------- tests ----------

# a point as whole numbers (rounded, so the float error of a turn does not show)
fn shown(p Vec3):
	"{p.x.round()} {p.y.round()} {p.z.round()}"

test "an orthographic projection maps the view's corners to the clip square":
	m = Mat4.ortho(0.0, 800.0, 600.0, 0.0)
	topLeft = m.applyPoint(Vec2(0.0, 0.0))
	bottomRight = m.applyPoint(Vec2(800.0, 600.0))
	middle = m.applyPoint(Vec2(400.0, 300.0))
	expect topLeft.x == -1
	expect topLeft.y == 1
	expect bottomRight.x == 1
	expect bottomRight.y == -1
	expect middle.x == 0
	expect middle.y == 0

test "matrices compose right to left":
	m = Mat4.translation(Vec3(1.0, 2.0, 0.0)) @ Mat4.scaling(Vec3(10.0, 5.0, 1.0))
	p = m.applyPoint(Vec2(2.0, 2.0))
	expect p.x == 21
	expect p.y == 12

test "a camera looking down -z sees a point ahead at the middle of the screen, nearer points nearer":
	view = Mat4.lookAlong(Vec3(0.0, 0.0, 0.0), Vec3.lookDirection(0.0, 0.0))
	camera = Mat4.perspective(pi / 2.0, 1.0, 0.1, 100.0) @ view
	ahead = camera.project(Vec3(0.0, 0.0, -10.0))
	print("{ahead.x.round()} {ahead.y.round()}")
	print(camera.project(Vec3(0.0, 0.0, -1.0)).z < ahead.z)
	# 90 degrees across: a point as far to the right as ahead lands on the right edge
	print((camera.project(Vec3(10.0, 0.0, -10.0)).x - 1.0).abs() < 0.001)
	prints """
		0 0
		true
		true
		"""

test "turned a quarter to the right the camera looks along +x; a box projection maps its corners to the edges":
	print(Vec3.lookDirection(pi / 2.0, 0.0).shown())
	box = Mat4.orthoBox(-2.0, 2.0, -1.0, 1.0, 1.0, 5.0)
	print(box.project(Vec3(-2.0, -1.0, -1.0)).shown())
	print(box.project(Vec3(2.0, 1.0, -5.0)).shown())
	prints """
		1 0 0
		-1 -1 -1
		1 1 1
		"""

test "moves, scales and turns about each axis place a point":
	p = Vec3(1.0, 2.0, 3.0)
	print(Mat4.translation(Vec3(1.0, 1.0, 1.0)).applyPoint(p).shown())
	print(Mat4.scaling(Vec3(2.0, 3.0, 4.0)).applyPoint(p).shown())
	# a quarter turn about x: y goes to z; about y: z goes to x; about z: x goes to y
	print(Mat4.rotationX(pi / 2.0).applyPoint(Vec3(0.0, 1.0, 2.0)).shown())
	print(Mat4.rotationY(pi / 2.0).applyPoint(Vec3(1.0, 0.0, 3.0)).shown())
	print(Mat4.rotationZ(pi / 2.0).applyPoint(Vec3(1.0, 0.0, 3.0)).shown())
	# directions turn but do not move
	print(Mat4.translation(Vec3(5.0, 5.0, 5.0)).applyDirection(Vec3(0.0, 1.0, 0.0)).shown())
	prints """
		2 3 4
		2 6 12
		0 -2 1
		3 0 -1
		0 1 3
		0 1 0
		"""

test "a turn about an axis, a quaternion's and a turn about y agree":
	angle f32 = 0.7
	# not unit: rotationOf makes it so
	q = Quat.about(Vec3(0.0, 1.0, 0.0), angle) * 3.0
	a = Mat4.rotationAbout(Vec3(0.0, 2.0, 0.0), angle)
	b = Mat4.rotationOf(q)
	c = Mat4.rotationY(angle)
	p = Vec3(1.0, 2.0, 3.0)
	print(a.applyPoint(p).distance(c.applyPoint(p)) < 0.0001)
	print(b.applyPoint(p).distance(c.applyPoint(p)) < 0.0001)
	print(Quat.about(Vec3(0.0, 1.0, 0.0), angle).rotate(p).distance(c.applyPoint(p)) < 0.0001)
	# placement is the move after the turn after the scale
	placed = Mat4.placement(Vec3(4.0, 5.0, 6.0), angle, 2.0)
	composed = Mat4.translation(Vec3(4.0, 5.0, 6.0)) @ Mat4.rotationY(angle) @
		Mat4.scaling(Vec3(2.0, 2.0, 2.0))
	print(placed.applyPoint(p).distance(composed.applyPoint(p)) < 0.0001)
	prints """
		true
		true
		true
		true
		"""

test "q @ r turns by r then q; a turn and its inverse undo each other":
	quarterY = Quat.about(Vec3(0.0, 1.0, 0.0), pi / 2.0)
	quarterZ = Quat.about(Vec3(0.0, 0.0, 1.0), pi / 2.0)
	# x turned about z goes to y, which a turn about y leaves; -z turned about y goes to -x,
	# which a turn about z takes to -y
	print((quarterY @ quarterZ).rotate(Vec3(1.0, 0.0, 0.0)).shown())
	print((quarterZ @ quarterY).rotate(Vec3(0.0, 0.0, -1.0)).shown())
	p = Vec3(0.3, -0.7, 2.0)
	print(
		(quarterY @ quarterZ).inverse().rotate((quarterY @ quarterZ).rotate(p)).distance(p) < 0.0001
	)
	print((quarterY.inverse() @ quarterY).rotate(p).distance(p) < 0.0001)
	prints """
		0 1 0
		0 -1 0
		true
		true
		"""

test "the turn between two directions takes one to the other, opposite ones too":
	print(
		Quat.between(Vec3(0.0, 2.0, 0.0), Vec3(0.0, 0.0, 3.0)).rotate(Vec3(0.0, 1.0, 0.0)).shown()
	)
	print(
		Quat.between(Vec3(1.0, 0.0, 0.0), Vec3(-1.0, 0.0, 0.0)).rotate(Vec3(1.0, 0.0, 0.0)).shown()
	)
	prints """
		0 0 1
		-1 0 0
		"""

test "transformOf, its affine inverse and the determinant of a mirror":
	m = Mat4.transformOf(
		Vec3(1.0, -2.0, 3.0),
		Quat.about(Vec3(1.0, 0.0, 0.0), 0.8),
		Vec3(2.0, 0.5, 3.0)
	)
	p = Vec3(0.3, 0.7, -1.1)
	back = m.inverseAffine().applyPoint(m.applyPoint(p))
	print(back.distance(p) < 0.0001)
	same = m.inverseAffine() @ m
	print(same.applyPoint(p).distance(p) < 0.0001)
	print(Mat4.scaling(Vec3(-1.0, 1.0, 1.0)).determinant3())
	prints """
		true
		true
		-1
		"""

test "quaternions blend the shorter way and stay unit":
	a = Quat(0.0, 0.0, 0.0, 1.0)
	b = Quat.about(Vec3(0.0, 1.0, 0.0), 1.0)
	mid = a.nlerp(b, 0.5)
	print((mid.length() - 1.0).abs() < 0.0001)
	# -b is the same turn as b: the blend goes the same short way
	other = a.nlerp(b * -1.0, 0.5)
	print((other - mid).length() < 0.0001)
	print((a.nlerp(b, 1.0) - b).length() < 0.0001)
	prints """
		true
		true
		true
		"""

test "a box is seen when inside the view, not when behind the camera":
	planes = (Mat4.perspective(pi / 2.0, 1.0, 0.1, 100.0) @
			Mat4.lookAlong(Vec3(0.0, 0.0, 0.0), Vec3(0.0, 0.0, -1.0))).frustumPlanes()
	ahead = isBoxInFrustum(planes, Vec3(-1.0, -1.0, -11.0), Vec3(1.0, 1.0, -9.0))
	behind = isBoxInFrustum(planes, Vec3(-1.0, -1.0, 9.0), Vec3(1.0, 1.0, 11.0))
	expect ahead
	expect not behind

test "an eased value moves the same at any frame rate":
	whole = 1.0 - easeShare(4.0, 0.5)
	halves = (1.0 - easeShare(4.0, 0.25)) * (1.0 - easeShare(4.0, 0.25))
	expect (whole - halves).abs() < 1e-6
	expect easeShare(4.0, 0.0) == 0.0

test "a turn toward an angle goes the shorter way round and stops on it":
	expect (angleBetween(0.1, 2.0 * pi - 0.1) + 0.2).abs() < 1e-5
	expect (angleBetween(-3.0, 3.0) - (6.0 - 2.0 * pi)).abs() < 1e-5
	expect (turnToward(0.0, 1.0, 0.25) - 0.25).abs() < 1e-6
	expect turnToward(0.9, 1.0, 0.25) == 1.0
	expect (turnToward(3.0, -3.0, 0.1) - 3.1).abs() < 1e-5
