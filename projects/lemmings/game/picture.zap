# The level as the DOS game draws it, composed on the CPU: the objects behind the terrain, the
# terrain, the objects drawn only on terrain, the objects in front, the lemmings and the bombers'
# countdowns. The window shows this picture; the oracle's comparison reads it pixel by pixel.

import dos.lemmings
import image

# a frame of a sheet (frames one under another, `h` rows each) put at (x, y) of the picture whose
# left edge is the world's column `left`; transparent pixels leave what is under them
fn blitFrame(
	mut img image.Image,
	sheet image.Image,
	frame i64,
	h i64,
	x i64,
	y i64,
	upsideDown bool
):
	for sy in 0..h:
		ty = y + (h - 1 - sy if upsideDown else sy)
		if ty < 0 or ty >= img.height: continue
		for sx in 0..sheet.width:
			tx = x + sx
			if tx < 0 or tx >= img.width: continue
			p = sheet[sx, frame * h + sy]
			if p.a != 0:
				img[tx, ty] = p

fn blitObject(mut img image.Image, g Game, o PlacedState, left i64):
	k = g.set.objects[o.kind]
	img.blitFrame(
		k.sheet,
		o.frame.clamp(0, k.frames - 1),
		k.height,
		o.placed.x - left,
		o.placed.y,
		o.placed.upsideDown
	)

fn blitObjects(mut img image.Image, g Game, left i64, behind bool):
	for e in g.entrances:
		if e.placed.noOverwrite == behind and not e.placed.onlyOnTerrain:
			img.blitObject(g, e, left)
	for o in g.objects:
		if o.placed.noOverwrite == behind and not o.placed.onlyOnTerrain:
			img.blitObject(g, o, left)

# the objects drawn only where the terrain has a pixel, at their animation's frame
fn blitOnTerrainObjects(mut img image.Image, g Game, left i64):
	for o in g.objects:
		if not o.placed.onlyOnTerrain: continue
		k = g.set.objects[o.kind]
		frame = o.frame.clamp(0, k.frames - 1)
		for sy in 0..k.height:
			ty = o.placed.y + (k.height - 1 - sy if o.placed.upsideDown else sy)
			if ty < 0 or ty >= img.height: continue
			for sx in 0..k.sheet.width:
				wx = o.placed.x + sx
				x = wx - left
				if x < 0 or x >= img.width or not g.world.hasPixelAt(wx, ty): continue
				p = k.sheet[sx, frame * k.height + sy]
				if p.a != 0:
					img[x, ty] = p

# the world's layer (terrain or what is drawn on it) from column `left` where it has pixels
fn blitLayer(mut img image.Image, layer image.Image, left i64):
	for y in 0..img.height.min(layer.height):
		for x in 0..img.width:
			wx = left + x
			if wx < 0 or wx >= layer.width: continue
			p = layer[wx, y]
			if p.a != 0:
				img[x, y] = p

fn blitLemmings(mut img image.Image, g Game, main lemmings.MainData, left i64):
	for i, l in g.lemmings:
		img.blitParticles(g, left, i)
		if l.removed: continue
		a = main.animations[l.animationIndex()]
		img.blitFrame(
			g.lemmingSheets[l.animationIndex()],
			l.frame.clamp(0, a.frames - 1),
			a.height,
			l.x + l.action.frameLeftDx() - left,
			l.y + l.action.frameTopDy(),
			false
		)
		if l.explosionTimer > 0:
			digit = l.countdownDigit()
			img.blitFrame(
				main.countdown[digit],
				0,
				8,
				l.x - left,
				l.y + l.action.frameTopDy() - 8,
				false
			)

# the iterations after the crater that the first particle frame is drawn on, and the particles'
# origin from the lemming's foot (the oracle)
particleDelay = 0
particleDx = 0
particleDy = 0

# the particles of the explosions still scattering
fn blitParticles(mut img image.Image, g Game, left i64, lemming i64):
	for e in g.explosions:
		if e.lemming != lemming: continue
		frame = g.iteration - e.iteration - particleDelay
		if frame < 0 or frame >= lemmings.particleFrames: continue
		for i in 0..lemmings.particlesPerFrame:
			dx, dy = lemmings.particleAt(frame, i) ?? continue
			x = e.x + 8 + particleDx + dx - left
			y = e.y + 14 + particleDy + dy
			if x >= 0 and x < img.width and y >= 0 and y < img.height:
				img[x, y] = g.set.palette.colors[lemmings.particleColors[i % 16]]

# the digit over a bomber: 5 down to 1 as its countdown runs
pub fn countdownDigit(l Lemming) i64:
	(l.explosionTimer / 16 + 1).clamp(1, 5)

# the view of `width` columns from the world's column `left`, the level's 160 rows
pub fn drawView(g Game, main lemmings.MainData, left i64, width i64) image.Image:
	img = image.Image(width, worldHeight, fill = image.Rgba8(0, 0, 0, 255))
	img.blitObjects(g, left, true)
	img.blitLayer(g.world.picture, left)
	img.blitOnTerrainObjects(g, left)
	for p in g.world.lingering:
		if p.x >= left and p.x < left + width:
			img[p.x - left, p.y] = p.color
	img.blitObjects(g, left, false)
	img.blitLemmings(g, main, left)
	img
