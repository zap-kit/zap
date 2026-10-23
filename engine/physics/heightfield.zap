# Terrain as a grid of heights: `side` x `side` vertices `step` apart, row by row from the
# smallest y, each row from the smallest x. Each square of the grid is two triangles whose
# diagonal alternates like a checkerboard (the square at column c, row r is cut from its
# lower-left corner to its upper-right one when c + r is even, from its upper-left to its
# lower-right one when odd), as Skyrim's landscape is cut; the collider and the drawn mesh read the
# same triangles through gridTriangles. Heights are in the world's units, z up.

# The indices of the grid's triangles (three each, counter-clockwise seen from above): two per
# square, in the order the squares lie.
pub fn gridTriangles(side i64) u32[]:
	out u32[] = []
	out.reserve((side - 1) * (side - 1) * 6)
	for r in 0..side - 1:
		for c in 0..side - 1:
			lowerLeft = u32(r * side + c)
			lowerRight = lowerLeft + 1
			upperLeft = lowerLeft + u32(side)
			upperRight = upperLeft + 1
			if (r + c) % 2 == 0:
				out.extend([upperRight, upperLeft, lowerLeft, lowerLeft, lowerRight, upperRight])
			else:
				out.extend([upperLeft, lowerLeft, lowerRight, lowerRight, upperRight, upperLeft])
	out

# The height of the grid at (x, y) measured from its first vertex, on the triangle that holds the
# point; none outside the grid.
pub fn gridHeight(heights f32[], side i64, step f32, x f32, y f32) f32?:
	extent = f32(side - 1) * step
	if x < 0.0 or y < 0.0 or x > extent or y > extent: return none
	c = i64(x / step).min(side - 2)
	r = i64(y / step).min(side - 2)
	u = x / step - f32(c)
	v = y / step - f32(r)
	lowerLeft = heights[r * side + c]
	lowerRight = heights[r * side + c + 1]
	upperLeft = heights[(r + 1) * side + c]
	upperRight = heights[(r + 1) * side + c + 1]
	if (r + c) % 2 == 0:
		if u >= v: return lowerLeft + u * (lowerRight - lowerLeft) + v * (upperRight - lowerRight)
		return lowerLeft + v * (upperLeft - lowerLeft) + u * (upperRight - upperLeft)
	if u + v <= 1.0: return lowerLeft + u * (lowerRight - lowerLeft) + v * (upperLeft - lowerLeft)
	upperRight + (1.0 - u) * (upperLeft - upperRight) + (1.0 - v) * (lowerRight - upperRight)

# the grid's vertices placed with its first one at `origin` (the heights are z)
pub fn gridPositions(heights f32[], side i64, step f32, origin Vec2) Vec3[]:
	out = []
	for r in 0..side:
		for c in 0..side:
			out.push(
				Vec3(origin.x + f32(c) * step, origin.y + f32(r) * step, heights[r * side + c])
			)
	out

# A static surface of the grid with its first vertex at `origin`, as a group of the scene under
# `key` (so removeGroup takes it out when the land is unloaded).
pub fn addHeightfield(
	mut w World,
	key i64,
	heights f32[],
	side i64,
	step f32,
	origin Vec2,
	friction f32,
	restitution f32,
	material i64 = 0
):
	first = w.scene.triangleCount()
	w.addSurface(
		gridPositions(heights, side, step, origin),
		gridTriangles(side),
		friction,
		restitution,
		fill(side * side * 2 - side * 4 + 2, material)
	)
	w.scene.groupFrom(key, first)
