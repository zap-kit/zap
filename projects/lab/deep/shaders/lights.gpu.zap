# A surface lit by hundreds of point lights read from a storage block (two Vec4 each: where it
# is and how far it reaches, then its color), each one skipped beyond its reach.

pub fn lightsPixel(b MeshPoint, p Surface) Vec4:
	n = b.worldNormal.normalized()
	v = (p.eye - b.worldPos).normalized()
	base = p.albedo
	if p.checker:
		k = b.texPlace.floor()
		base *= 1.0 if (k.x + k.y) - ((k.x + k.y) / 2.0).floor() * 2.0 < 1.0 else 0.6
	c = Vec3(0.0, 0.0, 0.0)
	for i in 0..p.lightCount:
		at = p.many[i * 2]
		l = at.xyz - b.worldPos
		d2 = l @ l
		r2 = at.w * at.w
		if d2 >= r2:
			continue
		fade = 1.0 - d2 / r2
		c += shade(
			n,
			v,
			l * d2.inverseSqrt(),
			p.many[i * 2 + 1].rgb * fade * fade / (d2 + 0.3),
			base,
			p.metal,
			p.rough
		)
	c += base * Vec3(0.012, 0.014, 0.025)
	c.withW(1.0)
