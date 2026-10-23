# The sky behind everything: the scattered light of the sky view, the sun's disc reddened by the
# air it is seen through, the moon, stars, and clouds lit by the sun (darker where they are thick
# toward it, their edges bright when it is behind them) and by the sky around.
#
# The sky in every direction, into a small texture (the sky view): across, the direction's
# azimuth; up, its elevation from -90 to 90 degrees. Drawn when the sun has moved; the sky, the
# fog and the reflections read it instead of scattering again.

import engine

pub type Sky:
	sunDirection Vec3
	time f32
	eye Vec3
	lightColor Vec3   # the sunlight, or the moonlight, on the ground
	camForward Vec3
	camRight Vec3
	camUp Vec3
	tanHalf Vec2   # the tangent of half the view, across and up
	skyView engine.Texture

pub fn skyPixel(uv Vec2, p Sky) Vec4:
	ndc = uv * 2.0 - 1.0
	d = (
		p.camForward + ndc.x * p.tanHalf.x * p.camRight + ndc.y * p.tanHalf.y * p.camUp
	).normalized()
	sun = p.sunDirection
	time = p.time
	c = skyColor(d, p.skyView)
	night = 1.0 - daylight(sun)
	# the sun's disc and the moon's
	s = d @ sun
	c += transmittance(sun) * 60.0 * s.smoothstep(0.99955, 0.9997)
	m = d @ -sun
	c += transmittance(-sun) * Vec3(0.9, 0.95, 1.1) * m.smoothstep(0.9992, 0.9994) * night
	# stars, twinkling, where the sky is dark
	if d.y > 0.0:
		cell = (d * 260.0).floor()
		h = engine.hash12(cell.xy + cell.z * 17.31)
		twinkle = 0.6 + 0.4 * (time * 3.0 + h * 80.0).sin()
		c += Vec3(0.6, 0.6, 0.6) * h.step(0.9975) * night * night * twinkle *
			d.y.smoothstep(0.0, 0.2)
	# clouds on a layer high above, drifting with the wind
	if d.y > 0.01:
		t = (190.0 - p.eye.y) / d.y
		at = (p.eye.xz + d.xz * t) * 0.0035 + Vec2(time * 0.004, time * 0.0015)
		thick = fbm(at)
		cover = thick.smoothstep(0.47, 0.72)
		# thicker toward the sun: less of its light gets through
		toward = fbm(at + (sun.xz + 1.0e-4).normalized() * 0.03)
		lit = (1.0 - (toward - thick) * 4.0 - (thick - 0.5) * 1.2).clamp(0.15, 1.0)
		behind = s.max(0.0).pow(6.0) * (1.0 - cover) * 2.0   # the silver lining
		ambient = skyColor(Vec3(0.0, 1.0, 0.0), p.skyView) * 1.6 +
			skyColor(Vec3(d.x, 0.05, d.z).normalized(), p.skyView) * 0.4
		cloud = ambient + p.lightColor * (lit + behind) * 0.9
		c = c.lerp(cloud, cover * (-t * 0.0009).exp() * d.y.smoothstep(0.01, 0.08))
	c.withW(1.0)

pub type SkyView:
	sunDirection Vec3

pub fn skyViewPixel(uv Vec2, p SkyView) Vec4:
	azimuth = (uv.x - 0.5) * 2.0 * pi
	elevation = (uv.y - 0.5) * pi
	dir = Vec3(elevation.cos() * azimuth.cos(), elevation.sin(), elevation.cos() * azimuth.sin())
	sky = scatteredLight(dir, p.sunDirection, 22.0)
	# the night: the moon, across from the sun, lights the air faintly blue, over a dark floor
	sky += scatteredLight(dir, -p.sunDirection, 22.0) * Vec3(0.004, 0.005, 0.008)
	sky += Vec3(0.0004, 0.0006, 0.0012)
	sky.withW(1.0)
