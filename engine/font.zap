# Text: a font of the system (any installed face, or one of a .ttf file the program adds)
# drawn once into an atlas texture, the
# printable ASCII characters in a grid, each with its own advance; a string is then a run of
# quads of that texture.

import image

# a face drawn into an atlas
pub type Font:
	atlas GpuTexture
	cellW i64   # the grid's cell, in atlas pixels
	cellH i64
	advances i64[]   # the width each character moves the pen, from ' ' to '~'
	lineHeight i64

# a bitmap of 32-bit pixels; a negative height lays its rows from the top
extern type BitmapInfoHeader:
	size u32 = 40
	width i32
	height i32
	planes u16 = 1
	bitCount u16 = 32
	compression u32 = 0
	sizeImage u32 = 0
	xPerMeter i32 = 0
	yPerMeter i32 = 0
	colorsUsed u32 = 0
	colorsImportant u32 = 0

extern "gdi32.dll" fn CreateCompatibleDC(dc i64) i64
extern "gdi32.dll" fn AddFontResourceExA(path str, flags i64, reserved i64) i64
extern "gdi32.dll" fn DeleteDC(dc i64) bool
extern "gdi32.dll" fn CreateDIBSection(
	dc i64,
	info BitmapInfoHeader,
	usage i64,
	out bits i64,
	section i64,
	offset i64
) i64
extern "gdi32.dll" fn SelectObject(dc i64, object i64) i64
extern "gdi32.dll" fn DeleteObject(object i64) bool
extern "gdi32.dll" fn CreateFontA(
	height i64,
	width i64,
	escapement i64,
	orientation i64,
	weight i64,
	italic i64,
	underline i64,
	strike i64,
	charset i64,
	outPrecision i64,
	clipPrecision i64,
	quality i64,
	pitch i64,
	face str
) i64
extern "gdi32.dll" fn SetTextColor(dc i64, color i64) i64
extern "gdi32.dll" fn SetBkColor(dc i64, color i64) i64
extern "gdi32.dll" fn TextOutA(dc i64, x i64, y i64, text str, n i64) bool
extern "gdi32.dll" fn GetCharWidth32A(dc i64, first i64, last i64, widths i32[]) bool
extern "gdi32.dll" fn GetDIBits(
	dc i64,
	bitmap i64,
	start i64,
	lines i64,
	bits u8[],
	mut info BitmapInfoHeader,
	usage i64
) i32
extern "gdi32.dll" fn GdiFlush() bool

firstChar = 32
lastChar = 126
atlasColumns = 16

# the faces of a font file (.ttf, .otf) made known to this program alone, for loadFont by their
# names; false when the file cannot be read as a font
pub fn addFontFile(path str) bool:
	AddFontResourceExA("{path}\0", 16, 0) > 0   # FR_PRIVATE

# The face (such as "Segoe UI" or "Consolas") at `pixels` pixels high and of `weight` (400
# regular, 700 bold), as a font to draw with. Needs the window's GPU (the atlas is a
# texture).
pub fn loadFont(face str, pixels i64, weight i64 = 400) Font:
	count = lastChar - firstChar + 1
	rows = (count + atlasColumns - 1) / atlasColumns
	dc = CreateCompatibleDC(0)
	font = CreateFontA(-pixels, 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 4, 0, "{face}\0")   # antialiased
	oldFont = SelectObject(dc, font)
	widths i32[] = zeros(count)
	GetCharWidth32A(dc, firstChar, lastChar, widths)
	cellW = 1
	for w in widths:
		cellW = cellW.max(i64(w))
	cellW += 2   # room for what antialiasing spills
	cellH = pixels + pixels / 3 + 2
	aw = cellW * atlasColumns
	ah = cellH * rows
	info = BitmapInfoHeader(width = i32(aw), height = i32(-ah))
	bitmap = CreateDIBSection(dc, info, 0, out _, 0, 0)
	oldBitmap = SelectObject(dc, bitmap)
	SetTextColor(dc, 0xFF_FFFF)
	SetBkColor(dc, 0)
	for i in 0..count:
		ch = str.fromCode(firstChar + i)
		TextOutA(dc, (i % atlasColumns) * cellW + 1, (i / atlasColumns) * cellH + 1, ch, 1)
	GdiFlush()
	SelectObject(dc, oldBitmap)   # GetDIBits wants the bitmap out of the DC
	bgra u8[] = zeros(aw * ah * 4)
	GetDIBits(dc, bitmap, 0, ah, bgra, info, 0)
	SelectObject(dc, oldFont)
	DeleteObject(font)
	DeleteObject(bitmap)
	DeleteDC(dc)
	# white everywhere, the glyph's coverage as alpha
	glyphs = image.Image(aw, ah, fill = image.Rgba8(255, 255, 255, 255))
	for y in 0..glyphs.height:
		for x in 0..glyphs.width:
			glyphs[x, y].a = bgra[(y * aw + x) * 4 + 1]
	Font(
		atlas = glyphs.newTexture(),
		cellW,
		cellH,
		advances = widths.map(i64(it)),
		lineHeight = pixels + pixels / 4
	)

# draws the text with its top-left corner at x, y; a line break starts a new line
pub fn drawText(mut r Renderer, f Font, text str, x f32, y f32, c Vec4):
	# on whole pixels: the atlas is sampled sharp, and a glyph between pixels loses columns
	penX = x.round()
	penY = y.round()
	for i in 0..text.len:
		code = i64(text[i])
		if code == 10:
			penX = x.round()
			penY += f32(f.lineHeight)
			continue
		if code < firstChar or code > lastChar: continue
		k = code - firstChar
		reg = Region(
			f.atlas.texture(),
			(k % atlasColumns) * f.cellW,
			(k / atlasColumns) * f.cellH,
			f.cellW,
			f.cellH
		)
		r.drawRegion(reg, penX - 1.0, penY - 1.0, f32(f.cellW), f32(f.cellH), c)
		penX += f32(f.advances[k])

# the width of the text's longest line, in pixels
pub fn textWidth(f Font, text str) i64:
	widest = 0
	line = 0
	for i in 0..text.len:
		code = i64(text[i])
		if code == 10:
			widest = widest.max(line)
			line = 0
		elif code >= firstChar and code <= lastChar:
			line += f.advances[code - firstChar]
	widest.max(line)

# draws the text with the middle of its top edge at cx, y (a title, a name over a figure)
pub fn drawTextCentered(mut r Renderer, f Font, text str, cx f32, y f32, c Vec4):
	r.drawText(f, text, cx - f32(f.textWidth(text)) / 2.0, y, c)

# A line of information on a dark box (a corner's frame rate and place): the box's top-left
# corner at x, y, `height` tall and 6 pixels wider than the text on each side, the text 4 pixels
# below its top.
pub fn drawLabel(
	mut r Renderer,
	f Font,
	text str,
	x f32 = 6.0,
	y f32 = 6.0,
	height f32 = 26.0,
	c Vec4 = white,
	background Vec4 = Vec4(0.0, 0.0, 0.0, 0.55)
):
	r.fillRect(x, y, f32(f.textWidth(text)) + 12.0, height, background)
	r.drawText(f, text, x + 6.0, y + 4.0, c)
