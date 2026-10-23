# What every lit shader of the lab shares: the sky (seen behind the scene and reflected by it)
# and physically based shading (GGX highlights, Smith masking, Schlick's Fresnel).

# the sky's light along direction d without the sun: blue above, pale at the horizon, warm
# ground below; `night` darkens it all to a starless night
fn skyBase(d Vec3, night f32) Vec3:
	h = d.y.clamp(-1.0, 1.0)
	zenith = Vec3(0.05, 0.16, 0.52).lerp(Vec3(0.004, 0.006, 0.02), night)
	horizon = Vec3(0.42, 0.56, 0.80).lerp(Vec3(0.03, 0.03, 0.06), night)
	ground = Vec3(0.20, 0.18, 0.16).lerp(Vec3(0.01, 0.01, 0.012), night)
	horizon.lerp(zenith, h.pow(0.45)) if h > 0.0 else horizon.lerp(ground, (-h).pow(0.35))

# the same with the sun's disk and glow toward `sun`
fn skyColor(d Vec3, sun Vec3, night f32) Vec3:
	s = (d @ sun).max(0.0)
	skyBase(d, night) +
		Vec3(1.0, 0.86, 0.62) * (s.pow(900.0) * 60.0 + s.pow(12.0) * 0.35) * (1.0 - night)

fn ggx(nh f32, a f32) f32:
	a2 = a * a
	d = nh * nh * (a2 - 1.0) + 1.0
	a2 / (pi * d * d)

fn smith(nv f32, nl f32, rough f32) f32:
	k = (rough + 1.0) * (rough + 1.0) / 8.0
	nv / (nv * (1.0 - k) + k) * nl / (nl * (1.0 - k) + k)

fn schlick(f0 Vec3, vh f32) Vec3:
	f0 + (1.0 - f0) * (1.0 - vh).pow(5.0)

# the light a surface sends toward v when `radiance` arrives along l (all unit vectors)
fn shade(n Vec3, v Vec3, l Vec3, radiance Vec3, albedo Vec3, metal f32, rough f32) Vec3:
	h = (v + l).normalized()
	nl = (n @ l).max(0.0)
	nv = (n @ v).max(1.0e-4)
	nh = (n @ h).max(0.0)
	vh = (v @ h).max(0.0)
	a = (rough * rough).max(0.002)
	f0 = Vec3(0.04, 0.04, 0.04).lerp(albedo, metal)
	f = schlick(f0, vh)
	spec = ggx(nh, a) * smith(nv, nl, rough) * f / (4.0 * nv * nl.max(1.0e-4))
	kd = (1.0 - f) * (1.0 - metal)
	(kd * albedo / pi + spec) * radiance * nl

# the sky's light on a surface: its diffuse share from the sky about the normal, and the sky it
# mirrors, blurred toward the sky's average as the surface gets rough (Karis' analytic
# approximation of the split-sum term)
fn ambient(n Vec3, v Vec3, albedo Vec3, metal f32, rough f32, sun Vec3, night f32) Vec3:
	f0 = Vec3(0.04, 0.04, 0.04).lerp(albedo, metal)
	nv = (n @ v).max(1.0e-4)
	r = rough * Vec4(-1.0, -0.0275, -0.572, 0.022) + Vec4(1.0, 0.0425, 1.04, -0.04)
	a004 = (r.x * r.x).min((-9.28 * nv).exp2()) * r.x + r.y
	ab = Vec2(-1.04, 1.04) * a004 + r.zw
	specColor = f0 * ab.x + ab.y
	rd = (-v).reflect(n)
	average = 0.5 *
		(skyBase(Vec3(0.0, 1.0, 0.0), night) + skyBase(Vec3(rd.x, 0.05, rd.z).normalized(), night))
	mirrored = skyColor(rd, sun, night).lerp(
		skyBase(rd.lerp(n, 0.5).normalized(), night),
		(rough * 2.0).clamp(0.0, 1.0)
	)
	env = mirrored.lerp(average, rough * rough)
	irradiance = 0.5 * (skyBase(n, night) + skyBase((n + Vec3(0.0, 1.0, 0.0)).normalized(), night))
	kd = (1.0 - specColor) * (1.0 - metal)
	kd * albedo * irradiance + env * specColor
