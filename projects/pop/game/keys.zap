# The keys that act on the game (SDLPoP's seg000.c process_key, do_paused, check_quick_op,
# quick_save, quick_load, save_game, load_game): pause, restart, the saves, the time, the
# cheats. A key is named as `Input.pressed` names it: "esc", "f6", "ctrl+a", "shift+l", "c".

import fs

pub quickFile = "QUICKSAVE.SAV"
pub saveFile = "PRINCE.SAV"

# where a file of the game's own is kept
pub fn savePath(g Game, name str) str:
	"{g.saveDir}{name}"

# the key of this frame: the one named, or the one a flag of the input stands for
fn keyOf(g Game):
	if g.input.pressed != "": return g.input.pressed.copy()
	if g.input.backspace: return "backspace"
	if g.input.restart: return "ctrl+a"
	if g.input.showTime: return "space"
	if g.input.nextLevel: return "shift+l"
	""

# the keys a replay lets through
replayKeys = [
	"esc",
	"shift+esc",
	"backspace",
	"space",
	"ctrl+s",
	"ctrl+v",
	"ctrl+c",
	"c",
	"shift+c",
	"shift+i",
	"shift+b",
	"t",
	"f",
	"shift+f"
]

# process_key: false when no key acts
pub fn processKey(mut g Game) bool:
	key = g.keyOf()
	if g.remMin != 0 and g.kid.alive > 6 and (g.controlShift != 0 or key == "enter"):
		key = "ctrl+a"   # the kid died: Enter or Shift starts the level again
	if g.recording:
		if key == "ctrl+a":
			g.specialMove = moveRestart
		elif key == "ctrl+r":
			g.recording = false
			g.saveReplayDialog(true)
			return true
	elif g.replaying:
		if key == "ctrl+r":
			g.endReplay()
		elif key == "tab":
			g.cycleReplay()
			return true
		elif key == "f" or key == "shift+f":
			g.skippingReplay = true
			g.replaySeekTarget = seekNextLevel if key == "shift+f" else seekNextRoom
		elif key != "" and not (key in replayKeys):
			key = "1"   # cannot be done in a replay; the key still counts as a press
	if key == "": return false
	answer = ""
	match key:
		"esc", "shift+esc": g.isPaused = true
		"backspace":
			g.isPaused = true
			g.menuWanted = true
		"space": g.isShowTime = 1
		"ctrl+a":
			if g.currentLevel != 15:
				g.stopSounds()
				g.isRestartLevel = true
		"ctrl+g":
			if g.currentLevel >= g.options.opt("saving_allowed_first_level") and
				g.currentLevel <= g.options.opt("saving_allowed_last_level"):
				g.saveGame()
		"ctrl+k": answer = "KEYBOARD MODE"
		"ctrl+j": answer = "JOYSTICK NOT FOUND"
		"ctrl+r": g.restartGame()
		"ctrl+s":
			g.soundOn = not g.soundOn
			answer = "SOUND ON" if g.soundOn else "SOUND OFF"
		"ctrl+v": answer = "SDLPoP in Zap"
		"shift+l": answer = g.skipLevelKey()
		"f6", "shift+f6":
			if g.kid.alive < 0: g.needQuickSave = true
		"f9", "shift+f9": g.needQuickLoad = true
		"ctrl+tab", "ctrl+shift+tab":
			if g.recording:
				g.stopRecording()
			else:
				g.startRecording()
		_: pass
	if g.cheatsEnabled and answer == "":
		answer = g.cheatKey(key)
	if answer != "":
		g.displayTextBottom(answer)
		g.textTimeTotal = 24
		g.textTimeRemaining = 24
	true

# Ctrl+R: the game starts again, from its title
fn restartGame(mut g Game):
	g.closeMenu()
	g.replaying = false
	g.startLevel = -1
	g.startTitle()

# process_key's branch before a game is started (start_level < 0): a key starts the game, from
# the first level, a saved game, a replay or a recording; false when it starts nothing
pub fn startFromKey(mut g Game) bool:
	key = g.keyOf()
	if key == "f9": g.needQuickLoad = true
	if key == "tab":
		if not g.startNextReplay(): g.startTitle()
		return true
	if key == "ctrl+tab":
		g.startLevel = g.options.opt("first_level")
		g.startRecording()
	elif key == "ctrl+l":
		if not g.loadGame(): return false
	else:
		g.startLevel = g.options.opt("first_level")
	g.initCopyprot()
	g.startGameAt(g.startLevel)
	true

# the player can start a game or load a saved one during the demo
pub fn demoKey(mut g Game):
	if g.input.pressed == "ctrl+l":
		if g.loadGame(): g.pendingStart = g.startLevel
	elif g.hasKey():
		g.pendingStart = g.options.opt("first_level")

# Shift+L: the next level, for the first levels or with the cheats
fn skipLevelKey(mut g Game):
	if g.currentLevel < g.options.opt("shift_L_allowed_until_level") or g.cheatsEnabled:
		if g.currentLevel == 14:
			g.nextLevel = 1
		elif g.currentLevel == 15 and g.cheatsEnabled:
			if g.options.isOn("enable_copyprot"):
				g.nextLevel = g.options.opt("copyprot_level")
				g.options.values["copyprot_level"] = [-1]
		else:
			g.nextLevel = g.currentLevel + 1
			if not g.cheatsEnabled and g.remMin > g.options.opt("shift_L_reduced_minutes"):
				g.remMin = g.options.opt("shift_L_reduced_minutes")
				g.remTick = g.options.opt("shift_L_reduced_ticks")
		g.stopSounds()
	""

# the cheats of process_key: what they answer, "" for none
fn cheatKey(mut g Game, key str):
	match key:
		"c": return "S{g.drawnRoom} L{g.roomL} R{g.roomR} A{g.roomA} B{g.roomB}"
		"shift+c": return "AL{g.roomAL} AR{g.roomAR} BL{g.roomBL} BR{g.roomBR}"
		"kp_minus":
			if g.remMin > 1: g.remMin -= 1
			g.textTimeTotal = 0
			g.textTimeRemaining = 0
			g.isShowTime = 1
		"kp_plus":
			g.remMin += 1
			g.textTimeTotal = 0
			g.textTimeRemaining = 0
			g.isShowTime = 1
		"r":
			if g.kid.alive > 0:
				g.resurrectTime = 20
				g.kid.alive = -1
				g.eraseBottomText(true)
		"k":
			if g.guard.charid != charidSkeleton:
				g.guardhpDelta = -g.guardhpCurr
				g.guard.alive = 0
		"t": g.timerShown = not g.timerShown
		"shift+i": g.toggleUpside()
		"shift+w": g.featherFall()
		"h":
			g.drawGuardHp(0, 10)
			g.nextRoom = g.roomL
		"j":
			g.drawGuardHp(0, 10)
			g.nextRoom = g.roomR
		"u":
			g.drawGuardHp(0, 10)
			g.nextRoom = g.roomA
		"n":
			g.drawGuardHp(0, 10)
			g.nextRoom = g.roomB
		"ctrl+b":
			g.drawGuardHp(0, 10)
			g.nextRoom = g.kid.room
		"shift+b":
			g.isBlindMode = 1 - g.isBlindMode
			if g.isBlindMode != 0:
				g.screen.drawRect(g.pal, Rect(0, 0, 192, 320), colorBlack)
			else:
				g.needFullRedraw = 1
		"shift+s":
			if g.hitpCurr != g.hitpMax:
				g.playSound(soundSmallPotion)
				g.hitpDelta = 1
				g.flashColor = 4
				g.flashTime = 2
		"shift+t":
			g.playSound(soundBigPotion)
			g.flashColor = 4
			g.flashTime = 4
			g.addLife()
		_: pass
	""

# do_paused: the keys read into the controls, the ones that act at once, and the pause Esc asks
pub fn doPaused(mut g Game):
	if g.replaying and g.skippingReplay: return
	g.nextRoom = 0
	g.controlShift = ctrlHeld if g.input.shift else ctrlReleased
	g.controlY = ctrlHeldUp if g.input.up else (ctrlHeldDown if g.input.down else ctrlReleased)
	g.controlX = ctrlHeldLeft if g.input.left
		else (ctrlHeldRight if g.input.right else ctrlReleased)
	g.processKey()
	if g.isPaused:
		g.displayTextBottom("GAME PAUSED")
		if g.options.isOn("enable_pause_menu") or g.menuWanted:
			g.menuWanted = false
			g.openMenu()   # the frame ends when the menu closes
		else:
			g.isPaused = false
			g.pausedWait = true   # the frame ends when a key is pressed

# a tick of the pause: the game waits for a key, which acts as it does in a game
pub fn pauseTick(mut g Game) bool:
	if not g.processKey() and not g.hasKey(): return false   # any key ends it
	g.pausedWait = false
	g.eraseBottomText(true)
	true

# check_quick_op: the quick save and load asked for
pub fn checkQuickOp(mut g Game):
	if not g.options.isOn("enable_quicksave"): return
	if g.needQuickSave:
		if g.quickSave():
			g.displayTextBottom("QUICKSAVE")
		else:
			g.displayTextBottom("NO QUICKSAVE")
		g.needQuickSave = false
		g.textTimeTotal = 24
		g.textTimeRemaining = 24
	if g.needQuickLoad:
		if g.quickLoad():
			g.displayTextBottom("QUICKLOAD")
		else:
			g.displayTextBottom("NO QUICKLOAD")
		g.needQuickLoad = false
		g.textTimeTotal = 24
		g.textTimeRemaining = 24

fn quickSave(mut g Game):
	b = quickVersion.bytes().copy()
	b.extend(g.savestate())
	_ = fs.writeBytes(g.savePath(quickFile), b)
	fs.exists(g.savePath(quickFile))

# quick_load: the state of QUICKSAVE.SAV, a minute off the time left when the penalty is on
fn quickLoad(mut g Game):
	b = fs.readBytes(g.savePath(quickFile)) ?? []
	if b.len < 8 or not b.matchesAt(0, quickVersion): return false
	g.stopSounds()
	oldRemMin = g.remMin
	oldRemTick = g.remTick
	ok = g.loadSavestate(b[8..])
	g.restoreRoomAfterQuickLoad()
	if g.options.isOn("enable_quicksave_penalty") and (
		g.currentLevel < g.options.opt("victory_stops_time_level") or
			(g.currentLevel == g.options.opt("victory_stops_time_level") and g.leveldoorOpen < 2)
	):
		elapsed = 720 * (g.remMin - oldRemMin) + (g.remTick - oldRemTick)
		if elapsed > 0 and elapsed < 720:
			g.remMin = oldRemMin
			g.remTick = oldRemTick
		else:
			if g.remMin == 6: g.remTick = 719
			if g.remMin > 5 or g.remMin < 0: g.remMin -= 1
	ok

# restore_room_after_quick_load: the screen and the level's pictures after a state is loaded
pub fn restoreRoomAfterQuickLoad(mut g Game):
	guardColor = g.currGuardColor
	next = g.nextLevel
	g.resetLevelUnusedFields()
	g.loadLevSpr(g.currentLevel)
	g.currGuardColor = guardColor
	g.nextLevel = next
	g.differentRoom = 1
	g.drawnRoom = g.kid.room
	g.nextRoom = g.kid.room
	g.loadRoomLinks()
	g.drawGameFrame()
	g.hitpDelta = 1
	g.guardhpDelta = 1
	if g.guard.room != g.drawnRoom:
		g.guard.direction = dirNone
		g.guardhpCurr = 0
	g.drawHp()
	g.loadkidAndOpp()
	g.textTimeTotal = 0
	g.textTimeRemaining = 0
	g.exitRoomTimer = 0

# the loaded level's unused fields cleared (reset_level_unused_fields)
fn resetLevelUnusedFields(mut g Game):
	g.level.usedRooms = g.level.usedRooms.min(24)

# save_game: the time left, the level and the hit points at its start
fn saveGame(mut g Game):
	b = []
	b.pushU16le(g.remMin)
	b.pushU16le(g.remTick)
	b.pushU16le(g.currentLevel)
	b.pushU16le(g.hitpBegLev)
	_ = fs.writeBytes(g.savePath(saveFile), b)
	if fs.exists(g.savePath(saveFile)):
		g.displayTextBottom("GAME SAVED")
	else:
		g.displayTextBottom("UNABLE TO SAVE GAME")
	g.textTimeRemaining = 24

# load_game: the level to start and the time left, from PRINCE.SAV; false when there is none
pub fn loadGame(mut g Game) bool:
	b = fs.readBytes(g.savePath(saveFile)) ?? []
	if b.len < 8: return false
	r = Reader(d = b)
	g.remMin = r.i16()
	g.remTick = r.u16()
	g.startLevel = r.u16()
	g.hitpBegLev = r.u16()
	if g.options.isOn("enable_copyprot") and g.options.opt("copyprot_level") > 0:
		g.options.values["copyprot_level"] = [g.startLevel]
	g.dontResetTime = true
	true
