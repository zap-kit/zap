# Loose floors and the chompers they wake (SDLPoP's seg007.c, the second half; the Apple II's
# MOVER.S): a loose floor shakes, falls as a moving object (a mob) row by row and crashes into
# debris; chompers start in a row when a character enters it.

yLooseLand = [2, 65, 128, 191, 254]
looseSound = [0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0]
ySomething = [-1, 62, 125, 188, 25]

fn animateLoose(mut g Game):
	if g.trob.trobType >= 0:
		g.currModifier = byte(g.currModifier + 1)
		if g.currModifier & 0x80 != 0:
			# just shaking; level 13's floors keep on, to fall by themselves
			if g.currentLevel == g.options.opt("loose_tiles_level"): return
			if g.currModifier >= 0x84:
				g.currModifier = 0
				g.trob.trobType = -1
			g.looseShake(g.currModifier == 0)
		elif g.currModifier >= g.options.opt("loose_floor_delay"):
			# something stood on it long enough: it falls
			room = g.trob.room
			tilepos = g.trob.tilepos
			g.currModifier = g.removeLoose(tilepos)
			g.trob.trobType = -1
			row = tilepos / 10
			g.curmob = Mob(
				xh = byte((tilepos % 10) << 2),
				y = byte(yLooseLand[row + 1]),
				room,
				speed = 0,
				mobType = 0,
				row
			)
			g.addMob()
		else:
			g.looseShake(false)
	g.redrawTileHeight(0x20)

fn looseShake(mut g Game, always bool):
	if always or looseSound[g.currModifier & 0x7F] != 0:
		soundId = g.prandom(2) + soundLooseShake1
		while soundId == g.lastLooseSound:
			soundId = g.prandom(2) + soundLooseShake1
		g.prandom(2)   # a number the original draws and drops
		g.lastLooseSound = soundId
		g.playSound(soundId)

# remove_loose: the floor gone; the empty tile's modifier is the level's kind
fn removeLoose(mut g Game, tilepos i64):
	g.setRoomTile(tilepos, tileEmpty)
	g.options.optAt("tbl_level_type", g.currentLevel)

pub fn makeLooseFall(mut g Game, modifier i64):
	# a loose floor with bit 0x20 is solid
	if (g.roomTile(g.currTilepos) & 0x20) == 0 and sbyte(g.roomMod(g.currTilepos)) <= 0:
		g.setRoomMod(g.currTilepos, modifier)
		g.addTrob(g.currRoom, g.currTilepos, 0)
		g.redrawTileHeight(0x20)

pub fn startChompers(mut g Game):
	timing = 15
	if g.char.currRow < 0 or g.char.currRow >= 3: return
	g.getRoomAddress(g.char.room)
	tilepos = tblLine[g.char.currRow]
	loop 10:
		if g.getCurrTile(tilepos) == tileChomper:
			modifier = g.currModifier & 0x7F
			if modifier == 0 or modifier >= 6:
				g.startAnimChomper(g.char.room, tilepos, timing | (g.currModifier & 0x80))
				timing = nextChomperTiming(timing)
		tilepos += 1

# 15, 12, 9, 6, 13, 10, 7, 14, 11, 8, again
fn nextChomperTiming(timing i64):
	t = byte(timing - 3)
	t + 10 if t < 6 else t

fn looseMakeShake(mut g Game):
	if g.roomMod(g.currTilepos) == 0 and g.currentLevel != g.options.opt("loose_tiles_level"):
		g.setRoomMod(g.currTilepos, 0x80)
		g.addTrob(g.currRoom, g.currTilepos, 1)

pub fn doKnock(mut g Game, room i64, row i64):
	for col in 0..10:
		if g.getTile(room, col, row) == tileLoose:
			g.looseMakeShake()

fn addMob(mut g Game):
	if g.mobs.len >= 14: return
	g.mobs.push(g.curmob)

pub fn doMobs(mut g Game):
	n = g.mobs.len
	g.curmobIndex = 0
	while g.curmobIndex < n:
		g.curmob = g.mobs[g.curmobIndex]
		g.moveMob()
		g.checkLooseFallOnKid()
		g.mobs[g.curmobIndex] = g.curmob
		g.curmobIndex += 1
	kept = []
	for m in g.mobs:
		if m.speed != -1: kept.push(m)
	g.mobs = kept

fn moveMob(mut g Game):
	if g.curmob.mobType == 0:
		g.moveLoose()
	if g.curmob.speed <= 0:
		g.curmob.speed += 1

fn moveLoose(mut g Game):
	if g.curmob.speed < 0: return
	if g.curmob.speed < 29: g.curmob.speed += 3
	g.curmob.y = byte(g.curmob.y + g.curmob.speed)
	if g.curmob.room == 0:
		if g.curmob.y >= 210: g.curmob.speed = -2
		return
	if g.curmob.y < 226 and ySomething[g.curmob.row + 1] <= g.curmob.y:
		# fell into another row
		tileTemp = g.getTile(g.curmob.room, g.curmob.xh >> 2, g.curmob.row)
		if tileTemp == tileLoose:
			g.looseFall()
		if tileTemp == tileEmpty or tileTemp == tileLoose:
			g.mobDownARow()
			return
		g.playSound(soundTileCrashing)
		g.doKnock(g.curmob.room, g.curmob.row)
		g.curmob.y = byte(ySomething[g.curmob.row + 1])
		g.curmob.speed = -2
		g.looseLand()

fn looseLand(mut g Game):
	buttonType = 0
	tiletype = g.getTile(g.curmob.room, g.curmob.xh >> 2, g.curmob.row)
	if tiletype == tileOpener:
		g.setRoomTile(g.currTilepos, tileDebris)
		buttonType = tileDebris
	if tiletype == tileOpener or tiletype == tileCloser:
		g.triggerButton(1, buttonType, -1)
		tiletype = g.getTile(g.curmob.room, g.curmob.xh >> 2, g.curmob.row)
	if tiletype in [tileOpener, tileCloser, tileFloor] or
		tiletype == tileSpike or tiletype == tilePotion or tiletype == tileTorch or
		tiletype == tileTorchWithDebris:
		if tiletype == tileTorch or tiletype == tileTorchWithDebris:
			g.setRoomTile(g.currTilepos, tileTorchWithDebris)
		else:
			g.setRoomTile(g.currTilepos, tileDebris)
		g.redrawAtCurMob()
		if g.tileCol != 0:
			g.setRedrawFull(g.currTilepos - 1, 1)

fn looseFall(mut g Game):
	g.setRoomMod(g.currTilepos, g.removeLoose(g.currTilepos))
	g.curmob.speed >>= 1
	g.mobs[g.curmobIndex] = g.curmob
	g.curmob.y = byte(g.curmob.y + 6)
	g.mobDownARow()
	g.addMob()
	g.curmob = g.mobs[g.curmobIndex]
	g.redrawAtCurMob()

fn redrawAtCurMob(mut g Game):
	if g.curmob.room == g.drawnRoom:
		g.redrawHeight = 0x20
		g.setRedrawFull(g.currTilepos, 1)
		g.setWipe(g.currTilepos, 1)
		if (g.currTilepos % 10) + 1 < 10:
			g.setRedrawFull(g.currTilepos + 1, 1)
			g.setWipe(g.currTilepos + 1, 1)

fn mobDownARow(mut g Game):
	g.curmob.row += 1
	if g.curmob.row >= 3:
		g.curmob.y = byte(g.curmob.y - 192)
		g.curmob.row = 0
		g.curmob.room = g.level.links[g.curmob.room - 1].down

pub fn drawMobs(mut g Game):
	for mut mob in g.mobs:
		g.curmob = mob
		g.drawMob()

fn drawMob(mut g Game):
	ypos = g.curmob.y
	if g.curmob.room == g.drawnRoom:
		if g.curmob.y >= 210: return
	elif g.curmob.room == g.roomB:
		if sbyte(ypos).abs() >= 18: return
		g.curmob.y = byte(g.curmob.y + 192)
		ypos = g.curmob.y
	elif g.curmob.room == g.roomA:
		if g.curmob.y < 174: return
		ypos = g.curmob.y - 189
	else:
		return
	col = g.curmob.xh >> 2
	row = yToRowMod4(ypos)
	g.objTilepos = byte(getTileposNominus(col, row))
	col += 1
	tilepos = getTilepos(col, row)
	g.setRedraw2(tilepos, 1)
	g.setRedrawFore(tilepos, 1)
	topRow = yToRowMod4(ypos - 18)
	if topRow != row:
		tilepos = getTilepos(col, topRow)
		g.setRedraw2(tilepos, 1)
		g.setRedrawFore(tilepos, 1)
	g.addMobToObjtable(ypos)

fn addMobToObjtable(mut g Game, ypos i64):
	if g.objtable.len >= 50: return
	clip = Rect(top = 0, left = 0, bottom = 0, right = 40)
	g.objtable.push(
		ObjItem(
			xh = sbyte(g.curmob.xh),
			xl = 0,
			y = short(ypos),
			chtabId = chtabEnvironment,
			id = 10,
			direction = 0,
			objType = g.curmob.mobType | 0x80,
			clip,
			tilepos = g.objTilepos
		)
	)
	if g.objTilepos < 30:
		g.tileObjectRedraw[g.objTilepos] = 1

pub fn isSpikeHarmful(g Game) i64:
	modifier = sbyte(g.roomMod(g.currTilepos))
	if modifier == 0 or modifier == -1: return 0
	if modifier < 0: return 1
	if modifier < 5: return 2
	0

fn checkLooseFallOnKid(mut g Game):
	g.loadkid()
	if g.char.room == g.curmob.room and g.char.currCol == g.curmob.xh >> 2 and
		g.curmob.y < g.char.y and
		g.char.y - 30 < g.curmob.y:
		g.fellOnYourHead()
		g.savekid()

fn fellOnYourHead(mut g Game):
	frame = g.char.frame
	action = g.char.action
	# loose floors hurt the running kid only on level 13
	if (g.currentLevel == g.options.opt("loose_tiles_level") or frame < 5 or frame >= 15) and
		(action < actHangClimb or action == actTurn):
		g.char.y = byte(yLand[g.char.currRow + 1])
		if g.takeHp(1):
			g.seqtblOffsetChar(seqCrushed)
			if frame == 177:
				g.char.x = byte(g.charDxForward(-12))
		elif frame != 109:
			if g.getTileBehindChar() == 0:
				g.char.x = byte(g.charDxForward(-2))
			g.seqtblOffsetChar(seqLooseFloorFellOnKid)
