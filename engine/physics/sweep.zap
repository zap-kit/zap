# A ball swept through the scene, as a camera kept off the walls is: how far it goes before it
# touches a triangle.

halvings = 12

# whether the ball of `radius` swept from `from` to `to` stays clear of triangle t
fn isClearOf(s Scene, t i64, from Vec3, to Vec3, radius f32):
	onSegment, onTriangle = closestOnSegmentTriangle(
		from,
		to,
		s.corner(t, 0),
		s.corner(t, 1),
		s.corner(t, 2)
	)
	(onSegment - onTriangle).length() >= radius

# The share (0..1) of the way from `from` to `to` a ball of `radius` goes before it touches the
# scene, to 1/4096 of the way; 0 when it touches at `from`. Each triangle in the way narrows the
# share by halving between none of the way and what is left of it.
pub fn sweepShare(mut s Scene, from Vec3, to Vec3, radius f32) f32:
	r = Vec3(radius, radius, radius)
	share f32 = 1.0
	for t in s.trianglesNear(from.min(to) - r, from.max(to) + r):
		if s.isClearOf(t, from, from + (to - from) * share, radius): continue
		lo = 0.0
		hi = share
		loop halvings:
			mid = (lo + hi) * 0.5
			if s.isClearOf(t, from, from + (to - from) * mid, radius):
				lo = mid
			else:
				hi = mid
		share = lo
	share

# The triangle straight under p within `depth` (the highest one a ray down from p meets), none
# when nothing is there: the floor a foot stands on.
pub fn triangleBelow(mut s Scene, p Vec3, depth f32) i64?:
	best i64? = none
	top = p.z - depth
	for t in s.trianglesNear(Vec3(p.x, p.y, p.z - depth), p):
		a = s.corner(t, 0)
		b = s.corner(t, 1)
		c = s.corner(t, 2)
		n = (b - a).cross(c - a)
		if n.z.abs() < 1.0e-6: continue
		u = (b - p).cross(c - p).z / n.z
		v = (c - p).cross(a - p).z / n.z
		if u < 0.0 or v < 0.0 or u + v > 1.0: continue
		z = a.z * u + b.z * v + c.z * (1.0 - u - v)
		if z <= p.z and z >= top:
			top = z
			best = t
	best
