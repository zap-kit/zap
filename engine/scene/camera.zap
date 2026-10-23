# Cameras for 3D scenes, over lookDirection and lookAlong: an orbit about a point (a drag turns
# and tilts it, the wheel brings it nearer or farther), a camera that flies free (W A S D along
# the view, E and Q up and down, Shift faster), and the ground under a screen pixel (the ray from
# the eye through it, followed until it passes under a height function).
#
# Both cameras keep yaw as lookDirection does (radians, 0 looking toward -z, turning toward +x);
# an orbit's pitch is how far it looks down, a free camera's how far it looks up.

import math

# ---------- the orbit ----------

# A camera circling `target` at `distance`, looking at it. Its limits and its feel are fields
# with defaults, set where they are made.
pub type Orbit:
	target Vec3
	yaw f32
	pitch f32   # radians below the horizon
	distance f32
	minPitch f32 = -0.2
	maxPitch f32 = 1.45
	minDistance f32 = 2.0
	maxDistance f32 = 200.0
	dragButton i64 = 0   # the mouse button that turns it (0 left, 1 right)
	turnSpeed f32 = 0.006   # radians a pixel of drag across
	tiltSpeed f32 = 0.005   # radians a pixel of drag up or down
	zoomStep f32 = 0.1   # the share of the distance a notch of the wheel takes or adds
	idle f32 = 0.0   # seconds since the hand last moved it (a scene may turn it then)
	dragging bool = false
	last IVec2 = IVec2(0, 0)   # where the mouse was

	# The frame's input applied: a drag with the orbit's button turns it (to the right: it looks
	# further right) and tilts it (down: it looks further down), the wheel brings it nearer (up) or
	# farther; `dt` counts toward `idle` while neither moves it.
	pub mut fn steer(dt f32):
		at = mousePosition()
		if isMouseDown(dragButton):
			if dragging:
				yaw += f32(at.x - last.x) * turnSpeed
				pitch = (pitch + f32(at.y - last.y) * tiltSpeed).clamp(minPitch, maxPitch)
			dragging = true
			idle = 0.0
		else:
			dragging = false
			idle += dt
		last = at
		turn = wheelTurn()
		if turn != 0.0:
			distance = (distance * (1.0 - zoomStep * turn)).clamp(minDistance, maxDistance)
			idle = 0.0

	# the way it looks
	fn forward():
		Vec3.lookDirection(yaw, -pitch)

	# where it is: `distance` back from the target along the way it looks
	fn eye():
		target - forward() * distance

	# the view: the world moved so the eye is at the origin looking down -z
	fn view():
		Mat4.lookAlong(eye(), forward())

# ---------- the free camera ----------

# A camera that flies: turned by the mouse (the caller says by how much: a drag's motion, or a
# captured mouse's), moved by the keys along the way it looks.
pub type FlyCamera:
	eye Vec3
	yaw f32
	pitch f32   # radians above the horizon
	speed f32 = 12.0   # units a second
	fastFactor f32 = 5.0   # the speed times this while Shift is held
	lookSpeed f32 = 0.006   # radians a pixel of mouse motion
	vertical bool = true   # E and Q move it up and down

	# The frame's input applied over `dt` seconds: the mouse's motion (pixels; up looks up) turns
	# it, W and S move it along the way it looks, D and A to the side, E and Q up and down (when
	# `vertical`), Shift faster.
	pub mut fn steer(dt f32, motion IVec2):
		yaw += f32(motion.x) * lookSpeed
		pitch = (pitch - f32(motion.y) * lookSpeed).clamp(-1.5, 1.5)
		forward = self.forward()
		right = forward.cross(Vec3(0.0, 1.0, 0.0)).normalized()
		step = speed * (fastFactor if isKeyDown(.Shift) else 1.0) * dt
		eye += forward * (keyAxis(.Char('W'), .Char('S')) * step) +
			right * (keyAxis(.Char('D'), .Char('A')) * step)
		if vertical:
			eye += Vec3(0.0, keyAxis(.Char('E'), .Char('Q')) * step, 0.0)

	fn forward():
		Vec3.lookDirection(yaw, pitch)

	# the eye at the origin, looking down -z
	fn view():
		Mat4.lookAlong(eye, forward())

# ---------- the ground under a pixel ----------

# The direction from the eye through the screen point (x, y) (pixels from the top left; a
# pixel's middle is at + 0.5) of a w x h screen, for a camera looking along `forward` (up being
# +y) with a view `fovY` radians from bottom to top.
pub fn rayThrough(forward Vec3, fovY f32, x f32, y f32, w f32, h f32) Vec3:
	f = forward.normalized()
	right = f.cross(Vec3(0.0, 1.0, 0.0)).normalized()
	up = right.cross(f)
	t = (fovY * 0.5).tan()
	across = (x / w * 2.0 - 1.0) * t * w / h.max(1.0)
	upward = (1.0 - y / h.max(1.0) * 2.0) * t
	(f + right * across + up * upward).normalized()

# Where the ray from `start` along `way` (unit) first passes under the ground `heightAt(x, z)`,
# within `reach`; none when it does not. It is followed in steps of half its height above the
# ground (between 0.05 and `maxStep`), which cannot step over ground rising at 45 degrees or less
# toward it, then the crossing is narrowed down by halving.
pub fn groundHit(
	start Vec3,
	way Vec3,
	heightAt fn(f32, f32) f32,
	reach f32 = 2500.0,
	maxStep f32 = 4.0
) Vec3?:
	s = 0.0
	last = 0.0
	while s < reach:
		p = start + way * s
		above = p.y - heightAt(p.x, p.z)
		if above <= 0.0: return start + way * start.crossing(way, heightAt, last, s)
		last = s
		s += (above * 0.5).clamp(0.05, maxStep)
	none

# the distance along the ray where it passes under the ground, between lo (above it) and hi
# (under it), to 1/4096 of their gap
fn crossing(start Vec3, way Vec3, heightAt fn(f32, f32) f32, lo f32, hi f32):
	a = lo
	b = hi
	loop 12:
		mid = (a + b) * 0.5
		p = start + way * mid
		if p.y <= heightAt(p.x, p.z):
			b = mid
		else:
			a = mid
	b
