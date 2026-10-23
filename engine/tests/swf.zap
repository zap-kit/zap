# The SWF reader and the tessellator on a movie made here by hand: a red rectangle (DefineShape),
# a font of one square glyph "A" (DefineFont2), a static text and a text field in it, both placed
# on the first frame, and a bitmap of two pixels (DefineBitsLossless2); once plain (FWS) and once
# through zlib (CWS). Then the drawer's parts that need no GPU: clipping, gradients, a text
# field's HTML, Scaleform's font config.

import deflate
import engine.swf

# bits from the highest first, as SWF's bit records are written
type BitWriter:
	out u8[] = []
	acc i64 = 0
	count i64 = 0

	fn bits(v i64, n i64):
		for k in 0..n:
			acc = (acc << 1) | ((v >> (n - 1 - k)) & 1)
			count += 1
			if count == 8:
				out.push(u8(acc))
				acc = 0
				count = 0

	mut fn flush():
		if count > 0: bits(0, 8 - count)

	fn byte(v i64):
		flush()
		out.push(v & 255)

	mut fn u16(v i64):
		byte(v)
		byte(v >> 8)

	fn text(s str):
		flush()
		out.extend(s.bytes())
		out.push(0)

	mut fn rect(x0 i64, x1 i64, y0 i64, y1 i64):
		flush()
		bits(16, 5)
		for v in [x0, x1, y0, y1]:
			bits(v, 16)
		flush()

	# a matrix of a move alone
	mut fn moveMatrix(tx i64, ty i64):
		flush()
		bits(0, 2)
		bits(14, 5)
		bits(tx, 14)
		bits(ty, 14)
		flush()

	mut fn line(dx i64, dy i64):
		bits(3, 2)   # an edge, straight
		bits(13 - 2, 4)
		bits(0, 1)
		if dx != 0:
			bits(0, 1)
			bits(dx, 13)
		else:
			bits(1, 1)
			bits(dy, 13)

	# a square of side `side` from the origin, its fill on one side: a style change moving to 0, 0
	# with the fill (`which` 0 or 1) set, four lines, the end
	mut fn square(side i64, which i64):
		bits(0, 1)
		bits(0b0_0011 if which == 0 else 0b0_0101, 5)
		bits(2, 5)
		bits(0, 2)
		bits(0, 2)
		bits(1, 1)
		line(side, 0)
		line(0, side)
		line(-side, 0)
		line(0, -side)
		bits(0, 6)
		flush()

fn tag(mut out u8[], code i64, body u8[]):
	if body.len < 63:
		out.pushU16le((code << 6) | body.len)
	else:
		out.pushU16le((code << 6) | 63)
		out.pushU32le(body.len)
	out.extend(body)

fn shapeTag():
	w = BitWriter()
	w.u16(1)
	w.rect(0, 2000, 0, 1000)
	w.byte(1)   # one fill: solid red
	w.byte(0)
	w.byte(255)
	w.byte(0)
	w.byte(0)
	w.byte(0)   # no lines
	w.bits(1, 4)
	w.bits(0, 4)
	w.bits(0, 1)   # a style change: move to 0, 0 and fill 1 on the left
	w.bits(0b0_0011, 5)
	w.bits(2, 5)
	w.bits(0, 2)
	w.bits(0, 2)
	w.bits(1, 1)
	w.line(2000, 0)
	w.line(0, 1000)
	w.line(-2000, 0)
	w.line(0, -1000)
	w.bits(0, 6)
	w.flush()
	w.out

fn fontTag():
	glyph = BitWriter()
	glyph.bits(1, 4)
	glyph.bits(0, 4)
	glyph.square(512, 1)
	w = BitWriter()
	w.u16(2)
	w.byte(0x80)   # a layout
	w.byte(0)
	w.byte(1)
	w.byte('T')
	w.u16(1)
	w.u16(4)   # the glyph after the two offsets
	w.u16(4 + glyph.out.len)
	w.out.extend(glyph.out)
	w.byte('A')
	w.u16(800)
	w.u16(224)
	w.u16(0)
	w.u16(600)
	w.rect(0, 512, 0, 512)
	w.u16(0)
	w.out

fn staticTextTag():
	w = BitWriter()
	w.u16(3)
	w.rect(0, 400, 0, 400)
	w.bits(0, 7)   # the identity matrix: no scale, no turn, no move
	w.flush()
	w.byte(1)
	w.byte(12)
	w.byte(0x8F)
	w.u16(2)
	w.byte(0)
	w.byte(0)
	w.byte(255)
	w.u16(0)
	w.u16(400)
	w.u16(400)
	w.byte(1)
	w.bits(0, 1)
	w.bits(234, 12)
	w.flush()
	w.byte(0)
	w.out

fn editTextTag():
	w = BitWriter()
	w.u16(4)
	w.rect(-40, 4000, -40, 600)
	w.byte(0x85)
	w.byte(0)
	w.u16(2)
	w.u16(400)
	for c in [255, 255, 255, 255]:
		w.byte(c)
	w.text("")
	w.text("A")
	w.out

fn placeTag(depth i64, character i64, tx i64):
	w = BitWriter()
	w.byte(6)
	w.u16(depth)
	w.u16(character)
	w.moveMatrix(tx, tx)
	w.out

# two pixels, premultiplied ARGB: red at half alpha, opaque green
fn bitmapTag():
	w = BitWriter()
	w.u16(5)
	w.byte(5)
	w.u16(2)
	w.u16(1)
	w.out.extend(deflate.deflateZlib([128, 64, 0, 0, 255, 0, 255, 0]))
	w.out

fn handMade(compressed bool):
	body = BitWriter()
	body.rect(0, 12_800, 0, 9600)
	body.u16(24 << 8)
	body.u16(1)
	tags = body.out
	tag(tags, 2, shapeTag())
	tag(tags, 48, fontTag())
	tag(tags, 11, staticTextTag())
	tag(tags, 37, editTextTag())
	tag(tags, 36, bitmapTag())
	tag(tags, 26, placeTag(1, 1, 400))
	tag(tags, 26, placeTag(2, 3, 0))
	tag(tags, 1, [])
	tag(tags, 0, [])
	out = ("CWS" if compressed else "FWS").bytes().copy()
	out.push(8)
	out.pushU32le(8 + tags.len)
	out.extend(deflate.deflateZlib(tags) if compressed else tags)
	out

test "a hand-made movie: its header, shape, font, texts and first frame" for compressed in [
	false,
	true
]:
	movie = swf.readSwf(handMade(compressed)) ?? fail
	expect movie.signature == ("CWS" if compressed else "FWS")
	expect movie.stageSize() == Vec2(640.0, 480.0) and movie.frameRate == 24.0
	expect movie.problems.isEmpty and movie.unknown.isEmpty
	shape = movie.shapes.get(1) ?? fail("no shape 1")
	expect shape.edges.len == 4 and shape.edges[0].fill0 == 1 and shape.edges[0].fill1 == 0
	expect shape.fills.len == 1
	expect shape.fills[0] == .Solid(Vec4(1.0, 0.0, 0.0, 1.0))
	area = swf.fillSegments(shape, 1, 5.0).fillTriangles(false).trianglesArea()
	expect area.isClose(2_000_000.0, 1.0)
	font = movie.fonts.get(2) ?? fail("no font 2")
	expect font.name == "T" and (font.byCode.get('A') ?? -1) == 0 and
		font.glyphs[0].advance == 600.0
	glyph = font.glyphs[0].shape
	expect swf
		.fillSegments(glyph, 1, 5.0)
		.fillTriangles(true)
		.trianglesArea()
		.isClose(262_144.0, 1.0)
	text = movie.texts.get(3) ?? fail("no text 3")
	expect text.records.len == 1 and text.records[0].glyphs == [0]
	expect text.records[0].height == 400.0 and text.records[0].advances == [234.0]
	field = movie.editTexts.get(4) ?? fail("no field 4")
	expect field.text == "A" and field.font == 2 and field.height == 400.0
	bitmap = movie.bitmaps.get(5) ?? fail("no bitmap 5")
	img = bitmap.decodeBitmap([]) ?? fail
	expect img.width == 2 and img.height == 1
	expect img[0, 0] == (128, 0, 0, 128) and img[1, 0] == (0, 255, 0, 255)
	expect movie.kinds.len == 5 and (movie.kinds.get(5) ?? 0) == 36
	placed = movie.timeline.displayList(0)
	expect placed.len == 2 and placed[0].character == 1 and placed[1].character == 3
	expect placed[0].matrix.tx == 400.0 and placed[0].matrix.ty == 400.0

test "even-odd and nonzero differ where two squares overlap the same way round":
	twice = BitWriter()
	twice.bits(1, 4)
	twice.bits(0, 4)
	twice.square(100, 1)
	r = swf.newReader(twice.out, 0, twice.out.len)
	shape = r.readGlyphShape()
	doubled = shape.fillSegments(1, 1.0)
	doubled.extend(doubled)
	expect doubled.fillTriangles(true).trianglesArea().isClose(10_000.0, 0.5)
	expect doubled.fillTriangles(false).trianglesArea() < 0.5

test "a triangle cut to a rectangle keeps the part inside, its texture places carried along":
	triangle = [Vec4(0.0, 0.0, 0.0, 0.0), Vec4(10.0, 0.0, 1.0, 0.0), Vec4(0.0, 10.0, 0.0, 1.0)]
	cut = swf.clipPolygon(triangle, swf.Rect(xmin = 0.0, ymin = 0.0, xmax = 5.0, ymax = 5.0))
	expect cut.len == 5
	points = []
	for k in 2..cut.len:
		points.extend([cut[0].xy, cut[k - 1].xy, cut[k].xy])
	expect points.trianglesArea().isClose(25.0, 0.001)
	for c in cut:
		expect c.z.isClose(c.x / 10.0, 0.0001) and c.w.isClose(c.y / 10.0, 0.0001)

test "a linear gradient's image runs from its first stop to its last":
	g = swf.Gradient(radial = false, matrix = swf.Affine(), stops = [
		swf.GradientStop(ratio = 0.0, color = Vec4(1.0, 0.0, 0.0, 1.0)),
		swf.GradientStop(ratio = 1.0, color = Vec4(0.0, 0.0, 1.0, 1.0))
	], spread = 0, linearRgb = false, focal = 0.0)
	img = g.gradientImage()
	expect img.width == 256 and img[0, 0] == (255, 0, 0, 255) and img[255, 0] == (0, 0, 255, 255)
	expect img[128, 0].r > 100 and img[128, 0].b > 100

test "a field's HTML gives its style and lines":
	field = swf.EditText(id = 1, bounds = swf.Rect(), font = 7, fontClass = "", height = 240.0,
		color = Vec4(1.0, 1.0, 1.0, 1.0), align = 0, leftMargin = 0.0, rightMargin = 0.0,
		indent = 0.0, leading = 0.0, variable = "",
		text = "<p align=\"center\"><font face=\"$EverywhereMediumFont\" size=\"24\" color=\"#FF0000\">N &amp; S</font></p><p>two</p>",
		html = true, wordWrap = false, multiline = true, border = false, autoSize = false)
	style, lines = field.fieldText(field.text, field.html)
	expect style.align == 2 and style.face == "$EverywhereMediumFont" and style.size == 480.0
	expect style.color == Vec4(1.0, 0.0, 0.0, 1.0)
	expect lines.map(.text()) == ["N & S", "two"]

test "Scaleform's font config: its libraries and its faces mapped to fonts":
	text = """
		fontlib "Interface/fonts_en.swf"
		map "$EverywhereBoldFont" = "Futura Condensed" Bold
		map "$DragonFont" = "Dragon_script" Normal
		"""
	config = swf.readFontConfig(text)
	expect config.libraries == ["Interface/fonts_en.swf"]
	bold = config.map.get("$EverywhereBoldFont") ?? fail("no bold face")
	expect bold.name == "Futura Condensed" and bold.bold
	expect not (config.map.get("$DragonFont") ?? fail("no dragon face")).bold
