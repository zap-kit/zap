# The screens around a level as the DOS game draws them on its 640 x 350 menu screen: the main
# menu (its signs, the rating board, the sound icon, the credits on the reel), a level's preview
# and its result. The layout is Lemmix's (Eric Langedijk's reading of the game), checked against
# the oracle's pictures; the pictures are main.dat's (sections 3 and 4).

import dos.lemmings
import image

pub menuWidth = 640
pub menuHeight = 350

# the credits the reel scrolls, one at a time (the original game's)
pub credits = ["Lemmings By DMA Design", "Programming By Russell Kay",
	"Animation By Gary Timmons", "Graphics By Scott Johnston",
	"Music By Brian Johnston & Tim Wright", "PC Music By Tony Williams",
	"Copyright 1991 Psygnosis Ltd."]

# what the F3 sign shows
pub type SoundSetting:
	Music
	Effects
	Silent

fn blit(mut img image.Image, from image.Image, x i64, y i64):
	for sy in 0..from.height:
		for sx in 0..from.width:
			p = from[sx, sy]
			tx = x + sx
			ty = y + sy
			if p.a != 0 and tx >= 0 and ty >= 0 and tx < img.width and ty < img.height:
				img[tx, ty] = p

# the brown background tiled from row `top` down
fn tileBackground(mut img image.Image, m lemmings.MenuData, top i64):
	y = top
	while y < img.height:
		x = 0
		while x < img.width:
			img.blit(m.background, x, y)
			x += m.background.width
		y += m.background.height

# purple text from (x, y): 16 pixels a character and a line
pub fn drawText(mut img image.Image, m lemmings.MenuData, text str, x i64, y i64):
	cx = x
	cy = y
	for c in text.bytes():
		if c == '\n':
			cx = x
			cy += 16
			continue
		if lemmings.glyphIndex(c) is i:
			img.blit(m.font[i], cx, cy)
		cx += 16

# each line centred across the screen
pub fn drawCentered(mut img image.Image, m lemmings.MenuData, text str, y i64):
	for i, line in text.lines():
		img.drawText(m, line, (img.width - line.len * 16) / 2, y + i * 16)

fn blank():
	image.Image(menuWidth, menuHeight, fill = image.Rgba8(0, 0, 0, 255))

# the main menu; `tick` moves the credits (a tick a frame of the menu)
pub fn drawMenu(m lemmings.MenuData, rating i64, sound SoundSetting, tick i64) image.Image:
	img = blank()
	img.tileBackground(m, 0)
	img.blit(m.logo, 8, 10)
	for i, at in [(68, 120), (196, 120), (324, 120), (452, 120), (196, 197), (324, 197)]:
		x, y = at
		img.blit(m.signs[i], x, y)
	if sound == .Music:
		img.blit(m.musicIcon, 351, 146)
	elif sound == .Effects:
		img.blit(m.effectsIcon, 351, 146)
	img.blit(m.ratings[rating], 484, 144)
	img.drawCentered(m, "(C)MCMXCI Psygnosis Ltd", 272)
	img.drawCentered(m, "A DMA Design Game", 288)
	img.drawReel(m, tick)
	img

# the reel at the bottom: a credit scrolled in from the right, the lemmings at its ends winding
fn drawReel(mut img image.Image, m lemmings.MenuData, tick i64):
	y = menuHeight - 16
	boxes = 34
	left = (menuWidth - boxes * 16) / 2
	for i in 0..boxes:
		img.blit(m.reel, left + i * 16, y)
	frame = tick / 2 % 16
	img.blit(m.scrollerLeft[frame], left - 48, y)
	img.blit(m.scrollerRight[frame], left + boxes * 16, y)
	text = credits[tick / 600 % len]
	shift = boxes * 16 - tick % 600 * 4
	x = left + shift.max((boxes * 16 - text.len * 16) / 2)
	for i, c in text.bytes():
		cx = x + i * 16
		if cx < left or cx + 16 > left + boxes * 16: continue
		if lemmings.glyphIndex(c) is i:
			img.blit(m.font[i], cx, y)

# a level's preview: the whole level at a quarter its size in the black above, its numbers
# a line each 32 rows
pub fn drawPreview(
	m lemmings.MenuData,
	main lemmings.MainData,
	g Game,
	ratingName str,
	number i64
) image.Image:
	img = blank()
	img.tileBackground(m, 80)
	view = g.drawView(main, 0, worldWidth)
	for y in 0..worldHeight / 4:
		for x in 0..worldWidth / 4:
			img[previewLeft + x, previewTop + y] = view[x * 4, y * 4]
	img.drawText(m, "Level {number + 1}", 0, previewTitleTop)
	img.drawText(m, g.level.name.trimmed(), 240, previewTitleTop)
	lines = [
		"Number of Lemmings {g.level.lemmings}",
		"{g.neededPercent()}%  To Be Saved",
		"Release Rate {g.level.releaseRate}",
		"Time {g.level.minutes} Minutes",
		"Rating  {ratingName}"
	]
	for i, line in lines:
		img.drawText(m, line, 160, previewTitleTop + 48 + i * 32)
	img.drawCentered(m, "Press mouse button to continue", previewTitleTop + 224)
	img

# the result: the game's verdict by how many were saved against how many were needed, the next
# level's access code when there is one, the buttons' meaning on lines 17 and 18
pub fn drawResult(m lemmings.MenuData, g Game, next i64, code str?) image.Image:
	img = blank()
	img.tileBackground(m, 0)
	saved = g.savedPercent()
	needed = g.neededPercent()
	won = saved >= needed
	lines = [
		"Your time is up!" if g.timeUp else "All lemmings accounted for.",
		"",
		"You rescued {saved}%",
		"You needed  {needed}%",
		"",
		verdict(saved, needed)
	].join("\n").lines()
	if won:
		if code is c:
			lines.extend(["", "", "", "", "", "", "Your Access Code for Level {next}", "is {c}"])
	while lines.len < 17:
		lines.push("")
	lines.push(
		"Press left mouse button for next level" if won
		else "Press left mouse button to retry level"
	)
	lines.push("Press right mouse button for menu")
	for i, line in lines:
		img.drawCentered(m, line, resultTop + i * 16)
	img

resultTop = 16
previewLeft = (menuWidth - worldWidth / 4) / 2
previewTop = 20
previewTitleTop = 80

# long: the game's nine verdicts, from none saved to all of them
fn verdict(saved i64, needed i64):
	if saved == 100:
		return "Superb! You rescued every lemmings on\nthat level. Can you do it again...."
	if saved == 0: return "ROCK BOTTOM! I hope for your sake\nthat you nuked that level."
	if saved < needed / 2: return "Better rethink your strategy before\nyou try this level again!"
	if saved < needed - 5: return "A little more practice on this level\nis definitely recommended."
	if saved < needed - 1:
		return "You got pretty close that time.\nNow try again for that few % extra."
	if saved == needed - 1: return "OH NO, So near and yet so far (teehee)\nMaybe this time....."
	if saved == needed:
		return "RIGHT ON. You can't get much closer\nthan that. Let's try the next..."
	if saved < needed + 20:
		return "That level seemed no problem to you on\nthat attempt. Onto the next...."
	"You totally stormed that level!\nLet's see if you can storm the next..."
