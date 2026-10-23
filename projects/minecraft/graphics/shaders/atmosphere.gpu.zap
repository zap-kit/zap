# The sky's light scattered by the air: Rayleigh scattering by its molecules (blue, the day sky;
# red, a low sun seen through much air) and Mie scattering by its haze (the glow around the sun),
# single scattering along a ray from a point just above the ground, the light reaching each step
# through the air toward the sun. Units: meters; the earth's radii and the scale heights of the
# two kinds of particle are the usual ones. pipeline.zap computes the same transmittance for the
# sunlight on the ground.

earthRadius f32 = 6360.0e3
airTop f32 = 6420.0e3
rayleighBeta Vec3 = Vec3(5.8e-6, 13.5e-6, 33.1e-6)
mieBeta f32 = 21.0e-6
rayleighHeight f32 = 7994.0
mieHeight f32 = 1200.0
mieG f32 = 0.76

# where a ray from o along d enters and leaves the sphere of radius r about the earth's center
# (the far one negative: no crossing)
fn sphereCrossings(o Vec3, d Vec3, r f32) Vec2:
	b = o @ d
	c = o @ o - r * r
	h = b * b - c
	if h < 0.0:
		return Vec2(-1.0, -1.0)
	h = h.sqrt()
	Vec2(-b - h, -b + h)

# the light of the sky seen along `dir` lit by a light from `light` of strength `strength`
fn scatteredLight(dir Vec3, light Vec3, strength f32) Vec3:
	origin = Vec3(0.0, earthRadius + 100.0, 0.0)
	far = sphereCrossings(origin, dir, airTop).y
	ground = sphereCrossings(origin, dir, earthRadius)
	if ground.x > 0.0:
		far = ground.x
	steps i32 = 16
	stepLength = far / f32(steps)
	rayleigh = Vec3(0.0, 0.0, 0.0)
	mie = Vec3(0.0, 0.0, 0.0)
	depthR f32 = 0.0
	depthM f32 = 0.0
	for i in 0..steps:
		at = origin + dir * (stepLength * (f32(i) + 0.5))
		height = at.length() - earthRadius
		densityR = (-height / rayleighHeight).exp() * stepLength
		densityM = (-height / mieHeight).exp() * stepLength
		depthR += densityR
		depthM += densityM
		# the light's way to this point
		lightFar = sphereCrossings(at, light, airTop).y
		lightStep = lightFar / 8.0
		lightR f32 = 0.0
		lightM f32 = 0.0
		shaded = false
		for j in 0..8:
			q = at + light * (lightStep * (f32(j) + 0.5))
			h = q.length() - earthRadius
			if h < 0.0:
				shaded = true
				break
			lightR += (-h / rayleighHeight).exp() * lightStep
			lightM += (-h / mieHeight).exp() * lightStep
		if not shaded:
			through = (
				-(rayleighBeta * (depthR + lightR) + mieBeta * 1.1 * (depthM + lightM))
			).exp()
			rayleigh += through * densityR
			mie += through * densityM
	mu = dir @ light
	phaseR = 3.0 / (16.0 * pi) * (1.0 + mu * mu)
	g2 = mieG * mieG
	phaseM = 3.0 / (8.0 * pi) * ((1.0 - g2) * (1.0 + mu * mu)) /
		((2.0 + g2) * (1.0 + g2 - 2.0 * mieG * mu).pow(1.5))
	strength * (rayleigh * rayleighBeta * phaseR + mie * mieBeta * phaseM)

# how much of a light from `dir` reaches the ground through the air (the sun's disc, reddened)
fn transmittance(dir Vec3) Vec3:
	origin = Vec3(0.0, earthRadius + 100.0, 0.0)
	if sphereCrossings(origin, dir, earthRadius).x > 0.0:
		return Vec3(0.0, 0.0, 0.0)
	far = sphereCrossings(origin, dir, airTop).y
	stepLength = far / 16.0
	depthR f32 = 0.0
	depthM f32 = 0.0
	for i in 0..16:
		h = (origin + dir * (stepLength * (f32(i) + 0.5))).length() - earthRadius
		depthR += (-h / rayleighHeight).exp() * stepLength
		depthM += (-h / mieHeight).exp() * stepLength
	(-(rayleighBeta * depthR + mieBeta * 1.1 * depthM)).exp()
