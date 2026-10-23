# Prince of Persia (Jordan Mechner, Broderbund 1989), the DOS game (v1.4) rebuilt in Zap: its
# rules ported routine by routine from SDLPoP's reading of the original (game/), its pictures,
# levels, tables and sounds read from the player's own copy (projects/dos/pop), and its VGA
# screen of 320x200 drawn as the original composes it, at an integer zoom.
#
#   zap run projects/pop/main.zap [--level 0..14] [--install dir]   (no level: the title, then the demo)
#     the arrows move the kid, Shift is the button, Space shows the time left, R starts the level
#     again (Enter too once he died), Shift+L skips to the next level (levels 1..3), Esc leaves
#   zap run projects/pop/main.zap --frames 30 --step 16 --shot pop.png
#   zap run projects/pop/main.zap --frames 200 --step 16 --keys right@40-80 --shot run.png   (played by a script)
#   needs: C:/Games/Prince of Persia (the DOS game's files, never committed)

import dos.pop
import engine
import engine.audio
import game

startLevel = (i64.parse(args.option("--level") ?? "-1") ?? -1).clamp(-1, 14)
route = game.parseKeyRoute(args.option("--keys") ?? "")
scripted = args.option("--keys") != none

mut g = game.newGame(args.option("--install") ?? pop.defaultInstall)
g.settingsDir = args.option("--ini") ?? "."
g.saveDir = args.option("--save-dir") ?? ""
g.useOptions(game.loadOptions(g.settingsDir))
g.startGame(i64.parse(args.option("--seed") ?? "0") ?? 0, startLevel)

mut win = engine.openWindow("Prince of Persia", 1920, 1080)
mut r = engine.newRenderer()
mut frames = engine.newFrames()
tex = g.screen.onscreen.newTexture()

# the game's sounds, one playing at a time as on the PC: samples made once, MIDI tunes streamed
# from the synthesizer
type Speakers:
	bank audio.Sound[]
	voice audio.Voice? = none
	music pop.MidiStream? = none
	musicPushed i64 = 0   # the samples of the tune given to the feed
	musicTime f32 = 0.0   # the seconds since it started
	feed audio.Feed

# a sound of nothing for the ones not heard
fn orSilence(move samples f32[]) f32[]:
	if samples.isEmpty: return [0.0]
	samples

# the frame's sounds: what played stops when the game stops it or starts another
fn playSounds(mut s Speakers, mut game game.Game):
	if game.soundsStopped or not game.soundsPlayed.isEmpty:
		if s.voice is v: v.stop()
		s.voice = none
		s.music = none
		game.soundsStopped = false
	for id in game.soundsPlayed:
		if game.sounds.midiStream(id) is m:
			if not game.options.isOn("enable_music"): continue
			s.music = m
			s.musicPushed = 0
			s.musicTime = 0.0
		else:
			s.voice = s.bank[id].play()

# the tune's next samples: the feed kept a tenth of a second ahead of the time played
fn streamMusic(mut s Speakers, dt f32):
	if s.music is mut m:
		s.musicTime += dt.min(0.25)
		due = i64((s.musicTime + 0.1) * f32(pop.outputRate)) - s.musicPushed
		if due > 0:
			s.feed.push(m.render(due), 1, pop.outputRate)
			s.musicPushed += due

audio.start()
mut speakers = Speakers(
	bank = (0..pop.soundCount).map(audio.newSound(orSilence(g.sounds.samplesOf(it)), 1, pop.outputRate)),
	feed = audio.newFeed()
)

# whether the key of a virtual-key code is held, and went down this frame
fn held(vk i64):
	engine.isKeyDown(.Raw(vk))

fn went(vk i64):
	engine.isKeyPressed(.Raw(vk))

# the keys of SDLPoP's read_keyb_control: the arrows, Home and Page Up for the diagonal jumps, the
# keypad, and the keys the controls settings name
fn anyHeld(codes i64[]):
	for c in codes:
		if held(c): return true
	false

# the virtual-key code of a key pressed this frame, 0 for none (the key settings' dialog)
fn anyKeyWent():
	for vk in 8..255:
		if went(vk): return vk
	0

fn hostInput(o game.Options, menuShown bool, mouse game.Input):
	shift = engine.isKeyDown(.Shift)
	moving = not menuShown
	game.Input(
		left = moving and anyHeld([o.opt("key_left"), 37, 100, o.opt("key_jump_left"), 36, 103]),
		right = moving and anyHeld([o.opt("key_right"), 39, 102, o.opt("key_jump_right"), 33, 105]),
		up = moving and anyHeld([o.opt("key_up"), 38, 104, o.opt("key_jump_left"), 36, 103, o.opt("key_jump_right"), 33, 105]),
		down = moving and anyHeld([o.opt("key_down"), 40, 98, 101, 12]),
		shift = shift or held(o.opt("key_action")),
		restart = engine.isKeyPressed(.Char('R')) or went(o.opt("key_enter")),
		showTime = engine.isKeyPressed(.Space),
		nextLevel = shift and engine.isKeyPressed(.Char('L')),
		typed = typedChar(shift),
		pressed = o.pressedKey(menuShown),
		rawKey = anyKeyWent(),
		backspace = engine.isKeyPressed(.Backspace) or (not menuShown and mouse.mouseClicked),
		enter = went(o.opt("key_enter")),
		mouseX = mouse.mouseX,
		mouseY = mouse.mouseY,
		mouseClicked = mouse.mouseClicked and menuShown,
		mouseRight = mouse.mouseRight and menuShown,
		wheel = mouse.wheel if menuShown else 0
	)

# the mouse in the 320x200 screen, as the window's picture lays it out
fn hostMouse(w engine.Window):
	zoom = (w.width / 320).min(w.height / 200).max(1)
	x = (i64(engine.mousePosition().x) - (w.width - 320 * zoom) / 2) / zoom
	y = (i64(engine.mousePosition().y) - (w.height - 200 * zoom) / 2) / zoom
	turn = engine.wheelTurn()
	game.Input(
		mouseX = x,
		mouseY = y,
		mouseClicked = engine.isMousePressed(0),
		mouseRight = engine.isMousePressed(1),
		wheel = -1 if turn > 0.0 else (1 if turn < 0.0 else 0)
	)

# the key of the game's keys pressed this frame, by its name as keys.zap reads it: Esc, F6, F9, Tab,
# Ctrl+A, G, J, K, L, R, S, V and Ctrl+Tab (with Shift as SDLPoP's process_key allows); in the menu
# the keys that move in it
ctrlLetters = ['A', 'G', 'J', 'K', 'L', 'R', 'S', 'V']

# a key that moves in the menu
type NavKey:
	code i64
	name str

fn pressedKey(o game.Options, menuShown bool):
	if went(o.opt("key_esc")): return "esc"
	if menuShown:
		for key in [
			NavKey(o.opt("key_up"), "up"),
			NavKey(38, "up"),
			NavKey(o.opt("key_down"), "down"),
			NavKey(40, "down"),
			NavKey(o.opt("key_left"), "left"),
			NavKey(37, "left"),
			NavKey(o.opt("key_right"), "right"),
			NavKey(39, "right"),
			NavKey(33, "pageup"),
			NavKey(34, "pagedown"),
			NavKey(36, "home"),
			NavKey(35, "end")
		]:
			if went(key.code): return key.name
	ctrl = engine.isKeyDown(.Ctrl)
	if engine.isKeyPressed(.Tab):
		if ctrl: return "ctrl+tab"
		return "tab"
	if engine.isKeyPressed(.F(6)): return "f6"
	if engine.isKeyPressed(.F(9)): return "f9"
	if ctrl:
		for c in ctrlLetters:
			if engine.isKeyPressed(.Char(c)): return "ctrl+{str.fromCode(c + 32)}"
	""

# the letter, digit or space typed this frame, 0 for none
fn typedChar(shift bool) i64:
	for c in 'A'..='Z':
		if engine.isKeyPressed(.Char(c)): return c if shift else c + 32
	for c in '0'..='9':
		if engine.isKeyPressed(.Char(c)): return c
	if engine.isKeyPressed(.Space): return 32
	0

# the game runs on ticks of 60 a second, a frame of it 5 (6 in a sword fight)
accumulated = 0.0
flashTicks = 0
n = 0
running = true
while win.nextFrame(frames, false) and running:
	accumulated += frames.dt.min(0.25)
	speakers.streamMusic(frames.dt)
	frameTime = f32(g.frameTicks()) / 60.0
	if accumulated >= frameTime:
		accumulated -= frameTime
		input = route.inputAt(n) if scripted else g.options.hostInput(g.menu.shown, win.hostMouse())
		running = g.runFrame(input)
		speakers.playSounds(g)
		n += 1
		# a flash shows for 2 ticks of the frame
		if g.flashShown >= 0:
			tex.updateTexture(g.flashedScreen())
			flashTicks = 2
		else:
			tex.updateTexture(g.displayImage())
	elif flashTicks > 0 and accumulated >= f32(2 - flashTicks + 1) / 60.0:
		flashTicks = 0
		tex.updateTexture(g.displayImage())
	zoom = (win.width / 320).min(win.height / 200)
	w = 320 * zoom
	h = 200 * zoom
	cam = engine.Camera(x = 0.0, y = 0.0, zoom = 1.0)
	r.beginFrame(win.width, win.height, engine.black, cam)
	r.drawQuad(tex.texture(), f32((win.width - w) / 2), f32((win.height - h) / 2), f32(w), f32(h))
	r.showFrame(win, frames)
print("{frames.fpsText()}; {n} game frames")
