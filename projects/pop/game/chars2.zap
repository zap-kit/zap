# The characters' play, controls and drawing (SDLPoP's seg006.c, the second half; the Apple II's
# CTRLSUBS.S and FRAMEADV.S): a frame of the kid and of the guard, the keys read into the
# controls, what the character presses, where it is clipped, and what it picks up.

pub fn playKid(mut g Game):
	g.fellOut()
	g.controlKid()
	if g.char.alive >= 0 and g.isDead():
		if g.resurrectTime != 0:
			g.stopSounds()
			g.loadkid()
			g.hitpDelta = g.hitpMax
			g.seqtblOffsetChar(seqStand)
			g.char.x = byte(g.char.x + 8)
			g.playSeq()
			g.loadFramDetCol()
			g.setStartPos()
		if g.isSoundPlaying() and g.currentSound != soundGateOpening: return
		g.isShowTime = 0
		if g.char.alive < 0 or g.char.alive >= 6:
			if g.char.alive == 6:
				if g.currentLevel != 0 and g.currentLevel != 15:
					g.playDeathMusic()
			else:
				if g.char.alive != 7 or g.isSoundPlaying(): return
				if g.remMin == 0:
					g.expired()
				if g.currentLevel != 0 and g.currentLevel != 15:
					g.textTimeRemaining = 288
					g.textTimeTotal = 288
					g.displayTextBottom("Press Button to Continue")
				else:
					g.textTimeRemaining = 36
					g.textTimeTotal = 36
		g.char.alive = sbyte(g.char.alive + 1)

pub fn controlKid(mut g Game):
	if g.char.alive < 0 and g.hitpCurr == 0:
		g.char.alive = 0
	if g.grabTimer != 0:
		g.grabTimer -= 1
	if g.currentLevel == 0 and not g.replaying:
		g.doDemo()
		g.control()
		g.demoKey()
	else:
		g.restCtrl1()
		g.doPaused()
		if g.recording: g.addReplayMove()
		if g.replaying: g.doReplayMove()
		g.readUserControl()
		g.userControl()
		g.saveCtrl1()

# do_demo: the demo level's kid moves by itself
pub fn doDemo(mut g Game):
	if g.checkpoint != 0:
		g.controlShift2 = g.releaseArrows()
		g.controlForward = ctrlHeld
		g.controlX = ctrlHeldForward
	elif g.char.sword != 0:
		g.guardSkill = 10
		g.autocontrolOpponent()
		g.guardSkill = 11
	else:
		g.doAutoMoves(demoMoves)

pub fn playGuard(mut g Game):
	if g.char.charid == charidMouse:
		g.autocontrolOpponent()
		return
	if g.char.alive < 0:
		if g.guardhpCurr != 0:
			g.autocontrolOpponent()
			g.control()
			return
		g.char.alive = 0
		g.onGuardKilled()
	if g.char.charid == charidShadow:
		g.clearChar()
	g.autocontrolOpponent()
	g.control()

pub fn userControl(mut g Game):
	if g.char.direction >= dirRight:
		g.flipControlX()
		g.control()
		g.flipControlX()
	else:
		g.control()

pub fn flipControlX(mut g Game):
	g.controlX = sbyte(-g.controlX)
	temp = g.controlForward
	g.controlForward = g.controlBackward
	g.controlBackward = temp

pub fn releaseArrows(mut g Game) i64:
	g.controlBackward = ctrlReleased
	g.controlForward = ctrlReleased
	g.controlUp = ctrlReleased
	g.controlDown = ctrlReleased
	1

pub fn saveCtrl1(mut g Game):
	g.ctrl1Forward = g.controlForward
	g.ctrl1Backward = g.controlBackward
	g.ctrl1Up = g.controlUp
	g.ctrl1Down = g.controlDown
	g.ctrl1Shift2 = g.controlShift2

pub fn restCtrl1(mut g Game):
	g.controlForward = g.ctrl1Forward
	g.controlBackward = g.ctrl1Backward
	g.controlUp = g.ctrl1Up
	g.controlDown = g.ctrl1Down
	g.controlShift2 = g.ctrl1Shift2

pub fn clearSavedCtrl(mut g Game):
	g.ctrl1Forward = ctrlReleased
	g.ctrl1Backward = ctrlReleased
	g.ctrl1Up = ctrlReleased
	g.ctrl1Down = ctrlReleased
	g.ctrl1Shift2 = ctrlReleased

# a control from its key: held when the key goes down, released when it goes up; one held or
# ignored stays so while the key is down
fn readControl(c i64, keyDown bool):
	if c < ctrlReleased: return c
	if not keyDown: return ctrlReleased
	if c == ctrlReleased: return ctrlHeld
	c

pub fn readUserControl(mut g Game):
	g.controlForward = readControl(g.controlForward, g.controlX == ctrlHeldForward)
	g.controlBackward = readControl(g.controlBackward, g.controlX == ctrlHeldBackward)
	g.controlUp = readControl(g.controlUp, g.controlY == ctrlHeldUp)
	g.controlDown = readControl(g.controlDown, g.controlY == ctrlHeldDown)
	g.controlShift2 = readControl(g.controlShift2, g.controlShift == ctrlHeld)

# can_grab: whether the char can grab curr_tile2 through through_tile
pub fn canGrab(mut g Game) bool:
	modifier = g.roomMod(g.currTilepos)
	if g.throughTile == tileWall: return false
	if g.throughTile == tileDoortop and g.char.direction >= dirRight: return false
	if tileIsFloor(g.throughTile): return false
	if g.currTile2 == tileLoose and modifier != 0: return false
	if g.currTile2 == tileDoortopWithFloor and g.char.direction < dirRight: return false
	tileIsFloor(g.currTile2)

pub fn wallType(tiletype i64) i64:
	if tiletype in [tileGate, tileDoortopWithFloor, tileDoortop]: return 1   # wall at right
	if tiletype == tileMirror: return 2   # wall at left
	if tiletype == tileChomper: return 3   # chomper at left
	if tiletype == tileWall: return 4   # both sides
	0

pub fn getTileAboveChar(mut g Game) i64:
	g.getTile(g.char.room, g.char.currCol, g.char.currRow - 1)

pub fn getTileBehindAboveChar(mut g Game) i64:
	g.getTile(g.char.room, dirBehind[g.char.direction + 1] + g.char.currCol, g.char.currRow - 1)

pub fn getTileFrontAboveChar(mut g Game) i64:
	g.infrontx = sbyte(dirFront[g.char.direction + 1] + g.char.currCol)
	g.getTile(g.char.room, g.infrontx, g.char.currRow - 1)

pub fn backDeltaX(g Game, deltaX i64) i64:
	deltaX if g.char.direction < dirRight else -deltaX

pub fn doPickup(mut g Game, objType i64):
	g.pickupObjType = objType
	g.controlShift2 = ctrlIgnore
	g.setRoomTile(g.currTilepos, tileFloor)
	g.setRoomMod(g.currTilepos, 0)
	g.redrawHeight = 35
	g.setWipe(g.currTilepos, 1)
	g.setRedrawFull(g.currTilepos, 1)

pub fn checkPress(mut g Game):
	frame = g.char.frame
	action = g.char.action
	if (frame >= 87 and frame < 100) or (frame >= 135 and frame < 141):
		# hanging or starting to climb: the tile grabbed
		g.getTileAboveChar()
	elif action == actTurn or action == actBumped or action < actHangClimb:
		if frame == 79 and g.getTileAboveChar() == tileLoose:
			g.makeLooseFall(1)   # jumping up breaks the loose floor above
			return
		if g.curFrame.flags & frameNeedsFloor == 0: return
		g.getTileAtChar()
	else:
		return
	if g.currTile2 == tileOpener or g.currTile2 == tileCloser:
		if g.char.alive < 0:
			g.triggerButton(1, 0, -1)
		else:
			g.diedOnButton()
	elif g.currTile2 == tileLoose:
		g.isGuardNotice = 1
		g.makeLooseFall(1)

pub fn checkSpikeBelow(mut g Game):
	rightCol = g.getTileDivModM7(g.charXRight)
	if rightCol < 0: return
	room = g.char.room
	col = g.getTileDivModM7(g.charXLeft)
	while col <= rightCol:
		row = g.char.currRow
		loop:
			if g.getTile(room, col, row) == tileSpike:
				g.startAnimSpike(g.currRoom, g.currTilepos)
				break
			if tileIsFloor(g.currTile2) or g.currRoom == 0 or room != g.currRoom: break
			row += 1
		col += 1

# clip_char: the character hidden behind the walls and door tops in front of it
pub fn clipChar(mut g Game):
	frame = g.char.frame
	action = g.char.action
	room = g.char.room
	row = g.char.currRow
	g.resetObjClip()
	if frame >= 224 and frame < 229:
		# going up the level door's stairs
		g.objClipTop = g.leveldoorYbottom + 1
		g.objClipRight = g.leveldoorRight
		return
	if g.getTile(room, g.charColLeft, g.charTopRow) == tileWall or tileIsFloor(g.currTile2):
		if (action == actStand and (frame == 79 or frame == 81)) or
			g.getTile(room, g.charColRight, g.charTopRow) == tileWall or tileIsFloor(g.currTile2):
			clipRow = row + 1
			clipY = yClip[clipRow]
			if clipRow == 1 or (clipY < g.objY and clipY - 15 < g.charTopY):
				g.charTopY = clipY
				g.objClipTop = clipY
	col = g.getTileDivMod(g.charXLeftColl - 4)
	if g.getTile(room, col + 1, row) == tileDoortopWithFloor or g.currTile2 == tileDoortop:
		g.objClipRight = (g.tileCol << 5) + 32
		return
	hanging = action == actHangClimb or action == actHangStraight or
		(action == actRunJump and frame >= 137 and frame < 140)
	if (g.getTile(room, col, row) != tileDoortopWithFloor and g.currTile2 != tileDoortop) or
		action == actInMidair or (action == actInFreefall and frame == 106) or
		(action == actBumped and frame == 107) or (g.char.direction < dirRight and hanging):
		col = g.getTileDivMod(g.charXRightColl)
		if (
			g.getTile(room, col, row) == tileWall or
				(g.currTile2 == tileMirror and g.char.direction == dirRight)
		) and
			(g.getTile(room, col, g.charTopRow) == tileWall or g.currTile2 == tileMirror) and
			room == g.currRoom:
			g.objClipRight = g.tileCol << 5
	else:
		g.objClipRight = (g.tileCol << 5) + 32

pub fn stuckLower(mut g Game):
	if g.getTileAtChar() == tileStuck:
		g.char.y = byte(g.char.y + 1)

pub fn setObjtileAtChar(mut g Game):
	frame = g.char.frame
	action = g.char.action
	if action == actRunJump:
		g.tileRow = g.charBottomRow
		g.tileCol = g.charColLeft
	else:
		g.tileRow = g.char.currRow
		g.tileCol = g.char.currCol
	if (frame >= 135 and frame < 149) or action == actHangClimb or action == actInMidair or
		action == actInFreefall or action == actHangStraight:
		g.tileCol -= 1
	g.objTilepos = byte(getTileposNominus(g.tileCol, g.tileRow))

pub fn procGetObject(mut g Game):
	if g.char.charid != charidKid or g.pickupObjType == 0: return
	if g.pickupObjType == -1:
		g.haveSword = -1
		g.playSound(soundVictory)
		g.flashColor = colorBrightYellow
		g.flashTime = 8
	elif g.pickupObjType == 1:
		# health
		if g.hitpCurr != g.hitpMax:
			g.stopSounds()
			g.playSound(soundSmallPotion)
			g.hitpDelta = 1
			g.flashColor = colorRed
			g.flashTime = 2
	elif g.pickupObjType == 2:
		# life
		g.stopSounds()
		g.playSound(soundBigPotion)
		g.flashColor = colorRed
		g.flashTime = 4
		g.addLife()
	elif g.pickupObjType == 3:
		g.featherFall()
	elif g.pickupObjType == 4:
		g.toggleUpside()
	elif g.pickupObjType == 6:
		# open
		g.getTile(8, 0, 0)
		g.triggerButton(0, 0, -1)
	elif g.pickupObjType == 5:
		# hurt; on the potions level, half the hit points
		g.stopSounds()
		g.playSound(soundKidHurt)
		g.hitpDelta = -((g.hitpMax + 1) >> 1) if g.currentLevel == 15 else -1

# spiked, chomped or dead
pub fn isDead(g Game) bool:
	g.char.frame >= 177 and (g.char.frame <= 178 or g.char.frame == 185)

pub fn playDeathMusic(mut g Game):
	if g.guard.charid == charidShadow:
		g.playSound(soundShadowMusic)
	elif g.holdingSword != 0:
		g.playSound(soundDeathInFight)
	else:
		g.playSound(soundDeathRegular)

pub fn onGuardKilled(mut g Game):
	if g.currentLevel == 0:
		# the demo: run out of the room
		g.checkpoint = 1
		g.demoIndex = 0
		g.demoTime = 0
	elif g.currentLevel == g.options.opt("jaffar_victory_level"):
		# Jaffar's
		g.flashColor = colorBrightWhite
		g.flashTime = g.options.opt("jaffar_victory_flash_time")
		g.isShowTime = 1
		g.leveldoorOpen = 2
		g.playSound(soundVictoryJaffar)
	elif g.char.charid != charidShadow:
		g.playSound(soundVictory)

pub fn clearChar(mut g Game):
	g.char.direction = dirNone
	g.char.alive = 0
	g.char.action = 0
	g.drawGuardHp(0, g.guardhpCurr)
	g.guardhpCurr = 0

pub fn saveObj(mut g Game):
	g.obj2 = ObjVars(
		g.objTilepos,
		g.objX,
		g.objY,
		g.objDirection,
		g.objId,
		g.objChtab,
		g.objClipTop,
		g.objClipBottom,
		g.objClipLeft,
		g.objClipRight
	)

pub fn loadObj(mut g Game):
	g.objTilepos = g.obj2.tilepos
	g.objX = g.obj2.x
	g.objY = g.obj2.y
	g.objDirection = g.obj2.direction
	g.objId = g.obj2.id
	g.objChtab = g.obj2.chtab
	g.objClipTop = g.obj2.clipTop
	g.objClipBottom = g.obj2.clipBottom
	g.objClipLeft = g.obj2.clipLeft
	g.objClipRight = g.obj2.clipRight

pub fn drawHurtSplash(mut g Game):
	frame = g.char.frame
	if frame == 178: return   # chomped
	g.saveObj()
	g.objTilepos = 255
	if frame == 185 or (frame >= 106 and frame < 111):
		# dead, or falling and landing
		g.objY = byte(g.objY + 4)
		g.objDxForward(5)
	elif frame == 177:
		g.objDxForward(-5)   # spiked
	else:
		g.objY = byte(g.objY - (4 if g.char.charid == charidKid else 0) - 11)
		g.objDxForward(5)
	if g.char.charid == charidKid:
		g.objChtab = chtabKid
		g.objId = 218
	else:
		g.objChtab = chtabGuard
		g.objId = 1
	g.resetObjClip()
	g.addObjtable(5)   # the hurt splash
	g.loadObj()

pub fn checkKilledShadow(mut g Game):
	# special event: the shadow killed on level 12
	if g.currentLevel == 12 and (g.char.charid | g.opp.charid) == charidShadow and
		g.char.alive < 0 and
		g.opp.alive >= 0:
		g.flashColor = colorBrightWhite
		g.flashTime = 5
		g.takeHp(100)

pub fn addSwordToObjtable(mut g Game):
	frame = g.char.frame
	if (frame >= 229 and frame < 238) or g.char.sword != swordSheathed or
		(g.char.charid == charidGuard and g.char.alive < 0):
		swordFrame = g.curFrame.sword & 0x3F
		if swordFrame == 0: return
		s = g.tables.swordFrames[swordFrame]
		g.objId = s.image
		if g.objId == 0xFF: return
		g.objX = calcScreenXCoord(g.objX)
		g.objDxForward(s.dx)
		g.objY = byte(g.objY + s.dy)
		g.objChtab = chtabSword
		g.addObjtable(3)   # the sword

pub fn controlGuardInactive(mut g Game):
	if g.char.frame == 166 and g.controlDown == ctrlHeld:
		if g.controlForward == ctrlHeld:
			g.drawSword()
		else:
			g.controlDown = ctrlIgnore
			g.seqtblOffsetChar(seqStandFlipped)

# char_opp_dist: > 0 when the opponent is in front, < 0 behind
pub fn charOppDist(g Game) i64:
	if g.char.room != g.opp.room: return 999
	distance = g.opp.x - g.char.x
	if g.char.direction < dirRight:
		distance = -distance
	if distance >= 0 and g.char.direction != g.opp.direction:
		distance += 13
	distance
