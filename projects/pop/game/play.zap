# A level played (SDLPoP's seg003.c; the Apple II's TOPCTRL.S and MISC.S): its start, a frame of
# the main loop, the screen drawn again, the timers, the mirror, what the guard sees, and the
# flash when the kid is hurt.

import image

# what the keyboard holds this frame, and the keys pressed
pub type Input:
	left bool = false
	right bool = false
	up bool = false
	down bool = false
	shift bool = false
	restart bool = false   # Ctrl+A, or Enter after dying
	showTime bool = false   # Space
	nextLevel bool = false   # Shift+L
	typed i64 = 0   # a character typed (the hall of fame's name)
	backspace bool = false
	enter bool = false
	pressed str = ""   # a key pressed, by its name ("esc", "f9", "ctrl+a", "shift+l"): see keys.zap
	rawKey i64 = 0   # a key pressed, by its virtual-key code, for the menu's key settings
	mouseX i64 = 0   # the mouse in the 320x200 screen
	mouseY i64 = 0
	mouseClicked bool = false   # the left button went down
	mouseRight bool = false   # the right button went down
	wheel i64 = 0   # the menu's scroll: -1 up, 1 down

# the game started at level `n` (-1 the title), its random numbers from `seed` (init_game_main
# draws the first)
pub fn startGame(mut g Game, seed i64, n i64):
	g.initPalette()   # set_hc_pal: the options' colours
	g.isBlindMode = g.options.opt("start_in_blind_mode")
	g.needDrects = true
	g.randomSeed = seed & 0xFFFF_FFFF
	g.prandom(1)
	g.readHallOfFame()
	if n < 0:
		g.startTitle()
	else:
		# a level asked for starts without its cutscene
		g.initCopyprot()
		g.startLevel = n
		g.initGame(n)
		if g.inShow:
			g.inShow = false
			g.showSteps = []
			g.playLevelAfterIntro(n)

# init_game: a new game from level `n`
pub fn initGame(mut g Game, n i64):
	g.textTimeRemaining = 0
	g.textTimeTotal = 0
	g.isShowTime = 0
	g.checkpoint = 0
	g.upsideDown = 0
	g.resurrectTime = 0
	if not g.dontResetTime:
		g.remMin = g.options.opt("start_minutes_left")
		g.remTick = g.options.opt("start_ticks_left")
		g.hitpBegLev = g.options.opt("start_hitp")
	g.needLevel1Music = 1 if n == g.options.opt("intro_music_level") else 0
	g.playLevel(g.protectedLevel(n))

# play_level up to the loop after the cutscene: the level loaded, the kid at his start, the
# first screen drawn
pub fn playLevelAfterIntro(mut g Game, n i64):
	if n != g.currentLevel:
		g.loadLevSpr(n)
	g.loadLevel()
	g.posGuards()
	g.clearCollRooms()
	g.clearSavedCtrl()
	g.drawnRoom = 0
	g.mobs.clear()
	g.trobs.clear()
	g.nextSound = -1
	g.holdingSword = 0
	g.grabTimer = 0
	g.canGuardSeeKid = 0
	g.unitedWithShadow = 0
	g.flashTime = 0
	g.leveldoorOpen = 0
	g.demoIndex = 0
	g.demoTime = 0
	g.guardhpCurr = 0
	g.hitpDelta = 0
	g.guard.charid = charidGuard
	g.guard.direction = dirNone
	g.doStartpos()
	g.haveSword = 1 if n == 0 or n >= g.options.opt("have_sword_from_level") else 0
	g.findStartLevelDoor()
	g.stopSounds()
	if g.replaying: g.replayRestoreLevel()
	g.skippingReplay = false   # a skip ends where a room or a level begins
	g.drawLevelFirst()
	g.showCopyprot(0)

fn doStartpos(mut g Game):
	# special event: level 3's checkpoint
	if g.currentLevel == g.options.opt("checkpoint_level") and g.checkpoint != 0:
		g.level.startDir = g.options.opt("checkpoint_respawn_dir")
		g.level.startRoom = g.options.opt("checkpoint_respawn_room")
		g.level.startPos = g.options.opt("checkpoint_respawn_tilepos")
		g.getTile(
			g.options.opt("checkpoint_clear_tile_room"),
			g.options.opt("checkpoint_clear_tile_col"),
			g.options.opt("checkpoint_clear_tile_row")
		)   # the loose floor there gone
		g.setRoomTile(g.currTilepos, tileEmpty)
	g.char.room = g.level.startRoom
	g.nextRoom = g.char.room
	x = g.level.startPos
	g.char.currCol = x % 10
	g.char.currRow = x / 10
	g.char.x = byte(xBump[g.char.currCol + firstOnscreenColumn] + tileSizeX)
	g.char.direction = sbyte(~g.level.startDir)   # opposite, to turn into it
	if g.seamless == 0:
		hp = g.hitpBegLev if g.currentLevel != 0 else g.options.opt("demo_hitp")
		g.hitpMax = hp
		g.hitpCurr = hp
	if g.options.optAt("tbl_entry_pose", g.currentLevel) == 1:
		# special event: level 1's start presses a button and falls in
		g.getTile(5, 2, 0)
		g.triggerButton(0, 0, -1)
		g.seqtblOffsetChar(seqFall)
	elif g.options.optAt("tbl_entry_pose", g.currentLevel) == 2:
		g.seqtblOffsetChar(seqRun)   # running in
	else:
		g.seqtblOffsetChar(seqTurn)
	g.setStartPos()

pub fn setStartPos(mut g Game):
	g.char.y = byte(yLand[g.char.currRow + 1])
	g.char.alive = -1
	g.char.charid = charidKid
	g.isScreaming = 0
	g.knock = 0
	g.upsideDown = g.options.opt("start_upside_down")
	g.isFeatherFall = 0
	g.char.fallY = 0
	g.char.fallX = 0
	g.offguard = 0
	g.char.sword = swordSheathed
	g.droppedout = 0
	g.playSeq()
	if g.currentLevel == g.options.opt("falling_entry_level") and
		g.char.room == g.options.opt("falling_entry_room"):
		# special event: level 7 starts falling into the room below
		g.gotoOtherRoom(3)
	g.savekid()

fn findStartLevelDoor(mut g Game):
	g.getRoomAddress(g.kid.room)
	for tilepos in 0..30:
		if (g.roomTile(tilepos) & 0x1F) == tileLevelDoorLeft:
			g.startLevelDoor(g.kid.room, tilepos)

fn drawLevelFirst(mut g Game):
	g.nextRoom = g.kid.room
	g.checkTheEnd()
	if g.isPalace():
		g.genPalaceWallColors()
	g.screen.toOnscreen = true
	g.screen.drawRect(g.pal, Rect(0, 0, 200, 320), colorBlack)
	g.showLevel()
	g.redrawScreen(false)
	g.drawKidHp(g.hitpCurr, g.hitpMax)

# redraw_screen: the whole room drawn afresh, then what moves
pub fn redrawScreen(mut g Game, differentRoomDrawn bool):
	if differentRoomDrawn:
		g.screen.drawRect(g.pal, Rect(0, 0, 192, 320), colorBlack)
	g.differentRoom = 0
	g.needDrects = false
	if g.isBlindMode != 0:
		g.screen.drawRect(g.pal, Rect(0, 0, 192, 320), colorBlack)
	else:
		if g.currGuardColor != 0:
			g.setTablePalette(chtabGuard, 0x30 * g.currGuardColor - 0x30, -1, g.guardPalettes)
		g.redrawRoom()
		g.isBlindMode = 1
		g.drawTables()
		g.drawCopyprotLetters()
		g.isBlindMode = 0
		g.clearTables()
		g.drawMoving()
		g.drawTables()
		g.needDrects = true
		g.screen.copyToOnscreen(g.upsideDown != 0)
	g.exitRoomTimer = 2

# play_level_2's loop, once: false when the game ends (time out, or the end)
pub fn runFrame(mut g Game, frameInput Input) bool:
	running = g.runFrameOnce(frameInput)
	while running and g.replaying and g.skippingReplay:
		running = g.runFrameOnce(Input())
	running

fn runFrameOnce(mut g Game, frameInput Input) bool:
	g.input = frameInput.copy()
	if g.inShow:
		g.runShowTick()
		return not g.gameOver
	if g.dialogWait:
		if not g.hasKey(): return true
		g.dialogWait = false
		g.needFullRedraw = 1
	if g.saveReplayWait:
		g.saveReplayTick()
		return true
	if g.menu.shown:
		if not g.menuTick(): return true
		if g.gameOver: return false
		return true if g.inShow else g.endFrame()
	if g.pausedWait:
		if not g.pauseTick(): return true
		return g.endFrame()
	g.checkQuickOp()
	g.frameLength = g.frameTicks()   # the timer is set before the frame
	g.guardhpDelta = 0
	g.hitpDelta = 0
	g.soundsPlayed.clear()
	g.flashShown = -1
	g.timers()
	g.playFrame()
	if g.gameOver: return false
	if g.inShow: return true   # a key or the end of a replay went to the title
	if g.pendingStart >= 0:
		n = g.pendingStart
		g.pendingStart = -1
		g.initCopyprot()
		g.startGameAt(n)
		return true
	if g.pausedWait or g.menu.shown: return true   # the frame ends when the pause does
	g.endFrame()

# the end of the frame play_level_2 makes of what play_frame did: the level started again, the
# next level, or the screen drawn
fn endFrame(mut g Game):
	# at the level's last frame the seed is kept, whatever the sound that plays on does with it
	if g.keepLastSeed == 1:
		g.preservedSeed = g.randomSeed
		g.keepLastSeed = -1
	if g.isRestartLevel:
		g.isRestartLevel = false
		g.playLevel(g.levelAfter(g.currentLevel))
	elif g.nextLevel == g.currentLevel or g.isSoundPlaying():
		g.drawGameFrame()
		g.flashIfHurt()
		g.removeFlashIfHurt()
		g.tickSounds(g.frameLength)
	else:
		g.stopSounds()
		g.hitpBegLev = g.hitpMax
		g.checkpoint = 0
		if g.keepLastSeed == -1:
			g.randomSeed = g.preservedSeed
			g.keepLastSeed = 0
		next = g.levelAfter(g.nextLevel)
		if next > 15:
			g.gameOver = true
			return false
		g.playLevel(next)
	not g.gameOver

# the ticks of 60 a second a frame lasts: 5, or 6 in a sword fight
pub fn frameTicks(g Game) i64:
	if g.inShow or g.saveReplayWait or g.menu.shown: return 1
	g.options.opt("fight_speed") if g.kid.sword == swordDrawn else g.options.opt("base_speed")

pub fn redrawAtChar(mut g Game):
	if g.char.sword >= swordDrawn:
		# a drawn sword widens what is drawn again
		if g.char.direction >= dirRight:
			g.charColRight = (g.charColRight + 1).min(9)
		else:
			g.charColLeft = (g.charColLeft - 1).max(0)
	topRow = g.charTopRow
	colRight = g.charColRight
	colLeft = g.charColLeft
	if g.char.charid == charidKid:
		topRow = g.charTopRow.min(g.prevCharTopRow)
		colRight = g.charColRight.max(g.prevCharColRight)
		colLeft = g.charColLeft.min(g.prevCharColLeft)
	row = topRow
	while row <= g.charBottomRow:
		col = colLeft
		while col <= colRight:
			g.setRedrawFore(getTilepos(col, row), 1)
			col += 1
		row += 1
	if g.char.charid == charidKid:
		g.prevCharTopRow = g.charTopRow
		g.prevCharColRight = g.charColRight
		g.prevCharColLeft = g.charColLeft

pub fn redrawAtChar2(mut g Game):
	action = g.char.action
	frame = g.char.frame
	overlay = false
	if frame < 78 or frame >= 80:
		if frame >= 137 and frame < 145:
			overlay = true   # climbing up
		elif action != actHangClimb and action != actInMidair and action != actInFreefall and
			action != actHangStraight and (action != actBumped or frame < 102 or frame > 106):
			return
	g.tileCol = g.charColRight
	while g.tileCol >= g.charColLeft:
		if action != 2:
			g.redrawFunc(overlay, getTilepos(g.tileCol, g.charBottomRow))
		if g.charTopRow != g.charBottomRow:
			g.redrawFunc(overlay, getTilepos(g.tileCol, g.charTopRow))
		g.tileCol -= 1

fn redrawFunc(mut g Game, overlay bool, tilepos i64):
	if overlay:
		g.setRedrawFloorOverlay(tilepos, 1)
	else:
		g.setRedraw2(tilepos, 1)

pub fn checkKnock(mut g Game):
	if g.knock != 0:
		g.doKnock(g.char.room, g.char.currRow - (1 if g.knock > 0 else 0))
		g.knock = 0

fn timers(mut g Game):
	if g.unitedWithShadow > 0:
		g.unitedWithShadow -= 1
		if g.unitedWithShadow == 0: g.unitedWithShadow -= 1
	if g.guardNoticeTimer > 0: g.guardNoticeTimer -= 1
	if g.resurrectTime > 0: g.resurrectTime -= 1
	if g.isFeatherFall != 0: g.isFeatherFall += 1
	if g.isFeatherFall != 0 and (not g.isSoundPlaying() or g.isFeatherFall > 225):
		if g.recording: g.specialMove = moveEffectEnd
		if not g.replaying: g.isFeatherFall = 0   # a replay's special move ends it
	# special event: the mouse of level 8
	if g.currentLevel == g.options.opt("mouse_level") and
		g.char.room == g.options.opt("mouse_room") and
		g.leveldoorOpen != 0:
		g.leveldoorOpen += 1
		if g.leveldoorOpen == g.options.opt("mouse_delay"):
			g.doMouse()

pub fn checkMirror(mut g Game):
	if g.jumpedThroughMirror == -1:
		g.jumpThroughMirror()
		return
	if g.getTileAtChar() != tileMirror: return
	g.loadkid()
	g.loadFrame()
	g.checkMirrorImage()
	if g.distanceMirror >= 0 and g.options.isOn("show_mirror_image") and
		g.char.room == g.drawnRoom:
		g.loadFrameToObj()
		g.resetObjClip()
		clipTop = word(yClip[g.char.currRow + 1])
		if clipTop < g.objY:
			g.objClipTop = clipTop
			g.objClipLeft = (g.char.currCol << 5) + 9
			g.addObjtable(4)   # the mirror image

fn jumpThroughMirror(mut g Game):
	g.loadkid()
	g.loadFrame()
	g.checkMirrorImage()
	g.jumpedThroughMirror = 0
	g.char.charid = charidShadow
	g.playSound(soundJumpThroughMirror)
	g.saveshad()
	g.guardhpMax = g.hitpMax
	g.guardhpCurr = g.hitpMax
	g.hitpCurr = 1
	g.drawKidHp(1, g.hitpMax)
	g.drawGuardHp(g.guardhpCurr, g.guardhpMax)

fn checkMirrorImage(mut g Game):
	xpos = xBump[g.char.currCol + firstOnscreenColumn] + 10
	distance = g.distanceToEdgeWeight()
	if g.char.direction >= dirRight:
		distance = short(~distance + tileSizeX)
	g.distanceMirror = sbyte(distance - 2)
	g.char.x = byte((xpos << 1) - g.char.x)
	g.char.direction = sbyte(~g.char.direction)

pub fn bumpIntoOpponent(mut g Game):
	# from play_kid_frame: char the kid, opp the guard
	if g.canGuardSeeKid >= 2 and g.char.sword == swordSheathed and g.opp.sword != swordSheathed and
		g.opp.action < 2 and g.char.direction != g.opp.direction:
		if g.charOppDist().abs() <= 15:
			g.char.y = byte(yLand[g.char.currRow + 1])
			g.char.fallY = 0
			g.seqtblOffsetChar(seqBump)
			g.playSeq()

fn posGuards(mut g Game):
	for r in 0..roomCount:
		t = g.level.guards[r].tile
		if t < 30:
			g.level.guards[r].x = xBump[(t % 10) + firstOnscreenColumn] + tileSizeX
			g.level.guards[r].seq &= 0xFF

# can_guard_see_kid: 0 not, 1 sees him but won't come, 2 sees him and comes
pub fn checkCanGuardSeeKid(mut g Game):
	kidFrame = g.kid.frame
	if g.guard.charid == charidMouse:
		g.canGuardSeeKid = 0
		return
	if (g.guard.charid != charidShadow or g.currentLevel == 12) and kidFrame != 0 and
		(kidFrame < 219 or kidFrame >= 229) and g.guard.direction != dirNone and g.kid.alive < 0 and
		g.guard.alive < 0 and g.kid.room == g.guard.room and g.kid.currRow == g.guard.currRow:
		g.canGuardSeeKid = 2
		leftPos = xBump[g.kid.currCol + firstOnscreenColumn] + tileMidX
		rightPos = xBump[g.guard.currCol + firstOnscreenColumn] + tileMidX
		if leftPos > rightPos:
			temp = leftPos
			leftPos = rightPos
			rightPos = temp
		# a chomper is on its tile's left, a gate on its right: neither counts
		if g.getTileAtKid(leftPos) == tileChomper: leftPos += tileSizeX
		if g.getTileAtKid(rightPos) == tileGate: rightPos -= tileSizeX
		if rightPos >= leftPos:
			while leftPos <= rightPos:
				if g.getTileAtKid(leftPos) == tileWall or g.currTile2 == tileDoortopWithFloor or
					g.currTile2 == tileDoortop:
					g.canGuardSeeKid = 0
					return
				if g.currTile2 == tileLoose or g.currTile2 == tileChomper or
					(g.currTile2 == tileGate and g.roomMod(g.currTilepos) < 112) or
					not tileIsFloor(g.currTile2):
					g.canGuardSeeKid = 1   # seen through, but not crossed
				leftPos += tileSizeX
	else:
		g.canGuardSeeKid = 0

fn getTileAtKid(mut g Game, xpos i64) i64:
	g.getTile(g.kid.room, g.getTileDivModM7(xpos), g.kid.currRow)

fn doMouse(mut g Game):
	g.loadkid()
	g.char.charid = g.options.opt("mouse_object")
	g.char.x = g.options.opt("mouse_start_x")
	g.char.currRow = 0
	g.char.y = byte(yLand[g.char.currRow + 1])
	g.char.alive = -1
	g.char.direction = dirLeft
	g.guardhpCurr = 1
	g.seqtblOffsetChar(seqMouseForward)
	g.playSeq()
	g.saveshad()

fn flashIfHurt(mut g Game):
	if g.flashTime != 0:
		g.doFlash(g.flashColor)
		return true
	if g.hitpDelta < 0:
		g.doFlash(colorBrightRed)
		return true
	false

fn removeFlashIfHurt(mut g Game):
	if g.flashTime != 0:
		g.flashTime -= 1
	elif g.hitpDelta >= 0:
		return
	g.removeFlash()

# do_flash: for 2 ticks the screen's black shows in the colour (set_bg_attr); the frame keeps it
# for the display to show
fn doFlash(mut g Game, color i64):
	if color != 0 and g.options.isOn("enable_flash"): g.flashShown = color

fn removeFlash(mut g Game):
	g.screen.copyToOnscreen(g.upsideDown != 0)

# the display as the flash showed it (set_bg_attr): its gameplay's black in the flash's colour
pub fn flashedScreen(g Game) image.Image:
	shown = g.screen.onscreen.copy()
	if g.flashShown < 0: return shown
	c = g.pal.colors[g.flashShown]
	for y in 0..gameplayHeight:
		for x in 0..screenWidth:
			p = shown[x, y]
			if p.r == 0 and p.g == 0 and p.b == 0:
				shown[x, y] = c
	shown
