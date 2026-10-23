# Materials: seven by seven spheres, metalness growing to the right and roughness toward the
# back, under the sun, the sky they mirror and four colored lights circling them.

import engine
import math

pub type Materials:
	orbit engine.Orbit
	ball engine.Model
	ground engine.Model
	time f32

pub fn newMaterials() Materials:
	Materials(
		orbit = sceneOrbit(Vec3(0.0, 1.0, 0.0), 19.0, 0.45),
		ball = engine.newModel(sphere(48, 96)),
		ground = engine.newModel(floor(60.0, 30.0)),
		time = 0.0
	)

pub fn stepMaterials(mut s Materials, dt f32):
	steer(s.orbit, dt)
	s.time += dt

pub fn drawMaterials(mut r engine.Renderer, s Materials, sh Shaders, st Stage, w i64, h i64):
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	sun = Vec3(0.5, 0.62, -0.6).normalized()
	r.beginScene(st, v, sun, 0.0)
	p = sh.lit
	surface = v.surfaceOf()
	surface.sky(sun, Vec3(6.5, 6.0, 5.2), 0.0)
	colors = [
		Vec3(30.0, 6.0, 4.0),
		Vec3(4.0, 24.0, 8.0),
		Vec3(5.0, 9.0, 34.0),
		Vec3(26.0, 20.0, 6.0)
	]
	for i in 0..4:
		a = s.time * 0.5 + f32(i) * pi * 0.5
		surface.pointLight(i, Vec3(a.cos() * 10.0, 3.0, a.sin() * 10.0), 14.0, colors[i])
	r.drawGround(p, surface, s.ground, Vec3(0.5, 0.5, 0.52), 0.7)
	for row in 0..7:
		for col in 0..7:
			metal = f32(col) / 6.0
			rough = (f32(row) / 6.0).max(0.05)
			albedo = Vec3(0.9 - metal * 0.0, 0.25 + metal * 0.5, 0.15 + metal * 0.2)
			surface.material(albedo, metal, rough)
			drawPlaced(
				r,
				p,
				surface,
				Mat4.placement(Vec3(f32(col - 3) * 2.4, 1.0, f32(row - 3) * 2.4), 0.0, 0.95),
				s.ball
			)
	r.finishScene(st, w, h, 0.65, 0.35)
