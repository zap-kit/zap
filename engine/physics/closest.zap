# Closest points between a point, segments and triangles (Ericson's Real-Time Collision Detection,
# 5.1): what a ball (a sphere or a capsule) meets of a triangle.

# the point of the triangle a b c nearest p
pub fn closestOnTriangle(p Vec3, a Vec3, b Vec3, c Vec3) Vec3:
	ab = b - a
	ac = c - a
	ap = p - a
	d1 = ab @ ap
	d2 = ac @ ap
	if d1 <= 0.0 and d2 <= 0.0: return a
	bp = p - b
	d3 = ab @ bp
	d4 = ac @ bp
	if d3 >= 0.0 and d4 <= d3: return b
	vc = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0: return a + ab * (d1 / (d1 - d3))
	cp = p - c
	d5 = ab @ cp
	d6 = ac @ cp
	if d6 >= 0.0 and d5 <= d6: return c
	vb = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0: return a + ac * (d2 / (d2 - d6))
	va = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	denominator = 1.0 / (va + vb + vc)
	a + ab * (vb * denominator) + ac * (vc * denominator)

# the nearest points of the segments p0..p1 and q0..q1, the first's then the second's
pub fn closestOnSegments(p0 Vec3, p1 Vec3, q0 Vec3, q1 Vec3) (Vec3, Vec3):
	d1 = p1 - p0
	d2 = q1 - q0
	r = p0 - q0
	a = d1 @ d1
	e = d2 @ d2
	f = d2 @ r
	tiny f32 = 1.0e-12
	if a <= tiny and e <= tiny: return (p0, q0)
	s = 0.0
	t f32 = 0.0
	if a <= tiny:
		t = (f / e).clamp(0.0, 1.0)
	else:
		c = d1 @ r
		if e <= tiny:
			s = (-c / a).clamp(0.0, 1.0)
		else:
			b = d1 @ d2
			denominator = a * e - b * b
			s = ((b * f - c * e) / denominator).clamp(0.0, 1.0) if denominator > tiny else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = (-c / a).clamp(0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = ((b - c) / a).clamp(0.0, 1.0)
	(p0 + d1 * s, q0 + d2 * t)

# where the segment p0..p1 crosses the triangle, none when it does not
fn segmentThrough(p0 Vec3, p1 Vec3, a Vec3, b Vec3, c Vec3) Vec3?:
	n = (b - a).cross(c - a)
	h0 = n @ (p0 - a)
	h1 = n @ (p1 - a)
	if (h0 > 0.0) == (h1 > 0.0) or h0 == h1: return none
	x = p0 + (p1 - p0) * (h0 / (h0 - h1))
	inside = x.closestOnTriangle(a, b, c)
	x if (inside - x).length() <= 1.0e-3 * (b - a).length().max(1.0) else none

# the nearest points of the segment p0..p1 and the triangle a b c, the segment's then the
# triangle's (one point twice where they cross)
pub fn closestOnSegmentTriangle(p0 Vec3, p1 Vec3, a Vec3, b Vec3, c Vec3) (Vec3, Vec3):
	if p0.segmentThrough(p1, a, b, c) is x: return (x, x)
	onSegment = p0
	onTriangle = p0.closestOnTriangle(a, b, c)
	q1 = p1.closestOnTriangle(a, b, c)
	if (p1 - q1).length() < (onSegment - onTriangle).length():
		onSegment = p1
		onTriangle = q1
	corners = [a, b, c]
	for k in 0..3:
		s, t = p0.closestOnSegments(p1, corners[k], corners[(k + 1) % 3])
		if (s - t).length() < (onSegment - onTriangle).length():
			onSegment = s
			onTriangle = t
	(onSegment, onTriangle)
