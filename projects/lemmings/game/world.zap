# The level's world as the game keeps it: the terrain picture (1584 x 160, a pixel is terrain
# when its alpha is set), the picture of the objects drawn only on terrain, and the object map
# the game reads at a resolution of 4 pixels (traps, exits, water, steel, one-way walls and the
# blockers' fields). The rules and numbers are DOS Lemmings' as Lemmix reads them.

import dos.lemmings
import image

pub worldWidth = 1584
pub worldHeight = 160

# the object map's values: 0..127 a triggered trap's index, 128 + an effect
pub domNone = 128
pub domExit = 129
pub domForceLeft = 130
pub domForceRight = 131
pub domWater = 133
pub domFire = 134
pub domOneWayLeft = 135
pub domOneWayRight = 136
pub domSteel = 137
pub domBlocker = 138

mapOffset = 16   # the map starts 16 pixels left of and above the world
mapColumns = (1647 + mapOffset) / 4
mapRows = (175 + mapOffset) / 4

# a terrain pixel taken away that the DOS screen still shows for a while (a dug row's: the next
pub type Lingering:
	x i64
	y i64
	color image.Rgba8
	steps i64 = 1   # the iterations it stays on the screen

pub type World:
	picture image.Image
	objectMap Grid<u8>
	brick image.Rgba8
	lingering Lingering[] = []

fn clear():
	image.Rgba8(0, 0, 0, 0)

pub fn hasPixelAt(w World, x i64, y i64) bool:
	x >= 0 and y >= 0 and x < worldWidth and y < worldHeight and w.picture[x, y].a != 0

# the pixel at (x, y), or at (x, minY) when y is above minY
pub fn hasPixelAtClipY(w World, x i64, y i64, minY i64) bool:
	w.hasPixelAt(x, y.max(minY))

pub fn removePixelAt(mut w World, x i64, y i64):
	if x >= 0 and y >= 0 and x < worldWidth and y < worldHeight:
		w.picture[x, y] = clear()

fn mapCell(x i64, y i64):
	((x & ~3) / 4 + mapOffset / 4, (y & ~3) / 4 + mapOffset / 4)

pub fn readObjectMap(w World, x i64, y i64) i64:
	cx, cy = mapCell(x, y)
	if cx < 0 or cx >= mapColumns or cy < 0 or cy >= mapRows: return domNone
	w.objectMap[cx, cy]

pub fn writeObjectMap(mut w World, x i64, y i64, v i64):
	cx, cy = mapCell(x, y)
	if cx >= 0 and cx < mapColumns and cy >= 0 and cy < mapRows:
		w.objectMap[cx, cy] = u8(v)

# a piece or a picture put on the terrain by the level's flags
fn stamp(mut w World, src image.Image, x i64, y i64, noOverwrite bool, upsideDown bool, erase bool):
	for sy in 0..src.height:
		ty = y + (src.height - 1 - sy if upsideDown else sy)
		if ty < 0 or ty >= worldHeight: continue
		for sx in 0..src.width:
			tx = x + sx
			if tx < 0 or tx >= worldWidth: continue
			p = src[sx, sy]
			if p.a == 0: continue
			if erase and not noOverwrite:
				w.picture[tx, ty] = clear()
			elif not noOverwrite or w.picture[tx, ty].a == 0:
				w.picture[tx, ty] = p

# the world of a level: its pieces (or a special set's picture at 304, 0), its steel and its
# objects' trigger areas in the map; a triggered trap's cell holds the object's index among the
# objects that are not entrances
pub fn buildWorld(level lemmings.Level, set lemmings.GraphicsSet) World:
	w = World(
		picture = image.Image(worldWidth, worldHeight, fill = clear()),
		objectMap = Grid<u8>(mapColumns, mapRows, fill = u8(domNone)),
		brick = set.palette.colors[7]
	)
	if set.special is picture:
		w.stamp(picture, 304, 0, false, false, false)
	else:
		for p in level.pieces:
			if p.piece < set.pieces.len:
				w.stamp(set.pieces[p.piece].picture, p.x, p.y, p.noOverwrite, p.upsideDown, p.erase)
	for s in level.steel:
		for y in s.y..s.y + s.height:
			for x in s.x..s.x + s.width:
				w.writeObjectMap(x, y, domSteel)
	trapIndex = 0
	for o in level.objects:
		if o.kind >= set.objects.len: continue
		k = set.objects[o.kind]
		if o.kind != lemmings.entranceKind:
			if trapIndex <= 15:   # the game reads no object past the sixteenth
				v = trapIndex if k.effect == 4 else 128 + k.effect
				top = (o.y & ~3) + k.triggerTop
				left = (o.x & ~3) + k.triggerLeft
				for y in top..top + k.triggerHeight:
					for x in left..left + k.triggerWidth:
						w.writeObjectMap(x, y, v)
			trapIndex += 1
	w

# a mask's frame takes the terrain away under its solid pixels; `linger` steps keeps what it took
# on the screen (the explosion's crater: the DOS screen shows it two iterations late)
pub fn applyMask(mut w World, m lemmings.Mask, frame i64, x i64, y i64, linger i64 = 0):
	for sy in 0..m.height:
		for sx in 0..m.width:
			if m.solid[(frame * m.height + sy) * m.width + sx]:
				if linger > 0 and w.hasPixelAt(x + sx, y + sy):
					w.lingering.push(
						Lingering(
							x = x + sx,
							y = y + sy,
							color = w.picture[x + sx, y + sy],
							steps = linger
						)
					)
				w.removePixelAt(x + sx, y + sy)

# six brick pixels from x at y where the terrain has none
pub fn layBrick(mut w World, x i64, y i64):
	for i in 0..6:
		tx = x + i
		if tx >= 0 and tx < worldWidth and y >= 0 and y < worldHeight and w.picture[tx, y].a == 0:
			w.picture[tx, y] = w.brick

# a digger's row: nine pixels centred on x; whether any was terrain. The DOS game's screen keeps
# the first, fifth and ninth (one VGA plane of the four) for one iteration more (the oracle); the
# row that meets steel keeps all nine (`atSteel`).
pub fn digRow(mut w World, x i64, y i64, atSteel bool = false) bool:
	yy = y.max(0)
	found = false
	for i in 0..9:
		if w.hasPixelAt(x - 4 + i, yy):
			if i % 4 == 0 or atSteel:
				w.lingering.push(Lingering(x = x - 4 + i, y = yy, color = w.picture[x - 4 + i, yy]))
			w.removePixelAt(x - 4 + i, yy)
			found = true
	found

# one iteration gone: what lingered its last iteration leaves the screen
pub fn ageLingering(mut w World):
	kept = []
	for p in w.lingering:
		if p.steps > 1:
			kept.push(Lingering(..p, steps = p.steps - 1))
	w.lingering = kept
