# A surface lit the physically based way: the sun (its shadow when the scene has a shadow map),
# up to four point lights, the sky's light; a material of one albedo, metalness and roughness,
# a checkered floor, a color per copy, and light of its own.

disk Vec2[16] = [
	Vec2(-0.942, -0.399),
	Vec2(0.946, -0.769),
	Vec2(-0.094, -0.929),
	Vec2(0.345, 0.294),
	Vec2(-0.916, 0.458),
	Vec2(-0.815, -0.879),
	Vec2(-0.383, 0.277),
	Vec2(0.975, 0.756),
	Vec2(0.443, -0.975),
	Vec2(0.537, -0.474),
	Vec2(-0.265, -0.419),
	Vec2(0.792, 0.191),
	Vec2(-0.242, 0.997),
	Vec2(-0.814, 0.914),
	Vec2(0.200, 0.786),
	Vec2(0.144, -0.141)]

# how much of the sun reaches `at`: sixteen taps of the shadow map on a disk turned per pixel
fn sunShadow(at Vec3, n Vec3, p Surface) f32:
	s = p.shadowViewProj @ (at + n * 0.05).withW(1.0)
	q = s.xyz / s.w * 0.5 + 0.5
	if q.z > 1.0:
		return 1.0
	turn = ((pixelPosition.xy @ Vec2(12.9898, 78.233)).sin() * 43758.5453).fract() * tau
	rot = Mat2(turn.cos(), turn.sin(), -turn.sin(), turn.cos())
	size = p.shadowMap.size()
	texel = 2.2 / Vec2(f32(size.x), f32(size.y))
	lit f32 = 0.0
	for i in 0..16:
		lit += p.shadowMap.compare(q.xy + rot @ disk[i] * texel, q.z - 0.0004)
	lit / 16.0

fn paletteOf(k f32) Vec3:
	0.55 + 0.45 * (tau * (Vec3(0.0, 0.33, 0.67) + (k * 0.000731).fract() * 1.7)).cos()

pub fn litPixel(b MeshPoint, p Surface) Vec4:
	n = b.worldNormal.normalized()
	v = (p.eye - b.worldPos).normalized()
	base = p.albedo
	if p.checker:
		c = b.texPlace.floor()
		base *= 1.0 if (c.x + c.y) - ((c.x + c.y) / 2.0).floor() * 2.0 < 1.0 else 0.55
	if p.paletted:
		base = paletteOf(f32(b.tag))
	sun = sunShadow(b.worldPos, n, p) if p.shadowed else 1.0
	c = shade(n, v, p.sunDir, p.sunLight * sun, base, p.metal, p.rough)
	for i in 0..4:
		if p.lights[i].at.w <= 0.0:
			continue
		l = p.lights[i].at.xyz - b.worldPos
		d2 = l @ l
		reach = p.lights[i].at.w
		fade = (1.0 - d2 * d2 / (reach * reach * reach * reach)).clamp(0.0, 1.0)
		c += shade(
			n,
			v,
			l * d2.inverseSqrt(),
			p.lights[i].color * fade * fade / (d2 + 0.5),
			base,
			p.metal,
			p.rough
		)
	c += ambient(n, v, base, p.metal, p.rough, p.sunDir, p.night) *
		(0.6 + 0.4 * sun).lerp(1.0, p.night)
	(c + p.emissive).withW(1.0)
