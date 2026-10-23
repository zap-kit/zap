# The game's own mouse cursor, as the client draws it: the install's cursors sprite
# (data\sprite\cursors.spr and .act) composited frame by frame when the game is prepared, each
# action placed and timed as roBrowser's cursor manager places it, and drawn last, sharp, at the
# mouse every frame. Its states: the arrow; the turning arrows while the camera is dragged (at
# where the drag began); the "no" sign over ground the hero cannot walk on. Over a walkable
# cell the client marks the cell itself: its grid selector (data\texture\grid.tga tinted green,
# as roBrowser tints it) lies on the cell under the mouse. Without the sprite, a drawn arrow.

import engine
import ragnarok
import world
import game.shaders
import image
import ragnarok.gat

pub cursorArrow = 0
pub cursorTurn = 4
pub cursorNo = 8

pub type CursorAction:
	cells i64[]   # its frames' cells in the atlas
	delay f32   # milliseconds a frame
	hotX i64   # the point of the cursor in its cell
	hotY i64

pub type CursorHead:
	cellSize i64
	columns i64
	atlas world.PreparedTexture
	actions CursorAction[]
	grid world.PreparedTexture   # the cell marker

pub type Cursors:
	head CursorHead
	atlas engine.GpuTexture
	grid engine.GpuTexture
	program engine.Program
	marker engine.Model

# a cursor frame's canvas, and where the sprite's origin is on it
cellSize = 96
originX = 48
originY = 64

# roBrowser's placing of the actions it knows: (action, drawX, drawY, startX, startY, delay
# multiplier); the cursor's point is (start - draw) from the sprite's origin
known = [
	(0, 1, 19, 0, 0, 2.0),
	(1, 20, 40, 20, 20, 1.0),
	(7, 10, 32, 0, 0, 1.0),
	(4, 18, 26, 10, 0, 1.0),
	(9, 20, 40, 15, 15, 1.0),
	(10, 20, 50, 20, 28, 0.5)
]

fn cursorsPath():
	"{world.preparedDir}/cursors.figure"

# the middle of the opaque pixels of an image (its centre when there are none)
fn middleOf(img image.Image):
	x0 = img.width
	y0 = img.height
	x1 = -1
	y1 = -1
	for y in 0..img.height:
		for x in 0..img.width:
			if img[x, y].a > 0:
				x0 = x0.min(x)
				y0 = y0.min(y)
				x1 = x1.max(x)
				y1 = y1.max(y)
	(img.width / 2, img.height / 2) if x1 < 0 else ((x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2)

# a plain arrow, for an install without the cursors sprite: white, outlined, its point at (0, 0)
fn drawnArrow():
	arrow = image.Image(cellSize, cellSize, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..17:
		for x in 0..12:
			inside = x <= y * 2 / 3 and y - x / 3 < 17
			edge = inside and (x == 0 or x == y * 2 / 3 or y - x / 3 == 16)
			if inside:
				v = u8(0 if edge else 255)
				arrow[x, y] = image.Rgba8(v, v, v, 255)
	arrow

# the cell marker: grid.tga at 0.6 alpha, its color made (50, 240, 160) as roBrowser makes it;
# a green outline without it
fn gridMarker(i ragnarok.Install):
	img = image.fromBytes(0, 0, [])
	if i.installReadPath("data/texture/grid.tga") is bytes:
		if ragnarok.decodeTga(bytes) is g:
			img = g
	if img.cells.isEmpty:
		img = image.Image(32, 32, fill = image.Rgba8(0, 0, 0, 0))
		for y in 0..img.height:
			for x in 0..img.width:
				if x < 2 or y < 2 or x > 29 or y > 29:
					img[x, y].a = 255
	for k in 0..img.cells.len:
		a = i64(img.cells[k].a) * 6 / 10
		img.cells[k] = image.Rgba8(50, 240, 160, a)
	img

# The cursors and the cell marker composited from the install and written to their prepared file.
pub fn prepareCursors(i ragnarok.Install):
	images = []
	actions = []
	match i.loadSprite("cursors", ragnarok.kindMonster):
		s:
			fig = ragnarok.Figure(sprites = [s], imf = none, player = false)
			delays = fig.sprites[0].act.delays
			count = fig.sprites[0].act.actions.len
			for a in 0..count:
				frames = fig.renderAction(a, cellSize, originX, originY)
				hot = frames[0].middleOf() if not frames.isEmpty else (originX, originY)
				cells = []
				for img in frames:
					cells.push(images.len)
					images.push(img)
				delay = delays[a] if a < delays.len else 100.0
				for (k, drawX, drawY, startX, startY, mult) in known:
					if k == a:
						hot = originX + startX - drawX, originY + startY - drawY
						delay *= f32(mult)
				hotX, hotY = hot
				actions.push(CursorAction(cells, delay, hotX, hotY))
		none:
			images.push(drawnArrow())
			actions.push(CursorAction(cells = [0], delay = 100.0, hotX = 0, hotY = 0))
	columns = 16
	body = []
	atlas = world.appendTexture(body, atlasOf(images, cellSize, columns), false)
	grid = world.appendTexture(body, i.gridMarker(), false)
	head = CursorHead(cellSize = cellSize, columns, atlas, actions, grid)
	world.writePrepared(cursorsPath(), head.toBytes(), body) ??
		fail("cannot write {cursorsPath()}: {error}")

# the cursors read from their prepared file and sent to the GPU, none when the file is missing
# or of another version
pub fn openCursors() Cursors?:
	file = try world.readPrepared(cursorsPath())
	head = try CursorHead.fromBytes(file.headOf().copy())
	sharp = engine.Sampling(
		smooth = false,
		mipmaps = false,
		repeat = false,
		mirror = 0,
		anisotropy = false
	)
	atlas = world.imageAt(file.bodyOf(), head.atlas).newTexture(sharp)
	grid = engine.newTexture(
		world.imageAt(file.bodyOf(), head.grid),
		engine.Sampling(
			smooth = true,
			mipmaps = false,
			repeat = false,
			mirror = 0,
			anisotropy = false
		)
	)
	Cursors(
		head,
		atlas,
		grid,
		program = engine.newProgram(shader(shaders.markerVertex, shaders.markerPixel)),
		marker = engine.newDynamicModel()
	)

# The cursor of state `action` (cursorArrow ...) `ms` into it, its point at (x, y) of the screen:
# on whole pixels, over everything.
pub fn drawCursor(mut r engine.Renderer, c Cursors, action i64, ms i64, x i64, y i64):
	h = c.head
	a = h.actions[action.clamp(0, len - 1)]
	if a.cells.isEmpty: return
	cell = a.cells[i64((f32(ms) / a.delay.max(1.0)).floor()) % len]
	tw = f32(c.atlas.width)
	th = f32(c.atlas.height)
	size = f32(h.cellSize)
	u0 = f32(cell % h.columns) * size / tw
	v0 = f32(cell / h.columns) * size / th
	engine.drawQuad(
		r,
		c.atlas.texture(),
		f32(x - a.hotX),
		f32(y - a.hotY),
		size,
		size,
		u0,
		v0,
		u0 + size / tw,
		v0 + size / th
	)

# The cell marker lying on the GAT cell (cx, cy), blended over the ground.
pub fn drawCellMarker(
	mut r engine.Renderer,
	mut c Cursors,
	gat gat.Gat,
	cx i64,
	cy i64,
	projection Mat4,
	view Mat4
):
	if not gat.inside(cx, cy): return
	heights = gat.cells[cx, cy].heights
	# just above the ground, so it is not lost in it
	corner = (dx i64, dy i64, c i64): Vec3(
		f32(cx + dx),
		-heights[c] * 0.2 + 0.03,
		-f32(cy + dy)
	)
	sw = shaders.MarkerVertex(position = corner(0, 0, 0), uv = Vec2(0.0, 1.0))
	se = shaders.MarkerVertex(position = corner(1, 0, 1), uv = Vec2(1.0, 1.0))
	nw = shaders.MarkerVertex(position = corner(0, 1, 2), uv = Vec2(0.0, 0.0))
	ne = shaders.MarkerVertex(position = corner(1, 1, 3), uv = Vec2(1.0, 0.0))
	c.marker.fillModel([sw, se, ne, sw, ne, nw])
	c.program.setParams(shaders.MarkerParams(projection, view, picture = c.grid.texture()))
	r.setBlending(true)
	r.setDepth(true, false, false)
	r.drawModel(c.program, c.marker)
	r.setDepth(true, true, false)
