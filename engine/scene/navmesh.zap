# A navigation mesh: the floor actors may walk, as triangles that know their neighbours across
# each edge, in the mesh's own space with z up. A path is found as the Recast/Detour libraries
# find theirs (Mikko Mononen's): A* over the triangles from centre to centre, then the funnel
# ("string pulling") through the edges crossed, so the path bends only at the corners it must go
# round.

# a triangle that lies in a doorway: the door's reference (an actor crossing it opens that door)
pub type DoorTriangle:
	triangle i64
	door i64

pub type NavMesh:
	vertices Vec3[]
	triangles i64[]   # three corners a triangle
	neighbours i64[]   # across the edges 0-1, 1-2 and 2-0, -1 for none
	doors DoorTriangle[] = []

pub fn triangleCount(m NavMesh) i64:
	m.triangles.len / 3

fn corner(m NavMesh, t i64, k i64):
	m.vertices[m.triangles[t * 3 + k]]

fn centreOf(m NavMesh, t i64):
	(m.corner(t, 0) + m.corner(t, 1) + m.corner(t, 2)) / 3.0

fn cross2(a Vec3, b Vec3):
	a.x * b.y - a.y * b.x

# whether p lies over or under the triangle, seen from above
fn overTriangle(m NavMesh, t i64, p Vec3):
	a = m.corner(t, 0)
	b = m.corner(t, 1)
	c = m.corner(t, 2)
	d1 = cross2(b - a, p - a)
	d2 = cross2(c - b, p - b)
	d3 = cross2(a - c, p - c)
	not ((d1 < 0.0 or d2 < 0.0 or d3 < 0.0) and (d1 > 0.0 or d2 > 0.0 or d3 > 0.0))

# the height of the triangle's plane under or over p
fn heightAt(m NavMesh, t i64, p Vec3):
	a = m.corner(t, 0)
	n = (m.corner(t, 1) - a).cross(m.corner(t, 2) - a)
	if n.z.abs() < 1.0e-6: return a.z
	a.z - (n.x * (p.x - a.x) + n.y * (p.y - a.y)) / n.z

# The triangle under (or over) p nearest it in height, none when p is outside the mesh seen from
# above or every triangle there is more than `reach` from it.
pub fn triangleAt(m NavMesh, p Vec3, reach f32) i64?:
	best i64? = none
	nearest = reach
	for t in 0..m.triangleCount():
		if not m.overTriangle(t, p): continue
		d = (m.heightAt(t, p) - p.z).abs()
		if d <= nearest:
			nearest = d
			best = t
	best

# the point of segment a-b nearest p
pub fn nearestOnSegment(a Vec3, b Vec3, p Vec3) Vec3:
	ab = b - a
	l = ab @ ab
	if l <= 0.0: return a
	a + ab * (((p - a) @ ab) / l).clamp(0.0, 1.0)

# The point of the mesh nearest p and its triangle: p dropped onto the triangle under it, else
# the nearest point of the nearest edge.
pub fn nearestPoint(m NavMesh, p Vec3) (i64, Vec3):
	if m.triangleAt(p, 64.0) is t: return (t, Vec3(p.x, p.y, m.heightAt(t, p)))
	best = 0, m.vertices[0]
	nearest = 1.0e30
	for t in 0..m.triangleCount():
		for k in 0..3:
			q = m.corner(t, k).nearestOnSegment(m.corner(t, (k + 1) % 3), p)
			d = (q - p).length()
			if d < nearest:
				nearest = d
				best = t, q
	best

# the triangles from `from` to `to` across shared edges (A* by the centres' distances), none
# when they are not joined
fn corridor(m NavMesh, from i64, to i64) i64[]?:
	n = m.triangleCount()
	cost = fill(n, f32(1.0e30))
	came = fill(n, -1)
	closed = fill(n, false)
	open = [from]
	cost[from] = 0.0
	goal = m.centreOf(to)
	while not open.isEmpty:
		k = (0..open.len).minBy(cost[open[it]] + (m.centreOf(open[it]) - goal).length()) ?? 0
		t = open[k]
		open.remove(k)
		if t == to: break
		closed[t] = true
		for e in 0..3:
			u = m.neighbours[t * 3 + e]
			if u < 0 or closed[u]: continue
			c = cost[t] + (m.centreOf(u) - m.centreOf(t)).length()
			if c >= cost[u]: continue
			cost[u] = c
			came[u] = t
			if u not in open: open.push(u)
	if from != to and came[to] < 0: return none
	out = [to]
	while out[len - 1] != from:
		out.push(came[out[len - 1]])
	out.reverse()
	out

# the edge triangle a shares with b: its two corners, the left one first going from a to b
fn portalOf(m NavMesh, a i64, b i64):
	for e in 0..3:
		if m.neighbours[a * 3 + e] != b: continue
		p = m.corner(a, e)
		q = m.corner(a, (e + 1) % 3)
		way = m.centreOf(b) - m.centreOf(a)
		return (p, q) if way.cross2(p - m.centreOf(a)) > 0.0 else (q, p)
	c = m.centreOf(b)
	(c, c)

# the funnel through the portals (each a left and a right corner) from start: the corners the
# path turns at, then end
fn pulled(portals (Vec3, Vec3)[], start Vec3, end Vec3):
	out = [start]
	apex = start
	left = start
	right = start
	at = 0
	leftAt = 0
	rightAt = 0
	all = portals.copy()
	all.push((end, end))
	while at < all.len:
		l, r = all[at]
		# the right side drawn in, unless it crosses the left: then the left corner is turned at
		if cross2(right - apex, r - apex) >= 0.0:
			if apex == right or cross2(left - apex, r - apex) <= 0.0:
				right = r
				rightAt = at
			else:
				out.push(left)
				apex = left
				right = apex
				rightAt = leftAt
				at = leftAt + 1
				continue
		if cross2(left - apex, l - apex) <= 0.0:
			if apex == left or cross2(right - apex, l - apex) >= 0.0:
				left = l
				leftAt = at
			else:
				out.push(right)
				apex = right
				left = apex
				leftAt = rightAt
				at = rightAt + 1
				continue
		at += 1
	if out[len - 1] != end: out.push(end)
	out

# the portal drawn in by `clearance` at both corners (at most to its middle), so that a path
# through it keeps a body that wide off the border the corners are on
fn drawnIn(portal (Vec3, Vec3), clearance f32):
	a, b = portal
	along = b - a
	inset = clearance.min(along.length() / 2.0)
	if inset <= 0.0: return portal
	way = along.normalized() * inset
	(a + way, b - way)

# The way from `from` to `to` over the mesh: the points to walk through, `from` first and `to`
# (moved onto the mesh) last, each turn kept `clearance` from the mesh's borders where the mesh
# allows; none when no triangles join them.
pub fn findPath(m NavMesh, from Vec3, to Vec3, clearance f32 = 0.0) Vec3[]?:
	if m.vertices.isEmpty: return none
	a, start = m.nearestPoint(from)
	b, end = m.nearestPoint(to)
	triangles = try m.corridor(a, b)
	portals = (0..triangles.len - 1).map(
		drawnIn(m.portalOf(triangles[it], triangles[it + 1]), clearance)
	)
	pulled(portals, start, end)
