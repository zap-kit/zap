# GAT, a map's altitude: "GRAT", a version, its size in cells (5 units square, two to a GND
# cube's side), then per cell its four corner heights (y down, in the GND's order: x, y; x + 1,
# y; x, y + 1; x + 1, y + 1) and its type. The server walks the same cells: types 0, 2, 3 (water
# one can wade), 4 and 6 are walkable, 1 and 5 are not (5 lets a shot pass).

pub type Cell:
	heights Vec4   # the corners: x, y; x + 1, y; x, y + 1; x + 1, y + 1
	kind u8

pub type Gat:
	cells Grid<Cell>

	fn inside(x i64, y i64):
		x >= 0 and y >= 0 and x < cells.width and y < cells.height

	fn walkable(x i64, y i64):
		if not self.inside(x, y): return false
		t = cells[x, y].kind
		t != 1 and t != 5

	# the ground's height (y down) at a point of the cell (fx, fy in 0..1 across it), between its
	# four corners
	fn heightAt(x i64, y i64, fx f32, fy f32) f32:
		if not self.inside(x, y): return 0.0
		h = cells[x, y].heights
		south = h[0] + (h[1] - h[0]) * fx
		north = h[2] + (h[3] - h[2]) * fx
		south + (north - south) * fy

# the cells of a GAT file, or why it cannot be read
pub fn parseGat(d u8[]) Gat ? str:
	if d.len < 14 or not d.startsWith("GRAT"): return "not a GAT file"
	r = Reader(d, at = 6)
	width = r.recordCount(1)
	height = r.recordCount(1)
	if r.short or 14 + width * height * 20 > d.len: return "the GAT's cells run past the end"
	cells = Grid<Cell>(width, height)
	for y in 0..cells.height:
		for x in 0..cells.width:
			cells[x, y].heights = Vec4(r.f32(), r.f32(), r.f32(), r.f32())
			cells[x, y].kind = u8(r.u32())
	Gat(cells)
