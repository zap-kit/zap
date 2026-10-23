# The camera: by default it orbits the skater (a drag with the right button turns it, the wheel
# brings it nearer or farther); F frees it to fly (W A S D along the view, Q and E down and up,
# Shift faster, the right drag to look around) and F again brings it back to the skater.

import engine
import math

pub type Camera:
	orbit engine.Orbit   # about the skater
	fly engine.FlyCamera   # free
	free bool
	drag IVec2?   # where the free camera's right drag was last (none: no drag)

# the orbit about `target`, `distance` away, turned `yaw` radians and looking down `pitch`
pub fn orbitCamera(target Vec3, yaw f32, pitch f32, distance f32) Camera:
	orbit = engine.Orbit(
		target,
		yaw,
		pitch,
		distance,
		minPitch = -1.5,
		maxPitch = 1.5,
		minDistance = 1.5,
		maxDistance = 40.0,
		dragButton = 1, tiltSpeed = 0.006, zoomStep = 0.12)
	Camera(
		orbit,
		fly = engine.FlyCamera(orbit.eye(), yaw, -pitch),
		free = false,
		drag = none
	)

# a free camera at `eye` looking `yaw` and `pitch` radians (up positive)
pub fn freeCamera(eye Vec3, yaw f32, pitch f32) Camera:
	c = eye.orbitCamera(yaw, -pitch, 4.0)
	c.fly = engine.FlyCamera(eye, yaw, pitch)
	c.free = true
	c

# the frame's keys, drag and wheel applied over `dt` seconds
pub fn steer(mut c Camera, dt f32):
	if engine.isKeyPressed(.Char('F')):
		c.free = not c.free
		if c.free:
			# the free camera starts where the orbit is, looking where it looked
			c.fly = engine.FlyCamera(c.orbit.eye(), c.orbit.yaw, -c.orbit.pitch)
	if not c.free:
		c.orbit.steer(dt)
		return
	at = engine.mousePosition()
	motion = IVec2(0, 0)
	if engine.isMouseDown(1):
		if c.drag is last:
			motion = at - last
		c.drag = at
	else:
		c.drag = none
	c.fly.steer(dt, motion)

# where the camera is
pub fn eyeOf(c Camera) Vec3:
	c.fly.eye if c.free else c.orbit.eye()

pub fn viewOf(c Camera) Mat4:
	c.fly.view() if c.free else c.orbit.view()

# the game's perspective: 60 degrees from bottom to top
pub fn projectionOf(aspect f32) Mat4:
	Mat4.perspective(60.0 * pi / 180.0, aspect, 0.1, 3000.0)
