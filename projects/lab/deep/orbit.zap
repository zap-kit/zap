# The camera of the 3D scenes: the engine's orbit about a point, dragged around by the left
# button, nearer or farther with the wheel, turning slowly by itself when left alone.

import engine
import math

# what the camera sees this frame, as the shaders take it
pub type View:
	eye Vec3
	forward Vec3
	right Vec3
	up Vec3
	tanHalf f32   # tan of half the vertical field of view
	aspect f32
	viewProj Mat4

# a scene's orbit about `target`, `distance` away, looking down `pitch` radians; a drag to the
# right turns the scene with it, as if held
pub fn sceneOrbit(target Vec3, distance f32, pitch f32) engine.Orbit:
	engine.Orbit(target, yaw = -0.6, pitch, distance, turnSpeed = -0.006, idle = 10.0)

# the hand's moves this frame, and the slow turn after three seconds without them
pub fn steer(mut o engine.Orbit, dt f32):
	o.steer(dt)
	if o.idle > 3.0:
		o.yaw -= dt * 0.12

# the view from the orbit on a screen of width / height `aspect`
pub fn viewOf(o engine.Orbit, aspect f32) View:
	fov f32 = 0.9
	eye = o.eye()
	forward = o.forward()
	right = forward.cross(Vec3(0.0, 1.0, 0.0)).normalized()
	up = right.cross(forward)
	proj = Mat4.perspective(fov, aspect, 0.1, 400.0)
	View(eye, forward, right, up, tanHalf = (fov * 0.5).tan(), aspect,
		viewProj = proj @ Mat4.lookAlong(eye, forward))
