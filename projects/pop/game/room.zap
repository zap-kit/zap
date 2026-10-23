# A room drawn into the tables (SDLPoP's seg008.c, the first half; the Apple II's GAMEBG.S and
# BGDATA.S): each tile as the pieces of it and of the tiles left of and below it that show, in
# the order the original lays them, plus the row of the room above.

# a tile's pieces: its base, its right side, the stripe, the top right, the bottom and the part in
# front of the characters, each a picture of the environment and where it sits (tile_table)
type Piece:
	baseId i64
	floorLeft i64
	baseY i64
	rightId i64
	floorRight i64
	rightY i64
	stripeId i64
	toprightId i64
	bottomId i64
	foreId i64
	foreX i64
	foreY i64

fn piece(v i64[]):
	Piece(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11])

tileTable = [
	piece([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),   # empty
	piece([41, 1, 0, 42, 1, 2, 145, 0, 43, 0, 0, 0]),   # floor
	piece([127, 1, 0, 133, 1, 2, 145, 0, 43, 0, 0, 0]),   # spike
	piece([92, 1, 0, 93, 1, 2, 0, 94, 43, 95, 1, 0]),   # pillar
	piece([46, 1, 0, 47, 1, 2, 0, 48, 43, 49, 3, 0]),   # door
	piece([41, 1, 1, 35, 1, 3, 145, 0, 36, 0, 0, 0]),   # stuck floor
	piece([41, 1, 0, 42, 1, 2, 145, 0, 96, 0, 0, 0]),   # close button
	piece([46, 1, 0, 0, 0, 2, 0, 0, 43, 49, 3, 0]),   # door top with floor
	piece([86, 1, 0, 87, 1, 2, 0, 0, 43, 88, 1, 0]),   # big pillar bottom
	piece([0, 0, 0, 89, 0, 3, 0, 90, 0, 91, 1, 3]),   # big pillar top
	piece([41, 1, 0, 42, 1, 2, 145, 0, 43, 12, 2, -3]),   # potion
	piece([0, 1, 0, 0, 0, 0, 145, 0, 0, 0, 0, 0]),   # loose floor
	piece([0, 0, 0, 0, 0, 2, 0, 0, 85, 49, 3, 0]),   # door top
	piece([75, 1, 0, 42, 1, 2, 0, 0, 43, 77, 0, 0]),   # mirror
	piece([97, 1, 0, 98, 1, 2, 145, 0, 43, 100, 0, 0]),   # debris
	piece([147, 1, 0, 42, 1, 1, 145, 0, 149, 0, 0, 0]),   # open button
	piece([41, 1, 0, 37, 0, 0, 0, 38, 43, 0, 0, 0]),   # level door left
	piece([0, 0, 0, 39, 1, 2, 0, 40, 43, 0, 0, 0]),   # level door right
	piece([0, 0, 0, 42, 1, 2, 145, 0, 43, 0, 0, 0]),   # chomper
	piece([41, 1, 0, 42, 1, 2, 0, 0, 43, 0, 0, 0]),   # torch
	piece([0, 0, 0, 1, 1, 2, 0, 2, 0, 0, 0, 0]),   # wall
	piece([30, 1, 0, 31, 1, 2, 0, 0, 43, 0, 0, 0]),   # skeleton
	piece([41, 1, 0, 42, 1, 2, 145, 0, 43, 0, 0, 0]),   # sword
	piece([41, 1, 0, 10, 0, 0, 0, 11, 43, 0, 0, 0]),   # balcony left
	piece([0, 0, 0, 12, 1, 2, 0, 13, 43, 0, 0, 0]),   # balcony right
	piece([92, 1, 0, 42, 1, 2, 145, 0, 43, 95, 1, 0]),   # lattice pillar
	piece([1, 0, 0, 0, 0, 0, 0, 0, 2, 9, 0, -53]),   # lattice down
	piece([3, 0, -10, 0, 0, 0, 0, 0, 0, 9, 0, -53]),   # lattice small
	piece([4, 0, -10, 0, 0, 0, 0, 0, 0, 9, 0, -53]),   # lattice left
	piece([5, 0, -10, 0, 0, 0, 0, 0, 0, 9, 0, -53]),   # lattice right
	piece([97, 1, 0, 98, 1, 2, 0, 0, 43, 100, 0, 0])   # debris with torch
]

colXh = [0, 4, 8, 12, 16, 20, 24, 28, 32, 36]
doortopFramTop = [0, 81, 83, 0]
doorFramTop = [60, 61, 62, 63, 64, 65, 66, 67]
bluelineFram1 = [0, 124, 125, 126]
bluelineFramY = [0, -20, -20, 0]
bluelineFram3 = [44, 44, 45, 45]
doortopFramBot = [78, 80, 82, 0]
spikesFramRight = [0, 134, 135, 136, 137, 138, 137, 135, 134, 0]
pub looseFramRight = [42, 71, 42, 72, 72, 42, 42, 42, 72, 72, 72, 0]
wallFramBottom = [7, 9, 5, 3]
pub looseFramBottom = [43, 73, 43, 74, 74, 43, 43, 43, 74, 74, 74, 0]
pub looseFramLeft = [41, 69, 41, 70, 70, 41, 41, 41, 70, 70, 70, 0]
spikesFramLeft = [0, 128, 129, 130, 131, 132, 131, 129, 128, 0]
potionFramBubb = [0, 16, 17, 18, 19, 20, 21, 22]
chomperFram1 = [3, 2, 0, 1, 4, 3, 3, 0]
chomperFramBot = [101, 102, 103, 104, 105, 0]
chomperFramTop = [0, 0, 111, 112, 113, 0]
chomperFramY = [0, 0, 0x25, 0x2F, 0x32]
spikesFramFore = [0, 139, 140, 141, 142, 143, 142, 140, 139, 0]
chomperFramFor = [106, 107, 108, 109, 110, 0]
wallFramMain = [8, 10, 6, 4]
doorFramSlice = [67, 59, 58, 57, 56, 55, 54, 53, 52]
floorLeftOverlay = [32, 151, 151, 150, 150, 151, 32, 32]

pub fn isPalace(g Game) bool:
	g.options.optAt("tbl_level_type", g.currentLevel) != 0

# redraw_room
pub fn redrawRoom(mut g Game):
	g.peels.clear()
	g.clearTables()
	g.resetObjClip()
	g.drawRoom()
	g.clearTileWipes()

pub fn clearTables(mut g Game):
	g.backtable.clear()
	g.foretable.clear()
	g.midtable.clear()
	g.wipetable.clear()
	g.objtable.clear()

pub fn loadRoomLinks(mut g Game):
	g.roomBR = 0
	g.roomBL = 0
	g.roomAR = 0
	g.roomAL = 0
	if g.drawnRoom == 0:
		g.roomB = 0
		g.roomA = 0
		g.roomR = 0
		g.roomL = 0
		return
	g.getRoomAddress(g.drawnRoom)
	links = g.level.links[g.drawnRoom - 1]
	g.roomL = links.left
	g.roomR = links.right
	g.roomA = links.up
	g.roomB = links.down
	if g.roomA != 0:
		g.roomAL = g.level.links[g.roomA - 1].left
		g.roomAR = g.level.links[g.roomA - 1].right
	else:
		if g.roomL != 0: g.roomAL = g.level.links[g.roomL - 1].up
		if g.roomR != 0: g.roomAR = g.level.links[g.roomR - 1].up
	if g.roomB != 0:
		g.roomBL = g.level.links[g.roomB - 1].left
		g.roomBR = g.level.links[g.roomB - 1].right
	else:
		if g.roomL != 0: g.roomBL = g.level.links[g.roomL - 1].down
		if g.roomR != 0: g.roomBR = g.level.links[g.roomR - 1].down

# the rows 2, 1, 0 of the room, then the bottom row of the room above along its top
pub fn drawRoom(mut g Game):
	g.loadLeftroom()
	g.drawnRow = 2
	while g.drawnRow >= 0:
		g.loadRowbelow()
		g.drawBottomY = 63 * g.drawnRow + 65
		g.drawMainY = g.drawBottomY - 3
		g.drawnCol = 0
		while g.drawnCol < 10:
			g.loadCurrAndLeftTile()
			g.drawTile()
			g.drawnCol += 1
		g.drawnRow -= 1
	savedRoom = g.drawnRoom
	g.drawnRoom = g.roomA
	g.loadRoomLinks()
	g.loadLeftroom()
	g.drawnRow = 2
	g.loadRowbelow()
	g.drawnCol = 0
	while g.drawnCol < 10:
		g.loadCurrAndLeftTile()
		g.drawMainY = -1
		g.drawBottomY = 2
		g.drawTileAboveroom()
		g.drawnCol += 1
	g.drawnRoom = savedRoom
	g.loadRoomLinks()

pub fn drawTile(mut g Game):
	g.drawTileFloorright()
	g.drawTileAnimTopright()
	g.drawTileRight()
	g.drawTileAnimRight()
	g.drawTileBottom(0)
	g.drawLoose()
	g.drawTileBase()
	g.drawTileAnim()
	g.drawTileFore()

fn drawTileAboveroom(mut g Game):
	g.drawTileFloorright()
	g.drawTileAnimTopright()
	g.drawTileRight()
	g.drawTileBottom(0)
	g.drawLoose()
	g.drawTileFore()

# get_tile_to_draw: a tile's kind and modifier as drawn (a pressed button drawn pressed)
pub fn getTileToDraw(mut g Game, room i64, column i64, row i64, tileRoom0 i64) (i64, i64):
	tiletype = tileRoom0
	modifier = 0
	if column == -1:
		tiletype = g.leftroomTiles[row]
		modifier = g.leftroomMods[row]
	elif room != 0:
		tilepos = tblLine[row] + column
		tiletype = g.roomTile(tilepos) & 0x1F
		modifier = g.roomMod(tilepos)
	t = tiletype & 0x1F
	if t == tileCloser:
		if g.getDoorlinkTimer(modifier) > 1: tiletype = tileStuck
	elif t == tileOpener:
		if g.getDoorlinkTimer(modifier) > 1:
			modifier = 0
			tiletype = tileFloor
	(tiletype, modifier)

fn loadCurrAndLeftTile(mut g Game):
	edge = g.options.opt("drawn_tile_top_level_edge") if g.drawnRow == 2 else tileWall
	t, m = g.getTileToDraw(g.drawnRoom, g.drawnCol, g.drawnRow, edge)
	g.currTile = t
	g.currModifier = m
	t, m = g.getTileToDraw(g.drawnRoom, g.drawnCol - 1, g.drawnRow, edge)
	g.tileLeft = t
	g.modifierLeft = m
	g.drawXh = colXh[g.drawnCol]

pub fn loadLeftroom(mut g Game):
	g.getRoomAddress(g.roomL)
	for row in 0..3:
		t, m = g.getTileToDraw(g.roomL, 9, row, g.options.opt("drawn_tile_left_level_edge"))
		g.leftroomTiles[row] = t
		g.leftroomMods[row] = m

pub fn loadRowbelow(mut g Game):
	room = g.drawnRoom
	roomLeft = g.roomL
	rowBelow = g.drawnRow + 1
	if g.drawnRow == 2:
		room = g.roomB
		roomLeft = g.roomBL
		rowBelow = 0
	g.getRoomAddress(room)
	for column in 1..10:
		t, m = g.getTileToDraw(room, column - 1, rowBelow, tileEmpty)
		g.rowBelowTiles[column] = t
		g.rowBelowMods[column] = m
	g.getRoomAddress(roomLeft)
	t, m = g.getTileToDraw(roomLeft, 9, rowBelow, tileWall)
	g.rowBelowTiles[0] = t
	g.rowBelowMods[0] = m
	g.getRoomAddress(g.drawnRoom)

fn drawTileFloorright(mut g Game):
	if not g.canSeeBottomleft(): return
	g.drawTileTopright()
	if tileTable[g.tileLeft].floorRight == 0: return
	g.addBacktable(
		chtabEnvironment,
		42,
		g.drawXh,
		0,
		tileTable[tileFloor].rightY + g.drawMainY,
		blitBlack
	)

fn canSeeBottomleft(g Game):
	g.currTile in [tileEmpty, tileBigpillarTop, tileDoortop] or
		g.currTile == tileLatticeDown

fn drawTileTopright(mut g Game):
	tiletype = g.rowBelowTiles[g.drawnCol]
	if tiletype == tileDoortopWithFloor or tiletype == tileDoortop:
		if not g.isPalace(): return
		g.addBacktable(
			chtabEnvironment,
			doortopFramTop[g.rowBelowMods[g.drawnCol]],
			g.drawXh,
			0,
			g.drawBottomY,
			blitOr
		)
	elif tiletype == tileWall:
		g.addBacktable(chtabEnvironmentWall, 2, g.drawXh, 0, g.drawBottomY, blitOr)
	else:
		g.addBacktable(
			chtabEnvironment,
			tileTable[tiletype].toprightId,
			g.drawXh,
			0,
			g.drawBottomY,
			blitOr
		)

pub fn drawTileAnimTopright(mut g Game):
	if (g.currTile in [tileEmpty, tileBigpillarTop, tileDoortop]) and
		g.rowBelowTiles[g.drawnCol] == tileGate:
		g.addBacktable(chtabEnvironment, 68, g.drawXh, 0, g.drawBottomY, blitMono)   # the gate top's mask
		modifier = g.rowBelowMods[g.drawnCol].min(188)
		g.addBacktable(
			chtabEnvironment,
			doorFramTop[(modifier >> 2) % 8],
			g.drawXh,
			0,
			g.drawBottomY,
			blitOr
		)

pub fn drawTileRight(mut g Game):
	if g.currTile == tileWall: return
	if g.tileLeft == tileEmpty:
		if g.modifierLeft > 3: return
		g.addBacktable(
			chtabEnvironment,
			bluelineFram1[g.modifierLeft],
			g.drawXh,
			0,
			bluelineFramY[g.modifierLeft] + g.drawMainY,
			blitOr
		)
	elif g.tileLeft == tileFloor:
		g.ptrAddTable(
			chtabEnvironment,
			42,
			g.drawXh,
			0,
			tileTable[g.tileLeft].rightY + g.drawMainY,
			blitTransp,
			false
		)
		num = 0 if g.modifierLeft > 3 else g.modifierLeft
		if num == (1 if g.isPalace() else 0): return
		g.addBacktable(
			chtabEnvironment,
			bluelineFram3[num],
			g.drawXh,
			0,
			g.drawMainY - 20,
			blitNoTransp
		)
	elif g.tileLeft == tileDoortopWithFloor or g.tileLeft == tileDoortop:
		if not g.isPalace(): return
		g.addBacktable(
			chtabEnvironment,
			doortopFramBot[g.modifierLeft],
			g.drawXh,
			0,
			tileTable[g.tileLeft].rightY + g.drawMainY,
			blitOr
		)
	elif g.tileLeft == tileWall:
		if g.isPalace() and g.modifierLeft & 0x80 == 0:
			g.addBacktable(chtabEnvironment, 84, g.drawXh + 3, 0, g.drawMainY - 27, blitNoTransp)   # the wall's stripe
		g.addBacktable(
			chtabEnvironmentWall,
			1,
			g.drawXh,
			0,
			tileTable[g.tileLeft].rightY + g.drawMainY,
			blitOr
		)
	else:
		g.drawTileRightOther()

fn drawTileRightOther(mut g Game):
	id = tileTable[g.tileLeft].rightId
	if id != 0:
		blit = blitOr
		if g.tileLeft == tileStuck:
			blit = blitTransp
			if g.currTile == tileEmpty or g.currTile == tileStuck or not tileIsFloor(g.currTile):
				id = 42   # floor B
		g.addBacktable(
			chtabEnvironment,
			id,
			g.drawXh,
			0,
			tileTable[g.tileLeft].rightY + g.drawMainY,
			blit
		)
	if g.isPalace():
		g.addBacktable(
			chtabEnvironment,
			tileTable[g.tileLeft].stripeId,
			g.drawXh,
			0,
			g.drawMainY - 27,
			blitOr
		)
	if g.tileLeft == tileTorch or g.tileLeft == tileTorchWithDebris:
		g.addBacktable(chtabEnvironment, 146, g.drawXh, 0, g.drawBottomY - 28, blitNoTransp)   # the torch's base

fn getSpikeFrame(modifier i64):
	5 if modifier & 0x80 != 0 else modifier

pub fn drawTileAnimRight(mut g Game):
	if g.tileLeft == tileSpike:
		g.addBacktable(
			chtabEnvironment,
			spikesFramRight[getSpikeFrame(g.modifierLeft)],
			g.drawXh,
			0,
			g.drawMainY - 7,
			blitTransp
		)
	elif g.tileLeft == tileGate:
		g.drawGateBack()
	elif g.tileLeft == tileLoose:
		g.addBacktable(
			chtabEnvironment,
			looseFramRight[getLooseFrame(g.modifierLeft)],
			g.drawXh,
			0,
			g.drawBottomY - 1,
			blitOr
		)
	elif g.tileLeft == tileLevelDoorLeft:
		g.drawLeveldoor()
	elif g.tileLeft == tileTorch or g.tileLeft == tileTorchWithDebris:
		if g.modifierLeft < 9:
			# pictures 1..9 are the flames
			g.addBacktable(
				chtabFlameSwordPotion,
				g.modifierLeft + 1,
				g.drawXh + 1,
				0,
				g.drawMainY - 40,
				blitNoTransp
			)

pub fn drawTileBottom(mut g Game, arg i64):
	id = 0
	blit = blitNoTransp
	chtab = chtabEnvironment
	if g.currTile == tileWall:
		if not g.isPalace():
			id = wallFramBottom[g.currModifier & 0x7F]
		chtab = chtabEnvironmentWall
	else:
		if g.currTile == tileDoortop: blit = blitOr
		id = tileTable[g.currTile].bottomId
	if g.ptrAddTable(chtab, id, g.drawXh, 0, g.drawBottomY, blit, false) and arg != 0:
		g.addForetable(chtab, id, g.drawXh, 0, g.drawBottomY, blit)
	if chtab == chtabEnvironmentWall:
		g.wallPattern(0, 0)

pub fn drawLoose(mut g Game):
	if g.currTile == tileLoose:
		id = looseFramBottom[getLooseFrame(g.currModifier)]
		g.addBacktable(chtabEnvironment, id, g.drawXh, 0, g.drawBottomY, blitNoTransp)
		g.addForetable(chtabEnvironment, id, g.drawXh, 0, g.drawBottomY, blitNoTransp)

pub fn drawTileBase(mut g Game):
	ybottom = g.drawMainY
	id = 0
	if g.tileLeft == tileLatticeDown and g.currTile == tileDoortop:
		id = 6   # lattice and door A
		ybottom += 3
	elif g.currTile == tileLoose:
		id = looseFramLeft[getLooseFrame(g.currModifier)]
	elif g.currTile == tileOpener and g.tileLeft == tileEmpty and not g.isPalace():
		id = 148   # the open button's left half with no floor left of it
	else:
		id = tileTable[g.currTile].baseId
	g.ptrAddTable(
		chtabEnvironment,
		id,
		g.drawXh,
		0,
		tileTable[g.currTile].baseY + ybottom,
		blitTransp,
		false
	)

pub fn drawTileAnim(mut g Game):
	if g.currTile == tileSpike:
		g.ptrAddTable(
			chtabEnvironment,
			spikesFramLeft[getSpikeFrame(g.currModifier)],
			g.drawXh,
			0,
			g.drawMainY - 2,
			blitTransp,
			false
		)
	elif g.currTile == tilePotion:
		g.drawPotionAnim()
	elif g.currTile == tileSword:
		lit = 1 if g.currModifier == 1 else 0
		g.addMidtable(
			chtabFlameSwordPotion,
			lit + 10,
			g.drawXh,
			0,
			g.drawMainY - 3,
			blitTransp,
			lit == 1
		)
	elif g.currTile == tileChomper:
		num = chomperFram1[(g.currModifier & 0x7F).min(6)]
		g.addBacktable(
			chtabEnvironment,
			chomperFramBot[num],
			g.drawXh,
			0,
			g.drawMainY,
			blitTransp
		)
		if g.currModifier & 0x80 != 0:
			g.addBacktable(   # blood
				chtabEnvironment,
				num + 114,
				g.drawXh + 1,
				4,
				g.drawMainY - 6,
				blitMono + 12
			)
		g.addBacktable(
			chtabEnvironment,
			chomperFramTop[num],
			g.drawXh,
			0,
			g.drawMainY - chomperFramY[num],
			blitTransp
		)

fn drawPotionAnim(mut g Game):
	kind = (g.currModifier & 0xF8) >> 3
	if kind == 0: return   # empty
	potSize = 0
	color = 12   # red
	if kind == 5 or kind == 6:
		color = 9   # blue: hurt, open
	elif kind == 3 or kind == 4:
		color = 10   # green: slow fall, upside down
		potSize = 1
	elif kind == 2:
		potSize = 1   # life
	y = g.drawMainY - (potSize << 2) - 14
	g.addBacktable(chtabFlameSwordPotion, 23, g.drawXh + 3, 1, y, blitMono)   # the bubble's mask
	g.addForetable(
		chtabFlameSwordPotion,
		potionFramBubb[g.currModifier & 7],
		g.drawXh + 3,
		1,
		y,
		color + blitMono
	)

pub fn drawTileFore(mut g Game):
	if g.tileLeft == tileGate and g.kid.currRow == g.drawnRow and
		g.kid.currCol == g.drawnCol - 1 and
		g.kid.room != g.roomR:
		g.drawGateFore()
	if g.currTile == tileSpike:
		g.addForetable(
			chtabEnvironment,
			spikesFramFore[getSpikeFrame(g.currModifier)],
			g.drawXh,
			0,
			g.drawMainY - 2,
			blitTransp
		)
	elif g.currTile == tileChomper:
		num = chomperFram1[(g.currModifier & 0x7F).min(6)]
		g.addForetable(
			chtabEnvironment,
			chomperFramFor[num],
			g.drawXh,
			0,
			g.drawMainY,
			blitTransp
		)
		if g.currModifier & 0x80 != 0:
			g.addForetable(
				chtabEnvironment,
				num + 119,
				g.drawXh + 1,
				4,
				g.drawMainY - 6,
				blitMono + 12
			)
	elif g.currTile == tileWall:
		if not g.isPalace():
			g.addForetable(
				chtabEnvironmentWall,
				wallFramMain[g.currModifier & 0x7F],
				g.drawXh,
				0,
				g.drawMainY,
				blitNoTransp
			)
		g.wallPattern(1, 1)
	else:
		g.drawTileForeOther()

fn drawTileForeOther(mut g Game):
	id = tileTable[g.currTile].foreId
	if id == 0: return
	xh = tileTable[g.currTile].foreX + g.drawXh
	ybottom = tileTable[g.currTile].foreY + g.drawMainY
	if g.currTile == tilePotion:
		# large pots for the potions 2, 3, 4; potions look different in the palace
		kind = (g.currModifier & 0xF8) >> 3
		if kind < 5 and kind >= 2: id = 13
		if g.isPalace(): id += 2
		g.addForetable(chtabFlameSwordPotion, id, xh, 6, ybottom, blitTransp)
	elif (g.currTile == tilePillar and not g.isPalace()) or
		(g.currTile >= tileLatticeSmall and g.currTile < tileTorchWithDebris):
		g.addForetable(chtabEnvironment, id, xh, 0, ybottom, blitNoTransp)
	else:
		g.addForetable(chtabEnvironment, id, xh, 0, ybottom, blitTransp)

pub fn getLooseFrame(modifier i64) i64:
	if modifier & 0x80 != 0:
		m = modifier & 0x7F
		if m > 10: return 1
		return m
	modifier

# ---------- gates and the level door ----------

fn calcGatePos(mut g Game):
	g.gateTopY = g.drawBottomY - 62
	g.gateOpenness = (g.modifierLeft.min(188) >> 2) + 1
	g.gateBottomY = g.drawMainY - g.gateOpenness

fn drawGateBack(mut g Game):
	g.calcGatePos()
	if g.gateBottomY + 12 < g.drawMainY:
		g.addBacktable(chtabEnvironment, 50, g.drawXh, 0, g.gateBottomY, blitNoTransp)   # the gate's bottom with B
	else:
		# erases the top right of the tile below left (drawn opaque), then draws it again unless
		# that was a gate or a pillar, as the original does
		g.addBacktable(
			chtabEnvironment,
			tileTable[tileGate].rightId,
			g.drawXh,
			0,
			tileTable[tileGate].rightY + g.drawMainY,
			blitNoTransp
		)
		if g.canSeeBottomleft(): g.drawTileTopright()
		g.drawTileBottom(0)
		g.drawLoose()
		g.drawTileBase()
		g.addBacktable(chtabEnvironment, 51, g.drawXh, 0, g.gateBottomY - 2, blitTransp)   # the gate's bottom
	ybottom = g.gateBottomY - 12
	if ybottom < 192:
		while ybottom >= 0 and ybottom > 7 and ybottom - 7 > g.gateTopY:
			g.addBacktable(chtabEnvironment, 52, g.drawXh, 0, ybottom, blitNoTransp)   # a slice of 8
			ybottom -= 8
	gateFrame = word(ybottom - g.gateTopY + 1)
	if gateFrame > 0 and gateFrame < 9:
		g.addBacktable(
			chtabEnvironment,
			doorFramSlice[gateFrame],
			g.drawXh,
			0,
			ybottom,
			blitNoTransp
		)

fn drawGateFore(mut g Game):
	g.calcGatePos()
	g.addForetable(chtabEnvironment, 51, g.drawXh, 0, g.gateBottomY - 2, blitTransp)
	ybottom = g.gateBottomY - 12
	if ybottom < 192:
		while ybottom >= 0 and ybottom > 7 and ybottom - 7 > g.gateTopY:
			g.addForetable(chtabEnvironment, 52, g.drawXh, 0, ybottom, blitTransp)
			ybottom -= 8

fn drawLeveldoor(mut g Game):
	ybottom = g.drawMainY - 13
	g.leveldoorRight = (g.drawXh << 3) + 48
	if g.isPalace(): g.leveldoorRight += 8
	g.addBacktable(chtabEnvironment, 99, g.drawXh + 1, 0, ybottom, blitNoTransp)   # the stairs' bottom
	if g.modifierLeft != 0:
		if g.level.startRoom != g.drawnRoom:
			g.addBacktable(chtabEnvironment, 144, g.drawXh + 1, 0, ybottom - 4, blitNoTransp)   # the stairs
		else:
			width = 48 if g.isPalace() else 39
			xLow = 0 if g.isPalace() else 2
			g.addWipetable(0, 8 * (g.drawXh + 1) + xLow, ybottom - 4, 45, width, 0)
	g.leveldoorYbottom = ybottom - (g.modifierLeft & 3) - 48
	y = ybottom - g.modifierLeft
	loop:
		g.addBacktable(chtabEnvironment, 33, g.drawXh + 1, 0, g.leveldoorYbottom, blitNoTransp)   # the door's bottom
		if y > g.leveldoorYbottom:
			g.leveldoorYbottom += 4
		else:
			break
	g.addBacktable(chtabEnvironment, 34, g.drawXh + 1, 0, g.drawMainY - 64, blitNoTransp)   # the door's top

# ---------- the level's modifiers as the game keeps them ----------

# alter_mods_allrm: gates open or shut, loose floors still, potions' kinds shifted and each wall's
# neighbours noted (bit 0 a wall right, bit 1 a wall left, 0x80 no blue)
pub fn alterModsAllrm(mut g Game):
	if g.level.usedRooms > 24: g.level.usedRooms = 24
	for room in 1..=g.level.usedRooms:
		g.getRoomAddress(room)
		g.roomL = g.level.links[room - 1].left
		g.roomR = g.level.links[room - 1].right
		for tilepos in 0..30:
			g.loadAlterMod(tilepos)

fn loadAlterMod(mut g Game, tilepos i64):
	tiletype = g.roomTile(tilepos) & 0x1F
	m = g.roomMod(tilepos)
	if tiletype == tileGate:
		g.setRoomMod(tilepos, 188 if m == 1 else 0)
	elif tiletype == tileLoose:
		g.setRoomMod(tilepos, 0)
	elif tiletype == tilePotion:
		g.setRoomMod(tilepos, 6 << 3 if g.isRightPotion(g.loadedRoom, tilepos) else m << 3)
	elif tiletype == tileWall:
		m = byte(m << 7)   # the "no blue" bit
		wallToLeft = true
		wallToRight = true
		if tilepos % 10 == 0:
			if g.roomL != 0:
				wallToLeft = (i64(g.level.tiles[30 * (g.roomL - 1) + tilepos + 9]) & 0x1F) ==
					tileWall
		else:
			wallToLeft = g.roomTile(tilepos - 1) & 0x1F == tileWall
		if tilepos % 10 == 9:
			if g.roomR != 0:
				wallToRight = (i64(g.level.tiles[30 * (g.roomR - 1) + tilepos - 9]) & 0x1F) ==
					tileWall
		else:
			wallToRight = g.roomTile(tilepos + 1) & 0x1F == tileWall
		if wallToLeft and wallToRight:
			m |= 3
		elif wallToLeft:
			m |= 2
		elif wallToRight:
			m |= 1
		g.setRoomMod(tilepos, m)

# ---------- overlays the climbing kid needs ----------

pub fn drawFloorOverlay(mut g Game):
	if g.tileLeft != tileEmpty: return
	if g.currTile in [tileFloor, tilePillar, tileStuck] or
		g.currTile == tileTorch:
		# frames 137..144: climbing
		if g.kid.frame >= 137 and g.kid.frame <= 144:
			g.addMidtable(
				chtabEnvironment,
				floorLeftOverlay[g.kid.frame - 137],
				g.drawXh,
				0,
				(1 if g.currTile == tileStuck else 0) + g.drawMainY,
				blitTransp,
				false
			)
		g.addTable = tableMid
		g.drawTileBottom(0)
		g.addTable = tableBack
	else:
		g.drawOtherOverlay()

pub fn drawOtherOverlay(mut g Game):
	if g.tileLeft == tileEmpty:
		g.addTable = tableMid
		g.drawTile2()
	elif g.currTile != tileEmpty and g.drawnCol > 0:
		left2, _ = g.getTileToDraw(g.drawnRoom, g.drawnCol - 2, g.drawnRow, tileEmpty)
		if left2 == tileEmpty:
			g.addTable = tableMid
			g.drawTile2()
			g.addTable = tableBack
			g.drawTile2()
			g.tileObjectRedraw[tblLine[g.drawnRow] + g.drawnCol] = 0xFF
	g.addTable = tableBack

fn drawTile2(mut g Game):
	g.drawTileRight()
	g.drawTileAnimRight()
	g.drawTileBase()
	g.drawTileAnim()
	g.drawTileBottom(0)
	g.drawLoose()
