# Standing on the world: the height of the collision surface under a point, found among the
# district's collision triangles (rw4.CollisionSoup) by testing each one that faces up.

import rw4

# The highest collision surface at (x, z) no higher than `top`, or none when there is none.
pub fn groundBelow(soup rw4.CollisionSoup, x f32, z f32, top f32) f32?:
	best = -1000000.0
	found = false
	c = soup.corners
	for t in 0..soup.surfaces.len:
		at = t * 9
		ax = c[at]
		az = c[at + 2]
		bx = c[at + 3]
		bz = c[at + 5]
		cx = c[at + 6]
		cz = c[at + 8]
		# a quick test of the triangle's box in x and z first
		if x < ax.min(bx).min(cx) or x > ax.max(bx).max(cx) or z < az.min(bz).min(cz) or
			z > az.max(bz).max(cz):
			continue
		# barycentric coordinates in the xz plane
		d = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
		if d.abs() < 0.000001: continue
		l1 = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / d
		l2 = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / d
		l3 = 1.0 - l1 - l2
		if l1 < -0.0001 or l2 < -0.0001 or l3 < -0.0001: continue
		y = l1 * c[at + 1] + l2 * c[at + 4] + l3 * c[at + 7]
		if y <= top and y > best:
			best = y
			found = true
	if not found: return none
	best
