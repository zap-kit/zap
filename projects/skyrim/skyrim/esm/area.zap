# The exterior area the game has loaded around a cell: GridCellArray's uGridsToLoad squared cells
# (SkyrimSE.exe 0x140226FA0 forces the setting to at least 5 and odd), centred on the cell the
# player is in. An area is named by its centre, `exterior_<world>_<x>_<y>` (the world's form id in
# decimal), and stands in for an interior cell wherever one is looked up by id (findCell,
# cellRecords): its references are those of every cell of the grid, the world's persistent ones
# lying in them too.

pub type Area:
	world i64
	x i64
	y i64

areaPrefix = "exterior_"

# the area's id: the prepared file's name and the id every cell lookup takes
pub fn areaId(a Area) str:
	"{areaPrefix}{a.world}_{a.x}_{a.y}"

# the area an id names, none for an interior's
pub fn areaOf(id str) Area?:
	if not id.startsWith(areaPrefix): return none
	parts = id[areaPrefix.len..].split("_")
	if parts.len != 3: return none
	Area(
		world = try i64.parse(parts[0]),
		x = try i64.parse(parts[1]),
		y = try i64.parse(parts[2])
	)

# the cells along one side of the loaded grid: uGridsToLoad, at least 5 and odd as the game makes it
pub fn gridSide(setting i64) i64:
	if setting < 5: return 5
	setting + 1 if setting % 2 == 0 else setting

# the grid places the game keeps loaded around the cell (x, y), row by row from the south west
pub fn loadedGrid(x i64, y i64, side i64) (i64, i64)[]:
	half = side / 2
	out = []
	for gy in y - half..=y + half:
		for gx in x - half..=x + half:
			out.push((gx, gy))
	out

# The cells that enter and leave the loaded grid when its centre moves from one area to another:
# the game loads and unloads a row or a column of the grid each time the player crosses into a
# neighbouring cell (a step of one cell enters and leaves `side` cells, a diagonal one 2 side - 1),
# and keeps the rest as they are.
pub type GridPlace:
	x i64
	y i64

pub type GridShift:
	entering GridPlace[]
	leaving GridPlace[]

fn placeAt(p (i64, i64)):
	x, y = p
	GridPlace(x, y)

# the loaded grid around the area's centre, as places
pub fn loadedPlaces(a Area, side i64) GridPlace[]:
	loadedGrid(a.x, a.y, side).map(placeAt(it))

pub fn gridShift(from Area, to Area, side i64) GridShift:
	before = from.loadedPlaces(side)
	after = to.loadedPlaces(side)
	GridShift(entering = after.filter(it not in before), leaving = before.filter(it not in after))

# the cell the player standing at p is in, and the area the game loads around it
pub fn areaAround(world i64, p Vec3) Area:
	x, y = p.gridOf()
	Area(world, x, y)

# whether the world has the area's centre cell (the sea and the world's edge have none)
pub fn hasCellAt(e Esm, a Area) bool:
	e.exteriorCell(a.world, a.x, a.y) != none

# the cells of the area that exist in the world (the sea and the edges have none)
fn areaCells(e Esm, a Area, side i64):
	out = []
	for place in loadedGrid(a.x, a.y, side):
		x, y = place
		if e.exteriorCellData(a.world, x, y) is c: out.push(c)
	out

# The area as one cell: the centre's record and lighting, the references of the whole grid; none
# when the centre does not exist.
pub fn areaCell(e Esm, a Area, side i64 = 5) Cell?:
	center = try e.exteriorCellData(a.world, a.x, a.y)
	refs = e.persistentRefsIn(a.world, loadedGrid(a.x, a.y, side))
	for c in e.areaCells(a, side):
		refs.extend(c.refs)
	Cell(..center, editorId = a.areaId(), refs, exterior = true)

# the records placed in the area's cells (REFR, ACHR, NAVM...) and the world's persistent ones lying in it
pub fn areaRecords(e Esm, a Area, side i64 = 5) Record[]:
	out = []
	for placed in e.persistentIn(a.world, loadedGrid(a.x, a.y, side)):
		out.push(placed.record.copy())
	for place in loadedGrid(a.x, a.y, side):
		x, y = place
		d = e.exteriorSubBlock(a.world, x, y) ?? continue
		h = exteriorHeadIn(d, x, y) ?? continue
		out.extend(recordsOfCell(d, h.at))
	out
