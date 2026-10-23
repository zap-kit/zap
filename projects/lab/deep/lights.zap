# Lights: a dark hall of pillars lit only by hundreds of moving point lights, every one read by
# every pixel from a storage block (Space doubles them, up to 1024; Backspace halves them).

import engine
import math

maxLights = 1024
firstLights = 256

pub type Lights:
	orbit engine.Orbit
	pillar engine.Model
	ground engine.Model
	bulb engine.Model
	many Vec4[]   # two a light: where it is and how far it reaches, its color (the lights shown alone)
	count i64
	time f32

pub fn newLights() Lights:
	Lights(
		orbit = sceneOrbit(Vec3(0.0, 1.0, 0.0), 30.0, 0.6),
		pillar = engine.newModel(box(0.8, 5.0, 0.8)),
		ground = engine.newModel(floor(60.0, 30.0)),
		bulb = engine.newModel(sphere(8, 16)), many = fill(
			firstLights * 2,
			Vec4(0.0, 0.0, 0.0, 0.0)
		), count = firstLights, time = 0.0)

pub fn lightCount(s Lights) i64:
	s.count

pub fn stepLights(mut s Lights, dt f32):
	steer(s.orbit, dt)
	s.time += dt
	if engine.isKeyPressed(.Space):
		s.count = (s.count * 2).min(maxLights)
	if engine.isKeyPressed(.Backspace):
		s.count = (s.count / 2).max(16)
	s.many.truncate(s.count * 2)
	while s.many.len < s.count * 2:
		s.many.push(Vec4(0.0, 0.0, 0.0, 0.0))
	# each light circles its own center at its own speed, bobbing; its color by its number
	t = s.time
	for i in (0..s.count).parallel():
		k = f32(i)
		a = t * (0.2 + 0.6 * engine.random01(i, 1, 3)) + k * 2.399
		r = 3.0 + 22.0 * engine.random01(i, 2, 5)
		hue = k * 0.618
		s.many[i * 2] = Vec4(
			a.cos() * r,
			0.4 + 1.6 * engine.random01(i, 4, 7) + 0.3 * (t * 2.0 + k).sin(),
			a.sin() * r,
			5.0
		)
		s.many[i * 2 + 1] = Vec4(
			3.0 * (0.5 + 0.5 * (tau * hue).cos()),
			3.0 * (0.5 + 0.5 * (tau * (hue + 0.33)).cos()),
			3.0 * (0.5 + 0.5 * (tau * (hue + 0.67)).cos()), 0.0)

pub fn drawLights(mut r engine.Renderer, mut s Lights, sh Shaders, st Stage, w i64, h i64):
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	sun = Vec3(0.3, 0.5, 0.4).normalized()
	r.beginScene(st, v, sun, 1.0)
	p = sh.lights
	surface = v.surfaceOf()
	surface.lightCount = i32(s.count)
	surface.many = move s.many   # lent to the frame's draws, given back after
	r.drawGround(p, surface, s.ground, Vec3(0.7, 0.7, 0.72), 0.45)
	surface.material(Vec3(0.8, 0.75, 0.7), 0.0, 0.35)
	for gx in 0..8:
		for gz in 0..8:
			drawPlaced(
				r,
				p,
				surface,
				Mat4.placement(Vec3(f32(gx - 4) * 6.0 + 3.0, 2.5, f32(gz - 4) * 6.0 + 3.0), 0.0, 1.0),
				s.pillar
			)
	# the bulbs, one copy per light
	sh.bulb.setParams(surface)
	r.drawCopies(sh.bulb, s.bulb, s.count)
	s.many = surface.many
	r.finishScene(st, w, h, 1.1, 0.7)
