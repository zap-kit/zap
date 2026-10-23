# The draw tables and what the characters add to them (SDLPoP's seg008.c, the second half; the
# Apple II's GAMEBG.S and FRAMEADV.S): the back, middle and fore tables of pictures and the wipe
# table of rectangles, drawn in that order onto the screen kept off the display, with the peels
# that restore what moved; the objects (characters, swords, splashes, loose floors) sorted by
# tile; and the dungeon's random wall pattern.

pub tableBack = 0
pub tableFore = 1
pub tableMid = 3

# chtab_flip_clip: the tables whose pictures are mirrored and clipped (the sword, the kid and the
# people of the cutscenes, the guards)
chtabFlipClip = [true, false, true, true, true, true, false, false, false, false]

# add_backtable / add_foretable / add_midtable: a picture by its 1-based id, its bottom at
# ybottom; false when there is none
pub fn addBacktable(mut g Game, chtab i64, id i64, xh i64, xl i64, ybottom i64, blit i64) bool:
	g.addBackFore(tableBack, chtab, id, xh, xl, ybottom, blit)

pub fn addForetable(mut g Game, chtab i64, id i64, xh i64, xl i64, ybottom i64, blit i64) bool:
	g.addBackFore(tableFore, chtab, id, xh, xl, ybottom, blit)

fn addBackFore(
	mut g Game,
	which i64,
	chtab i64,
	id i64,
	xh i64,
	xl i64,
	ybottom i64,
	blit i64
):
	if id == 0: return false
	count = g.backtable.len if which == tableBack else g.foretable.len
	if count >= 200: return false
	if g.pictureDims(chtab, id - 1) is p:
		item = BackItem(
			xh = sbyte(xh),
			xl = sbyte(xl),
			y = short(ybottom - p.height + 1),
			chtabId = chtab,
			id = id - 1,
			blit
		)
		if which == tableBack:
			g.backtable.push(item)
		else:
			g.foretable.push(item)
		return true
	false

pub fn addMidtable(
	mut g Game,
	chtab i64,
	id i64,
	xh i64,
	xl i64,
	ybottom i64,
	blit i64,
	peel bool
) bool:
	if id == 0 or g.midtable.len >= 50: return false
	if g.pictureDims(chtab, id - 1) is p:
		b = blit
		if g.objDirection == dirRight and chtabFlipClip[chtab]:
			b += 0x80
		clip = Rect(
			top = g.objClipTop,
			left = g.objClipLeft,
			bottom = g.objClipBottom,
			right = g.objClipRight
		)
		g.midtable.push(
			MidItem(
				xh = sbyte(xh),
				xl = sbyte(xl),
				y = short(ybottom - p.height + 1),
				chtabId = chtab,
				id = id - 1,
				peel,
				clip,
				blit = b
			)
		)
		return true
	false

# ptr_add_table: the table the tile routines add to (the overlays swap it)
pub fn ptrAddTable(
	mut g Game,
	chtab i64,
	id i64,
	xh i64,
	xl i64,
	ybottom i64,
	blit i64,
	peel bool
) bool:
	if g.addTable == tableMid: return g.addMidtable(chtab, id, xh, xl, ybottom, blit, peel)
	if g.addTable == tableFore: return g.addForetable(chtab, id, xh, xl, ybottom, blit)
	g.addBacktable(chtab, id, xh, xl, ybottom, blit)

fn addPeel(mut g Game, left i64, right i64, top i64, height i64):
	if g.peels.len >= 50: return
	g.peels.push(g.screen.readPeel(Rect(top, left, top + height, right)))

pub fn addWipetable(
	mut g Game,
	layer i64,
	left i64,
	bottom i64,
	height i64,
	width i64,
	color i64
):
	if g.wipetable.len >= 300: return
	g.wipetable.push(
		WipeItem(
			left = short(left),
			bottom = short(bottom + 1),
			height = sbyte(height),
			width = short(width),
			color = sbyte(color),
			layer = sbyte(layer)
		)
	)

fn drawTable(mut g Game, which i64):
	if which == tableMid:
		for i in 0..g.midtable.len:
			g.drawMid(i)
	elif which == tableBack:
		for i in 0..g.backtable.len:
			b = g.backtable[i]
			g.drawTableImage(b.chtabId, b.id, b.xh * 8 + b.xl, b.y, b.blit, false)
	else:
		for i in 0..g.foretable.len:
			b = g.foretable[i]
			g.drawTableImage(b.chtabId, b.id, b.xh * 8 + b.xl, b.y, b.blit, false)

fn drawWipes(mut g Game, which i64):
	for i in 0..g.wipetable.len:
		w = g.wipetable[i]
		if w.layer == which:
			r = Rect(
				top = w.bottom - w.height,
				left = w.left,
				bottom = w.bottom,
				right = w.left + w.width
			)
			g.screen.drawRect(g.pal, r, w.color)
			if g.needDrects: g.addDrect(r)

# a table's picture drawn, and where it was noted for the copy to the display (draw_image)
fn drawTableImage(mut g Game, chtab i64, id i64, xpos i64, ypos i64, blit i64, flip bool):
	g.drawImage(chtab, id, xpos, ypos, blit, flip)
	if g.needDrects:
		if g.pictureDims(chtab, id) is d:
			g.addDrect(
				Rect(top = ypos, left = xpos, bottom = ypos + d.height, right = xpos + d.width)
			)

# add_drect: a rectangle to copy, joined to the first one it touches
pub fn addDrect(mut g Game, r Rect):
	grown = Rect(top = r.top - 1, left = r.left - 1, bottom = r.bottom + 1, right = r.right + 1)
	for i in 0..g.drects.len:
		d = g.drects[i]
		if grown.rectsIntersect(d):
			g.drects[i] = Rect(
				top = d.top.min(r.top),
				left = d.left.min(r.left),
				bottom = d.bottom.max(r.bottom),
				right = d.right.max(r.right)
			)
			return
	if g.drects.len < 30:
		g.drects.push(r)

fn rectsIntersect(a Rect, b Rect):
	a.left.max(b.left) < a.right.min(b.right) and a.top.max(b.top) < a.bottom.min(b.bottom)

# the rectangles drawn this frame copied to the display, the last first
pub fn copyDrects(mut g Game):
	while g.drects.pop() is d:
		g.screen.copyRect(d, g.upsideDown != 0)

fn drawMid(mut g Game, index i64):
	m = g.midtable[index]
	xpos = short(m.xh * 8 + m.xl)
	ypos = m.y
	blit = m.blit
	flip = blit & 0x80 != 0
	if flip: blit &= 0x7F
	if chtabFlipClip[m.chtabId]:
		g.screen.clip = m.clip
		if m.chtabId != chtabSword:
			xpos = calcScreenXCoord(xpos)
	if g.pictureDims(m.chtabId, m.id) is p:
		if flip: xpos -= p.width
		if m.peel:
			g.addPeel(xpos, p.width + xpos, ypos, p.height)
	g.drawTableImage(m.chtabId, m.id, xpos, ypos, blit, flip)
	if chtabFlipClip[m.chtabId]:
		g.screen.resetClip()

# draw_image: a picture of a table by its blitter
pub fn drawImage(mut g Game, chtab i64, id i64, xpos i64, ypos i64, blit i64, flip bool):
	if g.chtabs[chtab] is t:
		if id >= 0 and id < t.pictures.len:
			if t.pictures[id] is p:
				g.screen.drawPicture(g.pal, t, p, xpos, ypos, blit, flip)

# draw_tables: the peels restored, then the back table, the middle one and the fore one, with the
# wipes of each layer before it
pub fn drawTables(mut g Game):
	g.drects.clear()
	g.screen.toOnscreen = false
	if g.isBlindMode != 0:
		g.screen.drawRect(g.pal, Rect(0, 0, 192, 320), colorBlack)
	g.restorePeels()
	g.drawWipes(0)
	g.drawTable(tableBack)
	g.drawTable(tableMid)
	g.drawWipes(1)
	g.drawTable(tableFore)
	g.screen.toOnscreen = true
	g.showCopyprot(1)

fn restorePeels(mut g Game):
	while g.peels.pop() is p:
		if g.needDrects: g.addDrect(p.rect)
		g.screen.restorePeel(p)

# draw_moving: the mobs and the people, then the tiles they marked to be drawn again
pub fn drawMoving(mut g Game):
	g.drawMobs()
	g.drawPeople()
	g.redrawNeededTiles()

fn redrawNeededTiles(mut g Game):
	g.loadLeftroom()
	g.drawObjtableItemsAtTile(30)
	g.drawnRow = 2
	while g.drawnRow >= 0:
		g.loadRowbelow()
		g.drawBottomY = 63 * g.drawnRow + 65
		g.drawMainY = g.drawBottomY - 3
		g.drawnCol = 0
		while g.drawnCol < 10:
			g.loadCurrAndLeftTile()
			g.redrawNeeded(tblLine[g.drawnRow] + g.drawnCol)
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
		g.redrawNeededAbove(g.drawnCol)
		g.drawnCol += 1
	g.drawnRoom = savedRoom
	g.loadRoomLinks()
	g.drawObjtableItemsAtTile(255)

fn redrawNeeded(mut g Game, tilepos i64):
	if g.wipeFrames[tilepos] != 0:
		g.wipeFrames[tilepos] -= 1
		g.drawTileWipe(g.wipeHeights[tilepos])
	if g.redrawFramesFull[tilepos] != 0:
		g.redrawFramesFull[tilepos] -= 1
		g.drawTile()
	elif g.redrawFramesAnim[tilepos] != 0:
		g.redrawFramesAnim[tilepos] -= 1
		g.drawTileAnimTopright()
		g.drawTileAnimRight()
		g.drawTileAnim()
	if g.redrawFrames2[tilepos] != 0:
		g.redrawFrames2[tilepos] -= 1
		g.drawOtherOverlay()
	elif g.redrawFramesFloorOverlay[tilepos] != 0:
		g.redrawFramesFloorOverlay[tilepos] -= 1
		g.drawFloorOverlay()
	if g.tileObjectRedraw[tilepos] != 0:
		if g.tileObjectRedraw[tilepos] == 0xFF:
			g.drawObjtableItemsAtTile(byte(tilepos - 1))
		g.drawObjtableItemsAtTile(tilepos)
		g.tileObjectRedraw[tilepos] = 0
	if g.redrawFramesFore[tilepos] != 0:
		g.redrawFramesFore[tilepos] -= 1
		g.drawTileFore()

fn redrawNeededAbove(mut g Game, column i64):
	if g.redrawFramesAbove[column] == 0: return
	g.redrawFramesAbove[column] -= 1
	g.drawTileWipe(3)
	g.drawTileFloorright()
	g.drawTileAnimTopright()
	g.drawTileRight()
	g.drawTileBottom(1)
	g.drawLoose()
	g.drawTileFore()

fn drawTileWipe(mut g Game, height i64):
	g.addWipetable(0, g.drawXh * 8, g.drawBottomY, height, 4 * 8, 0)

# ---------- the objects ----------

fn drawObjtableItemsAtTile(mut g Game, tilepos i64):
	if g.objtable.isEmpty: return
	currObjs = []
	i = g.objtable.len - 1
	while i >= 0:
		if g.objtable[i].tilepos == tilepos:
			currObjs.push(i)
		i -= 1
	if currObjs.isEmpty: return
	g.sortCurrObjs(currObjs)
	for k in currObjs:
		g.drawObjtableItem(k)

# a bubble sort, as the original's
fn sortCurrObjs(g Game, mut currObjs i64[]):
	last = currObjs.len - 1
	loop:
		swapped = false
		for i in 0..last:
			if g.compareCurrObjs(currObjs[i], currObjs[i + 1]):
				temp = currObjs[i]
				currObjs[i] = currObjs[i + 1]
				currObjs[i + 1] = temp
				swapped = true
		if not swapped: break

fn compareCurrObjs(g Game, a i64, b i64):
	if g.objtable[a].objType == 1: return true
	if g.objtable[b].objType == 1: return false
	if g.objtable[a].objType == 0x80 and g.objtable[b].objType == 0x80:
		return g.objtable[a].y < g.objtable[b].y
	g.objtable[a].y > g.objtable[b].y

fn drawObjtableItem(mut g Game, index i64):
	kind = g.loadObjFromObjtable(index)
	shadow = kind == 1
	if kind == 0 or kind == 4:
		# the kid or his mirror image, blinking a while after uniting with the shadow
		if g.objId == 0xFF: return
		if g.unitedWithShadow != 0 and g.unitedWithShadow % 2 == 0:
			shadow = true
		else:
			g.addMidtable(g.objChtab, g.objId + 1, g.objXh, g.objXl, g.objY, blitTransp, true)
	elif kind in [2, 3, 5]:
		g.addMidtable(g.objChtab, g.objId + 1, g.objXh, g.objXl, g.objY, blitTransp, true)
	elif kind == 0x80:
		# a loose floor falling
		g.objDirection = dirLeft
		g.addMidtable(
			g.objChtab,
			looseFramLeft[g.objId],
			g.objXh,
			g.objXl,
			g.objY - 3,
			blitTransp,
			true
		)
		g.addMidtable(g.objChtab, looseFramBottom[g.objId], g.objXh, g.objXl, g.objY, 0, true)
		g.addMidtable(
			g.objChtab,
			looseFramRight[g.objId],
			g.objX + 4,
			g.objXl,
			g.objY - 1,
			blitTransp,
			true
		)
	if shadow:
		if g.unitedWithShadow == 2:
			g.playSound(soundEndLevelMusic)
		g.addMidtable(g.objChtab, g.objId + 1, g.objXh, g.objXl, g.objY, blitOr, true)
		g.addMidtable(g.objChtab, g.objId + 1, g.objXh, g.objXl + 1, g.objY, blitXor, true)

fn loadObjFromObjtable(mut g Game, index i64):
	o = g.objtable[index]
	g.objX = o.xh
	g.objXh = byte(o.xh)
	g.objXl = byte(o.xl)
	g.objY = byte(o.y)
	g.objId = o.id
	g.objChtab = o.chtabId
	g.objDirection = o.direction
	g.objClipTop = o.clip.top
	g.objClipBottom = o.clip.bottom
	g.objClipLeft = o.clip.left
	g.objClipRight = o.clip.right
	o.objType

fn drawPeople(mut g Game):
	g.checkMirror()
	g.drawKid()
	g.drawGuard()
	g.resetObjClip()
	g.drawHp()

fn drawKid(mut g Game):
	if g.kid.room != 0 and g.kid.room == g.drawnRoom:
		g.addKidToObjtable()
		if g.hitpDelta < 0:
			g.drawHurtSplash()
		g.addSwordToObjtable()

fn drawGuard(mut g Game):
	if g.guard.direction != dirNone and g.guard.room == g.drawnRoom:
		g.addGuardToObjtable()
		if g.guardhpDelta < 0:
			g.drawHurtSplash()
		g.addSwordToObjtable()

fn addCharToObjtable(mut g Game):
	g.loadFramDetCol()
	g.loadFrameToObj()
	g.stuckLower()
	g.setCharCollision()
	g.setObjtileAtChar()
	g.redrawAtChar()
	g.redrawAtChar2()
	g.clipChar()

fn addKidToObjtable(mut g Game):
	g.loadkid()
	g.addCharToObjtable()
	g.addObjtable(0)   # the kid

fn addGuardToObjtable(mut g Game):
	g.loadshad()
	g.addCharToObjtable()
	if g.char.charid == charidShadow:
		# special event: the shadow shows only right of the mirror
		if g.currentLevel == g.options.opt("mirror_level") and
			g.char.room == g.options.opt("mirror_room"):
			g.objClipLeft = 137 + (g.options.opt("mirror_column") - 4) * 32
		g.addObjtable(1)   # the shadow
	else:
		g.addObjtable(2)   # a guard

pub fn addObjtable(mut g Game, objType i64):
	if g.objtable.len >= 50: return
	xh, xl = xToXhAndXl(g.objX)
	clip = Rect(
		top = g.objClipTop,
		left = g.objClipLeft,
		bottom = g.objClipBottom,
		right = g.objClipRight
	)
	g.objtable.push(
		ObjItem(
			xh,
			xl,
			y = g.objY,
			chtabId = g.objChtab,
			id = g.objId,
			direction = g.objDirection,
			objType,
			clip,
			tilepos = g.objTilepos
		)
	)
	if g.objTilepos < 30:
		g.tileObjectRedraw[g.objTilepos] = 1

# load_frame_to_obj: the character's frame as the object to draw
pub fn loadFrameToObj(mut g Game):
	g.resetObjClip()
	g.loadFrame()
	g.objDirection = g.char.direction
	g.objId = g.curFrame.image
	g.objChtab = chtabKid + (g.curFrame.sword >> 6)   # the top bits of sword pick the table
	g.objX = short((g.charDxForward(g.curFrame.dx) << 1) - 116)
	g.objY = byte(g.curFrame.dy + g.char.y)
	if sbyte(g.curFrame.flags ^ g.objDirection) >= 0:
		g.objX += 1   # the even/odd pixel

pub fn calcScreenXCoord(logicalX i64) i64:
	short(logicalX * 320 / 280)

# ---------- the wall pattern (HTamas's tracing of the original) ----------

# prandom: the original's random numbers 0..max
pub fn prandom(mut g Game, max i64) i64:
	g.randomSeed = (g.randomSeed * 214_013 + 2_531_011) & 0xFFFF_FFFF
	(g.randomSeed >> 16) % (max + 1)

fn wallPattern(mut g Game, whichPart i64, whichTable i64):
	savedTable = g.addTable
	g.addTable = tableBack if whichTable == 0 else tableFore
	savedSeed = g.randomSeed
	g.randomSeed = g.drawnRoom + tblLine[g.drawnRow] + g.drawnCol
	g.prandom(1)
	if g.isPalace():
		g.palaceWallPattern(whichPart, whichTable)
	else:
		g.dungeonWallPattern(whichPart)
	g.randomSeed = savedSeed
	g.addTable = savedTable

fn palaceWallPattern(mut g Game, whichPart i64, whichTable i64):
	at = 44 * g.drawnRow + g.drawnCol
	if whichPart != 0:
		# the bricks' colours, then the decals between them
		g.addWipetable(
			whichTable,
			8 * g.drawXh,
			g.drawMainY - 40,
			20,
			4 * 8,
			g.palaceWallColors[at]
		)
		g.addWipetable(
			whichTable,
			8 * g.drawXh,
			g.drawMainY - 19,
			21,
			2 * 8,
			g.palaceWallColors[at + 11]
		)
		g.addWipetable(
			whichTable,
			8 * (g.drawXh + 2),
			g.drawMainY - 19,
			21,
			2 * 8,
			g.palaceWallColors[at + 12]
		)
		g.addWipetable(
			whichTable,
			8 * g.drawXh,
			g.drawMainY,
			19,
			1 * 8,
			g.palaceWallColors[at + 22]
		)
		g.addWipetable(
			whichTable,
			8 * (g.drawXh + 1),
			g.drawMainY,
			19,
			3 * 8,
			g.palaceWallColors[at + 23]
		)
		g.ptrAddTable(
			chtabEnvironmentWall,
			g.prandom(2) + 3,
			g.drawXh + 3,
			0,
			g.drawMainY - 53,
			blitMono + 6,
			false
		)
		g.ptrAddTable(
			chtabEnvironmentWall,
			g.prandom(2) + 6,
			g.drawXh,
			0,
			g.drawMainY - 34,
			blitMono + 6,
			false
		)
		g.ptrAddTable(
			chtabEnvironmentWall,
			g.prandom(2) + 9,
			g.drawXh,
			0,
			g.drawMainY - 13,
			blitMono + 6,
			false
		)
		g.ptrAddTable(
			chtabEnvironmentWall,
			g.prandom(2) + 12,
			g.drawXh,
			0,
			g.drawMainY,
			blitMono + 6,
			false
		)
	g.addWipetable(whichTable, 8 * g.drawXh, g.drawBottomY, 3, 4 * 8, g.palaceWallColors[at + 33])
	g.ptrAddTable(
		chtabEnvironmentWall,
		g.prandom(2) + 15,
		g.drawXh,
		0,
		g.drawBottomY,
		blitMono + 6,
		false
	)

# the walls' pictures: 11/12 the broad and narrow dividers, 13 a random block, 14..17 the marks
fn dungeonWallPattern(mut g Game, whichPart i64):
	middleDivider = g.prandom(1)
	middleOffset = g.prandom(4)
	bottomDivider = g.prandom(1)
	bottomOffset = g.prandom(4)
	wallLeft = g.currModifier & 2 != 0
	wallRight = g.currModifier & 1 != 0
	part = whichPart != 0
	if wallLeft and wallRight:
		if part:
			g.wallRandomBlock()
			g.wallMiddleDivider(middleDivider, middleOffset)
		g.wallBottomDivider(bottomDivider, bottomOffset)
		if part:
			if g.prandom(4) == 0:
				g.drawRightMark(g.prandom(3), middleOffset)
			if g.prandom(4) == 0:
				g.drawLeftMark(
					g.prandom(4),
					middleOffset - middleDivider,
					bottomOffset - bottomDivider
				)
	elif not wallLeft and not wallRight:
		if part and g.prandom(6) == 0:
			g.drawLeftMark(
				g.prandom(1),
				middleOffset - middleDivider,
				bottomOffset - bottomDivider
			)
	elif wallRight:
		if part:
			g.wallRandomBlock()
			g.wallMiddleDivider(middleDivider, middleOffset)
			if g.prandom(4) == 0:
				g.drawRightMark(g.prandom(3), middleOffset)
			if g.prandom(4) == 0:
				g.drawLeftMark(
					g.prandom(3),
					middleOffset - middleDivider,
					bottomOffset - bottomDivider
				)
	else:
		if part:
			g.wallMiddleDivider(middleDivider, middleOffset)
		g.wallBottomDivider(bottomDivider, bottomOffset)
		if part:
			if g.prandom(4) == 0:
				g.drawRightMark(g.prandom(1) + 2, middleOffset)
			if g.prandom(4) == 0:
				g.drawLeftMark(
					g.prandom(4),
					middleOffset - middleDivider,
					bottomOffset - bottomDivider
				)

# a random block (13) one time in four, high on the wall
fn wallRandomBlock(mut g Game):
	if g.prandom(4) == 0:
		g.ptrAddTable(
			chtabEnvironmentWall,
			13,
			g.drawXh,
			0,
			g.drawBottomY - 42,
			blitNoTransp,
			false
		)

fn wallMiddleDivider(mut g Game, divider i64, offset i64):
	g.ptrAddTable(
		chtabEnvironmentWall,
		11 + divider,
		g.drawXh + 1,
		offset,
		g.drawBottomY - 21,
		blitTransp,
		false
	)

fn wallBottomDivider(mut g Game, divider i64, offset i64):
	g.ptrAddTable(
		chtabEnvironmentWall,
		11 + divider,
		g.drawXh,
		offset,
		g.drawBottomY,
		blitTransp,
		false
	)

leftMarkY = [58, 41, 37, 20, 16]
rightMarkY = [52, 42, 31, 21]

fn drawLeftMark(mut g Game, variant i64, arg2 i64, arg1 i64):
	id = 15 if variant % 2 != 0 else 14
	xl = 0
	if variant > 3:
		xl = word(arg1 + 6)
	elif variant > 1:
		xl = word(arg2 + 6)
	xh = g.drawXh + (1 if variant == 2 or variant == 3 else 0)
	g.ptrAddTable(
		chtabEnvironmentWall,
		id,
		xh,
		xl,
		g.drawBottomY - leftMarkY[variant],
		blitTransp,
		false
	)

fn drawRightMark(mut g Game, variant i64, arg1 i64):
	id = 17 if variant % 2 != 0 else 16
	xl = 24 if variant < 2 else word(arg1 - 3)
	xh = g.drawXh + (1 if variant > 1 else 0)
	g.ptrAddTable(
		chtabEnvironmentWall,
		id,
		xh,
		xl,
		g.drawBottomY - rightMarkY[variant],
		blitTransp,
		false
	)

# gen_palace_wall_colors: the palace walls' brick colours, the same for a room each time
pub fn genPalaceWallColors(mut g Game):
	oldSeed = g.randomSeed
	g.randomSeed = g.drawnRoom
	g.prandom(1)
	for row in 0..3:
		for subrow in 0..4:
			base = 0x61 if subrow % 2 != 0 else 0x66
			prev = 0xFFFF
			for column in 0..11:
				color = base + g.prandom(3)
				while color == prev:
					color = base + g.prandom(3)
				g.palaceWallColors[44 * row + 11 * subrow + column] = color
				prev = color
	g.randomSeed = oldSeed
