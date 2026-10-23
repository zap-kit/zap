# The level's solid surfaces as the game queries them (surface_collision.c): each triangle with
# its normal, the plane's offset and the heights it spans, sorted into floors (facing up),
# ceilings (facing down) and walls, and into a grid of 16 x 16 cells of 1024 units over the
# level (-8192..8192 in x and z) so a query reads only its cell. A floor is found under a point
# up to 78 units above it; walls push a cylinder of a radius out of them. The camera queries them
# apart (gCheckingSurfaceCollisionsForCamera): it meets the camera boundaries the others pass
# through and passes through what has no camera collision. Objects' own surfaces (dynamic ones)
# are not loaded.

import n64

pub type Surface:
	kind i64
	x1 i64
	y1 i64
	z1 i64
	x2 i64
	y2 i64
	z2 i64
	x3 i64
	y3 i64
	z3 i64
	normal Vec3
	offset f32   # the plane: normal . p + offset = 0
	lowerY i64
	upperY i64
	xProjection bool   # a wall facing x more than z: tested in the z-y plane
	force i64   # the push of wind, flowing water and moving quicksand: its direction << 8
	noCamCollision bool   # SURFACE_FLAG_NO_CAM_COLLISION

# what walls did to a cylinder (struct WallCollisionData after find_wall_collisions): where they
# pushed it, how many pushed, how many the game kept (four at most) and the last of those (-1 none)
pub type WallCollision:
	x f32
	z f32
	numCollisions i64
	numWalls i64
	wall i64

# surface types (surface_terrains.h) the queries treat apart
surfaceIntangible = 0x0012
surfaceCameraBoundary = 0x0072
surfaceNoCamCollision = 0x0076
surfaceNoCamCollision77 = 0x0077
surfaceSwitchType = 0x007A

pub type Surfaces:
	all Surface[]
	floors i64[,]   # per cell: floors, highest first
	ceilings i64[,]   # per cell: lowest first
	walls i64[,]
	water n64.WaterBox[]

boundary = 0x2000
cellSize = 0x400
cells = 16

pub floorLowerLimit f32 = -11000.0
pub ceilingLimit f32 = 20000.0

# the surfaces of a level's collision data
pub fn buildSurfaces(col n64.Collision) Surfaces:
	s = Surfaces(all = [], floors = [], ceilings = [], walls = [], water = col.water.copy())
	loop cells * cells:
		s.floors.push([])
		s.ceilings.push([])
		s.walls.push([])
	v = col.vertices
	for t in col.surfaces:
		if surfaceOf(
			t.kind,
			t.param,
			v[3 * t.a],
			v[3 * t.a + 1],
			v[3 * t.a + 2],
			v[3 * t.b],
			v[3 * t.b + 1],
			v[3 * t.b + 2],
			v[3 * t.c],
			v[3 * t.c + 1],
			v[3 * t.c + 2]
		) is surface:
			s.addSurface(surface)
	s

# read_surface_data: the normal scaled by the reciprocal of its length (taken in double, as the
# game's 1.0 / mag is), the plane's offset from the first vertex
fn surfaceOf(
	kind i64,
	force i64,
	x1 i64,
	y1 i64,
	z1 i64,
	x2 i64,
	y2 i64,
	z2 i64,
	x3 i64,
	y3 i64,
	z3 i64
) Surface?:
	nx = f32((y2 - y1) * (z3 - z2) - (z2 - z1) * (y3 - y2))
	ny = f32((z2 - z1) * (x3 - x2) - (x2 - x1) * (z3 - z2))
	nz = f32((x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2))
	mag = (nx * nx + ny * ny + nz * nz).sqrt()
	if f64(mag) < 0.0001: return none
	scale = f32(1.0 / f64(mag))
	n = Vec3(nx * scale, ny * scale, nz * scale)
	Surface(kind, x1, y1, z1, x2, y2, z2, x3, y3, z3, normal = n,
		offset = -(n.x * f32(x1) + n.y * f32(y1) + n.z * f32(z1)),
		lowerY = y1.min(y2).min(y3) - 5,
		upperY = y1.max(y2).max(y3) + 5,
		xProjection = f64(n.x) < -0.707 or f64(n.x) > 0.707, force,
		noCamCollision = kind in [
			surfaceNoCamCollision,
			surfaceNoCamCollision77,
			surfaceNoCamColVerySlippery,
			surfaceSwitchType
	])

# a surface put in every cell its box touches (and the next one within 50 units of an edge)
fn addSurface(mut s Surfaces, surface Surface):
	i = s.all.len
	s.all.push(surface)
	minX = surface.x1.min(surface.x2).min(surface.x3)
	maxX = surface.x1.max(surface.x2).max(surface.x3)
	minZ = surface.z1.min(surface.z2).min(surface.z3)
	maxZ = surface.z1.max(surface.z2).max(surface.z3)
	for cz in lowerCell(minZ)..=upperCell(maxZ):
		for cx in lowerCell(minX)..=upperCell(maxX):
			c = cz * cells + cx
			if f64(surface.normal.y) > 0.01:
				insertSorted(s.floors[c], i, s.all, true)
			elif f64(surface.normal.y) < -0.01:
				insertSorted(s.ceilings[c], i, s.all, false)
			else:
				s.walls[c].push(i)

# a floor in its cell's list by its first vertex's height, highest first (a ceiling lowest first)
fn insertSorted(mut list i64[], i i64, all Surface[], highestFirst bool):
	y = all[i].y1
	at = 0
	while at < list.len and (all[list[at]].y1 >= y if highestFirst else all[list[at]].y1 <= y):
		at += 1
	list.insert(at, i)

fn lowerCell(coord0 i64):
	coord = (coord0 + boundary).max(0)
	index = coord / cellSize
	if coord % cellSize < 50:
		index -= 1
	index.max(0)

fn upperCell(coord0 i64):
	coord = (coord0 + boundary).max(0)
	index = coord / cellSize
	if coord % cellSize > cellSize - 50:
		index += 1
	index.min(cells - 1)

# the cell a point is in (its coordinates cut to 16 bits, as the game's s16 casts do), -1
# outside the level
fn cellOf(x i64, z i64):
	if x <= -boundary or x >= boundary or z <= -boundary or z >= boundary: return -1
	((z + boundary) / cellSize & 15) * cells + ((x + boundary) / cellSize & 15)

# a coordinate as the game's (s16) cast leaves it
fn short(v f32) i64:
	i16.wrap(i64(v))

# The floor under (x, y, z), up to 78 units above it (find_floor): its height and its index, or
# the lower limit and -1. An intangible floor is looked under, 200 units below it. `forCamera`:
# while the camera checks (gCheckingSurfaceCollisionsForCamera).
pub fn findFloor(s Surfaces, x f32, y f32, z f32, forCamera bool = false) (f32, i64):
	px, py, pz = short(x), short(y), short(z)
	c = cellOf(px, pz)
	if c < 0: return (floorLowerLimit, -1)
	height, floor = s.floorFromList(s.floors[c], px, py, pz, forCamera)
	if floor >= 0 and s.all[floor].kind == surfaceIntangible:
		# (when nothing is under it, the game keeps the intangible floor's height with no floor)
		under, below = s.floorFromList(s.floors[c], px, i64(height - 200.0), pz, forCamera)
		return (under, below) if below >= 0 else (height, -1)
	(height, floor)

# whether a query skips the surface: the camera's skips those without camera collision, the
# others skip the camera's boundaries
fn skipsSurface(f Surface, forCamera bool):
	f.noCamCollision if forCamera else f.kind == surfaceCameraBoundary

# find_floor_from_list: the first floor of the cell's list (highest first by its first vertex)
# whose triangle holds the point and whose plane is at most 78 above it
fn floorFromList(s Surfaces, list i64[], px i64, py i64, pz i64, forCamera bool):
	for i in list:
		f = s.all[i]
		if (f.z1 - pz) * (f.x2 - f.x1) - (f.x1 - px) * (f.z2 - f.z1) < 0: continue
		if (f.z2 - pz) * (f.x3 - f.x2) - (f.x2 - px) * (f.z3 - f.z2) < 0: continue
		if (f.z3 - pz) * (f.x1 - f.x3) - (f.x3 - px) * (f.z1 - f.z3) < 0: continue
		if f.skipsSurface(forCamera) or f.normal.y == 0.0: continue
		height = -(f32(px) * f.normal.x + f.normal.z * f32(pz) + f.offset) / f.normal.y
		if f32(py) - (height - 78.0) < 0.0: continue
		return (height, i)
	(floorLowerLimit, -1)

# the ceiling over (x, y, z), down to 78 units below it (find_ceil): its height and index, or the
# limit and -1; `forCamera` as findFloor's
pub fn findCeiling(s Surfaces, x f32, y f32, z f32, forCamera bool = false) (f32, i64):
	px, py, pz = short(x), short(y), short(z)
	c = cellOf(px, pz)
	if c < 0: return (ceilingLimit, -1)
	for i in s.ceilings[c]:
		f = s.all[i]
		if (f.z1 - pz) * (f.x2 - f.x1) - (f.x1 - px) * (f.z2 - f.z1) > 0: continue
		if (f.z2 - pz) * (f.x3 - f.x2) - (f.x2 - px) * (f.z3 - f.z2) > 0: continue
		if (f.z3 - pz) * (f.x1 - f.x3) - (f.x3 - px) * (f.z1 - f.z3) > 0: continue
		if f.skipsSurface(forCamera) or f.normal.y == 0.0: continue
		height = -(f32(px) * f.normal.x + f.normal.z * f32(pz) + f.offset) / f.normal.y
		if f32(py) - (height + 78.0) > 0.0: continue
		return (height, i)
	(ceilingLimit, -1)

# vec3f_find_ceil: the ceiling over pos, looked for from `height`
pub fn vec3fFindCeil(s Surfaces, pos Vec3, height f32) (f32, i64):
	s.findCeiling(pos.x, height + 80.0, pos.z)

# resolve_and_return_wall_collisions: pos pushed out of the walls around it; the wall the game
# keeps of them (-1 none)
pub fn resolveAndReturnWallCollisions(s Surfaces, mut pos Vec3, offsetY f32, radius f32) i64:
	w = s.findWallCollisions(pos.x, pos.y, pos.z, offsetY, radius, false)
	pos.x = w.x
	pos.z = w.z
	w.wall

# find_wall_collisions (find_wall_collisions_from_list), for the camera or not
pub fn findWallCollisions(
	s Surfaces,
	x f32,
	y f32,
	z f32,
	offsetY f32,
	radius0 f32,
	forCamera bool
) WallCollision:
	radius f32 = 200.0 if radius0 > 200.0 else radius0
	px = x
	pz = z
	py = y + offsetY
	out = WallCollision(x, z, numCollisions = 0, numWalls = 0, wall = -1)
	c = cellOf(short(x), short(z))
	if c < 0: return out
	for i in s.walls[c]:
		w = s.all[i]
		if py < f32(w.lowerY) or py > f32(w.upperY): continue
		d = w.normal.x * px + w.normal.y * py + w.normal.z * pz + w.offset
		if d < -radius or d > radius: continue
		if not w.insideWall(px, py, pz) or w.skipsSurface(forCamera): continue
		out.x += w.normal.x * (radius - d)
		out.z += w.normal.z * (radius - d)
		if out.numWalls < 4:
			out.wall = i
			out.numWalls += 1
		out.numCollisions += 1
	out

# whether the point lies within the wall's triangle, seen along the axis it faces most
fn insideWall(w Surface, px f32, py f32, pz f32):
	y1, y2, y3 = f32(w.y1), f32(w.y2), f32(w.y3)
	w1 = f32(0.0)
	w2 = f32(0.0)
	w3 = f32(0.0)
	p = f32(0.0)
	positive = false
	if w.xProjection:
		w1 = f32(-w.z1)
		w2 = f32(-w.z2)
		w3 = f32(-w.z3)
		p = -pz
		positive = w.normal.x > 0.0
	else:
		w1 = f32(w.x1)
		w2 = f32(w.x2)
		w3 = f32(w.x3)
		p = px
		positive = w.normal.z > 0.0
	e1 = (y1 - py) * (w2 - w1) - (w1 - p) * (y2 - y1)
	e2 = (y2 - py) * (w3 - w2) - (w2 - p) * (y3 - y2)
	e3 = (y3 - py) * (w1 - w3) - (w3 - p) * (y1 - y3)
	e1 <= 0.0 and e2 <= 0.0 and e3 <= 0.0 if positive else e1 >= 0.0 and e2 >= 0.0 and e3 >= 0.0

# the water's height at (x, z) (find_water_level): the first water box (an id under 50; above
# are gas) strictly around the point, the floor's lower limit where there is none
pub fn waterLevel(s Surfaces, x f32, z f32) f32:
	for w in s.water:
		if f32(w.x1) < x and x < f32(w.x2) and f32(w.z1) < z and z < f32(w.z2) and
			w.id < 50:
			return f32(w.y)
	floorLowerLimit

# the poison gas's height at (x, z) (find_poison_gas_level): the first gas box (an id of 50, 60...)
# strictly around the point, the floor's lower limit where there is none
pub fn poisonGasLevel(s Surfaces, x f32, z f32) f32:
	for w in s.water:
		if w.id >= 50 and f32(w.x1) < x and x < f32(w.x2) and f32(w.z1) < z and
			z < f32(w.z2) and w.id % 10 == 0:
			return f32(w.y)
	floorLowerLimit
