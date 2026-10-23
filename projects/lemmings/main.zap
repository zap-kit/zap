# Lemmings (DMA Design, 1991) rebuilt in Zap from the player's own DOS copy: its levels, graphics
# and rules read from the game's files (projects/dos/lemmings, never committed), drawn with the
# original pixels at an integer zoom on a wider screen.
#
#   zap run projects/lemmings/main.zap [--rating 0..3] [--level 1..30] [--install dir]
#     1-8 choose a skill (or click its button), a click gives it to the lemming under the cursor,
#     - and + (or their buttons) change the release rate, P pauses, N nukes, F held speeds the
#     game up, arrows or the mouse at the screen's edges scroll, R starts the level again, Esc
#     goes to the menu (F1 plays, F3 the sound, F4 the rating); a level's preview and its result
#     go on with a click
#   zap run projects/lemmings/main.zap --frames 240 --step 16 --shot lemmings.png
#   zap run projects/lemmings/main.zap --frames 900 --step 16 --route digger@200 --shot dig.png   (played by a script)
#   needs: C:/Games/Lemmings (the DOS game's files, never committed)

import engine.audio
import dos.lemmings
import engine
import fs
import game

zoom = 5
screenWidth = 320
levelHeight = 160
panelHeight = 40

menuZoom = 3   # the menus' 640 x 350 screen

# where the player is: the screens around a level, or in one
type Screen:
	Menu
	Preview
	Playing
	Result

type Session:
	main lemmings.MainData
	menu lemmings.MenuData
	screen Screen
	screenTexture engine.GpuTexture   # the menus' screen, made on the CPU each frame
	menuTick i64 = 0
	sound game.SoundSetting = .Music
	driver lemmings.AdlibDriver
	feed audio.Feed
	sampleDebt f64 = 0.0
	panel engine.GpuTexture
	font engine.GpuTexture[]
	skillDigits engine.GpuTexture[]
	rating i64
	number i64
	g game.Game
	view engine.GpuTexture   # the level as the game draws it, made on the CPU each frame
	world engine.GpuTexture   # the terrain, for the minimap
	cameraX f32
	accumulated f32 = 0.0
	fast bool = false
	winHeight i64

fn startLevel(mut s Session, dir str):
	level = lemmings.loadLevel(dir, s.rating, s.number)
	set = lemmings.loadGraphicsSet(dir, level.graphicsSet, level.special)
	s.cameraX = f32(level.screenStart)
	s.g = game.newGame(level, set, s.main)
	s.world = s.g.world.picture.newTexture()
	s.accumulated = 0.0
	s.startMusic()
	print("{lemmings.ratings[s.rating]} {s.number + 1}: {s.g.level.name}  ({s.g.level.lemmings} lemmings, {s.g.neededPercent()}% to save, {s.g.level.minutes} minutes)")

# ---------- drawing ----------

# the panel's font: "%0123456789-" then the capitals; other characters are skipped
fn glyphIndex(c u8) i64?:
	if c == '%': return 0
	if c >= '0' and c <= '9': return 1 + i64(c - '0')
	if c == '-': return 11
	if c >= 'A' and c <= 'Z': return 12 + i64(c - 'A')
	if c >= 'a' and c <= 'z': return 12 + i64(c - 'a')
	none

fn drawGreenText(mut r engine.Renderer, s Session, text str, x i64, y i64):
	at = x
	for c in text.bytes():
		if glyphIndex(c) is i:
			r.draw(s.font[i].texture(), f32(at), f32(y))
		at += 8

# a skill count or the release rate in a button: two digits of four pixels
fn drawButtonNumber(mut r engine.Renderer, s Session, n i64, x i64, y i64):
	if n >= 10:
		r.draw(s.skillDigits[(n / 10 % 10) * 2 + 1].texture(), f32(x), f32(y))
	r.draw(s.skillDigits[n % 10 * 2].texture(), f32(x), f32(y))

fn drawPanel(mut r engine.Renderer, s Session, left i64, top i64):
	r.draw(s.panel.texture(), f32(left), f32(top))
	g = s.g
	cx, cy = s.cursorWorld()
	first, _, hits = g.lemmingsAt(cx, cy)
	if first is i:
		l = g.lemmings[i]
		name = "{l.action}".upper() if not (l.isClimber or l.isFloater)
			else "ATHLETE" if l.isClimber and l.isFloater
			else "CLIMBER" if l.isClimber
			else "FLOATER"
		r.drawGreenText(s, "{name} {hits}", left, top)
	r.drawGreenText(s, "OUT {g.out}", left + 104, top)
	r.drawGreenText(s, "IN {g.savedPercent()}%", left + 168, top)
	r.drawGreenText(s, "TIME {g.minutes}-{g.seconds:02}", left + 232, top)
	r.drawButtonNumber(s, g.releaseRate, left + 4, top + 17)
	r.drawButtonNumber(s, g.releaseRate, left + 20, top + 17)
	for i, skill in game.skills:
		r.drawButtonNumber(s, g.skillsLeft(skill), left + 36 + i * 16, top + 17)
		if skill == g.selected:
			x = f32(left + 32 + i * 16)
			y = f32(top + 16)
			r.fillRect(x, y, 16.0, 1.0, engine.white)
			r.fillRect(x, y + 23.0, 16.0, 1.0, engine.white)
			r.fillRect(x, y, 1.0, 24.0, engine.white)
			r.fillRect(x + 15.0, y, 1.0, 24.0, engine.white)
	if g.paused:
		r.fillRect(f32(left + 160), f32(top + 16), 16.0, 24.0, Vec4(1.0, 1.0, 1.0, 0.35))

fn drawMinimap(mut r engine.Renderer, s Session, left i64, top i64, viewWidth i64):
	# the level at a sixteenth across and an eighth down, in the panel's frame at 208..311
	scale = 104.0 / f32(game.worldWidth)
	r.drawQuad(
		s.world.texture(),
		f32(left + 208),
		f32(top + 18),
		104.0,
		20.0,
		tint = Vec4(1.0, 1.0, 1.0, 0.9)
	)
	for l in s.g.lemmings:
		if not l.removed:
			r.fillRect(
				f32(left + 208) + f32(l.x) * scale,
				f32(top + 18) + f32(l.y) * 20.0 / f32(game.worldHeight),
				1.0,
				1.0,
				Vec4(0.0, 1.0, 0.0, 1.0)
			)
	x0 = f32(left + 208) + s.cameraX * scale
	w = f32(viewWidth) * scale
	r.fillRect(x0, f32(top + 18), w, 1.0, engine.white)
	r.fillRect(x0, f32(top + 37), w, 1.0, engine.white)
	r.fillRect(x0, f32(top + 18), 1.0, 20.0, engine.white)
	r.fillRect(x0 + w - 1.0, f32(top + 18), 1.0, 20.0, engine.white)

fn drawFrame(mut r engine.Renderer, s Session, win engine.Window):
	viewWidth = win.width / zoom
	top = (win.height / zoom - levelHeight - panelHeight) / 2
	cam = engine.Camera(x = s.cameraX, y = f32(-top), zoom = f32(zoom))
	r.beginFrame(win.width, win.height, engine.black, cam)
	r.draw(s.view.texture(), s.cameraX, 0.0)
	panelLeft = i64(s.cameraX) + (viewWidth - screenWidth) / 2
	r.fillRect(
		s.cameraX,
		f32(levelHeight),
		f32(viewWidth),
		f32(panelHeight),
		Vec4(0.0, 0.0, 0.0, 1.0)
	)
	r.drawPanel(s, panelLeft, levelHeight)
	r.drawMinimap(s, panelLeft, levelHeight, viewWidth)

# a screen around a level, at the menus' zoom in the window's middle
fn drawMenuScreen(mut r engine.Renderer, s Session, win engine.Window):
	cam = engine.Camera(x = 0.0, y = 0.0, zoom = f32(menuZoom))
	r.beginFrame(win.width, win.height, engine.black, cam)
	x = (win.width / menuZoom - game.menuWidth) / 2
	y = (win.height / menuZoom - game.menuHeight) / 2
	r.draw(s.screenTexture.texture(), f32(x), f32(y))

# ---------- sound ----------

# the level's song: the 21 songs in turn through the 120 levels
fn startMusic(mut s Session):
	s.driver.setPlaying(0)
	if s.sound == .Music:
		s.driver.requestSong((s.rating * 30 + s.number) % 21 + 1)
	else:
		s.driver.requestSong(0x16)

# the game's sounds asked of the driver, and the chip's samples for the frame's time
fn playSound(mut s Session, dt f32):
	for c in s.g.cues:
		effect = c.effectOf()
		if effect > 0 and s.sound != .Silent:
			s.driver.requestEffect(effect)
	s.g.cues.clear()
	s.sampleDebt += f64(dt.min(0.25)) * f64(lemmings.oplRate)
	n = i64(s.sampleDebt)
	s.sampleDebt -= n
	if n > 0:
		s.feed.push(s.driver.render(n), 1, lemmings.oplRate)

# ---------- input ----------

# the cursor in the level's pixels
fn cursorWorld(s Session):
	m = engine.mousePosition()
	(i64(s.cameraX) + m.x / zoom, m.y / zoom - s.panelTop())

fn panelTop(s Session):
	(s.winHeight / zoom - levelHeight - panelHeight) / 2

fn handlePanelClick(mut s Session, px i64, py i64, held bool):
	if py < 16 or px < 0 or px >= 192: return
	button = px / 16
	if held:
		s.g.rateChange = -1 if button == 0 else 1 if button == 1 else 0
		return
	if button >= 2 and button <= 9:
		s.g.selected = game.skills[button - 2]
		s.g.cues.push(.SkillButton)
	elif button == 10:
		s.g.paused = not s.g.paused
	elif button == 11:
		s.g.nuke()

fn handleInput(mut s Session, win engine.Window, dt f32):
	s.winHeight = win.height
	viewWidth = win.width / zoom
	scroll = engine.keyAxis(.Right, .Left) * 240.0 * dt
	m = engine.mousePosition()
	if m.x < 8: scroll -= 240.0 * dt
	if m.x >= win.width - 8: scroll += 240.0 * dt
	s.cameraX = (s.cameraX + scroll).clamp(0.0, f32(game.worldWidth - viewWidth))
	for i in 0..8:
		if engine.isKeyPressed(.Char('1' + i)):
			s.g.selected = game.skills[i]
			s.g.cues.push(.SkillButton)
	if engine.isKeyPressed(.Char('P')): s.g.paused = not s.g.paused
	if engine.isKeyPressed(.Char('N')): s.g.nuke()
	s.fast = engine.isKeyDown(.Char('F'))
	s.g.rateChange = 0
	if engine.isKeyDown(.Char('-')): s.g.rateChange = -1
	if engine.isKeyDown(.Char('=')) or engine.isKeyDown(.Char('+')): s.g.rateChange = 1
	wx, wy = s.cursorWorld()
	panelLeft = i64(s.cameraX) + (viewWidth - screenWidth) / 2
	if wy >= levelHeight:
		if engine.isMouseDown(0):
			s.handlePanelClick(wx - panelLeft, wy - levelHeight, true)
		if engine.isMousePressed(0):
			s.handlePanelClick(wx - panelLeft, wy - levelHeight, false)
	elif engine.isMousePressed(0) and wy >= 0 and not s.g.finished:
		s.g.clickAt(wx, wy, engine.isMouseDown(1))

# ---------- the screens around a level ----------

# the access code the result shows: the next level's, after a win, none after the rating's last
fn nextCode(s Session) str?:
	if s.number >= 29 or s.g.savedPercent() < s.g.neededPercent(): return none
	lemmings.accessCode(s.rating * 30 + s.number + 1, s.g.savedPercent())

# the menus' screen as it is now
fn menuPicture(s Session):
	match s.screen:
		Menu: s.menu.drawMenu(s.rating, s.sound, s.menuTick)
		Preview: s.menu.drawPreview(s.main, s.g, lemmings.ratings[s.rating], s.number)
		_: s.menu.drawResult(s.g, s.number + 2, s.nextCode())

fn clicked():
	engine.isMousePressed(0) or engine.isKeyPressed(.Enter)

# the menu's keys: F1 plays, F3 the sound, F4 the rating (its first level)
fn handleMenu(mut s Session, dir str):
	if engine.isKeyPressed(.F(1)) or engine.isMousePressed(0):
		s.startLevel(dir)
		s.screen = .Preview
	elif engine.isKeyPressed(.F(3)):
		s.sound = match s.sound:
			Music: .Effects
			Effects: .Silent
			Silent: .Music
	elif engine.isKeyPressed(.F(4)):
		s.rating = (s.rating + 1) % 4
		s.number = 0

# the result's buttons: the left goes on (the next level once won), the right to the menu
fn handleResult(mut s Session, dir str):
	if engine.isMousePressed(1) or engine.isKeyPressed(.Escape):
		s.screen = .Menu
		return
	if not clicked(): return
	if s.g.savedPercent() >= s.g.neededPercent():
		s.number += 1
		if s.number >= 30:
			s.number = 0
			s.rating = (s.rating + 1) % 4
	s.startLevel(dir)
	s.screen = .Preview

# ---------- the program ----------

dir = args.option("--install") ?? lemmings.defaultInstall
rating = (i64.parse(args.option("--rating") ?? "0") ?? 0).clamp(0, 3)
number = ((i64.parse(args.option("--level") ?? "1") ?? 1) - 1).clamp(0, 29)
# a level asked for, or a scripted run, starts in it; else the menu comes first
direct = args.option("--level") != none or args.option("--route") != none or
	args.option("--frames") != none

main = lemmings.loadMainData(dir)
menu = lemmings.loadMenuData(dir)
adlib = fs.readBytes("{dir}/adlib.dat") ?? fail("cannot read adlib.dat: {error}")
audio.start()
mut win = engine.openWindow("Lemmings", 1920, 1080)
mut r = engine.newRenderer()
mut frames = engine.newFrames()
firstLevel = lemmings.loadLevel(dir, rating, number)
firstSet = lemmings.loadGraphicsSet(dir, firstLevel.graphicsSet, firstLevel.special)
firstCamera = f32(firstLevel.screenStart)
firstGame = game.newGame(firstLevel, firstSet, main)
s = Session(
	main,
	menu,
	screen = .Playing if direct else .Menu,
	screenTexture = menu.drawMenu(rating, .Music, 0).newTexture(),
	driver = lemmings.newAdlibDriver(adlib),
	feed = audio.newFeed(),
	panel = main.panel.newTexture(),
	font = main.font.map(.newTexture()),
	skillDigits = main.skillDigits.map(.newTexture()),
	rating,
	number,
	g = firstGame,
	view = firstGame.drawView(main, i64(firstCamera), win.width / zoom).newTexture(),
	world = firstGame.world.picture.newTexture(),
	cameraX = firstCamera,
	winHeight = win.height
)
if direct:
	s.startMusic()

tick = f32(1.0 / game.iterationsPerSecond)
route = game.parseRoute(args.option("--route") ?? "")
while win.nextFrame(frames):
	s.playSound(frames.dt)
	if s.screen != .Playing:
		match s.screen:
			Menu: s.handleMenu(dir)
			Preview:
				if clicked(): s.screen = .Playing
			_: s.handleResult(dir)
		s.menuTick += 1
		s.screenTexture.updateTexture(s.menuPicture())
		r.drawMenuScreen(s, win)
		r.showFrame(win, frames)
		continue
	s.handleInput(win, frames.dt)
	if engine.isKeyPressed(.Char('R')):
		s.startLevel(dir)
	if engine.isKeyPressed(.Escape):
		s.screen = .Menu
	s.accumulated += frames.dt.min(0.25) * (4.0 if s.fast else 1.0)
	while s.accumulated >= tick:
		s.accumulated -= tick
		s.g.step()
		for line in s.g.runRoute(route):
			print(line)
	if s.g.finished and not direct:
		s.screen = .Result
	s.view.updateTexture(s.g.drawView(s.main, i64(s.cameraX), win.width / zoom))
	s.world.updateTexture(s.g.world.picture)
	r.drawFrame(s, win)
	r.showFrame(win, frames)
print("{frames.fpsText()}; saved {s.g.saved} of {s.g.level.lemmings}")
