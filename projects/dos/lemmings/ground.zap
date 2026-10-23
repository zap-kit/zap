# A graphics set: groundXo.dat (uncompressed, 1056 bytes: 16 objects of 28 bytes, 64 terrain
# pieces of 8, then the palettes) and vgagrX.dat (two .DAT sections: the terrain pieces' bitmaps,
# then the objects'), as ccexplore's document describes them.

import dos
import fs
import image

# an interactive object of a set: an entrance, an exit, a trap, water, a one-way wall...
pub type ObjectKind:
	triggered bool   # animates only when a lemming sets it off; else loops
	startFrame i64
	frames i64
	width i64
	height i64
	frameBytes i64
	maskOffset i64
	triggerLeft i64   # the trigger area relative to the object's corner (rounded down to 4)
	triggerTop i64
	triggerWidth i64
	triggerHeight i64
	effect i64   # 0 none, 1 exit, 4 trap, 5 drown, 6 vaporize, 7 one-way left, 8 one-way right
	framesAt i64
	previewFrame i64
	sound i64
	sheet image.Image   # the frames one under another

pub type TerrainPiece:
	width i64
	height i64
	picture image.Image

pub type GraphicsSet:
	objects ObjectKind[]
	pieces TerrainPiece[]
	palette dos.Palette
	special image.Image?   # a special set's whole terrain (960 x 160), in place of pieces

fn word(bytes u8[], at i64):
	bytes[at] | i64(bytes[at + 1]) << 8

# the fixed lower half of every level's palette (groundXo.dat's standard entries are not used)
fn fixedColors():
	[
		dos.vgaColor(0, 0, 0),
		dos.vgaColor(16, 16, 56),
		dos.vgaColor(0, 44, 0),
		dos.vgaColor(60, 52, 52),
		dos.vgaColor(44, 44, 0), dos.vgaColor(60, 8, 8), dos.vgaColor(
			32,
			32,
			32
		), dos.vgaColor(0, 0, 0)]

# the level palette: the fixed colours, the set's eight, and colour 7 (bricks, the minimap) the
# set's first
pub fn levelPalette(custom image.Rgba8[]) dos.Palette:
	colors image.Rgba8[16]
	for i, c in fixedColors():
		colors[i] = c
	for i, c in custom:
		colors[8 + i] = c
	colors[7] = colors[8]
	dos.Palette(colors)

# eight VGA entries of 3 bytes at `at`
pub fn vgaEntries(bytes u8[], at i64) image.Rgba8[]:
	(0..8).map(dos.vgaColor(bytes[at + it * 3], bytes[at + it * 3 + 1], bytes[at + it * 3 + 2]))

# the one-way arrows are drawn in the palette's colour 5 whatever their bitmap's index
oneWayLeftEffect = 7
oneWayRightEffect = 8
oneWayColor = 5

# every visible pixel of the picture in one colour
fn recolor(mut img image.Image, c image.Rgba8):
	for y in 0..img.height:
		for x in 0..img.width:
			if img[x, y].a != 0:
				img[x, y] = c

fn objectKind(g u8[], at i64, objects u8[], pal dos.Palette):
	frames = i64(g[at + 3])
	width = i64(g[at + 4])
	height = i64(g[at + 5])
	frameBytes = word(g, at + 6)
	maskOffset = word(g, at + 8)
	framesAt = word(g, at + 21)
	sheet = image.Image(width.max(1), (height * frames).max(1), fill = image.Rgba8(0, 0, 0, 0))
	for f in 0..frames:
		frameAt = framesAt + f * frameBytes
		indices = dos.planarIndices(objects, frameAt, width, height, 4)
		mask = dos.planarMask(objects, frameAt + maskOffset, width, height)
		sheet.paste(dos.paint(indices, mask, width, height, pal), 0, f * height)
	if g[at + 20] == oneWayLeftEffect or g[at + 20] == oneWayRightEffect:
		sheet.recolor(pal.colors[oneWayColor])
	ObjectKind(
		triggered = g[at] & 1 != 0,
		startFrame = g[at + 2],
		frames,
		width,
		height,
		frameBytes,
		maskOffset,
		triggerLeft = word(g, at + 14) * 4,
		triggerTop = word(g, at + 16) * 4 - 4,
		triggerWidth = i64(g[at + 18]) * 4,
		triggerHeight = i64(g[at + 19]) * 4,
		effect = g[at + 20],
		framesAt,
		previewFrame = (word(g, at + 23) - framesAt) / frameBytes.max(1),
		sound = g[at + 27],
		sheet
	)

fn terrainPiece(g u8[], at i64, terrain u8[], pal dos.Palette):
	width = i64(g[at])
	height = i64(g[at + 1])
	indices = dos.planarIndices(terrain, word(g, at + 2), width, height, 4)
	mask = dos.planarMask(terrain, word(g, at + 4), width, height)
	TerrainPiece(width, height, picture = dos.paint(indices, mask, width, height, pal))

# the set `id` of the install dir; a special level's whole picture from vgaspec<special - 1>.dat
pub fn loadGraphicsSet(dir str, id i64, special i64) GraphicsSet:
	g = fs.readBytes("{dir}/ground{id}o.dat") ?? fail("cannot read ground{id}o.dat: {error}")
	sections = sectionsOf(
		fs.readBytes("{dir}/vgagr{id}.dat") ?? fail("cannot read vgagr{id}.dat: {error}")
	)
	if sections.len != 2: fail("vgagr{id}.dat has {sections.len} sections, not 2")
	custom = vgaEntries(g, 984)
	specialPicture image.Image? = none
	if special > 0:
		specialPicture, custom = loadSpecial("{dir}/vgaspec{special - 1}.dat")
	pal = levelPalette(custom)
	objects = []
	for i in 0..16:
		if g[i * 28 + 4] == 0: break
		objects.push(objectKind(g, i * 28, sections[1].bytes, pal))
	pieces = []
	if special == 0:
		for i in 0..64:
			if g[448 + i * 8] == 0: break
			pieces.push(terrainPiece(g, 448 + i * 8, sections[0].bytes, pal))
	GraphicsSet(objects, pieces, palette = pal, special = specialPicture)

# the object kinds every set has first
pub exitKind = 0
pub entranceKind = 1
