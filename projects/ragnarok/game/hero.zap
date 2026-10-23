# The hero walking the GAT's cells as the server walks a player: a click picks a cell, the path
# to it is found over walkable cells in eight directions (a diagonal step only past two open
# sides, as rAthena allows it), and each step takes 100 ms straight and 140 ms diagonal (faster
# than the client's default 150, as the player asked; a diagonal 14/10 of it). The hero faces
# its step in Ragnarok's eight directions: 0 south, then turning west, 2 west, 4 north, 6 east.

import ragnarok.gat

pub type Hero:
	x i64   # the cell it stands on (or leaves)
	y i64
	path Cell[]   # the cells still to walk to
	stepMs i64   # into the current step
	facing i64
	headDir i64   # where the head looks standing: 0 ahead, 1 and 2 aside
	walking bool
	animMs i64   # into the current action's animation

	# where the hero is in the world: between its cell and the next one of its path, on the ground
	fn place(gat gat.Gat):
		fx = f32(x) + 0.5
		fy = f32(y) + 0.5
		if walking and not path.isEmpty:
			Cell(nx, ny) = path[0]
			t = f32(stepMs) / f32(stepTime(nx - x, ny - y))
			fx += f32(nx - x) * t
			fy += f32(ny - y) * t
		cx = i64(fx.floor())
		cy = i64(fy.floor())
		Vec3(fx, -gat.heightAt(cx, cy, fx - f32(cx), fy - f32(cy)) * 0.2, -fy)

# a cell of the GAT
pub type Cell:
	x i64
	y i64

walkSpeed = 100
maxSearch = 20_000

pub fn newHero(gat gat.Gat, x i64, y i64) Hero:
	h = Hero(x, y, path = [], stepMs = 0, facing = 0, headDir = 0, walking = false, animMs = 0)
	# a spawn on a cell that is not walkable moves to the nearest that is
	if not gat.walkable(x, y):
		for r in 1..20:
			for dy in -r..=r:
				for dx in -r..=r:
					if gat.walkable(x + dx, y + dy) and not gat.walkable(h.x, h.y):
						h.x = x + dx
						h.y = y + dy
	h

# Ragnarok's direction of a step (dx, dy with y north)
pub fn directionOf(dx i64, dy i64) i64:
	if dx == 0: return 0 if dy < 0 else 4
	if dx < 0: return 1 if dy < 0 else 2 if dy == 0 else 3
	5 if dy > 0 else 6 if dy == 0 else 7

fn stepTime(dx i64, dy i64):
	walkSpeed * 14 / 10 if dx != 0 and dy != 0 else walkSpeed

# The way from (x0, y0) to (x1, y1) over walkable cells: the cells after the start. The direct
# way first; else A* over the cells; when (x1, y1) cannot be reached (not walkable, walled off,
# or too far to search), the way to the reachable cell nearest it, as the client walks toward
# a click on a wall or the water. Empty when the hero cannot get any nearer.
pub fn findPath(gat gat.Gat, x0 i64, y0 i64, x1 i64, y1 i64) Cell[]:
	out = []
	if x0 == x1 and y0 == y1: return out
	# the direct way first, as rAthena tries it: diagonal steps, then straight ones, so the hero
	# turns once instead of zigzagging between two facings
	if gat.walkable(x1, y1):
		direct = gat.directPath(x0, y0, x1, y1)
		if not direct.isEmpty: return direct
	w = gat.cells.width
	h = gat.cells.height
	start = Cell(x0, y0)
	goal = Cell(x1, y1)
	unknown = 1_000_000_000
	cost = Grid(w, h, fill = unknown)
	from = Grid<Cell?>(w, h)
	closed = Grid(w, h, fill = false)
	# the open set as a binary heap of (estimate, cell)
	heap = []
	cost[x0, y0] = 0
	push(heap, (estimate(x0, y0, x1, y1), start))
	# the cell searched nearest the goal (then the cheapest to reach)
	best = start
	bestLeft = estimate(x0, y0, x1, y1)
	searched = 0
	while not heap.isEmpty and searched < maxSearch:
		_, cell = pop(heap)
		cx = cell.x
		cy = cell.y
		if closed[cx, cy]: continue
		closed[cx, cy] = true
		searched += 1
		left = estimate(cx, cy, x1, y1)
		if left < bestLeft or (left == bestLeft and cost[cx, cy] < cost[best.x, best.y]):
			best = cell
			bestLeft = left
		if cell == goal: break
		here = cost[cx, cy]
		for (dx, dy) in [(0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]:
			nx = cx + dx
			ny = cy + dy
			if not gat.walkable(nx, ny): continue
			if dx != 0 and dy != 0 and
				(not gat.walkable(cx + dx, cy) or not gat.walkable(cx, cy + dy)):
				continue
			c = here + (14 if dx != 0 and dy != 0 else 10)
			if c < cost[nx, ny]:
				cost[nx, ny] = c
				from[nx, ny] = cell
				push(heap, (c + estimate(nx, ny, x1, y1), Cell(nx, ny)))
	cell = best
	while cell != start:
		out.push(cell)
		cell = from[cell.x, cell.y] ?? break
	out.reverse()
	out

# the cells from (x0, y0) to (x1, y1) stepping diagonally while both coordinates differ, then
# straight; empty when a cell of it is not walkable (or a diagonal step cuts a blocked corner)
fn directPath(gat gat.Gat, x0 i64, y0 i64, x1 i64, y1 i64):
	out = []
	x = x0
	y = y0
	while x != x1 or y != y1:
		dx = (x1 - x).clamp(-1, 1)
		dy = (y1 - y).clamp(-1, 1)
		if not gat.walkable(x + dx, y + dy) or
			(dx != 0 and dy != 0 and (not gat.walkable(x + dx, y) or not gat.walkable(x, y + dy))):
			return []
		x += dx
		y += dy
		out.push(Cell(x, y))
	out

# the octile distance in tenths of a cell
fn estimate(x0 i64, y0 i64, x1 i64, y1 i64):
	dx = (x1 - x0).abs()
	dy = (y1 - y0).abs()
	10 * (dx + dy) - 6 * dx.min(dy)

fn costOf(item (i64, Cell)):
	cost, _ = item
	cost

fn push(mut heap (i64, Cell)[], item (i64, Cell)):
	heap.push(item)
	i = heap.len - 1
	while i > 0:
		p = (i - 1) / 2
		if costOf(heap[p]) <= costOf(heap[i]): break
		t = heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p

fn pop(mut heap (i64, Cell)[]):
	top = heap[0]
	last = heap.pop() ?? top
	if not heap.isEmpty:
		heap[0] = last
		i = 0
		loop:
			l = i * 2 + 1
			r = l + 1
			m = i
			if l < heap.len and costOf(heap[l]) < costOf(heap[m]):
				m = l
			if r < heap.len and costOf(heap[r]) < costOf(heap[m]):
				m = r
			if m == i: break
			t = heap[m]
			heap[m] = heap[i]
			heap[i] = t
			i = m
	top

# a new destination: from the cell the hero is stepping into (it finishes its step first)
pub fn walkTo(mut h Hero, gat gat.Gat, x i64, y i64):
	fromX = h.x
	fromY = h.y
	keep = []
	if h.walking and not h.path.isEmpty:
		Cell(fromX, fromY) = h.path[0]
		keep.push(h.path[0])
	route = gat.findPath(fromX, fromY, x, y)
	if route.isEmpty and keep.isEmpty: return
	keep.extend(route)
	h.path = keep
	if not h.walking:
		h.walking = true
		h.stepMs = 0
		h.animMs = 0

# the hero moved on by `ms` milliseconds
pub fn stepHero(mut h Hero, gat gat.Gat, ms i64):
	_ = gat
	h.animMs += ms
	if not h.walking: return
	h.stepMs += ms
	while not h.path.isEmpty:
		Cell(nx, ny) = h.path[0]
		h.facing = directionOf(nx - h.x, ny - h.y)
		need = stepTime(nx - h.x, ny - h.y)
		if h.stepMs < need: return
		h.stepMs -= need
		h.x = nx
		h.y = ny
		h.path.remove(0)
	h.walking = false
	h.stepMs = 0
	h.animMs = 0
