# A frame of play and of drawing (SDLPoP's seg000.c; the Apple II's TOPCTRL.S): the kid's and the
# guard's frames, the rooms changed, the hit points, the time left and the special events of
# the levels' ends.

pub fn playFrame(mut g Game):
	g.doMobs()
	g.processTrobs()
	g.checkSkel()
	g.checkCanGuardSeeKid()
	if g.playKidFrame(): return   # the level starts again
	g.playGuardFrame()
	if g.resurrectTime == 0:
		g.checkSwordHurting()
		g.checkSwordHurt()
	g.checkSwordVsSword()
	g.doDeltaHp()
	g.exitRoom()
	g.checkTheEnd()
	g.checkGuardFallout()
	if g.currentLevel == 0:
		# special event: the demo ends running out of its last room
		if g.kid.room == g.options.opt("demo_end_room"):
			g.startLevel = -1
			g.startTitle()
			return
	elif g.currentLevel == g.options.opt("falling_exit_level"):
		# special event: level 6 ends falling
		if g.roomleaveResult == -2:
			g.kid.y = 255
			g.stopSounds()
			g.nextLevel += 1
	elif g.options.optAt("tbl_seamless_exit", g.currentLevel) >= 0:
		# special event: level 12 ends running into room 23
		if g.kid.room == g.options.optAt("tbl_seamless_exit", g.currentLevel):
			g.nextLevel += 1
			g.stopSounds()
			g.seamless = 1
	g.showTime()
	# time out (not on Jaffar's and the princess's levels)
	if g.currentLevel < 13 and g.remMin == 0:
		g.expired()

pub fn drawGameFrame(mut g Game):
	if g.needFullRedraw != 0:
		g.redrawScreen(false)
		g.needFullRedraw = 0
	elif g.differentRoom != 0:
		g.drawnRoom = g.nextRoom
		if g.isPalace():
			g.genPalaceWallColors()
		g.redrawScreen(true)
	elif g.needRedrawBecauseFlipped != 0:
		g.needRedrawBecauseFlipped = 0
		g.redrawScreen(false)
	else:
		g.clearTables()
		g.drawMoving()
		g.drawTables()
		if g.isBlindMode != 0:
			g.screen.drawRect(g.pal, Rect(0, 0, 192, 320), colorBlack)   # on the display (the original's)
		g.copyDrects()
	g.playNextSound()
	# texts are known by their total time
	if g.textTimeRemaining == 1:
		if g.textTimeTotal == 36 or g.textTimeTotal == 288:
			# died on the demo or the potions level, or "press button": the game starts over
			g.startTitle()
			return
		else:
			g.eraseBottomText(true)
	elif g.textTimeRemaining != 0 and g.textTimeTotal != 1188:
		g.textTimeRemaining -= 1
		if g.textTimeTotal == 288 and g.textTimeRemaining < 72:
			# "press button to continue" blinks
			blinkFrame = g.textTimeRemaining % 12
			if blinkFrame > 3:
				g.eraseBottomText(false)
			elif blinkFrame == 3:
				g.displayTextBottom("Press Button to Continue")
				g.startSound(soundBlink)

pub fn animTileModif(mut g Game):
	for tilepos in 0..30:
		t = g.getCurrTile(tilepos)
		if t == tilePotion:
			g.startAnimPotion(g.drawnRoom, tilepos)
		elif t == tileTorch or t == tileTorchWithDebris:
			g.startAnimTorch(g.drawnRoom, tilepos)
		elif t == tileSword:
			g.startAnimSword(g.drawnRoom, tilepos)
	# the torches of the left room's last column show here
	for row in 0..3:
		t = g.getTile(g.roomL, 9, row)
		if t == tileTorch or t == tileTorchWithDebris:
			g.startAnimTorch(g.roomL, row * 10 + 9)

fn playKidFrame(mut g Game):
	g.loadkidAndOpp()
	g.loadFramDetCol()
	g.checkKilledShadow()
	g.playKid()
	if g.inShow: return true   # the game went to its title (a replay ended, or Ctrl+R)
	if g.upsideDown != 0 and g.char.alive >= 0:
		g.upsideDown = 0
		g.needRedrawBecauseFlipped = 1
	if g.isRestartLevel: return true
	if g.char.room != 0:
		g.playSeq()
		g.fallAccel()
		g.fallSpeed()
		g.loadFrameToObj()
		g.loadFramDetCol()
		g.setCharCollision()
		g.bumpIntoOpponent()
		g.checkCollisions()
		g.checkBumped()
		g.checkGatePush()
		g.checkAction()
		g.checkPress()
		g.checkSpikeBelow()
		if g.resurrectTime == 0:
			g.checkSpiked()
			g.checkChompedKid()
		g.checkKnock()
	g.savekid()
	false

fn playGuardFrame(mut g Game):
	if g.guard.direction == dirNone: return
	g.loadshadAndOpp()
	g.loadFramDetCol()
	g.checkKilledShadow()
	g.playGuard()
	if g.char.room == g.drawnRoom:
		g.playSeq()
		if g.char.x >= 44 and g.char.x < 211:
			g.fallAccel()
			g.fallSpeed()
			g.loadFrameToObj()
			g.loadFramDetCol()
			g.setCharCollision()
			g.checkGuardBumped()
			g.checkAction()
			g.checkPress()
			g.checkSpikeBelow()
			g.checkSpiked()
			g.checkChompedGuard()
	g.saveshad()

pub fn checkTheEnd(mut g Game):
	if g.nextRoom == 0 or g.nextRoom == g.drawnRoom: return
	g.drawnRoom = g.nextRoom
	g.loadRoomLinks()
	if g.currentLevel == 14 and g.drawnRoom == 5:
		g.endSequence()   # special event: the end of the game
		return
	g.differentRoom = 1
	g.loadkid()
	g.animTileModif()
	g.startChompers()
	g.checkFallFlo()
	g.checkShadow()

fn checkFallFlo(mut g Game):
	# special event: level 13's floors fall by themselves
	if g.currentLevel == g.options.opt("loose_tiles_level") and
		(
			g.drawnRoom == g.options.opt("loose_tiles_room_1") or
				g.drawnRoom == g.options.opt("loose_tiles_room_2")
		):
		g.currRoom = g.roomA
		g.getRoomAddress(g.currRoom)
		g.currTilepos = g.options.opt("loose_tiles_first_tile")
		while g.currTilepos <= g.options.opt("loose_tiles_last_tile"):
			g.makeLooseFall(byte(-(g.prandom(0xFF) & 0x0F)))
			g.currTilepos += 1

# ---------- hit points ----------

pub fn drawKidHp(mut g Game, currHp i64, maxHp i64):
	i = currHp
	while i < maxHp:
		g.blitOnscreen(chtabKid, 217, i * 7, 194, blitNoTransp)   # empty
		i += 1
	i = 0
	while i < currHp:
		g.blitOnscreen(chtabKid, 216, i * 7, 194, blitNoTransp)   # full
		i += 1

pub fn drawGuardHp(mut g Game, currHp i64, maxHp i64):
	if g.chtabs[chtabGuard] == none: return
	id = g.guard.charid
	if id == charidSkeleton or id == charidMouse or (id == charidShadow and g.currentLevel != 12):
		return
	i = currHp
	while i < maxHp:
		g.blitOnscreen(chtabGuard, 0, 314 - i * 7, 194, blitBlack)
		i += 1
	i = 0
	while i < currHp:
		g.blitOnscreen(chtabGuard, 0, 314 - i * 7, 194, blitNoTransp)
		i += 1

# a picture straight onto the displayed screen (method_6_blit_img_to_scr outside the tables)
fn blitOnscreen(mut g Game, chtab i64, id i64, x i64, y i64, blit i64):
	saved = g.screen.toOnscreen
	g.screen.toOnscreen = true
	g.drawImage(chtab, id, x, y, blit, false)
	g.screen.toOnscreen = saved

pub fn addLife(mut g Game):
	g.hitpMax = (g.hitpMax + 1).min(10)
	g.hitpDelta = g.hitpMax - g.hitpCurr

pub fn drawHp(mut g Game):
	if g.hitpDelta != 0:
		g.drawKidHp(g.hitpCurr, g.hitpMax)
	blink = (g.remTick & 1) != 0
	if g.hitpCurr == 1 and g.currentLevel != 15:
		# the last hit point blinks
		if blink:
			g.drawKidHp(1, 0)
		else:
			g.drawKidHp(0, 1)
	if g.guardhpDelta != 0:
		g.drawGuardHp(g.guardhpCurr, g.guardhpMax)
	if g.guardhpCurr == 1:
		if blink:
			g.drawGuardHp(1, 0)
		else:
			g.drawGuardHp(0, 1)

fn doDeltaHp(mut g Game):
	# level 12: the shadow's hurts are the kid's
	if g.opp.charid == charidShadow and g.currentLevel == 12 and g.guardhpDelta != 0:
		g.hitpDelta = g.guardhpDelta
	g.hitpCurr = (g.hitpCurr + g.hitpDelta).clamp(0, g.hitpMax)
	g.guardhpCurr = (g.guardhpCurr + g.guardhpDelta).clamp(0, g.guardhpMax)

fn checkSwordVsSword(mut g Game):
	if g.kid.frame == 167 or g.guard.frame == 167:
		g.playSound(soundSwordVsSword)

pub fn toggleUpside(mut g Game):
	g.upsideDown = ~g.upsideDown
	g.needRedrawBecauseFlipped = 1

pub fn featherFall(mut g Game):
	g.isFeatherFall = 1
	g.flashColor = 2   # green
	g.flashTime = 3
	g.stopSounds()
	g.playSound(soundLowWeight)

# ---------- the time and the bottom line ----------

pub fn showTime(mut g Game):
	if g.kid.alive < 0 and g.remMin != 0 and
		(
			g.currentLevel < g.options.opt("victory_stops_time_level") or
				(
					g.currentLevel == g.options.opt("victory_stops_time_level") and
						g.leveldoorOpen == 0
				)
		) and g.currentLevel < 15:
		# time passes
		g.remTick -= 1
		if g.remTick == 0:
			g.remTick = 719   # 720 ticks of 12 a second: a minute
			g.remMin -= 1
			if g.remMin != 0 and (g.remMin <= 5 or g.remMin % 5 == 0):
				g.isShowTime = 1
		elif g.remMin == 1 and g.remTick % 12 == 0:
			g.isShowTime = 1
			g.textTimeRemaining = 0
	if g.isShowTime != 0 and g.textTimeRemaining == 0:
		g.textTimeRemaining = 24
		g.textTimeTotal = 24
		if g.remMin > 0:
			if g.remMin == 1:
				remSec = (g.remTick + 1) / 12
				if remSec == 1:
					g.textTimeRemaining = 12
					g.textTimeTotal = 12
					g.displayTextBottom("1 SECOND LEFT")
				else:
					g.displayTextBottom("{remSec} SECONDS LEFT")
			else:
				g.displayTextBottom("{g.remMin} MINUTES LEFT")
		else:
			g.displayTextBottom("TIME HAS EXPIRED!")
		g.isShowTime = 0

pub fn showLevel(mut g Game):
	shown = g.currentLevel
	if shown != 0 and shown < g.options.opt("hide_level_number_from_level") and g.seamless == 0:
		if shown == 13: shown = g.options.opt("level_13_level_number")
		g.textTimeRemaining = 24
		g.textTimeTotal = 24
		g.displayTextBottom("LEVEL {shown}")
		g.isShowTime = 1
	g.seamless = 0

pub fn expired(mut g Game):
	g.expiredShow()   # the hourglass's cutscene, then the title
