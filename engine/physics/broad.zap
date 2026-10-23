# The broad phase: the scene's triangles in a uniform grid of cubes, each listing the triangles
# whose bounds reach into it, and the bodies' pairs found by sweeping their bounds sorted along x.

# the static triangles bodies rest on, with their surfaces, in a grid of cells
pub type Scene:
	cellSize f32
	corners Vec3[] = []   # three per triangle
	normals Vec3[] = []
	friction f32[] = []
	restitution f32[] = []
	materials i64[] = []   # each triangle's material (a number the game gives it), 0 for none
	cells {i64: i64[]} = {}
	seen i64[] = []   # each triangle's last query that met it
	removed bool[] = []   # each triangle taken out of the scene (a door that opened)
	groups {i64: TriangleRange} = {}   # triangles added together, by the key they were given
	query i64 = 0

# the triangles first..end of a scene
pub type TriangleRange:
	first i64
	end i64

# an empty scene whose grid's cubes are cellSize wide
pub fn sceneOf(cellSize f32) Scene:
	Scene(cellSize)

# how many triangles the scene holds
pub fn triangleCount(s Scene) i64:
	s.normals.len

fn cellOf(s Scene, p Vec3):
	IVec3(
		i32((p.x / s.cellSize).floor()),
		i32((p.y / s.cellSize).floor()),
		i32((p.z / s.cellSize).floor())
	)

fn cellKey(x i32, y i32, z i32):
	bias i64 = 1 << 20
	((x + bias) << 42) | ((y + bias) << 21) | (z + bias)

# the triangle a b c added, of a surface of this friction, restitution and material
pub fn addTriangle(
	mut s Scene,
	a Vec3,
	b Vec3,
	c Vec3,
	friction f32,
	restitution f32,
	material i64 = 0
):
	n = (b - a).cross(c - a)
	if n.length() <= 0.0: return
	t = s.normals.len
	s.corners.extend([a, b, c])
	s.normals.push(n.normalized())
	s.friction.push(friction)
	s.restitution.push(restitution)
	s.materials.push(material)
	s.seen.push(-1)
	s.removed.push(false)
	lo = s.cellOf(a.min(b).min(c))
	hi = s.cellOf(a.max(b).max(c))
	for x in lo.x..=hi.x:
		for y in lo.y..=hi.y:
			for z in lo.z..=hi.z:
				key = cellKey(x, y, z)
				if key not in s.cells: s.cells[key] = []
				s.cells[key].push(t)

# the triangles added since `first` kept as a group by `key`
pub fn groupFrom(mut s Scene, key i64, first i64):
	s.groups[key] = TriangleRange(first, s.triangleCount())

# the group's triangles taken out of the scene: nothing meets them any more
pub fn removeGroup(mut s Scene, key i64):
	range = s.groups.get(key) ?? return
	for t in range.first..range.end:
		s.removed[t] = true

# the triangles whose cells the box lo..hi reaches, each once, in the order the cells list them
pub fn trianglesNear(mut s Scene, lo Vec3, hi Vec3) i64[]:
	s.query += 1
	out = []
	a = s.cellOf(lo)
	b = s.cellOf(hi)
	for x in a.x..=b.x:
		for y in a.y..=b.y:
			for z in a.z..=b.z:
				ids = s.cells.get(cellKey(x, y, z)) ?? continue
				for t in ids:
					if s.seen[t] == s.query or s.removed[t]: continue
					s.seen[t] = s.query
					out.push(t)
	out

# corner k (0 to 2) of triangle t
pub fn corner(s Scene, t i64, k i64) Vec3:
	s.corners[t * 3 + k]

# whether the boxes a and b come within `margin` of each other
pub fn boxesMeet(alo Vec3, ahi Vec3, blo Vec3, bhi Vec3, margin f32) bool:
	alo.x <= bhi.x + margin and blo.x <= ahi.x + margin and alo.y <= bhi.y + margin and
		blo.y <= ahi.y + margin and alo.z <= bhi.z + margin and blo.z <= ahi.z + margin

# the pairs of bodies (lower index first) whose bounds come within the margin and what the two
# may cross in dt, one of them awake, found by sweeping their bounds sorted by their lowest x
pub fn bodyPairs(bodies Body[], margin f32, dt f32) (i64, i64)[]:
	order = (0..bodies.len).map(it).sortedBy((bodies[it].lo.x, it))
	fastest = bodies.map(.velocity.length()).max() ?? 0.0
	pairs = []
	for k in 0..order.len:
		a = order[k]
		for m in k + 1..order.len:
			b = order[m]
			if bodies[b].lo.x > bodies[a].hi.x + margin + 2.0 * fastest * dt: break
			if bodies[a].asleep and bodies[b].asleep: continue
			reach = margin + (bodies[a].velocity.length() + bodies[b].velocity.length()) * dt
			if bodies[a].lo.boxesMeet(bodies[a].hi, bodies[b].lo, bodies[b].hi, reach):
				pairs.push((a.min(b), a.max(b)))
	pairs
