# The opponents' minds and the sword's hits (SDLPoP's seg002.c, the second half; the Apple II's
# AUTO.S): the guard's, the skeleton's, the shadow's and the mouse's moves as if from a joystick,
# who a strike hurts, the skeleton waking and the demo's recorded moves.

# a demo's move: from frame `time` on, `kind`
type AutoMove:
	time i64
	kind i64

fn autoMoves(pairs i64[]):
	(0..pairs.len / 2).map(AutoMove(time = pairs[it * 2], kind = pairs[it * 2 + 1]))

pub demoMoves = autoMoves(
	[
		0x00,
		0,
		0x01,
		1,
		0x0D,
		0,
		0x1E,
		1,
		0x25,
		5,
		0x2F,
		0,
		0x30,
		1,
		0x41,
		0,
		0x49,
		2,
		0x4B,
		0,
		0x63,
		2,
		0x64,
		0,
		0x73,
		5,
		0x80,
		6,
		0x88,
		3,
		0x9D,
		7,
		0x9E,
		0,
		0x9F,
		1,
		0xAB,
		4,
		0xB1,
		0,
		0xB2,
		1,
		0xBC,
		0,
		0xC1,
		1,
		0xCD,
		0,
		0xE9,
		-1
	]
)
shadDrinkMove = autoMoves([0x00, 0, 0x01, 1, 0x0E, 0, 0x12, 6, 0x1D, 7, 0x2D, 2, 0x31, 1, 0xFF, -2])

fn move0Nothing(mut g Game):
	g.controlShift = ctrlReleased
	g.controlY = ctrlReleased
	g.controlX = ctrlReleased
	g.controlShift2 = ctrlReleased
	g.controlDown = ctrlReleased
	g.controlUp = ctrlReleased
	g.controlBackward = ctrlReleased
	g.controlForward = ctrlReleased

fn move1Forward(mut g Game):
	g.controlX = ctrlHeldForward
	g.controlForward = ctrlHeld

fn move2Backward(mut g Game):
	g.controlBackward = ctrlHeld
	g.controlX = ctrlHeldBackward

fn move3Up(mut g Game):
	g.controlY = ctrlHeldUp
	g.controlUp = ctrlHeld

fn move4Down(mut g Game):
	g.controlDown = ctrlHeld
	g.controlY = ctrlHeldDown

fn moveDownBack(mut g Game):
	g.controlDown = ctrlHeld
	g.move2Backward()

fn moveDownForw(mut g Game):
	g.controlDown = ctrlHeld
	g.move1Forward()

fn move6Shift(mut g Game):
	g.controlShift = ctrlHeld
	g.controlShift2 = ctrlHeld

pub fn autocontrolOpponent(mut g Game):
	g.move0Nothing()
	charid = g.char.charid
	if charid == charidKid:
		g.autocontrolGuard()
		return
	if g.justblocked != 0: g.justblocked -= 1
	if g.kidSwordStrike != 0: g.kidSwordStrike -= 1
	if g.guardRefrac != 0: g.guardRefrac -= 1
	if charid == charidMouse:
		g.autocontrolMouse()
	elif charid == charidSkeleton:
		g.char.sword = swordDrawn
		g.autocontrolGuard()
	elif charid == charidShadow:
		g.autocontrolShadow()
	else:
		g.autocontrolGuard()   # Jaffar's too

fn autocontrolMouse(mut g Game):
	if g.char.direction == dirNone: return
	if g.char.action == actStand:
		if g.char.x >= 200: g.clearChar()
	elif g.char.x < 166:
		g.seqtblOffsetChar(seqMouseStandUpAndGo)
		g.playSeq()

fn autocontrolShadow(mut g Game):
	if g.currentLevel == g.options.opt("mirror_level"): g.autocontrolShadowLevel4()
	if g.currentLevel == g.options.opt("shadow_steal_level"): g.autocontrolShadowLevel5()
	if g.currentLevel == g.options.opt("shadow_step_level"): g.autocontrolShadowLevel6()
	if g.currentLevel == 12: g.autocontrolShadowLevel12()

fn autocontrolGuard(mut g Game):
	if g.char.sword < swordDrawn:
		g.autocontrolGuardInactive()
	else:
		g.autocontrolGuardActive()

fn autocontrolGuardInactive(mut g Game):
	if g.kid.alive >= 0: return
	distance = g.charOppDist()
	if g.opp.currRow != g.char.currRow or word(distance) < word(-8):
		# a sound the kid makes turns the guard to him
		if g.isGuardNotice != 0:
			g.isGuardNotice = 0
			if distance < 0:
				if word(distance) < word(-4): g.move4Down()
				return
		elif distance < 0:
			return
	if g.canGuardSeeKid != 0:
		# seeing the kid, the guard takes his fighting pose
		if g.currentLevel != 13 or g.guardNoticeTimer == 0:
			g.moveDownForw()

fn autocontrolGuardActive(mut g Game):
	frame = g.char.frame
	if frame == 166 or frame < 150 or g.canGuardSeeKid == 1: return
	if g.canGuardSeeKid == 0:
		if g.droppedout != 0:
			g.guardFollowsKidDown()
		elif g.char.charid != charidSkeleton:
			g.moveDownBack()
		return
	oppFrame = g.opp.frame
	distance = g.charOppDist()
	if distance >= 12 and oppFrame >= 102 and oppFrame < 118 and g.opp.action == actBumped: return
	if distance < 35:
		if (g.char.sword < swordDrawn and distance < 8) or distance < 12:
			if g.char.direction == g.opp.direction:
				g.move2Backward()   # turns around
			else:
				g.move1Forward()
		else:
			g.autocontrolGuardKidInSight(distance)
		return
	if g.guardRefrac != 0: return
	if g.char.direction != g.opp.direction:
		if oppFrame >= 7 and oppFrame < 15:
			# the kid runs at him
			if distance < 40: g.move6Shift()
			return
		if oppFrame >= 34 and oppFrame < 44:
			if distance < 50: g.move6Shift()
			return
	g.autocontrolGuardKidFar()

fn autocontrolGuardKidFar(mut g Game):
	if tileIsFloor(g.getTileInfrontofChar()) or tileIsFloor(g.getTileInfrontof2Char()):
		g.move1Forward()
	else:
		g.move2Backward()

fn guardFollowsKidDown(mut g Game):
	oppAction = g.opp.action
	if oppAction == actHangClimb or oppAction == actHangStraight: return
	stay = wallType(g.getTileInfrontofChar()) != 0
	if not stay and not tileIsFloor(g.currTile2):
		g.tileRow += 1
		below = g.getTile(g.currRoom, g.tileCol, g.tileRow)
		stay = below == tileSpike or g.currTile2 == tileLoose or wallType(g.currTile2) != 0 or
			not tileIsFloor(g.currTile2) or g.char.currRow + 1 != g.opp.currRow
	if stay:
		g.droppedout = 0
		g.move2Backward()
	else:
		g.move1Forward()

fn autocontrolGuardKidInSight(mut g Game, distance i64):
	if g.opp.sword == swordDrawn:
		g.autocontrolGuardKidArmed(distance)
	elif g.guardRefrac == 0:
		if distance < 29:
			g.move6Shift()
		else:
			g.move1Forward()

fn autocontrolGuardKidArmed(mut g Game, distance i64):
	if distance < 10 or distance >= 29:
		g.guardAdvance()
		return
	g.guardBlock()
	if g.guardRefrac == 0:
		if distance < 12 or distance >= 29:
			g.guardAdvance()
		else:
			g.guardStrike()

fn guardAdvance(mut g Game):
	if g.guardSkill == 0 or g.kidSwordStrike == 0:
		if g.options.optAt("advprob", g.guardSkill) > g.prandom(255): g.move1Forward()

fn guardBlock(mut g Game):
	oppFrame = g.opp.frame
	if oppFrame in [152, 153, 162]:
		if g.justblocked != 0:
			if g.options.optAt("impblockprob", g.guardSkill) > g.prandom(255): g.move3Up()
		elif g.options.optAt("blockprob", g.guardSkill) > g.prandom(255):
			g.move3Up()

fn guardStrike(mut g Game):
	oppFrame = g.opp.frame
	if oppFrame == 169 or oppFrame == 151: return
	frame = g.char.frame
	if frame == 161 or frame == 150:
		if g.options.optAt("restrikeprob", g.guardSkill) > g.prandom(255): g.move6Shift()
	elif g.options.optAt("strikeprob", g.guardSkill) > g.prandom(255):
		g.move6Shift()

fn hurtBySword(mut g Game):
	if g.char.alive >= 0: return
	if g.char.sword != swordDrawn:
		# hurt off guard is death
		g.takeHp(100)
		g.seqtblOffsetChar(seqStabbedToDeath)
		g.stabbedToDeath()
	elif g.char.charid != charidSkeleton and g.takeHp(1):
		g.stabbedToDeath()   # skeletons can't be hurt
	else:
		g.seqtblOffsetChar(seqHitBySword)
		g.char.y = byte(yLand[g.char.currRow + 1])
		g.char.fallY = 0
	g.playSound(soundKidHurt if g.char.charid == charidKid else soundGuardHurt)
	g.playSeq()

fn stabbedToDeath(mut g Game):
	distance = 0
	behind = g.getTileBehindChar()
	if behind == 0:
		distance = g.distanceToEdgeWeight()
	if behind != 0 or distance < 4:
		g.seqtblOffsetChar(seqStabbedToDeath)
		if g.char.charid != charidKid and g.char.direction < dirRight and
			(g.currTile2 == tileGate or g.getTileAtChar() == tileGate):
			g.char.x = byte(
				xBump[g.tileCol - (0 if g.currTile2 == tileGate else 1) + firstOnscreenColumn] +
					tileMidX
			)
			g.char.x = byte(g.charDxForward(10))
		g.char.y = byte(yLand[g.char.currRow + 1])
		g.char.fallY = 0
	else:
		g.char.x = byte(g.charDxForward(distance - 20))
		g.loadFramDetCol()
		g.incCurrRow()
		g.seqtblOffsetChar(seqKidPushedOffLedge)

pub fn checkSwordHurt(mut g Game):
	if g.guard.action == actHurt:
		if g.kid.action == actHurt:
			g.kid.action = actRunJump
		g.loadshad()
		g.hurtBySword()
		g.saveshad()
		g.guardRefrac = g.options.optAt("refractimer", g.guardSkill)
	elif g.kid.action == actHurt:
		g.loadkid()
		g.hurtBySword()
		g.savekid()

pub fn checkSwordHurting(mut g Game):
	kidFrame = g.kid.frame
	# not while going up the stairs
	if kidFrame != 0 and (kidFrame < 219 or kidFrame >= 229):
		g.loadshadAndOpp()
		g.checkHurting()
		g.saveshadAndOpp()
		g.loadkidAndOpp()
		g.checkHurting()
		g.savekidAndOpp()

fn checkHurting(mut g Game):
	if g.char.sword != swordDrawn or g.char.currRow != g.opp.currRow: return
	frame = g.char.frame
	if frame != 153 and frame != 154: return   # poking
	distance = g.charOppDist()
	oppFrame = g.opp.frame
	if distance < 0 or distance >= 29 or (oppFrame != 161 and oppFrame != 150):
		# the opponent doesn't parry
		if g.char.frame == 154:
			minHurtRange = 8 if g.opp.sword < swordDrawn else 12
			distance = g.charOppDist()
			if distance >= minHurtRange and distance < 29:
				g.opp.action = actHurt
	else:
		g.opp.frame = 161
		if g.char.charid != charidKid: g.justblocked = 4
		g.seqtblOffsetChar(seqAttackWasParried)
		g.playSeq()
	if g.char.direction == dirNone: return
	if g.char.frame == 154 and g.opp.frame != 161 and g.opp.action != actHurt:
		g.playSound(soundSwordMoving)

pub fn checkSkel(mut g Game):
	# special event: the skeleton of level 3 wakes
	if g.currentLevel != g.options.opt("skeleton_level") or g.guard.direction != dirNone or
		g.drawnRoom != g.options.opt("skeleton_room"):
		return
	if g.leveldoorOpen == 0 and g.options.isOn("skeleton_require_open_level_door"): return
	if g.kid.currCol != g.options.opt("skeleton_trigger_column_1") and
		g.kid.currCol != g.options.opt("skeleton_trigger_column_2"):
		return
	g.getTile(g.drawnRoom, g.options.opt("skeleton_column"), g.options.opt("skeleton_row"))
	if g.currTile2 != tileSkeleton: return
	g.setRoomTile(g.currTilepos, tileFloor)
	g.redrawHeight = 24
	g.setRedrawFull(g.currTilepos, 1)
	g.setWipe(g.currTilepos, 1)
	g.currTilepos += 1
	g.setRedrawFull(g.currTilepos, 1)
	g.setWipe(g.currTilepos, 1)
	g.char.room = g.drawnRoom
	g.char.currRow = g.options.opt("skeleton_row")
	g.char.y = byte(yLand[g.char.currRow + 1])
	g.char.currCol = g.options.opt("skeleton_column")
	g.char.x = byte(xBump[g.char.currCol + firstOnscreenColumn] + tileSizeX)
	g.char.direction = dirLeft
	g.seqtblOffsetChar(seqSkelWakeUp)
	g.playSeq()
	g.playSound(soundSkelAlive)
	g.guardSkill = g.options.opt("skeleton_skill")
	g.char.alive = -1
	g.guardhpMax = 3
	g.guardhpCurr = 3
	g.char.fallX = 0
	g.char.fallY = 0
	g.isGuardNotice = 0
	g.guardRefrac = 0
	g.char.sword = swordDrawn
	g.char.charid = charidSkeleton
	g.saveshad()

pub fn doAutoMoves(mut g Game, moves AutoMove[]):
	if g.demoTime >= 0xFE: return
	g.demoTime += 1
	index = g.demoIndex
	if moves[index].time <= g.demoTime:
		g.demoIndex += 1
	else:
		index = g.demoIndex - 1
	m = moves[index].kind
	if m == 0:
		g.move0Nothing()
	elif m == 1:
		g.move1Forward()
	elif m == 2:
		g.move2Backward()
	elif m == 3:
		g.move3Up()
	elif m == 4:
		g.move4Down()
	elif m == 5:
		g.move3Up()
		g.move1Forward()
	elif m == 6:
		g.move6Shift()
	elif m == 7:
		g.controlShift = ctrlReleased

fn autocontrolShadowLevel4(mut g Game):
	if g.char.room == g.options.opt("mirror_room"):
		if g.char.x < 80:
			g.clearChar()
		else:
			g.move1Forward()

fn autocontrolShadowLevel5(mut g Game):
	if g.char.room == g.options.opt("shadow_steal_room"):
		if g.demoTime == 0:
			g.getTile(g.options.opt("shadow_steal_room"), 1, 0)
			if g.roomMod(g.currTilepos) < 80: return   # the gate isn't open
			g.demoIndex = 0
		g.doAutoMoves(shadDrinkMove)
		if g.char.x < 15:
			g.clearChar()

fn autocontrolShadowLevel6(mut g Game):
	if g.char.room == g.options.opt("shadow_step_room") and g.kid.frame == 43 and g.kid.x < 128:
		g.move6Shift()
		g.move1Forward()

fn autocontrolShadowLevel12(mut g Game):
	if g.char.room == 15 and g.shadowInitialized == 0:
		if g.opp.x >= 150:
			g.doInitShad(initShad12, seqFall)
			return
		g.shadowInitialized = 1
	if g.char.sword >= swordDrawn:
		# the shadow puts his sword away when the kid does, once he was hurt
		if g.offguard == 0 or g.guardRefrac == 0:
			g.autocontrolGuardActive()
		else:
			g.move4Down()
		return
	if g.opp.sword >= swordDrawn or g.offguard == 0:
		xdiff = 0x7000
		if g.canGuardSeeKid >= 2: xdiff = g.charOppDist()
		if g.canGuardSeeKid < 2 or xdiff >= 90:
			if xdiff < 0: g.move2Backward()
			return
		if g.char.frame == 15: g.moveDownForw()   # draws his sword
		return
	if g.charOppDist() < 10:
		# the kid unites with the shadow
		g.flashColor = colorBrightWhite
		g.flashTime = 18
		g.addLife()
		g.unitedWithShadow = 42
		g.char.charid = charidKid
		g.savekid()
		g.clearChar()
		return
	if g.canGuardSeeKid == 2:
		oppFrame = g.opp.frame
		# the kid running or stepping to the shadow: he runs to the kid
		if (oppFrame >= 3 and oppFrame < 15) or (oppFrame >= 127 and oppFrame < 133):
			g.move1Forward()
