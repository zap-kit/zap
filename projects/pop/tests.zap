# The ports of SDLPoP's saves, replays and options checked against themselves: what is saved and
# loaded again, or recorded and played again, ends in the state it began from. The tests that
# need the player's own game files are skipped without them.

import dos.pop
import game
import fs

# whether the DOS game's files are there
fn haveGame():
	fs.exists("{pop.defaultInstall}/PRINCE.DAT")

# a game started at `level`, its files kept under `dir`
fn testGame(dir str, level i64):
	_ = fs.createDir(dir)
	g = game.newGame(pop.defaultInstall)
	g.settingsDir = dir.copy()
	g.saveDir = dir.copy()
	g.startGame(5, level)
	g

# the kid's and the guard's place and the time, as one text
fn stateText(g game.Game):
	"{g.kid.frame} {g.kid.x} {g.kid.y} {g.kid.currSeq} {g.guard.frame} {g.randomSeed} {g.remMin} {g.remTick} {g.drawnRoom}"

# a game recorded for `ticks` frames along a route
fn recordedGame(dir str, level i64, route str, ticks i64):
	g = testGame(dir, level)
	g.startRecording()
	g.play(game.parseKeyRoute(route), 0, ticks)
	g

fn play(mut g game.Game, route game.KeyRoute, from i64, to i64):
	for n in from..to:
		g.runFrame(route.inputAt(n))

test "the options of a replay are the sizes SDLPoP writes, and read back":
	o = game.Options()
	expect o.replayBytes(0).len == 3
	expect o.replayBytes(1).len == 6
	expect o.replayBytes(2).len == 38
	expect o.replayBytes(3).len == 147
	expect o.replayBytes(4).len == 144
	o.readIni("[General]\nenable_copyprot = true\n[CustomGameplay]\nstart_hitp = 5 ; more\nmirror_tile = wall\nvga_color_1 = 4, 8, 255\n[Level 3]\nguard_hp = 9\nlevel_type = palace\n[Skill 2]\nstrikeprob = 77\n")
	expect o.isOn("enable_copyprot")
	expect o.opt("start_hitp") == 5 and o.opt("mirror_tile") == 20
	expect o.optAt("vga_palette", 3) == 1 and o.optAt("vga_palette", 5) == 63
	expect o.optAt("tbl_guard_hp", 3) == 9 and o.optAt("tbl_level_type", 3) == 1
	expect o.optAt("strikeprob", 2) == 77
	p = game.Options()
	for i in 0..5:
		p.setReplayBytes(i, o.replayBytes(i))
	expect p.opt("start_hitp") == 5 and p.optAt("tbl_guard_hp", 3) == 9 and
		p.isOn("enable_copyprot")
	expect not p.hasFix("fix_gate_sounds")

test "a savestate loaded again is the same bytes":
	if haveGame():
		g = testGame("{testDir()}a/", 1)
		route = game.parseKeyRoute("right@5-40,shift@50-60")
		g.play(route, 0, 80)
		saved = g.savestate()
		expect saved.len == 3458
		if haveGame():
			h = testGame("{testDir()}b/", 3)
			expect h.loadSavestate(saved)
			expect h.savestate() == saved
			expect h.stateText() == g.stateText()
	else:
		print("skipped: needs the DOS game's files")

test "a quicksave loaded again takes the game back":
	if haveGame():
		g = testGame("{testDir()}q/", 1)
		route = game.parseKeyRoute("right@5-60,f6@30")
		g.play(route, 0, 31)
		g.checkQuickOp()   # what the next frame begins with
		expect fs.exists("{testDir()}q/QUICKSAVE.SAV")
		expected = g.stateText()
		g.play(route, 31, 60)
		expect g.stateText() != expected
		g.needQuickLoad = true
		g.checkQuickOp()
		expect g.stateText().startsWith(expected[..expected.len - 10])
	else:
		print("skipped: needs the DOS game's files")

test "a replay recorded is played to the same state, and the file is read back":
	if haveGame():
		g = testGame("{testDir()}r/", 2)
		g.startRecording()
		route = game.parseKeyRoute(
			"right@5-40,shift@50-60,up@80,right@100-160,restart@170,right@190-230"
		)
		g.play(route, 0, 260)
		expected = g.stateText()
		file = g.recordedReplay()
		if game.readReplay(file) is rep:
			expect rep.ticks == 260 and rep.startLevel == 2
			if haveGame():
				h = testGame("{testDir()}p/", 2)
				h.startReplay(rep)
				h.play(game.parseKeyRoute(""), 0, 260)
				expect h.stateText() == expected
				expect not h.replaying or h.currTick == 260
		else:
			expect false
	else:
		print("skipped: needs the DOS game's files")

test "the pause waits for a key when the menu is off":
	if haveGame():
		g = testGame("{testDir()}e/", 1)
		g.options.readIni("enable_pause_menu = false")
		route = game.parseKeyRoute("esc@10,right@20-40")
		g.play(route, 0, 11)
		expect g.pausedWait
		held = g.stateText()
		g.play(route, 11, 20)
		expect g.pausedWait and g.stateText() == held
		g.play(route, 20, 21)
		expect not g.pausedWait
	else:
		print("skipped: needs the DOS game's files")

test "the pause menu opens over the game, moves, toggles a setting and resumes":
	if haveGame():
		g = testGame("{testDir()}u/", 1)
		g.play(game.parseKeyRoute("esc@10"), 0, 11)
		expect g.menu.shown and g.isPaused
		held = g.stateText()
		g.runFrame(game.Input())
		expect g.menu.hovering == 0 and g.stateText() == held
		expect g.screen.onscreen[10, 10].r < 40   # darkened or black
		loop 4:
			g.runFrame(game.Input(down = true))
		expect g.menu.hovering == 5   # SETTINGS
		g.runFrame(game.Input(pressed = "return"))
		expect g.menu.drawn == 1 and g.menu.hovering == 8
		g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(pressed = "return"))   # GAMEPLAY
		expect g.menu.area == 1 and g.menu.activeSub == 9
		expect not g.cheatsEnabled
		g.runFrame(game.Input(right = true))
		expect g.cheatsEnabled
		loop 3:
			g.runFrame(game.Input(pressed = "esc"))
		expect not g.menu.shown and not g.isPaused
		before = g.kid.frame
		g.play(game.parseKeyRoute("right@0-9"), 0, 10)
		expect g.kid.frame != before or g.kid.x != 0
	else:
		print("skipped: needs the DOS game's files")

test "the hall of fame is kept in PRINCE.HOF as SDLPoP keeps it":
	if haveGame():
		g = testGame("{testDir()}h/", 1)
		g.hallOfFame = [
			game.HofEntry(name = "Ana", min = 12, tick = 100),
			game.HofEntry(name = "Bia", min = 7, tick = 5)
		]
		g.writeHallOfFame()
		bytes = fs.readBytes("{testDir()}h/PRINCE.HOF") ?? []
		expect bytes.len == 2 + 6 * 29 and bytes[0] == 2 and bytes[2] == 'A'
		g.hallOfFame = []
		g.readHallOfFame()
		expect g.hallOfFame.len == 2 and g.hallOfFame[1].name == "Bia" and g.hallOfFame[0].min == 12
	else:
		print("skipped: needs the DOS game's files")

test "the game saved is read back, and the copy protection leads to the potions level":
	if haveGame():
		g = testGame("{testDir()}s/", 3)
		g.remMin = 41
		g.remTick = 300
		g.hitpBegLev = 4
		g.input = game.Input(pressed = "ctrl+g")
		g.processKey()
		expect fs.exists("{testDir()}s/PRINCE.SAV")
		g.remMin = 5
		expect g.loadGame()
		expect g.remMin == 41 and g.remTick == 300 and g.startLevel == 3 and g.hitpBegLev == 4
	if haveGame():
		g = testGame("{testDir()}c/", 1)
		g.options.readIni("enable_copyprot = true")
		g.play(game.parseKeyRoute("next@10"), 0, 30)
		expect g.currentLevel == 15
	else:
		print("skipped: needs the DOS game's files")

test "the options' colours are the game's own at the defaults, and the table of cutscenes maps levels":
	if haveGame():
		g = game.newGame(pop.defaultInstall)
		for i in 0..48:
			expect g.options.optAt("vga_palette", i) == g.tables.dataByte(0x2CBE + i)
		expect g.cutsceneSteps(g.options.optAt("tbl_cutscenes_by_index", 8)).len > 0
		expect g.cutsceneSteps(g.options.optAt("tbl_cutscenes_by_index", 5)).len == 0
	else:
		print("skipped: needs the DOS game's files")

test "the custom options read where SDLPoP reads them":
	if haveGame():
		g = testGame("{testDir()}o/", 4)
		g.options.readIni("[CustomGameplay]\nlevel_edge_hit_tile = floor\nallow_triggering_any_tile = true\ndrawn_tile_left_level_edge = floor\nstart_in_blind_mode = true\n")
		expect g.getTile(0, 0, 0) == game.tileFloor
		g.roomL = 0
		g.loadLeftroom()
		expect g.leftroomTiles[0] == game.tileFloor
		g.startGame(5, 4)
		expect g.isBlindMode == 1
	else:
		print("skipped: needs the DOS game's files")

test "the recording's end asks the file name and saves what is typed, Esc cancels":
	if haveGame():
		g = recordedGame("{testDir()}n/", 2, "right@5-40", 60)
		g.stopRecording()
		expect g.saveReplayWait
		for c in [97, 98]:
			g.runFrame(game.Input(typed = c))
		g.runFrame(game.Input(enter = true))
		expect not g.saveReplayWait
		expect fs.exists("{testDir()}n/replays/ab.p1r")
		if game.readReplay(fs.readBytes("{testDir()}n/replays/ab.p1r") ?? []) is rep:
			expect rep.ticks == 60
		else:
			expect false
		g.startRecording()
		g.stopRecording()
		g.runFrame(game.Input(pressed = "esc"))
		expect not g.saveReplayWait
	else:
		print("skipped: needs the DOS game's files")

test "F skips a replay to the next room, where the same state is reached as by playing it":
	if haveGame():
		g = recordedGame("{testDir()}k/", 3, "right@5-400", 400)
		file = g.recordedReplay()
		if game.readReplay(file) is rep:
			room = rep
			h = testGame("{testDir()}l/", 3)
			h.startReplay(room)
			first = h.drawnRoom
			h.runFrame(game.Input(pressed = "f"))
			expect h.drawnRoom != first and not h.skippingReplay and h.currTick > 10
			target = h.currTick
			plain = testGame("{testDir()}m/", 3)
			plain.startReplay(room)
			while plain.currTick < target:
				plain.runFrame(game.Input())
			expect plain.stateText() == h.stateText()
		else:
			expect false
	else:
		print("skipped: needs the DOS game's files")

test "the customization off leaves the defaults and keeps its values, and the cfg reads back":
	o = game.Options()
	o.readIni("[CustomGameplay]\nstart_hitp = 5\nuse_custom_options = false")
	expect o.opt("start_hitp") == 3 and not o.isOn("use_custom_options")
	expect o.replayBytes(3)[4] == 5   # a replay keeps custom_saved
	o.setCustomOn(true)
	expect o.opt("start_hitp") == 5
	o.values["key_left"] = [65]
	o.setCustomOn(false)
	p = game.Options()
	p.readCfg(o.cfgText())
	expect p.opt("key_left") == 65 and p.opt("start_hitp") == 3
	p.setCustomOn(true)
	expect p.opt("start_hitp") == 5

test "the mouse hovers and clicks the pause menu":
	if haveGame():
		g = testGame("{testDir()}w/", 1)
		g.play(game.parseKeyRoute("esc@10"), 0, 11)
		g.runFrame(game.Input(mouseX = 160, mouseY = 70))
		expect g.menu.hovering == 2
		g.runFrame(game.Input(mouseX = 160, mouseY = 57))
		expect g.menu.hovering == 0
		g.runFrame(game.Input(mouseX = 160, mouseY = 57, mouseClicked = true))
		expect not g.menu.shown
	else:
		print("skipped: needs the DOS game's files")

test "the level's settings and the key settings are changed in the menu, and saved":
	if haveGame():
		g = testGame("{testDir()}v/", 1)
		g.settingsDir = "{testDir()}v"
		g.play(game.parseKeyRoute("esc@10"), 0, 11)
		loop 4:
			g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(pressed = "return"))
		loop 3:
			g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(pressed = "return"))   # MODS
		g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(pressed = "return"))   # Customize level...
		g.runFrame(game.Input())
		g.runFrame(game.Input(right = true))
		g.runFrame(game.Input(pressed = "return"))
		expect g.menu.activeSub == 12 and g.menu.level == 2
		g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(right = true))   # Level type: palace
		expect g.options.optAt("tbl_level_type", 2) == 1
		loop 2:
			g.runFrame(game.Input(pressed = "esc"))
		g.runFrame(game.Input(down = true))
		g.runFrame(game.Input(pressed = "return"))   # CONTROLS
		g.runFrame(game.Input(pressed = "return"))   # Left
		g.runFrame(game.Input())
		g.runFrame(game.Input(rawKey = 65))
		expect g.options.opt("key_left") == 65
		loop 3:
			g.runFrame(game.Input(pressed = "esc"))
		expect not g.menu.shown
		saved = game.loadOptions("{testDir()}v")
		expect saved.opt("key_left") == 65 and saved.optAt("tbl_level_type", 2) == 1
	else:
		print("skipped: needs the DOS game's files")

test "the timer shows over the game when T is pressed with the cheats":
	if haveGame():
		g = testGame("{testDir()}t/", 1)
		g.cheatsEnabled = true
		g.play(game.parseKeyRoute("t@5"), 0, 8)
		expect g.timerShown
		shown = g.displayImage()
		lit = 0
		for y in 0..11:
			for x in 0..40:
				if shown[x, y].r > 200: lit += 1
		expect lit > 10
	else:
		print("skipped: needs the DOS game's files")
