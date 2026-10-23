# Collisions (SDLPoP's seg004.c; the Apple II's COLL.S): the walls and gates a character runs
# into, chompers that catch it, gates that push it, and how far the edge in front of it is.

wallDistFromLeft = [0, 10, 0, -1, 0, 0]
wallDistFromRight = [0, 0, 10, 13, 0, 0]

pub edgeTypeCloser = 0   # a closer, sword or potion
pub edgeTypeWall = 1   # a wall, gate, tapestry, mirror or chomper
pub edgeTypeFloor = 2   # floor, nothing near

pub fn checkCollisions(mut g Game):
	g.bumpColLeftOfWall = -1
	g.bumpColRightOfWall = -1
	if g.char.action == actTurn: return
	g.collisionRow = g.char.currRow
	g.moveCollToPrev()
	g.prevCollisionRow = g.collisionRow
	g.rightCheckedCol = (g.getTileDivModM7(g.charXRightColl) + 2).min(11)
	g.leftCheckedCol = g.getTileDivModM7(g.charXLeftColl) - 1
	g.getRowCollisionData(g.collisionRow, 0)
	g.getRowCollisionData(g.collisionRow + 1, 1)
	g.getRowCollisionData(g.collisionRow - 1, -1)
	column = 9
	while column >= 0:
		if g.currRowCollRoom[column] >= 0 and g.prevCollRoom[column] == g.currRowCollRoom[column]:
			# into a wall's left, or its right
			if (g.prevCollFlags[column] & 0x0F) == 0 and (g.currRowCollFlags[column] & 0x0F) != 0:
				g.bumpColLeftOfWall = column
			if (g.prevCollFlags[column] & 0xF0) == 0 and (g.currRowCollFlags[column] & 0xF0) != 0:
				g.bumpColRightOfWall = column
		column -= 1

fn moveCollToPrev(mut g Game):
	r = g.collisionRow
	p = g.prevCollisionRow
	for column in 0..10:
		if r == p or r + 3 == p or r - 3 == p:
			g.prevCollRoom[column] = g.currRowCollRoom[column]
			g.prevCollFlags[column] = g.currRowCollFlags[column]
		elif r + 1 == p or r - 2 == p:
			g.prevCollRoom[column] = g.aboveRowCollRoom[column]
			g.prevCollFlags[column] = g.aboveRowCollFlags[column]
		else:
			g.prevCollRoom[column] = g.belowRowCollRoom[column]
			g.prevCollFlags[column] = g.belowRowCollFlags[column]
		g.belowRowCollRoom[column] = -1
		g.aboveRowCollRoom[column] = -1
		g.currRowCollRoom[column] = -1

# a row's tiles near the character: which room each is in, and whether the character overlaps its
# wall from the left (0x0F) or the right (0xF0); `which` 0 the current row, 1 below, -1 above
fn getRowCollisionData(mut g Game, row i64, which i64):
	room = g.char.room
	g.collTileLeftXpos = xBump[g.leftCheckedCol + firstOnscreenColumn] + tileMidX
	column = g.leftCheckedCol
	while column <= g.rightCheckedCol:
		leftWallXpos = g.getLeftWallXpos(room, column, row)
		rightWallXpos = g.getRightWallXpos(room, column, row)
		flags = (0x0F if leftWallXpos < g.charXRightColl else 0) | (
			0xF0 if rightWallXpos > g.charXLeftColl else 0
		)
		if which == 0:
			g.currRowCollFlags[g.tileCol] = flags
			g.currRowCollRoom[g.tileCol] = sbyte(g.currRoom)
		elif which == 1:
			g.belowRowCollFlags[g.tileCol] = flags
			g.belowRowCollRoom[g.tileCol] = sbyte(g.currRoom)
		else:
			g.aboveRowCollFlags[g.tileCol] = flags
			g.aboveRowCollRoom[g.tileCol] = sbyte(g.currRoom)
		g.collTileLeftXpos += tileSizeX
		column += 1

fn getLeftWallXpos(mut g Game, room i64, column i64, row i64):
	t = wallType(g.getTile(room, column, row))
	if t != 0: return wallDistFromLeft[t] + g.collTileLeftXpos
	0xFF

fn getRightWallXpos(mut g Game, room i64, column i64, row i64):
	t = wallType(g.getTile(room, column, row))
	if t != 0: return g.collTileLeftXpos - wallDistFromRight[t] + tileRightX
	0

pub fn checkBumped(mut g Game):
	if g.char.action != actHangClimb and g.char.action != actHangStraight and
		(g.char.frame < 135 or g.char.frame >= 149):
		if g.bumpColLeftOfWall >= 0:
			g.checkBumpedLookRight()
		elif g.bumpColRightOfWall >= 0:
			g.checkBumpedLookLeft()

fn checkBumpedLookLeft(mut g Game):
	if (g.char.sword == swordDrawn or g.char.direction < dirRight) and
		g.isObstacleAtCol(g.bumpColRightOfWall):
		g.bumped(
			sbyte(g.getRightWallXpos(g.currRoom, g.tileCol, g.tileRow) - g.charXLeftColl),
			dirRight
		)

fn checkBumpedLookRight(mut g Game):
	if (g.char.sword == swordDrawn or g.char.direction == dirRight) and
		g.isObstacleAtCol(g.bumpColLeftOfWall):
		g.bumped(
			sbyte(g.getLeftWallXpos(g.currRoom, g.tileCol, g.tileRow) - g.charXRightColl),
			dirLeft
		)

fn isObstacleAtCol(mut g Game, col i64) bool:
	row = g.char.currRow
	if row < 0: row += 3
	if row >= 3: row -= 3
	g.getTile(g.currRowCollRoom[col], col, row)
	g.isObstacle()

fn isObstacle(mut g Game):
	if g.currTile2 == tilePotion: return false
	if g.currTile2 == tileGate:
		if not g.canBumpIntoGate(): return false
	elif g.currTile2 == tileChomper:
		if g.roomMod(g.currTilepos) != 2: return false   # the chomper is open
	elif g.currTile2 == tileMirror and g.char.charid == charidKid and g.char.frame >= 39 and
		g.char.frame < 44 and g.char.direction < dirRight:
		# a running jump leftwards through the mirror breaks it
		g.setRoomMod(g.currTilepos, 0x56)
		g.jumpedThroughMirror = -1
		return false
	g.collTileLeftXpos = g.xposInDrawnRoom(xBump[g.tileCol + firstOnscreenColumn]) + tileMidX
	true

fn xposInDrawnRoom(g Game, xpos i64):
	if g.currRoom != g.drawnRoom:
		if g.currRoom == g.roomL or g.currRoom == g.roomBL: return xpos - tileSizeX * 10
		if g.currRoom == g.roomR or g.currRoom == g.roomBR: return xpos + tileSizeX * 10
	xpos

fn bumped(mut g Game, deltaX i64, pushDirection i64):
	if g.char.alive >= 0 or g.char.frame == 177: return   # dead or spiked
	g.char.x = byte(g.char.x + deltaX)
	if pushDirection < dirRight:
		if g.currTile2 == tileWall:
			g.tileCol -= 1
			g.getTile(g.currRoom, g.tileCol, g.tileRow)
	elif g.currTile2 in [tileDoortop, tileDoortopWithFloor, tileWall]:
		g.tileCol += 1
		if g.currRoom == 0 and g.tileCol == 10:
			g.currRoom = g.char.room
			g.tileCol = 0
		g.getTile(g.currRoom, g.tileCol, g.tileRow)
	if tileIsFloor(g.currTile2):
		g.bumpedFloor(pushDirection)
	else:
		g.bumpedFall()

fn bumpedFall(mut g Game):
	action = g.char.action
	g.char.x = byte(g.charDxForward(-4))
	if action == actInFreefall:
		g.char.fallX = 0
	else:
		g.seqtblOffsetChar(seqBumpfall)
		g.playSeq()
	g.bumpedSound()

fn bumpedFloor(mut g Game, pushDirection i64):
	if g.char.sword != swordDrawn and word(yLand[g.char.currRow + 1] - g.char.y) >= 15:
		g.bumpedFall()
		return
	g.char.y = byte(yLand[g.char.currRow + 1])
	if g.char.fallY >= 22:
		g.char.x = byte(g.charDxForward(-5))
		return
	g.char.fallY = 0
	if g.char.alive == 0: return
	seqIndex = seqBump
	if g.char.sword == swordDrawn:
		if pushDirection == g.char.direction:
			g.seqtblOffsetChar(seqBumpForwardWithSword)
			g.playSeq()
			g.char.x = byte(g.charDxForward(1))
			return
		seqIndex = seqPushedBackWithSword
	else:
		frame = g.char.frame
		if frame == 24 or frame == 25 or (frame >= 40 and frame < 43) or
			(frame >= 102 and frame < 107):
			seqIndex = seqHardbump   # into a wall after a running jump
	g.seqtblOffsetChar(seqIndex)
	g.playSeq()
	g.bumpedSound()

fn bumpedSound(mut g Game):
	g.isGuardNotice = 1
	g.playSound(soundBumped)

pub fn clearCollRooms(mut g Game):
	for i in 0..10:
		g.prevCollRoom[i] = -1
		g.currRowCollRoom[i] = -1
		g.belowRowCollRoom[i] = -1
		g.aboveRowCollRoom[i] = -1
	g.prevCollisionRow = -1

fn canBumpIntoGate(g Game):
	(g.roomMod(g.currTilepos) >> 2) + 6 < g.charHeight

# get_edge_distance: how far ahead the edge is, and its kind in edge_type
pub fn getEdgeDistance(mut g Game) i64:
	g.determineCol()
	g.loadFrameToObj()
	g.setCharCollision()
	tiletype = g.getTileAtChar()
	distance = 0
	if wallType(tiletype) != 0:
		g.tileCol = g.char.currCol
		distance = g.distFromWallForward(tiletype)
		if distance >= 0:
			distance = g.wallEdge(distance)
			g.currTile2 = tiletype
			return distance
	tiletype = g.getTileInfrontofChar()
	if tiletype == tileDoortop and g.char.direction >= dirRight:
		g.edgeType = edgeTypeCloser
		distance = g.distanceToEdgeWeight()
	else:
		if wallType(tiletype) != 0:
			g.tileCol = g.infrontx
			distance = g.distFromWallForward(tiletype)
			if distance >= 0:
				distance = g.wallEdge(distance)
				g.currTile2 = tiletype
				return distance
		if tiletype == tileLoose:
			g.edgeType = edgeTypeCloser
			distance = g.distanceToEdgeWeight()
		elif tiletype in [tileCloser, tileSword, tilePotion]:
			distance = g.distanceToEdgeWeight()
			if distance != 0:
				g.edgeType = edgeTypeCloser
			else:
				g.edgeType = edgeTypeFloor
				distance = 11
		elif tileIsFloor(tiletype):
			g.edgeType = edgeTypeFloor
			distance = 11
		else:
			g.edgeType = edgeTypeCloser
			distance = g.distanceToEdgeWeight()
	g.currTile2 = tiletype
	distance

fn wallEdge(mut g Game, distance i64):
	if distance <= tileRightX:
		g.edgeType = edgeTypeWall
		return distance
	g.edgeType = edgeTypeFloor
	11

pub fn checkChompedKid(mut g Game):
	row = g.char.currRow
	for col in 0..10:
		if g.currRowCollFlags[col] == 0xFF and
			g.getTile(g.currRowCollRoom[col], col, row) == tileChomper and
			(g.roomMod(g.currTilepos) & 0x7F) == 2:
			g.chomped()

fn chomped(mut g Game):
	g.setRoomMod(g.currTilepos, g.roomMod(g.currTilepos) | 0x80)   # blood
	if g.char.frame != 178 and g.char.room == g.currRoom:
		g.char.x = byte(xBump[g.tileCol + firstOnscreenColumn] + tileMidX)
		g.char.x = byte(g.charDxForward(7 - (1 if g.char.direction == 0 else 0)))
		g.char.y = byte(yLand[g.char.currRow + 1])
		g.takeHp(100)
		g.playSound(soundChomped)
		g.seqtblOffsetChar(seqChomped)
		g.playSeq()

# a closing gate pushes the kid
pub fn checkGatePush(mut g Game):
	frame = g.char.frame
	if g.char.action == actTurn or frame == 15 or (frame >= 108 and frame < 111):
		g.getTileAtChar()
		origCol = g.tileCol
		gateHere = g.currTile2 == tileGate
		if not gateHere:
			g.tileCol -= 1
			gateHere = g.getTile(g.currRoom, g.tileCol, g.tileRow) == tileGate
		if gateHere and (g.currRowCollFlags[g.tileCol] & g.prevCollFlags[g.tileCol]) == 0xFF and
			g.canBumpIntoGate():
			g.bumpedSound()
			g.char.x = byte(g.char.x + 5 - (10 if origCol <= g.tileCol else 0))

pub fn checkGuardBumped(mut g Game):
	if g.char.action != actRunJump or g.char.alive >= 0 or g.char.sword < swordDrawn: return
	hit = g.getTileAtChar() == tileWall or g.currTile2 == tileDoortopWithFloor or
		(g.currTile2 == tileGate and g.canBumpIntoGate())
	if not hit and g.char.direction >= dirRight:
		g.tileCol -= 1
		hit = g.getTile(g.currRoom, g.tileCol, g.tileRow) == tileDoortopWithFloor or
			(g.currTile2 == tileGate and g.canBumpIntoGate())
	if not hit: return
	g.loadFrameToObj()
	g.setCharCollision()
	if g.isObstacle():
		deltaX = g.distFromWallBehind(g.currTile2)
		if deltaX < 0 and deltaX > -13:
			g.char.x = byte(g.charDxForward(-deltaX))
			g.seqtblOffsetChar(seqBumpForwardWithSword)
			g.playSeq()
			g.loadFramDetCol()

pub fn checkChompedGuard(mut g Game):
	g.getTileAtChar()
	if not g.checkChompedHere():
		g.tileCol += 1
		g.getTile(g.currRoom, g.tileCol, g.tileRow)
		g.checkChompedHere()

fn checkChompedHere(mut g Game):
	if g.currTile2 == tileChomper and (g.roomMod(g.currTilepos) & 0x7F) == 2:
		g.collTileLeftXpos = xBump[g.tileCol + firstOnscreenColumn] + tileMidX
		if g.getLeftWallXpos(g.currRoom, g.tileCol, g.tileRow) < g.charXRightColl and
			g.getRightWallXpos(g.currRoom, g.tileCol, g.tileRow) > g.charXLeftColl:
			g.chomped()
			return true
	false

pub fn distFromWallForward(mut g Game, tiletype i64) i64:
	if tiletype == tileGate and not g.canBumpIntoGate(): return -1
	g.collTileLeftXpos = xBump[g.tileCol + firstOnscreenColumn] + tileMidX
	t = wallType(tiletype)
	if t == 0: return -1
	if g.char.direction < dirRight:
		return g.charXLeftColl - (g.collTileLeftXpos + tileRightX - wallDistFromRight[t])
	wallDistFromLeft[t] + g.collTileLeftXpos - g.charXRightColl

pub fn distFromWallBehind(g Game, tiletype i64) i64:
	t = wallType(tiletype)
	if t == 0: return 99
	if g.char.direction >= dirRight:
		return g.charXLeftColl - (g.collTileLeftXpos + tileRightX - wallDistFromRight[t])
	wallDistFromLeft[t] + g.collTileLeftXpos - g.charXRightColl
