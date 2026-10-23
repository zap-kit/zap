# Shadows: a ring of columns, spheres and a turning ring under a sun that circles the sky; its
# shadow map is 4096 texels a side, each shadow read sixteen times on a disk turned per pixel.

import engine
import deep.shaders
import math

shadowSize = 4096
reach f32 = 26.0

pub type Shadows:
	orbit engine.Orbit
	map engine.RenderTarget
	column engine.Model
	ball engine.Model
	ring engine.Model
	ground engine.Model
	time f32

pub fn newShadows() Shadows:
	Shadows(
		orbit = sceneOrbit(Vec3(0.0, 1.5, 0.0), 26.0, 0.55),
		map = engine.newShadowTarget(shadowSize),
		column = engine.newModel(box(1.0, 6.0, 1.0)),
		ball = engine.newModel(sphere(32, 64)), ring = engine.newModel(
			torus(2.4, 0.45, 96, 32)
		), ground = engine.newModel(floor(80.0, 40.0)), time = 0.0)

pub fn stepShadows(mut s Shadows, dt f32):
	steer(s.orbit, dt)
	s.time += dt

# the sun's direction (toward it) at a time: low and turning, so the shadows sweep and stretch
fn sunAt(t f32):
	a = t * 0.25
	Vec3(a.cos(), 0.55 + 0.25 * (t * 0.13).sin(), a.sin()).normalized()

pub fn drawShadows(mut r engine.Renderer, s Shadows, sh Shaders, st Stage, w i64, h i64):
	sun = sunAt(s.time)
	toSun = Mat4.lookAlong(sun * 40.0, sun * -1.0)
	shadowView = Mat4.orthoBox(-reach, reach, -reach, reach, 1.0, 90.0) @ toSun
	# the shadow map: the casters seen from the sun
	r.setBlending(false)
	r.useTarget(s.map)
	r.setDepth(true, true, false)
	r.clearTarget(engine.white)
	r.setDepthBias(true)
	v = s.orbit.viewOf(f32(w) / f32(h).max(1.0))
	fromSun = v.surfaceOf()
	fromSun.viewProj = shadowView
	r.drawCasters(s, sh.depth, fromSun)
	r.setDepthBias(false)
	# the scene
	r.beginScene(st, v, sun, 0.0)
	p = sh.lit
	surface = v.surfaceOf()
	surface.sky(sun, Vec3(7.0, 6.4, 5.4), 0.0)
	surface.shadowViewProj = shadowView
	surface.shadowed = true
	surface.shadowMap = s.map.shadowMap()
	r.drawGround(p, surface, s.ground, Vec3(0.62, 0.6, 0.56), 0.85)
	r.drawCasters(s, p, surface)
	r.finishScene(st, w, h, 0.6, 0.3)

# what casts shadows, with each its material (ignored by the depth pass)
fn drawCasters(r engine.Renderer, s Shadows, p engine.Program, mut surface shaders.Surface):
	for i in 0..10:
		a = f32(i) / 10.0 * 2.0 * pi
		surface.material(Vec3(0.8, 0.78, 0.72), 0.0, 0.6)
		drawPlaced(
			r,
			p,
			surface,
			Mat4.placement(Vec3(a.cos() * 9.0, 3.0, a.sin() * 9.0), a, 1.0),
			s.column
		)
	for i in 0..5:
		a = f32(i) / 5.0 * 2.0 * pi + 0.3
		surface.material(Vec3(0.95, 0.7, 0.3), 1.0, 0.25)
		drawPlaced(
			r,
			p,
			surface,
			Mat4.placement(Vec3(a.cos() * 4.5, 1.0 + 0.6 * (s.time * 1.5 + a).sin().abs(), a.sin() * 4.5), 0.0, 1.0),
			s.ball
		)
	surface.material(Vec3(0.2, 0.45, 0.9), 0.0, 0.3)
	r.drawPlaced(p, surface, ringPlace(s.time), s.ring)

# the ring stands up and turns about two axes over the middle
fn ringPlace(t f32):
	a = t * 0.7
	b = t * 0.4
	m f32[16]
	# a turn about x by a (the ring stood up), then about y by b, then lifted
	ca = a.cos()
	sa = a.sin()
	cb = b.cos()
	sb = b.sin()
	m[0] = cb
	m[1] = 0.0
	m[2] = -sb
	m[4] = sb * sa
	m[5] = ca
	m[6] = cb * sa
	m[8] = sb * ca
	m[9] = -sa
	m[10] = cb * ca
	m[13] = 3.2
	m[15] = 1.0
	Mat4(m)
