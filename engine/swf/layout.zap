# A text field's text laid out in its fonts: the HTML Scaleform's fields hold read into lines of
# runs, each run in the style its tags give (the paragraph's alignment; the font's face, size,
# color and letterSpacing, a <font> tag's lasting to its end), tags dropped, entities decoded, a
# paragraph's end, a <br> or a line's end in the text a new line; then each line's glyphs placed
# along one baseline by each run's font's advances and kerning, the letter spacing after each
# glyph, aligned in the field's bounds inside Flash's gutter of 2 pixels.

# the style a field's text is drawn in
pub type TextStyle:
	face str   # "" the field's own font
	size f32   # twips
	color Vec4
	align i64   # 0 left, 1 right, 2 center, 3 justify
	spacing f32 = 0.0   # letterSpacing: twips after each glyph

# What a script's setTextFormat set over a field's runs: the properties it gave, none for those it
# left as each run has them.
pub type TextOverride:
	face str? = none
	size f32? = none
	color Vec4? = none
	align i64? = none
	spacing f32? = none

# the override that sets every property to the style's
pub fn overrideOf(style TextStyle) TextOverride:
	TextOverride(face = style.face.copy(), size = style.size, color = style.color,
		align = style.align, spacing = style.spacing)

# the style with what the override sets
pub fn overridden(style TextStyle, o TextOverride) TextStyle:
	TextStyle(face = (o.face ?? style.face).copy(), size = o.size ?? style.size,
		color = o.color ?? style.color, align = o.align ?? style.align,
		spacing = o.spacing ?? style.spacing)

# a stretch of a line's text in one style, or an image (Scaleform's <img src>: a bitmap the movie
# exports under that name, its size the tag's or its own, lowered by vspace)
pub type TextRun:
	text str
	style TextStyle
	image str = ""
	size Vec2 = Vec2(0.0, 0.0)   # the image's width and height in pixels, 0 for its own
	vspace f32 = 0.0

pub type TextLine:
	runs TextRun[]

gutter f32 = 40.0

# the line's text, its runs' together
pub fn text(l TextLine) str:
	l.runs.map(.text).join("")

# The field's style (its first run's, else its own) and lines for the text it shows: HTML read
# when it is, else the text as it is in the field's style.
pub fn fieldText(t EditText, shown str, html bool) (TextStyle, TextLine[]):
	base = TextStyle(face = "", size = t.height, color = t.color, align = t.align)
	if not html:
		plain = shown.replace("\r\n", "\n").replace("\r", "\n").lines()
		return (base, plain.map(TextLine(runs = [TextRun(text = .copy(), style = base.copy())])))
	r = HtmlReader(styles = [base.copy()])
	text = shown.bytes()
	at = 0
	while at < text.len:
		c = text[at]
		if c == '<':
			end = at
			while end < text.len and text[end] != '>':
				end += 1
			r.readHtmlTag(t, str(text[at + 1..end].copy()))
			at = end + 1
		elif c == '\n' or c == '\r':
			r.endLine()
			at += 2 if c == '\r' and at + 1 < text.len and text[at + 1] == '\n' else 1
		elif c == '&':
			end = at
			while end < text.len and text[end] != ';' and end - at < 8:
				end += 1
			r.add(entity(str(text[at..end + 1].copy())))
			at = end + 1
		else:
			r.add(str([c]))
			at += 1
	r.endLine()
	while not r.lines.isEmpty and r.lines[len - 1].runs.isEmpty:
		r.lines.pop()
	first = base.copy()
	for l in r.lines:
		if not l.runs.isEmpty:
			first = l.runs[0].style.copy()
			break
	(first, r.lines)

# the lines read so far, the open line and the styles of the open tags, the innermost last
type HtmlReader:
	lines TextLine[] = []
	line TextRun[] = []
	styles TextStyle[]

fn add(mut r HtmlReader, text str):
	style = r.styles[len - 1].copy()
	if not r.line.isEmpty and r.line[len - 1].style == style:
		r.line[len - 1].text = "{r.line[r.line.len - 1].text}{text}"
	else:
		r.line.push(TextRun(text = text.copy(), style))

# an <img> tag's image in the line
fn addImage(mut r HtmlReader, tag str):
	src = attribute(tag, "src") ?? return
	number = (name str): f32.parse(attribute(tag, name) ?? "0") ?? 0.0
	r.line.push(TextRun(text = "", style = r.styles[len - 1].copy(), image = src,
		size = Vec2(number("width"), number("height")), vspace = number("vspace")))

fn endLine(mut r HtmlReader):
	r.lines.push(TextLine(runs = move r.line))
	r.line = []

# a tag's effect: a new line, a paragraph's alignment, a font's style until its end
fn readHtmlTag(mut r HtmlReader, t EditText, tag str):
	name = tag.split(" ")[0].lower()
	top = r.styles[len - 1].copy()
	match name:
		"/p", "br", "br/": r.endLine()
		"p":
			if attribute(tag, "align") is a:
				for mut style in r.styles:
					style.align = alignOf(a)
		"font":
			if attribute(tag, "face") is f: top.face = f
			if attribute(tag, "size") is s: top.size = (f32.parse(s) ?? t.height / 20.0) * 20.0
			if attribute(tag, "color") is col: top.color = hexColor(col, top.color)
			if attribute(tag, "letterSpacing") is ls: top.spacing = (f32.parse(ls) ?? 0.0) * 20.0
			r.styles.push(top)
		"/font":
			if r.styles.len > 1: r.styles.pop()
		"img": r.addImage(tag)
		_: pass

# the value of `name="..."` (or `name='...'`) in a tag's text
fn attribute(tag str, name str) str?:
	for quote in ["\"", "'"]:
		key = "{name}={quote}"
		start = tag.indexOf(key) ?? continue
		from = start + key.len
		end = tag[from..].indexOf(quote) ?? continue
		return tag[from..from + end].copy()
	none

fn alignOf(a str):
	match a.lower():
		"right": 1
		"center": 2
		"justify": 3
		_: 0

# "#RRGGBB" as a color (opaque), `otherwise` when it is not one
fn hexColor(text str, otherwise Vec4):
	digits = text[1..] if text.startsWith("#") else text[..]
	v = i64.parse("0x{digits}") ?? return otherwise
	Vec4(
		f32((v >> 16) & 255) / 255.0,
		f32((v >> 8) & 255) / 255.0,
		f32(v & 255) / 255.0,
		otherwise.w
	)

fn entity(e str):
	match e:
		"&amp;": "&"
		"&lt;": "<"
		"&gt;": ">"
		"&quot;": "\""
		"&apos;": "'"
		"&nbsp;": " "
		_: e.copy()

# where a line `width` wide starts in the field's bounds by the style's alignment, inside the
# gutter and the margins
pub fn lineStart(t EditText, bounds Rect, style TextStyle, width f32) f32:
	left = bounds.xmin + gutter + t.leftMargin
	right = bounds.xmax - gutter - t.rightMargin
	if style.align == 1: return right - width
	if style.align == 2: return (left + right - width) * 0.5
	left + t.indent

# the advances and kernings of the codes, in the font's units
pub fn lineWidth(f Font, codes i64[]) f32:
	w = 0.0
	for k, code in codes:
		if f.byCode.get(code) is g: w += f.glyphs[g].advance
		if k + 1 < codes.len: w += f.kerningOf(code, codes[k + 1])
	w

fn kerningOf(f Font, a i64, b i64):
	f.kerning.get((a << 16) | b) ?? 0.0
