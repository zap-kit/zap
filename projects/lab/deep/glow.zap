# Glow: a night of glowing orbs and rings over a glossy floor, their light far above 1
# and spilling into the bloom; the orbs light the floor too.

import engine
import math

pub type Glow:
	orbit engine.Orbit
	orb engine.Model
	ring engine.Model
	ground engine.Model
	time f32

pub fn newGlow() Glow:
	Glow(
		orbit = sceneOrbit(Vec3(0.0, 1.5, 0.0), 16.0, 0.3),
		orb = engine.newModel(sphere(32, 64)),
		ring = engine.newModel(torus(3.5, 0.12, 128, 16)),
		ground = engine.newModel(floor(80.0, 40.0)), time = 0.0)

pub fn stepGlow(mut s Glow, dt f32):
	steer(s.orbit, dt)
	s.time += dt

pub fn drawGlow(mut r engine.Renderer, s Glow, sh Shaders, st Stage, w i64, h i64):
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	moon = Vec3(-0.3, 0.6, -0.7).normalized()
	r.beginScene(st, v, moon, 1.0)
	p = sh.lit
	surface = v.surfaceOf()
	surface.sky(moon, Vec3(0.08, 0.09, 0.14), 1.0)
	colors = [
		Vec3(1.0, 0.25, 0.1),
		Vec3(0.1, 0.6, 1.0),
		Vec3(0.4, 1.0, 0.3),
		Vec3(1.0, 0.2, 0.8)
	]
	orbs = (0..4).map(orbAt(s.time, it))
	for i in 0..4:
		surface.pointLight(i, orbs[i], 12.0, colors[i] * 25.0)
	r.drawGround(p, surface, s.ground, Vec3(0.08, 0.08, 0.09), 0.12)
	for i in 0..4:
		pulse = 1.0 + 0.5 * (s.time * 3.0 + f32(i) * 1.7).sin()
		surface.material(Vec3(0.0, 0.0, 0.0), 0.0, 1.0, colors[i] * (12.0 * pulse))
		r.drawPlaced(p, surface, Mat4.placement(orbs[i], 0.0, 0.45), s.orb)
	for i in 0..3:
		material(
			surface,
			Vec3(0.0, 0.0, 0.0),
			0.0,
			1.0,
			Vec3(2.0, 1.4, 0.5) * (4.0 + 2.0 * f32(i))
		)
		drawPlaced(
			r,
			p,
			surface,
			Mat4.placement(Vec3(0.0, 0.3 + f32(i) * 1.4, 0.0), s.time * (0.3 + f32(i) * 0.2), 1.0 - f32(i) * 0.25),
			s.ring
		)
	r.finishScene(st, w, h, 1.0, 1.0)

# where orb i floats at a time: circling the middle, bobbing
fn orbAt(t f32, i i64):
	a = t * 0.4 + f32(i) * pi * 0.5
	Vec3(a.cos() * 4.0, 1.2 + 0.5 * (t * 1.3 + f32(i)).sin(), a.sin() * 4.0)
