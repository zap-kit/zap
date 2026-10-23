# A surface with depth in its texture: parallax occlusion mapping steps along the view into the
# height field (alpha: the height) to the place really seen, the normal comes from the height's
# slopes there, and the light toward it is traced back through the field for a soft self-shadow.
# The tangent frame comes from the screen-space slopes of position and texture place.

import engine

fn frameOf(n Vec3, at Vec3, t Vec2) Mat3:
	dp1 = at.ddx()
	dp2 = at.ddy()
	dt1 = t.ddx()
	dt2 = t.ddy()
	p2 = dp2.cross(n)
	p1 = n.cross(dp1)
	tu = p2 * dt1.x + p1 * dt2.x
	tv = p2 * dt1.y + p1 * dt2.y
	s = (tu @ tu).max(tv @ tv).inverseSqrt()
	Mat3(tu * s, tv * s, n)

fn depthAt(t Vec2, relief engine.Texture) f32:
	1.0 - relief.sample(t).a

# the texture place where the view along vt (tangent space, z out of the surface) meets the field
fn seen(t Vec2, vt Vec3, p Surface) Vec2:
	layers = 64.0.lerp(16.0, vt.z.clamp(0.0, 1.0))
	step = vt.xy / vt.z.max(0.08) * p.depthScale / layers
	layer f32 = 0.0
	d = depthAt(t, p.relief)
	at = t
	loop 64:
		if not (layer < d):
			break
		at -= step
		layer += 1.0 / layers
		d = depthAt(at, p.relief)
	# between the last two steps, where the ray crossed the field
	before = at + step
	after = d - layer
	prior = depthAt(before, p.relief) - (layer - 1.0 / layers)
	w = after / (after - prior)
	at.lerp(before, w.clamp(0.0, 1.0))

# how much light along lt (tangent space) reaches the place t, the field casting soft shadow
fn selfShadow(t Vec2, lt Vec3, p Surface) f32:
	if lt.z <= 0.0:
		return 0.0
	d = depthAt(t, p.relief)
	step = lt.xy / lt.z * p.depthScale / 24.0
	lit f32 = 1.0
	for i in 1..24 + 1:
		rayDepth = d - f32(i) / 24.0
		if rayDepth <= 0.0:
			break
		blocked = rayDepth - depthAt(t + step * f32(i), p.relief)
		lit = lit.min(1.0 - (blocked * 12.0).clamp(0.0, 1.0) * (1.0 - f32(i) / 24.0))
	lit

pub fn reliefPixel(b MeshPoint, p Surface) Vec4:
	n0 = b.worldNormal.normalized()
	tbn = frameOf(n0, b.worldPos, b.texPlace)
	toTangent = tbn.transpose()
	v = (p.eye - b.worldPos).normalized()
	t = seen(b.texPlace, toTangent @ v, p)
	size = p.relief.size()
	e = 1.0 / Vec2(f32(size.x), f32(size.y))
	hx = p.relief.sample(t + Vec2(e.x, 0.0)).a - p.relief.sample(t - Vec2(e.x, 0.0)).a
	hy = p.relief.sample(t + Vec2(0.0, e.y)).a - p.relief.sample(t - Vec2(0.0, e.y)).a
	n = (tbn @ Vec3(-hx * 6.0, -hy * 6.0, 1.0).normalized()).normalized()
	base = p.relief.sample(t).rgb
	rough f32 = 0.75
	c = shade(
		n,
		v,
		p.sunDir,
		p.sunLight * selfShadow(t, toTangent @ p.sunDir, p),
		base,
		0.0,
		rough
	)
	for i in 0..4:
		if p.lights[i].at.w <= 0.0:
			continue
		l = p.lights[i].at.xyz - b.worldPos
		d2 = l @ l
		ld = l * d2.inverseSqrt()
		reach = p.lights[i].at.w
		fade = (1.0 - d2 * d2 / (reach * reach * reach * reach)).clamp(0.0, 1.0)
		c += shade(
			n,
			v,
			ld,
			p.lights[i].color * fade * fade / (d2 + 0.5) * selfShadow(t, toTangent @ ld, p),
			base,
			0.0,
			rough
		)
	c += ambient(n, v, base, 0.0, rough, p.sunDir, p.night) * (0.35 + 0.65 * p.relief.sample(t).a)
	c.withW(1.0)
