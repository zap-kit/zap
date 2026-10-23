# The characters' tiles, frames and sequences (SDLPoP's seg006.c, from the Apple II's
# CTRLSUBS.S and FRAMEADV.S): which tile a place is in, the frame a character shows, and the
# sequence table's commands that move it.

import dos.pop

# get_room_address: the room the tile routines read
pub fn getRoomAddress(mut g Game, room i64):
	g.loadedRoom = room
	if room != 0:
		g.currRoomBase = (room - 1) * 30

# the tile and modifier at `tilepos` of the room get_room_address chose (curr_room_tiles,
# curr_room_modif)
pub fn roomTile(g Game, tilepos i64) i64:
	g.level.tiles[g.currRoomBase + tilepos]

pub fn roomMod(g Game, tilepos i64) i64:
	g.level.modifiers[g.currRoomBase + tilepos]

pub fn setRoomTile(mut g Game, tilepos i64, v i64):
	g.level.tiles[g.currRoomBase + tilepos] = u8.wrap(v)

pub fn setRoomMod(mut g Game, tilepos i64, v i64):
	g.level.modifiers[g.currRoomBase + tilepos] = u8.wrap(v)

# get_tile: the kind of the tile at (col, row) of `room`, past its edges into the rooms around
pub fn getTile(mut g Game, room i64, col i64, row i64) i64:
	g.currRoom = room
	g.tileCol = col
	g.tileRow = row
	g.currRoom = g.findRoomOfTile()
	if g.currRoom > 0:
		g.getRoomAddress(g.currRoom)
		g.currTilepos = tblLine[g.tileRow] + g.tileCol
		g.currTile2 = g.roomTile(g.currTilepos) & 0x1F
	else:
		g.currTile2 = g.options.opt("level_edge_hit_tile")   # the level's edge
	g.currTile2

# find_room_of_tile, in the original's order (columns before rows)
pub fn findRoomOfTile(mut g Game) i64:
	loop:
		if g.tileCol < 0:
			g.tileCol += 10
			if g.currRoom > 0: g.currRoom = g.level.links[g.currRoom - 1].left
		elif g.tileCol >= 10:
			g.tileCol -= 10
			if g.currRoom > 0: g.currRoom = g.level.links[g.currRoom - 1].right
		elif g.tileRow < 0:
			g.tileRow += 3
			if g.currRoom > 0: g.currRoom = g.level.links[g.currRoom - 1].up
		elif g.tileRow >= 3:
			g.tileRow -= 3
			if g.currRoom > 0: g.currRoom = g.level.links[g.currRoom - 1].down
		else:
			break
	g.currRoom

pub fn getTilepos(col i64, row i64) i64:
	if row < 0: return -(col + 1)
	if row >= 3 or col >= 10 or col < 0: return 30
	tblLine[row] + col

pub fn getTileposNominus(col i64, row i64) i64:
	t = getTilepos(col, row)
	30 if t < 0 else t

pub fn loadFramDetCol(mut g Game):
	g.loadFrame()
	g.determineCol()

pub fn determineCol(mut g Game):
	g.char.currCol = sbyte(g.getTileDivModM7(g.dxWeight()))

fn frameOf(frames pop.Frame[], n i64):
	if n >= 0 and n < frames.len: return frames[n]
	pop.Frame(image = 255, sword = 0, dx = 0, dy = 0, flags = 0)

# load_frame: the frame of the frame table the character's kind draws from
pub fn loadFrame(mut g Game):
	frame = g.char.frame
	id = g.char.charid
	if id == charidKid or id == charidMouse or
		(id == charidShadow and (frame < 150 or frame >= 190)):
		g.curFrame = frameOf(g.tables.kidFrames, frame)
	elif id in [charidGuard, charidSkeleton, charidShadow]:
		add = 70 if id != charidShadow and frame >= 102 and frame < 107 else 0
		g.curFrame = frameOf(g.tables.guardFrames, frame + add - 149)
	elif id == charidPrincess or id == charidVizier:
		g.curFrame = frameOf(g.tables.cutsceneFrames, frame)

pub fn dxWeight(g Game) i64:
	offset = sbyte(g.curFrame.dx - (g.curFrame.flags & frameWeightX))
	g.charDxForward(offset)

pub fn charDxForward(g Game, deltaX i64) i64:
	d = -deltaX if g.char.direction < dirRight else deltaX
	d + g.char.x

pub fn objDxForward(mut g Game, deltaX i64) i64:
	d = -deltaX if g.objDirection < dirRight else deltaX
	g.objX = short(g.objX + d)
	g.objX

fn seqByte(g Game) i64:
	g.tables.data[g.char.currSeq]

# play_seq: the sequence's commands up to its next frame
pub fn playSeq(mut g Game):
	loop:
		command = g.seqByte()
		g.char.currSeq = word(g.char.currSeq + 1)
		if command == seqDx:
			g.char.x = byte(g.charDxForward(g.seqByte()))
			g.char.currSeq += 1
		elif command == seqDy:
			g.char.y = byte(g.char.y + g.seqByte())
			g.char.currSeq += 1
		elif command == seqFlip:
			g.char.direction = sbyte(~g.char.direction)
		elif command == seqJmpIfFeather and g.isFeatherFall == 0:
			g.char.currSeq += 2
		elif command == seqJmp or command == seqJmpIfFeather:
			g.char.currSeq = g.tables.data.u16le(g.char.currSeq)
		elif command == seqUp:
			g.char.currRow = sbyte(g.char.currRow - 1)
			g.startChompers()
		elif command == seqDown:
			g.incCurrRow()
			g.startChompers()
		elif command == seqAction:
			g.char.action = g.seqByte()
			g.char.currSeq += 1
		elif command == seqSetFall:
			g.char.fallX = sbyte(g.seqByte())
			g.char.currSeq += 1
			g.char.fallY = sbyte(g.seqByte())
			g.char.currSeq += 1
		elif command == seqKnockUp:
			g.knock = 1
		elif command == seqKnockDown:
			g.knock = -1
		elif command == seqSound:
			which = g.seqByte()
			g.char.currSeq += 1
			g.seqSoundCommand(which)
		elif command == seqEndLevel:
			g.nextLevel += 1
			# the seed of this frame is kept for the next level's, however long the sound plays on
			g.keepLastSeed = 1
			if g.replaying and g.skippingReplay: g.stopSounds()
		elif command == seqGetItem:
			which = g.seqByte()
			g.char.currSeq += 1
			if which == 1: g.procGetObject()
		elif command == seqDie:
			continue
		else:
			g.char.frame = command
			return

fn seqSoundCommand(mut g Game, which i64):
	if which == 0:
		g.isGuardNotice = 1   # silent, but the guards notice
	elif which == 1:
		g.playSound(soundFootstep)
		g.isGuardNotice = 1
	elif which == 2:
		g.playSound(soundBumped)
		g.isGuardNotice = 1
	elif which == 3:
		g.playSound(soundDrink)
	elif which == 4:
		if g.recording or g.replaying:
			return   # no end of level music in replays
		if g.currentLevel == g.options.opt("mirror_level"):
			g.playSound(soundShadowMusic)
		elif g.currentLevel != 13 and g.currentLevel != 15:
			g.playSound(soundEndLevelMusic)

pub fn getTileDivModM7(mut g Game, xpos i64) i64:
	g.getTileDivMod(xpos - 7)

# tile_div_tbl and tile_mod_tbl of the data segment (v1.4's data:23B2 and data:24B2)
tileDivTblAt = 0x23B2
tileModTblAt = 0x24B2

# get_tile_div_mod: the column of a place and (in obj_xl) the place within it; places off the
# tables read the bytes around them, as the original does
pub fn getTileDivMod(mut g Game, xpos i64) i64:
	x = xpos - screenspaceX
	xl = x % tileSizeX
	xh = x / tileSizeX
	if xl < 0:
		xh -= 1
		xl += tileSizeX
	if xpos < 0 and xpos >= -34:
		xh = g.tables.data[tileDivTblAt + xpos]
		xl = sbyte(g.tables.data[tileDivTblAt + 256 + xpos])
	if xpos >= 256 and xpos < 256 + 34:
		xh = g.tables.data[tileModTblAt + xpos - 256]
		xl = g.tables.data[tileModTblAt + xpos]
	g.objXl = byte(xl)
	xh

pub fn yToRowMod4(ypos i64) i64:
	(ypos + 60) / tileSizeY % 4 - 1

pub fn loadkid(mut g Game):
	g.char = g.kid

pub fn savekid(mut g Game):
	g.kid = g.char

pub fn loadshad(mut g Game):
	g.char = g.guard

pub fn saveshad(mut g Game):
	g.guard = g.char

pub fn loadkidAndOpp(mut g Game):
	g.char = g.kid
	g.opp = g.guard

pub fn savekidAndOpp(mut g Game):
	g.kid = g.char
	g.guard = g.opp

pub fn loadshadAndOpp(mut g Game):
	g.char = g.guard
	g.opp = g.kid

pub fn saveshadAndOpp(mut g Game):
	g.guard = g.char
	g.kid = g.opp

pub fn resetObjClip(mut g Game):
	g.objClipLeft = 0
	g.objClipTop = 0
	g.objClipRight = 320
	g.objClipBottom = 192

# x_to_xh_and_xl: a place in pixels as bytes of 8 and the pixels past them (the original's
# rounding of negative places)
pub fn xToXhAndXl(xpos i64) (i64, i64):
	if xpos < 0: return (sbyte(-((-xpos >> 3) + 1)), sbyte(-((-xpos - 1) % 8 - 7)))
	(sbyte(xpos >> 3), sbyte(xpos % 8))

pub fn fallAccel(mut g Game):
	if g.char.action == actInFreefall:
		if g.isFeatherFall != 0:
			g.char.fallY = (g.char.fallY + 1).min(4)
		else:
			g.char.fallY = (g.char.fallY + 3).min(33)

pub fn fallSpeed(mut g Game):
	g.char.y = byte(g.char.y + g.char.fallY)
	if g.char.action == actInFreefall:
		g.char.x = byte(g.charDxForward(g.char.fallX))
		g.loadFramDetCol()

pub fn checkAction(mut g Game):
	action = g.char.action
	frame = g.char.frame
	if action == actHangStraight or action == actBumped:
		if frame == 109: g.checkOnFloor()   # crouching
	elif action == actInFreefall:
		g.doFall()
	elif action == actInMidair:
		if frame >= 102 and frame < 106: g.checkGrab()   # start fall
	elif action != actHangClimb:
		g.checkOnFloor()

pub fn tileIsFloor(tiletype i64) bool:
	not (
		tiletype in [tileEmpty, tileBigpillarTop, tileDoortop] or
			tiletype == tileWall or (tiletype >= tileLatticeDown and tiletype <= tileLatticeRight)
	)

pub fn checkSpiked(mut g Game):
	frame = g.char.frame
	if g.getTile(g.char.room, g.char.currCol, g.char.currRow) == tileSpike:
		harmful = g.isSpikeHarmful()
		running = (frame >= 7 and frame < 15) or (frame >= 34 and frame < 40)
		if (harmful >= 2 and running) or ((frame == 43 or frame == 26) and harmful != 0):
			g.spiked()

pub fn takeHp(mut g Game, count i64) bool:
	dead = false
	if g.char.charid == charidKid:
		if count >= g.hitpCurr:
			g.hitpDelta = -g.hitpCurr
			dead = true
		else:
			g.hitpDelta = -count
	elif count >= g.guardhpCurr:
		g.guardhpDelta = -g.guardhpCurr
		dead = true
	else:
		g.guardhpDelta = -count
	dead

pub fn getTileAtChar(mut g Game) i64:
	g.getTile(g.char.room, g.char.currCol, g.char.currRow)

# set_char_collision: the columns and rows the character's picture covers
pub fn setCharCollision(mut g Game):
	if g.pictureDims(g.objChtab, g.objId) is p:
		g.charWidthHalf = (p.width + 1) / 2
		g.charHeight = p.height
	else:
		g.charWidthHalf = 0
		g.charHeight = 0
	g.charXLeft = short(g.objX / 2 + 58)
	if g.char.direction >= dirRight:
		g.charXLeft -= g.charWidthHalf
	g.charXLeftColl = g.charXLeft
	g.charXRight = g.charXLeft + g.charWidthHalf
	g.charXRightColl = g.charXRight
	g.charTopY = short(g.objY - g.charHeight + 1)
	if g.charTopY >= 192:
		g.charTopY = 0
	g.charTopRow = yToRowMod4(g.charTopY)
	g.charBottomRow = yToRowMod4(g.objY)
	if g.charBottomRow == -1:
		g.charBottomRow = 3
	g.charColLeft = g.getTileDivMod(g.charXLeft).max(0)
	g.charColRight = g.getTileDivMod(g.charXRight).min(9)
	if g.curFrame.flags & frameThin != 0:
		g.charXLeftColl += 4
		g.charXRightColl -= 4

pub fn checkOnFloor(mut g Game):
	if g.curFrame.flags & frameNeedsFloor == 0: return
	if g.getTileAtChar() == tileWall:
		g.inWall()
	if tileIsFloor(g.currTile2): return
	# special event: the floors that appear on level 12
	if g.currentLevel == 12 and g.unitedWithShadow < 0 and g.char.currRow == 0 and
		(g.char.room == 2 or (g.char.room == 13 and g.tileCol >= 6)):
		g.setRoomTile(g.currTilepos, tileFloor)
		g.setWipe(g.currTilepos, 1)
		g.setRedrawFull(g.currTilepos, 1)
		g.currTilepos += 1
		g.setWipe(g.currTilepos, 1)
		g.setRedrawFull(g.currTilepos, 1)
	else:
		g.startFall()

pub fn startFall(mut g Game):
	frame = g.char.frame
	g.char.sword = swordSheathed
	g.incCurrRow()
	g.startChompers()
	g.fallFrame = frame
	seqId = seqFall
	if frame == 9:
		seqId = seqFall   # run
	elif frame == 13:
		seqId = seqFall19
	elif frame == 26:
		seqId = seqFallAfterStandingJump
	elif frame == 44:
		seqId = seqFallAfterRunningJump
	elif frame >= 81 and frame < 86:
		seqId = seqFall19   # after jumping up
		g.char.x = byte(g.charDxForward(5))
		g.loadFramDetCol()
	elif frame >= 150 and frame < 180:
		# with the sword, falling or dead
		if g.char.charid == charidGuard:
			if g.char.currRow == 3 and g.char.currCol == 10:
				g.clearChar()
				return
			if g.char.fallX < 0:
				seqId = seqGuardPushedOffLedge
				if g.char.direction < dirRight and g.distanceToEdgeWeight() <= 7:
					g.char.x = byte(g.charDxForward(-5))
			else:
				g.droppedout = 0
				seqId = seqGuardFall
		else:
			g.droppedout = 1
			if g.char.direction < dirRight and g.distanceToEdgeWeight() <= 7:
				g.char.x = byte(g.charDxForward(-5))
			seqId = seqKidPushedOffLedge
	g.seqtblOffsetChar(seqId)
	g.playSeq()
	g.loadFramDetCol()
	if g.getTileAtChar() == tileWall:
		g.inWall()
		return
	if g.getTileInfrontofChar() == tileWall:
		if g.fallFrame != 44 or g.distanceToEdgeWeight() >= 6:
			g.char.x = byte(g.charDxForward(-1))
		else:
			g.seqtblOffsetChar(seqStartFallInFrontOfWall)
			g.playSeq()
		g.loadFramDetCol()

pub fn checkGrab(mut g Game):
	if g.controlShift == ctrlHeld and g.char.fallY < 32 and g.char.alive < 0 and
		word(yLand[g.char.currRow + 1]) <= word(g.char.y + 25):
		oldX = g.char.x
		g.char.x = byte(g.charDxForward(-8))
		g.loadFramDetCol()
		if not g.canGrabFrontAbove():
			g.char.x = oldX
		else:
			g.char.x = byte(g.charDxForward(g.distanceToEdgeWeight()))
			g.char.y = byte(yLand[g.char.currRow + 1])
			g.char.fallY = 0
			g.seqtblOffsetChar(seqGrabLedgeMidair)
			g.playSeq()
			g.grabTimer = 12
			g.playSound(soundGrab)
			g.isScreaming = 0

pub fn canGrabFrontAbove(mut g Game) bool:
	g.throughTile = g.getTileAboveChar()
	g.getTileFrontAboveChar()
	g.canGrab()

pub fn inWall(mut g Game):
	deltaX = g.distanceToEdgeWeight()
	if deltaX >= 8 or g.getTileInfrontofChar() == tileWall:
		deltaX = 6 - deltaX
	else:
		deltaX += 4
	g.char.x = byte(g.charDxForward(deltaX))
	g.loadFramDetCol()
	g.getTileAtChar()

pub fn getTileInfrontofChar(mut g Game) i64:
	g.infrontx = sbyte(dirFront[g.char.direction + 1] + g.char.currCol)
	g.getTile(g.char.room, g.infrontx, g.char.currRow)

pub fn getTileInfrontof2Char(mut g Game) i64:
	g.infrontx = sbyte((dirFront[g.char.direction + 1] << 1) + g.char.currCol)
	g.getTile(g.char.room, g.infrontx, g.char.currRow)

pub fn getTileBehindChar(mut g Game) i64:
	g.getTile(g.char.room, dirBehind[g.char.direction + 1] + g.char.currCol, g.char.currRow)

pub fn distanceToEdgeWeight(mut g Game) i64:
	g.distanceToEdge(g.dxWeight())

pub fn distanceToEdge(mut g Game, xpos i64) i64:
	g.getTileDivModM7(xpos)
	distance = g.objXl
	if g.char.direction == dirRight:
		distance = tileRightX - distance
	distance

pub fn fellOut(mut g Game):
	if g.char.alive < 0 and g.char.room == 0:
		g.takeHp(100)
		g.char.alive = 0
		g.eraseBottomText(true)
		g.char.frame = 185   # dead

pub fn incCurrRow(mut g Game):
	g.char.currRow = sbyte(g.char.currRow + 1)

pub fn seqtblOffsetChar(mut g Game, seq i64):
	g.char.currSeq = g.tables.seqStarts[seq]

pub fn seqtblOffsetOpp(mut g Game, seq i64):
	g.opp.currSeq = g.tables.seqStarts[seq]
