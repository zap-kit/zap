# Particles: born of an emission, aged, pulled, and their color and size over their life.

import engine

fn still(speed f32, radius f32, life f32):
	engine.Emission(
		speed,
		speedVariation = 0.0,
		declination = 0.0,
		declinationVariation = 0.0,
		planarAngle = 0.0,
		planarAngleVariation = 0.0,
		color = Vec4(1.0, 1.0, 1.0, 1.0),
		radius,
		radiusVariation = 0.0,
		life,
		lifeVariation = 0.0
	)

test "a particle born of an emission with no variation goes up z at its speed, scaled":
	s = engine.newSwarm(1)
	p = s.random.bornParticle(still(10.0, 3.0, 2.0), Vec3(1.0, 2.0, 3.0), Mat4(1.0), 2.0, 0)
	print("{p.position} {p.velocity} {p.radius} {p.life} {p.cell}")
	prints "Vec3(x = 1, y = 2, z = 3) Vec3(x = 0, y = 0, z = 20) 6 2 -1"

test "a place in a box stays inside it":
	s = engine.newSwarm(7)
	inside = true
	loop 100:
		at = s.random.volumePoint(engine.volumeBox, Vec3(2.0, 4.0, 6.0))
		inside = inside and at.x.abs() <= 1.0 and at.y.abs() <= 2.0 and at.z.abs() <= 3.0
	expect inside

test "aged past their life, particles die; the living move and are dragged":
	s = engine.newSwarm(3)
	for life in [1.0, 3.0]:
		s.particles.push(s.random.bornParticle(still(1.0, 1.0, f32(life)), Vec3(0.0, 0.0, 0.0),
			Mat4(1.0), 1.0, 0))
	shakes = s.ageSwarm(2.0)
	s.particles[0].dragParticle(0.5, 1.0)
	s.particles[0].moveParticle(2.0)
	print("{s.particles.len} {shakes.len} {s.particles[0].position.z}")
	prints "1 1 1"

test "the color and the size over a life: the alpha fades in until 0.1 and out from 0.9; all times 0 hold the middle color":
	colors = [Vec4(1.0, 0.0, 0.0, 0.0), Vec4(0.0, 1.0, 0.0, 1.0), Vec4(0.0, 0.0, 1.0, 0.0)]
	times = Vec4(0.0, 0.5, 0.5, 1.0)
	print(engine.colorOverLife(0.1, 0.9, times, colors, 0.05))
	print(engine.colorOverLife(0.1, 0.9, times, colors, 0.5))
	print(engine.colorOverLife(0.1, 0.9, times, colors, 0.95))
	print(engine.colorOverLife(0.0, 0.0, Vec4(0.0, 0.0, 0.0, 0.0), colors, 0.95))
	print("{engine.scaleOverLife([1.0, 3.0], 0.5)} {engine.scaleOverLife([], 0.5)} {engine.scaleOverLife([1.0, 3.0], 1.0)}")
	prints """
		Vec4(x = 0.9, y = 0.1, z = 0, w = 0.5)
		Vec4(x = 0, y = 1, z = 0, w = 1)
		Vec4(x = 0, y = 0.100000024, z = 0.9, w = 0.5)
		Vec4(x = 0, y = 1, z = 0, w = 1)
		2 1 3
		"""
