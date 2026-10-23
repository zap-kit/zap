# Fonts and text (SWF specification v19, chapters 10 and 11): DefineFont2 and 3 (glyph shapes,
# the code table, the layout: ascent, descent, leading, advances and kerning; DefineFont3's
# coordinates are 20 times finer, an em of 20480), DefineFontName, DefineText 1 and 2 (records of
# glyphs in a font, a color, a place and a height) and DefineEditText (a dynamic field: its
# bounds, font, size, color, alignment, margins, variable name and initial text).

# a font's glyph: its code, its shape in em units and its advance
pub type Glyph:
	code i64
	shape Shape   # in em units
	advance f32

# DefineFont2 or 3
pub type Font:
	id i64
	name str
	bold bool
	italic bool
	em f32   # the units of an em: 1024, or 20480 for DefineFont3
	glyphs Glyph[]
	byCode {i64: i64}   # a character's code to its glyph
	ascent f32
	descent f32
	leading f32
	kerning {i64: f32}   # code1 << 16 | code2 to the adjustment, in em units

# a run of a static text's glyphs in one font, color and size
pub type TextRecord:
	font i64
	color Vec4
	x f32   # twips, the first glyph's origin
	y f32
	height f32   # twips
	glyphs i64[]
	advances f32[]   # twips

# DefineText or DefineText2
pub type StaticText:
	id i64
	bounds Rect
	matrix Affine
	records TextRecord[]

# DefineEditText: a text field
pub type EditText:
	id i64
	bounds Rect
	font i64   # -1: none
	fontClass str
	height f32   # twips
	color Vec4
	align i64   # 0 left, 1 right, 2 center, 3 justify
	leftMargin f32
	rightMargin f32
	indent f32
	leading f32
	variable str
	text str
	html bool
	wordWrap bool
	multiline bool
	border bool
	autoSize bool

# DefineFont2 (tag 48) or DefineFont3 (75)
pub fn readFont(mut r TagReader, version i64) Font:
	id = r.u16()
	flags = r.u8()
	r.u8()   # the language
	name = fontName(r.bytes(r.u8()))
	n = r.u16()
	wideOffsets = (flags & 8) != 0
	wideCodes = (flags & 4) != 0
	f = Font(id, name, bold = (flags & 1) != 0, italic = (flags & 2) != 0,
		em = 20480.0 if version == 3 else 1024.0, glyphs = [], byCode = {}, ascent = 0.0,
		descent = 0.0, leading = 0.0, kerning = {})
	table = r.at
	offsets = []
	loop n:
		offsets.push(r.u32() if wideOffsets else r.u16())
	layoutBytes = 8 if (flags & 0x80) != 0 else 0
	if n > 0 or r.remaining() >= layoutBytes + (4 if wideOffsets else 2):
		offsets.push(r.u32() if wideOffsets else r.u16())   # the code table's
	for k in 0..n:
		r.at = table + offsets[k]
		f.glyphs.push(Glyph(code = 0, shape = r.readGlyphShape(), advance = 0.0))
	if n > 0: r.at = table + offsets[n]
	r.align()
	for k in 0..n:
		code = r.u16() if wideCodes else r.u8()
		f.glyphs[k].code = code
		f.byCode[code] = k
	if (flags & 0x80) == 0: return f
	f.ascent = f32(r.u16())
	f.descent = f32(r.u16())
	f.leading = f32(r.i16())
	for k in 0..n:
		f.glyphs[k].advance = f32(r.i16())
	loop n:
		r.rect()
	loop r.u16():
		a = r.u16() if wideCodes else r.u8()
		b = r.u16() if wideCodes else r.u8()
		f.kerning[(a << 16) | b] = f32(r.i16())
	f

# a name as fonts store it, without the NUL some end with
fn fontName(bytes u8[]):
	end = bytes.len
	while end > 0 and bytes[end - 1] == 0:
		end -= 1
	str(bytes[..end].copy())

# DefineFontName (tag 88): the font's id and its full name (the copyright after it is left)
pub fn readFontName(mut r TagReader) (i64, str):
	id = r.u16()
	(id, r.text())

# DefineText (tag 11) or DefineText2 (33), the version 1 or 2
pub fn readText(mut r TagReader, version i64) StaticText:
	t = StaticText(id = r.u16(), bounds = r.rect(), matrix = r.matrix(), records = [])
	glyphBits = r.u8()
	advanceBits = r.u8()
	font = -1
	color = Vec4(0.0, 0.0, 0.0, 1.0)
	x = 0.0
	y = 0.0
	height = 0.0
	while not r.short:
		flags = r.u8()
		if flags == 0: break
		if (flags & 8) != 0: font = r.u16()
		if (flags & 4) != 0: color = r.rgba() if version == 2 else r.rgb()
		if (flags & 1) != 0: x = f32(r.i16())
		if (flags & 2) != 0: y = f32(r.i16())
		if (flags & 8) != 0: height = f32(r.u16())
		count = r.u8()
		rec = TextRecord(font, color, x, y, height, glyphs = [], advances = [])
		loop count:
			rec.glyphs.push(r.ub(glyphBits))
			advance = f32(r.sb(advanceBits))
			rec.advances.push(advance)
			x += advance
		r.align()
		t.records.push(rec)
	t

# DefineEditText (tag 37)
pub fn readEditText(mut r TagReader) EditText:
	id = r.u16()
	bounds = r.rect()
	flags = r.u8()
	flags2 = r.u8()
	t = EditText(id, bounds, font = -1, fontClass = "", height = 240.0,
		color = Vec4(0.0, 0.0, 0.0, 1.0), align = 0, leftMargin = 0.0, rightMargin = 0.0,
		indent = 0.0, leading = 0.0, variable = "", text = "", html = (flags2 & 2) != 0,
		wordWrap = (flags & 0x40) != 0, multiline = (flags & 0x20) != 0,
		border = (flags2 & 8) != 0, autoSize = (flags2 & 0x40) != 0)
	if (flags & 1) != 0: t.font = r.u16()
	if (flags2 & 0x80) != 0: t.fontClass = r.text()
	if (flags & 1) != 0 or (flags2 & 0x80) != 0: t.height = f32(r.u16())
	if (flags & 4) != 0: t.color = r.rgba()
	if (flags & 2) != 0: r.u16()   # the maximum length
	if (flags2 & 0x20) != 0:
		t.align = r.u8()
		t.leftMargin = f32(r.u16())
		t.rightMargin = f32(r.u16())
		t.indent = f32(r.u16())
		t.leading = f32(r.i16())
	t.variable = r.text()
	if (flags & 0x80) != 0: t.text = r.text()
	t
