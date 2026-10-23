# The controls turned into moves (SDLPoP's seg005.c; the Apple II's CTRL.S): falling and landing,
# standing, running, jumping, climbing and hanging, picking things up and the sword fight.

pub fn doFall(mut g Game):
	if g.isScreaming == 0 and g.char.fallY >= 31:
		g.playSound(soundFalling)
		g.isScreaming = 1
	if word(yLand[g.char.currRow + 1]) > word(g.char.y):
		g.checkGrab()
		return
	if g.getTileAtChar() == tileWall:
		g.inWall()
	if tileIsFloor(g.currTile2):
		g.land()
	else:
		g.incCurrRow()

fn land(mut g Game):
	g.isScreaming = 0
	g.char.y = byte(yLand[g.char.currRow + 1])
	checkFall = false
	if g.getTileAtChar() == tileSpike:
		if g.landOnSpikes(): return
		checkFall = true
	else:
		if not tileIsFloor(g.getTileInfrontofChar()) and g.distanceToEdgeWeight() < 3:
			g.char.x = byte(g.charDxForward(-3))
		g.startChompers()
		if g.char.alive < 0:
			if (g.distanceToEdgeWeight() >= 12 and g.getTileBehindChar() == tileSpike) or
				g.getTileAtChar() == tileSpike:
				if g.landOnSpikes(): return
			checkFall = true
	seqId = 0
	if not checkFall:
		g.takeHp(100)   # dead already
		seqId = g.fellToDeath()
	elif g.char.fallY < 22 or (g.char.fallY < 33 and g.char.charid == charidShadow):
		seqId = g.softLand()
	elif g.char.fallY < 33 and g.char.charid != charidGuard:
		# two rows: the kid (or a skeleton) loses a hit point
		if not g.takeHp(1):
			g.playSound(soundMediumLand)
			g.isGuardNotice = 1
			seqId = seqMediumLand
		else:
			seqId = g.fellToDeath()
	else:
		g.takeHp(100)
		seqId = g.fellToDeath()
	g.seqtblOffsetChar(seqId)
	g.playSeq()
	g.char.fallY = 0

# the spikes the character fell on: true when they killed it
fn landOnSpikes(mut g Game):
	if g.isSpikeHarmful() != 0:
		g.spiked()
		return true
	false

fn softLand(mut g Game):
	seqId = seqSoftLand   # crouch
	if g.char.charid >= charidGuard or g.char.sword == swordDrawn:
		g.char.sword = swordDrawn
		seqId = seqGuardActiveAfterFall
	if g.char.charid == charidKid:
		g.playSound(soundSoftLand)
		g.isGuardNotice = 1
	seqId

fn fellToDeath(mut g Game):
	g.playSound(soundFellToDeath)
	seqCrushed

pub fn spiked(mut g Game):
	# spikes someone fell into harm no one else
	g.setRoomMod(g.currTilepos, 0xFF)
	g.char.y = byte(yLand[g.char.currRow + 1])
	g.char.x = byte(xBump[g.tileCol + firstOnscreenColumn] + 10)
	g.char.x = byte(g.charDxForward(8))
	g.char.fallY = 0
	g.playSound(soundSpiked)
	g.takeHp(100)
	g.seqtblOffsetChar(seqSpiked)
	g.playSeq()

pub fn control(mut g Game):
	frame = g.char.frame
	if g.char.alive >= 0:
		if frame in [15, 166, 158, 171]:
			g.seqtblOffsetChar(seqDying)   # standing: dies
		return
	action = g.char.action
	if action == actBumped or action == actInFreefall:
		g.releaseArrows()
	elif g.char.sword == swordDrawn:
		g.controlWithSword()
	elif g.char.charid >= charidGuard:
		g.controlGuardInactive()
	elif frame == 15 or (frame >= 50 and frame < 53):
		g.controlStanding()   # standing, or the end of a turn
	elif frame == 48:
		g.controlTurning()
	elif frame < 4:
		g.controlStartrun()
	elif frame >= 67 and frame < 70:
		g.controlJumpup()
	elif frame < 15:
		g.controlRunning()
	elif frame >= 87 and frame < 100:
		g.controlHanging()
	elif frame == 109:
		g.controlCrouched()

fn controlCrouched(mut g Game):
	if g.needLevel1Music != 0 and g.currentLevel == 1:
		# special event: the music while crouching at level 1's start
		if not g.isSoundPlaying():
			if g.needLevel1Music == 1:
				g.playSound(soundPresentation)
				g.needLevel1Music = 2
			else:
				if g.recording: g.specialMove = moveEffectEnd
				if not g.replaying: g.needLevel1Music = 0   # a replay's special move ends it
		return
	g.needLevel1Music = 0
	if g.controlShift2 == ctrlHeld and g.checkGetItem(): return
	if g.controlY != ctrlHeldDown:
		g.seqtblOffsetChar(seqStandUpFromCrouch)
	elif g.controlForward == ctrlHeld:
		g.controlForward = ctrlIgnore
		g.seqtblOffsetChar(seqCrouchHop)

fn controlStanding(mut g Game):
	if g.controlShift2 == ctrlHeld and g.controlShift == ctrlHeld and g.checkGetItem(): return
	if g.char.charid != charidKid and g.controlDown == ctrlHeld and g.controlForward == ctrlHeld:
		g.drawSword()
		return
	offguardRun = false
	if g.haveSword != 0:
		if g.offguard != 0 and g.controlShift >= ctrlReleased:
			offguardRun = true
		elif g.canGuardSeeKid >= 2:
			distance = g.charOppDist()
			if distance >= -10 and distance < 90:
				g.holdingSword = 1
				if word(distance) < word(-6):
					if g.opp.charid == charidShadow and
						(g.opp.action == actInMidair or (g.opp.frame >= 107 and g.opp.frame < 118)):
						g.offguard = 0
					else:
						g.drawSword()
						return
				else:
					g.backPressed()
					return
		else:
			g.offguard = 0
	if not offguardRun and g.controlShift == ctrlHeld:
		if g.controlBackward == ctrlHeld:
			g.backPressed()
		elif g.controlUp == ctrlHeld:
			g.upPressed()
		elif g.controlDown == ctrlHeld:
			g.downPressed()
		elif g.controlX == ctrlHeldForward and g.controlForward == ctrlHeld:
			g.safeStep()
	elif g.controlForward == ctrlHeld:
		if g.isKeyboardMode and g.controlUp == ctrlHeld:
			g.standingJump()
		else:
			g.forwardPressed()
	elif g.controlBackward == ctrlHeld:
		g.backPressed()
	elif g.controlUp == ctrlHeld:
		if g.isKeyboardMode and g.controlForward == ctrlHeld:
			g.standingJump()
		else:
			g.upPressed()
	elif g.controlDown == ctrlHeld:
		g.downPressed()
	elif g.controlX == ctrlHeldForward:
		g.forwardPressed()

fn upPressed(mut g Game):
	# an open level door near: in it goes
	doorTilepos = -1
	if g.getTileAtChar() == tileLevelDoorLeft:
		doorTilepos = g.currTilepos
	elif g.getTileBehindChar() == tileLevelDoorLeft:
		doorTilepos = g.currTilepos
	elif g.getTileInfrontofChar() == tileLevelDoorLeft:
		doorTilepos = g.currTilepos
	if doorTilepos != -1 and g.level.startRoom != g.drawnRoom and g.leveldoorOpen != 0:
		g.goUpLeveldoor()
		return
	if g.controlX == ctrlHeldForward:
		g.standingJump()
	else:
		g.checkJumpUp()

fn downPressed(mut g Game):
	g.controlDown = ctrlIgnore
	if not tileIsFloor(g.getTileInfrontofChar()) and g.distanceToEdgeWeight() < 3:
		g.char.x = byte(g.charDxForward(5))
		g.loadFramDetCol()
		return
	if not tileIsFloor(g.getTileBehindChar()) and g.distanceToEdgeWeight() >= 8:
		g.throughTile = g.getTileBehindChar()
		g.getTileAtChar()
		if g.canGrab() and
			(
				g.char.direction >= dirRight or g.getTileAtChar() != tileGate or
					g.roomMod(g.currTilepos) >> 2 >= 6
			):
			g.char.x = byte(g.charDxForward(g.distanceToEdgeWeight() - 9))
			g.seqtblOffsetChar(seqClimbDown)
			return
	g.crouch()

fn goUpLeveldoor(mut g Game):
	g.char.x = byte(xBump[g.tileCol + firstOnscreenColumn] + 10)
	g.char.direction = dirLeft
	g.seqtblOffsetChar(seqGoUpOnLevelDoor)

fn controlTurning(mut g Game):
	if g.controlShift >= ctrlReleased and g.controlX == ctrlHeldForward and
		g.controlY >= ctrlReleased:
		g.seqtblOffsetChar(seqStartRunAfterTurn)

fn crouch(mut g Game):
	g.seqtblOffsetChar(seqCrouch)
	g.controlDown = g.releaseArrows()

fn backPressed(mut g Game):
	g.controlBackward = g.releaseArrows()
	# turning, the kid draws his sword at a guard behind him
	if g.haveSword == 0 or g.canGuardSeeKid < 2 or g.charOppDist() > 0 or
		g.distanceToEdgeWeight() < 2:
		g.seqtblOffsetChar(seqTurn)
	else:
		g.char.sword = swordDrawn
		g.offguard = 0
		g.seqtblOffsetChar(seqTurnDrawSword)

fn forwardPressed(mut g Game):
	distance = g.getEdgeDistance()
	if g.edgeType == edgeTypeWall and g.currTile2 != tileChomper and distance < 8:
		# near a wall: a step, not a run
		if g.controlForward == ctrlHeld: g.safeStep()
	else:
		g.seqtblOffsetChar(seqStartRun)

fn controlRunning(mut g Game):
	if g.controlX == ctrlReleased and (g.char.frame == 7 or g.char.frame == 11):
		g.controlForward = g.releaseArrows()
		g.seqtblOffsetChar(seqStopRun)
	elif g.controlX == ctrlHeldBackward:
		g.controlBackward = g.releaseArrows()
		g.seqtblOffsetChar(seqRunTurn)
	elif g.controlY == ctrlHeldUp and g.controlUp == ctrlHeld:
		g.runJump()
	elif g.controlDown == ctrlHeld:
		g.controlDown = ctrlIgnore
		g.seqtblOffsetChar(seqCrouchWhileRunning)

fn safeStep(mut g Game):
	g.controlShift2 = ctrlIgnore
	g.controlForward = ctrlIgnore
	distance = g.getEdgeDistance()
	if distance != 0:
		g.char.repeat = 1
		g.seqtblOffsetChar(distance + 28)   # 29..42: a step up to the edge
	elif g.edgeType != edgeTypeWall and g.char.repeat != 0:
		g.char.repeat = 0
		g.seqtblOffsetChar(seqStepOnEdge)
	else:
		g.seqtblOffsetChar(39)   # a step off the ledge

fn checkGetItem(mut g Game):
	if g.getTileAtChar() == tilePotion or g.currTile2 == tileSword:
		if not tileIsFloor(g.getTileBehindChar()): return false
		g.char.x = byte(g.charDxForward(-14))
		g.loadFramDetCol()
	if g.getTileInfrontofChar() == tilePotion or g.currTile2 == tileSword:
		g.getItem()
		return true
	false

fn getItem(mut g Game):
	if g.char.frame != 109:
		distance = g.getEdgeDistance()
		if g.edgeType != edgeTypeFloor:
			g.char.x = byte(g.charDxForward(distance))
		if g.char.direction >= dirRight:
			g.char.x = byte(g.charDxForward((1 if g.currTile2 == tilePotion else 0) - 2))
		g.crouch()
	elif g.currTile2 == tileSword:
		g.doPickup(-1)
		g.seqtblOffsetChar(seqGetSword)
	else:
		g.doPickup(g.roomMod(g.currTilepos) >> 3)
		g.seqtblOffsetChar(seqDrink)
		g.removeCopyprotLetter(g.currRoom, g.currTilepos)

fn controlStartrun(mut g Game):
	if g.controlY == ctrlHeldUp and g.controlX == ctrlHeldForward:
		g.standingJump()

fn controlJumpup(mut g Game):
	if g.controlX == ctrlHeldForward or g.controlForward == ctrlHeld:
		g.standingJump()

fn standingJump(mut g Game):
	g.controlUp = ctrlIgnore
	g.controlForward = ctrlIgnore
	g.seqtblOffsetChar(seqStandingJump)

fn checkJumpUp(mut g Game):
	g.controlUp = g.releaseArrows()
	g.throughTile = g.getTileAboveChar()
	g.getTileFrontAboveChar()
	if g.canGrab():
		g.grabUpWithFloorBehind()
		return
	g.throughTile = g.getTileBehindAboveChar()
	g.getTileAboveChar()
	if g.canGrab():
		g.jumpUpOrGrab()
	else:
		g.jumpUp()

fn jumpUpOrGrab(mut g Game):
	distance = g.distanceToEdgeWeight()
	if distance < 6:
		g.jumpUp()
	elif not tileIsFloor(g.getTileBehindChar()):
		g.grabUpNoFloorBehind()
	else:
		g.char.x = byte(g.charDxForward(distance - tileSizeX))
		g.loadFramDetCol()
		g.grabUpWithFloorBehind()

fn grabUpNoFloorBehind(mut g Game):
	g.getTileAboveChar()
	g.char.x = byte(g.charDxForward(g.distanceToEdgeWeight() - 10))
	g.seqtblOffsetChar(seqJumpUpAndGrab)

fn jumpUp(mut g Game):
	g.controlUp = g.releaseArrows()
	distance = g.getEdgeDistance()
	if distance < 4 and g.edgeType == edgeTypeWall:
		g.char.x = byte(g.charDxForward(distance - 3))
	g.getTile(
		g.char.room,
		g.getTileDivMod(g.backDeltaX(0) + g.dxWeight() - 6),
		g.char.currRow - 1
	)
	if g.currTile2 != tileWall and not tileIsFloor(g.currTile2):
		g.seqtblOffsetChar(seqJumpUpWithNothingAbove)
	else:
		g.seqtblOffsetChar(seqJumpUpIntoCeiling)

fn controlHanging(mut g Game):
	if g.char.alive >= 0:
		g.hangFall()
	elif g.grabTimer == 0 and g.controlY == ctrlHeld:
		g.canClimbUp()
	elif g.controlShift == ctrlHeld:
		# hanging against a wall or a door top
		if g.char.action != actHangStraight and
			(
				g.getTileAtChar() == tileWall or
					(
						g.char.direction == dirLeft and
							(g.currTile2 == tileDoortopWithFloor or g.currTile2 == tileDoortop)
					)
			):
			if g.grabTimer == 0: g.playSound(soundBumped)
			g.seqtblOffsetChar(seqHangAgainstWall)
		elif not tileIsFloor(g.getTileAboveChar()):
			g.hangFall()
	else:
		g.hangFall()

fn canClimbUp(mut g Game):
	seqId = seqClimbUp
	g.controlShift2 = g.releaseArrows()
	g.controlUp = g.controlShift2
	g.getTileAboveChar()
	if (
		(g.currTile2 == tileMirror or g.currTile2 == tileChomper) and g.char.direction == dirRight
	) or
		(
			g.currTile2 == tileGate and g.char.direction != dirRight and
				g.roomMod(g.currTilepos) >> 2 < 6
		):
		seqId = seqClimbUpToClosedGate
	g.seqtblOffsetChar(seqId)

fn hangFall(mut g Game):
	g.controlDown = g.releaseArrows()
	if not tileIsFloor(g.getTileBehindChar()) and not tileIsFloor(g.getTileAtChar()):
		g.seqtblOffsetChar(seqReleaseLedgeAndFall)
		return
	if g.getTileAtChar() == tileWall or
		(
			g.char.direction < dirRight and
				(g.currTile2 == tileDoortopWithFloor or g.currTile2 == tileDoortop)
		):
		g.char.x = byte(g.charDxForward(-7))
	g.seqtblOffsetChar(seqReleaseLedgeAndLand)

fn grabUpWithFloorBehind(mut g Game):
	distance = g.distanceToEdgeWeight()
	edgeDistance = g.getEdgeDistance()
	if distance < 4 and edgeDistance < 4 and g.edgeType != edgeTypeWall:
		g.char.x = byte(g.charDxForward(distance))
		g.seqtblOffsetChar(seqJumpUpAndGrabStraight)
	else:
		g.char.x = byte(g.charDxForward(distance - 4))
		g.seqtblOffsetChar(seqJumpUpAndGrabForward)

fn runJump(mut g Game):
	if g.char.frame < 7: return
	# the kid lines up with the edge he jumps from
	xpos = short(g.charDxForward(4))
	col = g.getTileDivModM7(xpos)
	for tilesForward in 0..2:
		col += dirFront[g.char.direction + 1]
		g.getTile(g.char.room, col, g.char.currRow)
		if g.currTile2 == tileSpike or not tileIsFloor(g.currTile2):
			adjustment = short(g.distanceToEdge(xpos) + tileSizeX * tilesForward - tileSizeX)
			if word(adjustment) < word(-8) or adjustment >= 2:
				if adjustment < 128: return
				adjustment = -3
			g.char.x = byte(g.charDxForward(adjustment + 4))
			break
	g.controlUp = g.releaseArrows()
	g.seqtblOffsetChar(seqRunJump)

fn backWithSword(mut g Game):
	frame = g.char.frame
	if frame in [158, 170, 171]:
		g.controlBackward = ctrlIgnore
		g.seqtblOffsetChar(seqBackWithSword)

fn forwardWithSword(mut g Game):
	frame = g.char.frame
	if frame in [158, 170, 171]:
		g.controlForward = ctrlIgnore
		g.seqtblOffsetChar(
			seqForwardWithSword if g.char.charid == charidKid else seqGuardForwardWithSword
		)

pub fn drawSword(mut g Game):
	seqId = seqDrawSword
	g.controlShift2 = g.releaseArrows()
	g.controlForward = g.controlShift2
	if g.char.charid == charidKid:
		g.playSound(soundDrawSword)
		g.offguard = 0
	elif g.char.charid != charidShadow:
		seqId = seqEnGarde
	g.char.sword = swordDrawn
	g.seqtblOffsetChar(seqId)

fn controlWithSword(mut g Game):
	if g.char.action >= actHangClimb: return
	if g.getTileAtChar() == tileLoose or g.canGuardSeeKid >= 2:
		distance = g.charOppDist()
		if word(distance) < 90:
			g.swordfight()
			return
		if distance < 0:
			if word(distance) < word(-4):
				g.seqtblOffsetChar(seqTurnWithSword)   # after switching places
			else:
				g.swordfight()
			return
	if g.char.charid == charidKid and g.char.alive < 0:
		g.holdingSword = 0
	if g.char.charid < charidGuard:
		if g.char.frame == 171:
			g.char.sword = swordSheathed
			g.seqtblOffsetChar(seqPutSwordAway)   # the guard died
	else:
		g.swordfight()

fn swordfight(mut g Game):
	frame = g.char.frame
	charid = g.char.charid
	if frame == 161 and g.controlShift2 >= 0:
		g.seqtblOffsetChar(seqBackWithSword)   # back, when parrying
		return
	if g.controlShift2 == ctrlHeld:
		if charid == charidKid: g.kidSwordStrike = 15
		g.swordStrike()
		if g.controlShift2 == ctrlIgnore: return
	if g.controlDown == ctrlHeld:
		if frame in [158, 170, 171]:
			g.controlDown = ctrlIgnore
			g.char.sword = swordSheathed
			seqId = seqGuardBecomeInactive
			if charid == charidKid:
				g.offguard = 1
				g.guardRefrac = 9
				g.holdingSword = 0
				seqId = seqPutSwordAwayFast
			elif charid == charidShadow:
				seqId = seqPutSwordAway
			g.seqtblOffsetChar(seqId)
	elif g.controlUp == ctrlHeld:
		g.parry()
	elif g.controlForward == ctrlHeld:
		g.forwardWithSword()
	elif g.controlBackward == ctrlHeld:
		g.backWithSword()

fn swordStrike(mut g Game):
	frame = g.char.frame
	seqId = 0
	if frame in [157, 158, 170, 171, 165]:
		seqId = seqStrike if g.char.charid == charidKid else seqGuardStrike
	elif frame == 150 or frame == 161:
		seqId = seqStrikeAfterParry
	else:
		return
	g.controlShift2 = ctrlIgnore
	g.seqtblOffsetChar(seqId)

fn parry(mut g Game):
	charFrame = g.char.frame
	oppFrame = g.opp.frame
	charid = g.char.charid
	seqId = seqParry
	doPlaySeq = false
	if charFrame in [158, 170, 171, 168] or
		charFrame == 165:
		if g.charOppDist() >= 32 and charid != charidKid:
			g.backWithSword()
			return
		elif charid == charidKid:
			if oppFrame == 168: return
			if oppFrame != 151 and oppFrame != 152 and oppFrame != 162:
				if oppFrame == 153:
					doPlaySeq = true   # a strike
		elif oppFrame != 152:
			return
	else:
		if charFrame != 167: return   # blocked
		seqId = seqParryAfterStrike
	g.controlUp = ctrlIgnore
	g.seqtblOffsetChar(seqId)
	if doPlaySeq:
		g.playSeq()
