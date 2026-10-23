# The cameras' pure parts: where an orbit's and a free camera's eyes are and what they look at,
# the ray through a screen pixel, and the ground found under it (flat and sloped).

import engine

fn shown(p Vec3):
	"{(p.x * 100.0).round() / 100.0} {(p.y * 100.0).round() / 100.0} {(p.z * 100.0).round() / 100.0}"

test "an orbit sits back from its target and its view puts the target ahead":
	level = engine.Orbit(Vec3(0.0, 0.0, 0.0), 0.0, 0.0, 10.0)
	# looking toward -z, so it sits at +z
	print(level.eye().shown())
	# looking straight down, from above
	above = engine.Orbit(Vec3(0.0, 0.0, 0.0), 0.0, pi / 2.0, 10.0)
	print(above.eye().shown())
	turned = engine.Orbit(Vec3(3.0, 1.0, -2.0), 0.8, 0.4, 7.0)
	ahead = turned.view().applyPoint(turned.target)
	print(ahead.distance(Vec3(0.0, 0.0, -7.0)) < 0.001)
	prints """
		0 0 10
		0 10 0
		true
		"""

test "a free camera looks along its yaw and pitch":
	c = engine.FlyCamera(Vec3(1.0, 2.0, 3.0), pi / 2.0, 0.0)
	print(c.forward().shown())
	print(
		c.view().applyPoint(c.eye + c.forward() * 5.0).distance(Vec3(0.0, 0.0, -5.0)) < 0.001
	)
	prints """
		1 0 0
		true
		"""

test "the ray through the screen's middle is the way the camera looks; through its top edge, half the view up":
	forward = Vec3(0.0, 0.0, -1.0)
	fov f32 = 1.0
	print(forward.rayThrough(fov, 400.0, 300.0, 800.0, 600.0).shown())
	top = forward.rayThrough(fov, 400.0, 0.0, 800.0, 600.0)
	print((top.y.atan2(-top.z) - fov * 0.5).abs() < 0.0001)
	prints """
		0 0 -1
		true
		"""

test "the ground under a ray: a flat one, a slope, and none when the ray looks up":
	flat = (x f32, z f32): f32(0.0)
	start = Vec3(0.0, 5.0, 0.0)
	down = Vec3(1.0, -1.0, -1.0).normalized()
	print(shown(start.groundHit(down, flat) ?? Vec3(-1.0, -1.0, -1.0)))
	# ground rising toward +x at half a unit a unit: met where 5 - t = t / 2 along x
	slope = (x f32, z f32): x * 0.5
	along = Vec3(1.0, -1.0, 0.0).normalized()
	hit = start.groundHit(along, slope) ?? Vec3(-1.0, -1.0, -1.0)
	print((hit.y - hit.x * 0.5).abs() < 0.001 and (hit.x - 10.0 / 3.0).abs() < 0.001)
	print(start.groundHit(Vec3(0.0, 1.0, 0.0), flat, reach = 100.0) == none)
	prints """
		5 0 -5
		true
		true
		"""
