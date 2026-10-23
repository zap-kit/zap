# The texts of the bottom line (SDLPoP's seg008.c display_text_bottom and seg009.c draw_text):
# the game's font drawn in the DAC's colour 15, centred in its rectangle, lines broken at spaces.

import dos.pop

rectBottomText = Rect(top = 193, left = 70, bottom = 202, right = 250)
textColor = 15

pub fn displayTextBottom(mut g Game, text str):
	g.screen.drawRect(g.pal, rectBottomText, colorBlack)
	g.showText(rectBottomText, 0, 1, text, textColor)

pub fn eraseBottomText(mut g Game, clearTimer bool):
	g.screen.drawRect(g.pal, rectBottomText, colorBlack)
	if clearTimer:
		g.textTimeTotal = 0
		g.textTimeRemaining = 0

# the font in use: the game's, or the menu's small one
pub fn font(g Game) pop.Font:
	g.menuFont if g.smallFont else g.tables.font

fn charWidth(g Game, c i64):
	f = g.font()
	if c < f.first or c > f.last: return 0
	if f.pictures[c - f.first] is p:
		if p.width != 0: return p.width + f.charSpace
	0

# find_linebreak: how many characters of `text` from `start` fit in `breakWidth`
fn findLinebreak(g Game, text str, start i64, length i64, breakWidth i64, xAlign i64):
	pos = 0
	lastBreak = 0
	width = 0
	while pos < length:
		width += g.charWidth(text[start + pos])
		if width > breakWidth: return pos if lastBreak == 0 else lastBreak
		c = i64(text[start + pos])
		pos += 1
		if c == '\n': return pos
		next = i64(text[start + pos]) if start + pos < text.len else 0
		if c == 45 or (xAlign <= 0 and (c == 32 or next == 32)) or (next == 32 and c == 32):   # after "-" or at a space
			lastBreak = pos
	pos

# show_text: `text` in rect, x-aligned -1 left, 0 centre, 1 right, y-aligned likewise top to bottom
pub fn showText(mut g Game, rect Rect, xAlign i64, yAlign i64, text str, color i64):
	f = g.font()
	width = rect.right - rect.left
	height = rect.bottom - rect.top
	starts = []
	lengths = []
	start = 0
	rest = text.len
	while rest > 0:
		n = g.findLinebreak(text, start, rest, width, xAlign)
		if n == 0: break
		starts.push(start)
		lengths.push(n)
		start += n
		rest -= n
	lineDistance = f.aboveBaseline + f.belowBaseline + f.lineSpace
	textHeight = lineDistance * starts.len - f.lineSpace
	top = rect.top
	if yAlign == 0:
		top += (height + 1) / 2 - (textHeight + 1) / 2
	elif yAlign > 0:
		top += height - textHeight
	g.screen.clip = rect
	y = top + f.aboveBaseline
	for i in 0..starts.len:
		lineWidth = 0
		for k in 0..lengths[i]:
			lineWidth += g.charWidth(text[starts[i] + k])
		x = rect.left
		if xAlign == 0:
			x += width / 2 - lineWidth / 2
		elif xAlign > 0:
			x += width - lineWidth
		for k in 0..lengths[i]:
			x += g.drawTextCharacter(text[starts[i] + k], x, y, color)
		y += lineDistance
	g.screen.resetClip()

fn drawTextCharacter(mut g Game, c i64, x i64, y i64, color i64):
	f = g.font()
	if c < f.first or c > f.last: return 0
	if f.pictures[c - f.first] is p:
		g.screen.drawMono(g.pal, p, x, y - f.aboveBaseline, color)
		return f.charSpace + p.width
	0
