# Relief: a wall and a floor of stones whose depth is only in their texture (a height in its
# alpha), seen with parallax occlusion mapping and lit by a lamp that walks along the wall
# (Up and Down: deeper or shallower).

import engine
import image
import math

texSide = 512

pub type Relief:
	orbit engine.Orbit
	stones engine.GpuTexture
	wall engine.Model
	ground engine.Model
	bulb engine.Model
	time f32
	depth f32

pub fn newRelief() Relief:
	Relief(
		orbit = sceneOrbit(Vec3(0.0, 1.6, 0.0), 8.0, 0.25),
		stones = stoneImage(texSide).newTexture(engine.smoothTiled),
		wall = engine.newModel(box(10.0, 4.0, 0.4)),
		ground = engine.newModel(
			floor(20.0, 6.0)
		), bulb = engine.newModel(sphere(16, 32)), time = 0.0, depth = 0.06)

pub fn stepRelief(mut s Relief, dt f32):
	steer(s.orbit, dt)
	s.time += dt
	if engine.isKeyPressed(.Up):
		s.depth = (s.depth + 0.01).min(0.15)
	if engine.isKeyPressed(.Down):
		s.depth = (s.depth - 0.01).max(0.0)

pub fn reliefDepth(s Relief) f32:
	s.depth

pub fn drawRelief(mut r engine.Renderer, s Relief, sh Shaders, st Stage, w i64, h i64):
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	sun = Vec3(-0.4, 0.35, 0.85).normalized()
	lamp = Vec3((s.time * 0.6).sin() * 4.0, 1.4 + 0.6 * (s.time * 0.9).sin(), 1.1)
	lampLight = Vec3(18.0, 11.0, 5.0)
	r.beginScene(st, v, sun, 0.55)
	p = sh.relief
	surface = v.surfaceOf()
	surface.sky(sun, Vec3(0.9, 0.85, 0.8), 0.55)
	surface.pointLight(0, lamp, 9.0, lampLight)
	surface.depthScale = s.depth
	surface.relief = s.stones.texture()
	r.drawPlaced(p, surface, Mat4.placement(Vec3(0.0, 2.0, -0.2), 0.0, 1.0), s.wall)
	r.drawPlaced(p, surface, Mat4(1.0), s.ground)
	q = sh.lit
	bulb = v.surfaceOf()
	bulb.sky(sun, Vec3(0.0, 0.0, 0.0), 0.55)
	bulb.material(Vec3(0.0, 0.0, 0.0), 0.0, 1.0, lampLight * 0.4)
	r.drawPlaced(q, bulb, Mat4.placement(lamp, 0.0, 0.1), s.bulb)
	r.finishScene(st, w, h, 1.0, 0.5)

# Stones of uneven tones in rows, rounded at their edges, their faces rough with noise, the
# mortar between them low and grey: the color in r, g, b and the height in a.
fn stoneImage(n i64):
	out = image.Image(n, n, fill = image.Rgba8(0, 0, 0, 0))
	rows = 8
	for y in (0..n).parallel():
		for x in 0..n:
			fy = f32(y) / f32(n) * f32(rows)
			row = i64(fy.floor())
			shift f32 = 0.0 if row % 2 == 0 else 0.5
			fx = f32(x) / f32(n) * 4.0 + shift
			col = i64(fx.floor())
			# the distance to the stone's edge, in stone heights
			ex = (fx - fx.floor()).min(1.0 - (fx - fx.floor())) * 2.0
			ey = (fy - fy.floor()).min(1.0 - (fy - fy.floor()))
			edge = (ex * 0.5).min(ey)
			grain = engine.valueNoise(f32(x) / 9.0, f32(y) / 9.0, 5) * 0.6 +
				engine.valueNoise(f32(x) / 3.0, f32(y) / 3.0, 11) * 0.4
			bulge = (edge * 9.0).clamp(0.0, 1.0)
			mortar = edge < 0.05
			height = 0.1 + grain * 0.1 if mortar
				else 0.45 + 0.4 * (bulge * (2.0 - bulge)) + grain * 0.15
			tone = engine.random01(col % 4, row, 23)
			r = 0.45 + grain * 0.1 if mortar else 0.52 + 0.25 * tone + grain * 0.15
			g = 0.43 + grain * 0.1 if mortar else 0.40 + 0.12 * tone + grain * 0.12
			b = 0.40 + grain * 0.1 if mortar else 0.30 + 0.05 * tone + grain * 0.1
			out[x, y] = image.Rgba8(
				image.unitToByte(r * r),
				image.unitToByte(g * g),
				image.unitToByte(b * b),
				image.unitToByte(height)
			)
	out
