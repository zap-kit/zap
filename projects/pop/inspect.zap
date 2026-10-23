# Lists what the DOS files hold and writes pictures of them to check the readers by eye:
#   zap run projects/pop/inspect.zap [--install dir] [--out dir] [--level 1..15]
# writes each sprite table as one sheet, and the level's map: its rooms placed by their links,
# each tile a block coloured by its kind.

import dos.pop
import fs
import image

dir = args.option("--install") ?? pop.defaultInstall
out = args.option("--out") ?? "projects/pop/assets/inspect"
_ = fs.createDir(out)
levelNumber = (i64.parse(args.option("--level") ?? "1") ?? 1).clamp(0, 15)

# the pictures of a table side by side in rows, each in a cell of the largest's size
fn sheetOf(t pop.SpriteTable):
	cellW = 1
	cellH = 1
	for p in t.pictures:
		if p is q:
			cellW = cellW.max(q.width)
			cellH = cellH.max(q.height)
	perRow = 16
	rows = (t.pictures.len + perRow - 1) / perRow
	sheet = image.Image(
		perRow * (cellW + 2),
		rows.max(1) * (cellH + 2),
		fill = image.Rgba8(40, 0, 40, 255)
	)
	for i, p in t.pictures:
		if p is q:
			pic = q.toImage(t.palette)
			x0 = (i % perRow) * (cellW + 2)
			y0 = (i / perRow) * (cellH + 2)
			for (x, y), c in pic:
				if c.a != 0:
					sheet[x0 + x, y0 + y] = c
	sheet

fn saveTable(files str[], first i64, name str):
	t = pop.spriteTableOf(pop.DatChain(files.map(pop.loadDat(dir, it))), first)
	count = t.pictures.count(it != none)
	print("{files} {first}: {t.pictures.len} pictures, {count} drawn")
	_ = t.sheetOf().savePng("{out}/{name}.png")

saveTable(["KID.DAT"], 400, "kid")
saveTable(["VDUNGEON.DAT"], 200, "dungeon")
saveTable(["VDUNGEON.DAT"], 360, "dungeon-wall")
saveTable(["VPALACE.DAT"], 200, "palace")
saveTable(["VPALACE.DAT"], 360, "palace-wall")
saveTable(["GUARD.DAT", "GUARD2.DAT"], 750, "guard")
saveTable(["PRINCE.DAT"], 150, "flame-sword-potion")
saveTable(["PRINCE.DAT"], 700, "sword")
saveTable(["TITLE.DAT"], 50, "title")

tables = pop.loadTables(dir)
print("sequences {tables.sequences.len} bytes, {tables.seqStarts.len - 1} sequences, kid frames {tables.kidFrames.len}")

# the colour of a tile kind on the map
fn kindColor(kind i64):
	match kind:
		0: image.Rgba8(0, 0, 0, 255)
		1: image.Rgba8(150, 110, 60, 255)
		2: image.Rgba8(220, 220, 220, 255)
		4: image.Rgba8(60, 60, 220, 255)
		10: image.Rgba8(220, 40, 40, 255)
		11: image.Rgba8(200, 150, 40, 255)
		16, 17: image.Rgba8(40, 220, 40, 255)
		20: image.Rgba8(100, 100, 120, 255)
		_: image.Rgba8(170, 130, 90, 255)

levels = pop.loadDat(dir, "LEVELS.DAT")
level = levels.loadLevel(levelNumber)
print("level {levelNumber}: start room {level.startRoom} tile {level.startPos} dir {level.startDir}, {level.usedRooms} rooms")
# each room's place on a grid of rooms, found from the start room through the links
place {i64: (i64, i64)} = {}
place[level.startRoom] = 0, 0
queue = [level.startRoom]
while queue.pop() is room:
	x, y = place[room]
	l = level.links[room - 1]
	for (next, dx, dy) in [(l.left, -1, 0), (l.right, 1, 0), (l.up, 0, -1), (l.down, 0, 1)]:
		if next >= 1 and next <= 24 and place.get(next) == none:
			place[next] = x + dx, y + dy
			queue.push(next)
minX = 0
minY = 0
maxX = 0
maxY = 0
for _, (x, y) in place:
	minX = minX.min(x)
	minY = minY.min(y)
	maxX = maxX.max(x)
	maxY = maxY.max(y)
cell = 8
map = image.Image(
	(maxX - minX + 1) * 10 * cell,
	(maxY - minY + 1) * 3 * cell * 2,
	fill = image.Rgba8(30, 30, 30, 255)
)
for room, (rx, ry) in place:
	for t in 0..30:
		kind = i64(level.tiles[(room - 1) * 30 + t] & 0x1F)
		x0 = ((rx - minX) * 10 + t % 10) * cell
		y0 = ((ry - minY) * 3 + t / 10) * cell * 2
		for y in 1..cell * 2:
			for x in 1..cell:
				map[x0 + x, y0 + y] = kindColor(kind)
	g = level.guards[room - 1]
	if g.tile < 30:
		x0 = ((rx - minX) * 10 + g.tile % 10) * cell
		y0 = ((ry - minY) * 3 + g.tile / 10) * cell * 2
		for y in 2..8:
			for x in 2..6:
				map[x0 + x, y0 + y] = image.Rgba8(255, 0, 255, 255)
_ = map.savePng("{out}/level{levelNumber}-map.png")
