# Guards entering and leaving rooms, and the kid leaving one (SDLPoP's seg002.c, the first half;
# the Apple II's AUTO.S and SPECIALK.S): the guard a room keeps, the shadow's appearances, the
# kid going to the next room and the guard that follows him.

# where the shadow starts: frame, x, y, direction, column, row, action
initShad6 = [0x0F, 0x51, 0x76, 0, 0, 1, 0]
initShad5 = [0x0F, 0x37, 0x37, 0, -1, 0, 0]
initShad12 = [0x0F, 0x51, 0xE8, 0, 0, 0, 0]

fn doInitShad(mut g Game, source i64[], seqIndex i64):
	g.char.frame = source[0]
	g.char.x = source[1]
	g.char.y = source[2]
	g.char.direction = source[3]
	g.char.currCol = source[4]
	g.char.currRow = source[5]
	g.char.action = source[6]
	g.seqtblOffsetChar(seqIndex)
	g.char.charid = charidShadow
	g.demoTime = 0
	g.guardSkill = 3
	g.guardhpMax = 4
	g.guardhpCurr = 4
	g.guardhpDelta = 4
	g.saveshad()

fn getGuardHp(mut g Game):
	g.guardhpMax = g.options.optAt("extrastrength", g.guardSkill) +
		g.options.optAt("tbl_guard_hp", g.currentLevel)
	g.guardhpCurr = g.guardhpMax
	g.guardhpDelta = g.guardhpMax

pub fn checkShadow(mut g Game):
	g.offguard = 0
	if g.currentLevel == 12:
		# special event: the shadow of level 12
		if g.unitedWithShadow == 0 and g.drawnRoom == 15:
			g.char.room = g.drawnRoom
			if g.getTile(15, 1, 0) == tileSword: return
			g.shadowInitialized = 0
			g.doInitShad(initShad12, seqFall)
			return
	if g.currentLevel == g.options.opt("shadow_step_level"):
		# special event: the shadow of level 6
		g.char.room = g.drawnRoom
		if g.char.room == g.options.opt("shadow_step_room"):
			if g.leveldoorOpen != 0x4D:
				g.playSound(soundPresentation)
				g.leveldoorOpen = 0x4D
			g.doInitShad(initShad6, seqStand)
			return
	if g.currentLevel == g.options.opt("shadow_steal_level"):
		# special event: the shadow steals the potion on level 5
		g.char.room = g.drawnRoom
		if g.char.room == g.options.opt("shadow_steal_room"):
			if g.getTile(g.options.opt("shadow_steal_room"), 3, 0) != tilePotion: return
			g.doInitShad(initShad5, seqStand)
			return
	g.enterGuard()

fn enterGuard(mut g Game):
	r = g.drawnRoom - 1
	entry = g.level.guards[r]
	if entry.tile >= 30: return
	g.char.room = g.drawnRoom
	g.char.currRow = entry.tile / 10
	g.char.y = byte(yLand[g.char.currRow + 1])
	g.char.x = entry.x
	g.char.currCol = sbyte(g.getTileDivModM7(g.char.x))
	g.char.direction = entry.direction
	# only the plain guards have colours
	g.currGuardColor = entry.color & 0x0F if g.options.optAt("tbl_guard_type", g.currentLevel) == 0
		else 0
	g.char.charid = charidSkeleton if g.options.optAt("tbl_guard_type", g.currentLevel) == 2
		else charidGuard
	if entry.seq >> 8 == 0:
		if g.char.charid == charidSkeleton:
			g.char.sword = swordDrawn
			g.seqtblOffsetChar(seqGuardActiveAfterFall)
		else:
			g.char.sword = swordSheathed
			g.seqtblOffsetChar(seqGuardStandInactive)
	else:
		g.char.currSeq = entry.seq
	g.playSeq()
	g.guardSkill = entry.skill
	if g.guardSkill >= 12: g.guardSkill = 3
	frame = g.char.frame
	if frame in [185, 177, 178]:
		g.char.alive = 1
		g.drawGuardHp(0, g.guardhpCurr)
		g.guardhpCurr = 0
	else:
		g.char.alive = -1
		g.justblocked = 0
		g.guardRefrac = 0
		g.isGuardNotice = 0
		g.getGuardHp()
	g.char.fallY = 0
	g.char.fallX = 0
	g.char.action = actRunJump
	g.saveshad()

pub fn checkGuardFallout(mut g Game):
	if g.guard.direction == dirNone or g.guard.y < 211: return
	if g.guard.charid == charidShadow:
		if g.guard.action != actInFreefall: return
		g.loadshad()
		g.clearChar()
		g.saveshad()
	elif g.guard.charid == charidSkeleton and
		g.level.links[g.guard.room - 1].down == g.options.opt("skeleton_reappear_room"):
		# the skeleton falls into its reappearing room
		g.guard.room = g.level.links[g.guard.room - 1].down
		g.guard.x = g.options.opt("skeleton_reappear_x")
		g.guard.currRow = g.options.opt("skeleton_reappear_row")
		g.guard.direction = sbyte(g.options.opt("skeleton_reappear_dir"))
		g.guard.alive = -1
		g.leaveGuard()
	else:
		g.onGuardKilled()
		g.level.guards[g.drawnRoom - 1].tile = 255
		g.guard.direction = dirNone
		g.drawGuardHp(0, g.guardhpCurr)
		g.guardhpCurr = 0

pub fn leaveGuard(mut g Game):
	if g.guard.direction == dirNone or g.guard.charid == charidShadow or
		g.guard.charid == charidMouse:
		return
	r = g.guard.room - 1
	g.level.guards[r].tile = byte(getTilepos(0, g.guard.currRow))
	g.level.guards[r].color = g.currGuardColor & 0x0F
	g.level.guards[r].x = g.guard.x
	g.level.guards[r].direction = g.guard.direction
	g.level.guards[r].skill = g.guardSkill
	if g.guard.alive < 0:
		g.level.guards[r].seq &= 0xFF
	else:
		g.level.guards[r].seq = g.guard.currSeq
	g.guard.direction = dirNone
	g.drawGuardHp(0, g.guardhpCurr)
	g.guardhpCurr = 0

fn followGuard(mut g Game):
	g.level.guards[g.kid.room - 1].tile = 255
	g.level.guards[g.guard.room - 1].tile = 255
	g.loadshad()
	g.gotoOtherRoom(g.roomleaveResult)
	g.saveshad()

pub fn exitRoom(mut g Game):
	if g.exitRoomTimer != 0:
		g.exitRoomTimer -= 1
		return
	g.loadkid()
	g.loadFrameToObj()
	g.setCharCollision()
	g.roomleaveResult = g.leaveRoom()
	if g.roomleaveResult < 0: return
	g.savekid()
	g.nextRoom = g.char.room
	if g.guard.direction == dirNone: return
	leave = true
	if g.guard.alive < 0 and g.guard.sword == swordDrawn:
		kidRoom = g.kid.room - 1
		if kidRoom >= 0 and kidRoom <= 23 and
			(g.level.guards[kidRoom].tile >= 30 or g.level.guards[kidRoom].seq >> 8 != 0):
			# the guard follows the kid unless he is too far from the way out
			if g.roomleaveResult == 0:
				leave = g.guard.x >= 91
			elif g.roomleaveResult == 1:
				leave = g.guard.x < 165
			elif g.roomleaveResult == 2:
				leave = g.guard.currRow >= 0
			else:
				leave = g.guard.currRow < 3
	if leave:
		g.leaveGuard()
	else:
		g.followGuard()

# goto_other_room: the character into the room on side `direction` (left, right, up, down)
pub fn gotoOtherRoom(mut g Game, direction i64) i64:
	other = 0
	if g.char.room == 0:
		other = g.level.doorLinks2[252 + direction]   # room 0's links: the bytes before room 1's
	else:
		links = g.level.links[g.char.room - 1]
		other = [links.left, links.right, links.up, links.down][direction]
	g.char.room = other
	if direction == 0:
		g.char.x = byte(g.char.x + 140)
		return 1
	if direction == 1:
		g.char.x = byte(g.char.x - 140)
		return 0
	if direction == 2:
		g.char.y = byte(g.char.y + 189)
		g.char.currRow = sbyte(yToRowMod4(g.char.y))
		return 3
	g.char.y = byte(g.char.y - 189)
	g.char.currRow = sbyte(yToRowMod4(g.char.y))
	2

fn leaveRoom(mut g Game):
	chary = g.char.y
	action = g.char.action
	frame = g.char.frame
	leaveDir = 0
	if action != actBumped and action != actInFreefall and action != actInMidair and
		sbyte(chary) < 10 and sbyte(chary) > -16:
		leaveDir = 2   # up
	elif chary >= 211:
		leaveDir = 3   # down
	elif (frame >= 135 and frame < 150) or (frame >= 110 and frame < 120) or
		(frame >= 150 and frame < 163) or (frame >= 166 and frame < 169) or action == actTurn:
		return -1   # climbing, standing up, or with the sword
	elif g.char.direction != dirRight:
		if g.charXLeft <= 54:
			leaveDir = 0
		elif g.charXLeft >= 198:
			leaveDir = 1
		else:
			return -1
	else:
		g.getTile(g.char.room, 9, g.char.currRow)
		if g.currTile2 != tileDoortopWithFloor and g.currTile2 != tileDoortop and
			g.charXRight >= 201:
			leaveDir = 1
		elif g.charXRight <= 57:
			leaveDir = 0
		else:
			return -1
	if leaveDir == 0:
		g.playMirrMus()
		g.level3SetChkp()
		g.jaffarExit()
	elif leaveDir == 1:
		g.swordDisappears()
		g.meetJaffar()
	elif leaveDir == 3:
		# special event: level 6's way out is falling
		if g.currentLevel == g.options.opt("falling_exit_level") and
			g.char.room == g.options.opt("falling_exit_room"):
			return -2
	g.gotoOtherRoom(leaveDir)
	if g.skippingReplay and g.replaySeekTarget == seekNextRoom: g.skippingReplay = false
	leaveDir

fn jaffarExit(mut g Game):
	if g.leveldoorOpen == 2:
		g.getTile(24, 0, 0)
		g.triggerButton(0, 0, -1)

fn level3SetChkp(mut g Game):
	# special event: level 3's checkpoint
	if g.currentLevel == g.options.opt("checkpoint_level") and g.char.room == 7:
		g.checkpoint = 1
		g.hitpBegLev = g.hitpMax

fn swordDisappears(mut g Game):
	# special event: the sword gone on level 12
	if g.currentLevel == 12 and g.char.room == 18:
		g.getTile(15, 1, 0)
		g.setRoomTile(g.currTilepos, tileFloor)

fn meetJaffar(mut g Game):
	# special event: Jaffar's music, and his wait
	if g.currentLevel == 13 and g.leveldoorOpen == 0 and g.char.room == 3:
		g.playSound(soundMeetJaffar)
		g.guardNoticeTimer = 28

fn playMirrMus(mut g Game):
	# special event: the mirror's music on level 4
	if g.leveldoorOpen != 0 and g.leveldoorOpen != 0x4D and
		g.currentLevel == g.options.opt("mirror_level") and
		g.char.currRow == g.options.opt("mirror_row") and
		g.char.room == 11:
		g.playSound(soundPresentation)
		g.leveldoorOpen = 0x4D
