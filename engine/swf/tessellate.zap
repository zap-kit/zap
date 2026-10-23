# Shapes into triangles on the CPU. Each fill style's outline is gathered from the edges that have
# it on either side (those with it on the left turned around, so the region lies on the same side
# of every segment), curves flattened into segments within a tolerance, and the region filled by
# scanlines: the plane cut into bands at every vertex's y (and where two segments cross), each
# band's spans between segments that the even-odd or nonzero rule says are inside made trapezoids,
# two triangles each. Lines become thin quads along their segments.

# a straight piece of an outline, from a to b
pub type Segment:
	a Vec2
	b Vec2

# the points a curve or a line passes through after its start, `tolerance` (shape units) from the
# true curve at most
pub fn flattenEdge(e Edge, tolerance f32, mut out Vec2[]):
	if not e.curved:
		out.push(e.to)
		return
	# a quadratic Bezier strays from its chords by a quarter of its second difference over n squared
	d = e.from - e.control * 2.0 + e.to
	n = i64((d.length() / (4.0 * tolerance.max(0.001))).sqrt().ceil()).clamp(1, 64)
	for k in 1..=n:
		t = f32(k) / f32(n)
		u = 1.0 - t
		out.push(e.from * (u * u) + e.control * (2.0 * u * t) + e.to * (t * t))

# the outline of the fill `fill` (1-based), each segment with the region on its right
pub fn fillSegments(s Shape, fill i64, tolerance f32) Segment[]:
	out = []
	points Vec2[] = []
	for e in s.edges:
		if e.fill0 == e.fill1 or (e.fill0 != fill and e.fill1 != fill): continue
		points.clear()
		points.push(e.from)
		e.flattenEdge(tolerance, points)
		for k in 1..points.len:
			if e.fill1 == fill:
				out.push(Segment(a = points[k - 1], b = points[k]))
			else:
				out.push(Segment(a = points[k], b = points[k - 1]))
	out

# a segment crossing a band: its x at the band's top and bottom, and its direction
type Crossing:
	x0 f32
	x1 f32
	winding i64

# The triangles that fill the region the segments enclose, by the nonzero rule or the even-odd
# one, three points each.
pub fn fillTriangles(segments Segment[], nonzero bool) Vec2[]:
	ys = []
	for s in segments:
		ys.push(s.a.y)
		ys.push(s.b.y)
	ys.sort()
	out = []
	for k in 1..ys.len:
		if ys[k] - ys[k - 1] > 1e-4:
			fillBand(segments, ys[k - 1], ys[k], nonzero, 0, out)
	out

fn crossings(segments Segment[], y0 f32, y1 f32):
	out = []
	for s in segments:
		top = s.a.y.min(s.b.y)
		bottom = s.a.y.max(s.b.y)
		if top > y0 + 1e-5 or bottom < y1 - 1e-5 or bottom - top < 1e-6: continue
		out.push(Crossing(x0 = s.xAt(y0), x1 = s.xAt(y1), winding = 1 if s.b.y > s.a.y else -1))
	out.sortBy((.x0 + .x1) * 0.5)
	out

fn xAt(s Segment, y f32):
	t = (y - s.a.y) / (s.b.y - s.a.y)
	s.a.x + (s.b.x - s.a.x) * t

# One band's spans as trapezoids; a band where two segments cross is cut at the crossing.
fn fillBand(segments Segment[], y0 f32, y1 f32, nonzero bool, depth i64, mut out Vec2[]):
	cs = crossings(segments, y0, y1)
	if depth < 24:
		for k in 1..cs.len:
			a = cs[k - 1]
			b = cs[k]
			if (a.x0 - b.x0) * (a.x1 - b.x1) < -1e-6:
				t = (b.x0 - a.x0) / ((a.x1 - a.x0) - (b.x1 - b.x0))
				y = y0 + (y1 - y0) * t.clamp(0.0, 1.0)
				if y - y0 > 1e-4 and y1 - y > 1e-4:
					fillBand(segments, y0, y, nonzero, depth + 1, out)
					fillBand(segments, y, y1, nonzero, depth + 1, out)
					return
	count = 0
	left = 0
	for k, c in cs:
		inside = (count != 0) if nonzero else (count & 1) == 1
		count += c.winding
		now = (count != 0) if nonzero else (count & 1) == 1
		if now and not inside: left = k
		elif inside and not now:
			l = cs[left]
			trapezoid(Vec2(l.x0, y0), Vec2(c.x0, y0), Vec2(c.x1, y1), Vec2(l.x1, y1), out)

fn trapezoid(a Vec2, b Vec2, c Vec2, d Vec2, mut out Vec2[]):
	if (b.x - a.x).abs() > 1e-5:
		out.push(a)
		out.push(b)
		out.push(c)
	if (c.x - d.x).abs() > 1e-5:
		out.push(a)
		out.push(c)
		out.push(d)

# the quads along the edges drawn with line style `line` (1-based), `width` across
pub fn strokeTriangles(s Shape, line i64, width f32, tolerance f32) Vec2[]:
	out = []
	points Vec2[] = []
	half = width * 0.5
	for e in s.edges:
		if e.line != line: continue
		points.clear()
		points.push(e.from)
		e.flattenEdge(tolerance, points)
		for k in 1..points.len:
			a = points[k - 1]
			b = points[k]
			along = b - a
			length = along.length()
			if length < 1e-6: continue
			n = Vec2(-along.y, along.x) * (half / length)
			ext = along * (half / length)   # square caps, so the corners of a polyline close
			out.push(a - ext + n)
			out.push(b + ext + n)
			out.push(b + ext - n)
			out.push(a - ext + n)
			out.push(b + ext - n)
			out.push(a - ext - n)
	out

# the area the triangles cover (shape units squared)
pub fn trianglesArea(points Vec2[]) f32:
	area = 0.0
	for k in (0..points.len - 2 step 3):
		a = points[k]
		b = points[k + 1]
		c = points[k + 2]
		area += ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs() * 0.5
	area
