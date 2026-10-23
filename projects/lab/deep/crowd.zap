# Crowd: a field of turning cubes rolling in waves, drawn in one call as copies of one cube;
# every copy's place worked out each frame on every processor (Space: 25 000, 100 000 or
# 250 000 of them).

import engine
import deep.shaders

maxCubes = 250_000

pub type Crowd:
	orbit engine.Orbit
	cube engine.Model
	ground engine.Model
	copies shaders.Copy[]
	count i64
	time f32

pub fn newCrowd() Crowd:
	still = shaders.Copy(place = Vec4(0.0, 0.0, 0.0, 0.0), scale = 0.0, number = 0.0)
	Crowd(
		orbit = sceneOrbit(Vec3(0.0, 0.0, 0.0), 120.0, 0.5),
		cube = engine.newModel(box(1.0, 1.0, 1.0)),
		ground = engine.newModel(floor(400.0, 100.0)),
		copies = fill(maxCubes, still), count = 100_000, time = 0.0)

pub fn cubeCount(s Crowd) i64:
	s.count

pub fn stepCrowd(mut s Crowd, dt f32):
	steer(s.orbit, dt)
	s.time += dt
	if engine.isKeyPressed(.Space):
		s.count = 100_000 if s.count == 25_000 else maxCubes if s.count == 100_000 else 25_000
	side = i64(f64(s.count).sqrt().ceil())
	t = s.time
	half = f32(side) * 0.5
	for i in (0..s.count).parallel():
		x = f32(i % side) - half
		z = f32(i / side) - half
		d = (x * x + z * z).sqrt()
		y = 4.2 + 2.5 * (d * 0.18 - t * 2.0).sin() +
			1.2 * (x * 0.07 + t).sin() * (z * 0.05 - t * 0.7).cos()
		s.copies[i] = shaders.Copy(
			place = Vec4(x * 0.9, y, z * 0.9, t * 0.8 + d * 0.05),
			scale = 0.55,
			number = f32(i)
		)

pub fn drawCrowd(mut r engine.Renderer, s Crowd, sh Shaders, st Stage, w i64, h i64):
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	sun = Vec3(0.4, 0.7, 0.3).normalized()
	r.beginScene(st, v, sun, 0.0)
	p = sh.lit
	surface = v.surfaceOf()
	surface.sky(sun, Vec3(7.0, 6.4, 5.4), 0.0)
	r.drawGround(p, surface, s.ground, Vec3(0.45, 0.47, 0.5), 0.8)
	surface.paletted = true
	surface.material(Vec3(1.0, 1.0, 1.0), 0.2, 0.45)
	p.setParams(surface)
	r.drawInstances(p, s.cube, s.copies[..s.count])
	r.finishScene(st, w, h, 0.6, 0.25)
