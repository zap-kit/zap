# The tiles that move (SDLPoP's seg007.c, the first half; the Apple II's MOVER.S): torches,
# potions, the sword, chompers, spikes, gates and the level door as transitional objects
# (trobs), and the redraws each frame of theirs asks for.

pub fn processTrobs(mut g Game):
	if g.trobs.isEmpty: return
	needDelete = false
	index = 0
	while index < g.trobs.len:
		g.trob = g.trobs[index]
		g.animateTile()
		g.trobs[index].trobType = g.trob.trobType
		if g.trob.trobType < 0: needDelete = true
		index += 1
	if needDelete:
		kept = []
		for t in g.trobs:
			if t.trobType >= 0: kept.push(t)
		g.trobs = kept

fn animateTile(mut g Game):
	g.getRoomAddress(g.trob.room)
	t = g.getCurrTile(g.trob.tilepos)
	if t == tileTorch or t == tileTorchWithDebris:
		g.animateTorch()
	elif t == tileCloser or t == tileOpener:
		g.animateButton()
	elif t == tileSpike:
		g.animateSpike()
	elif t == tileLoose:
		g.animateLoose()
	elif t == tileEmpty:
		g.animateEmpty()
	elif t == tileChomper:
		g.animateChomper()
	elif t == tileGate:
		g.animateDoor()
	elif t == tileLevelDoorLeft:
		g.animateLeveldoor()
	elif t == tilePotion:
		g.animatePotion()
	elif t == tileSword:
		g.animateSword()
	else:
		g.trob.trobType = -1
	g.setRoomMod(g.trob.tilepos, g.currModifier)

fn isTrobInDrawnRoom(mut g Game):
	if g.trob.room != g.drawnRoom:
		g.trob.trobType = -1
		return false
	true

fn setRedrawAnimRight(mut g Game):
	g.setRedrawAnim(g.getTrobRightPosInDrawnRoom(), 1)

fn setRedrawAnimCurr(mut g Game):
	g.setRedrawAnim(g.getTrobPosInDrawnRoom(), 1)

fn redrawAtTrob(mut g Game):
	g.redrawHeight = 63
	tilepos = g.getTrobPosInDrawnRoom()
	g.setRedrawFull(tilepos, 1)
	g.setWipe(tilepos, 1)

pub fn redrawTileHeight(mut g Game, height i64):
	g.redrawHeight = height
	tilepos = g.getTrobPosInDrawnRoom()
	g.setRedrawFull(tilepos, 1)
	g.setWipe(tilepos, 1)
	tilepos = g.getTrobRightPosInDrawnRoom()
	g.setRedrawFull(tilepos, 1)
	g.setWipe(tilepos, 1)

fn drawTrob(mut g Game):
	tilepos = g.getTrobRightPosInDrawnRoom()
	g.setRedrawAnim(tilepos, 1)
	g.setRedrawFore(tilepos, 1)
	g.setRedrawAnim(g.getTrobRightAbovePosInDrawnRoom(), 1)

# where the trob is among the drawn room's tiles: -1..-10 the room above's bottom row, 30 none
fn getTrobPosInDrawnRoom(g Game):
	tilepos = g.trob.tilepos
	if g.trob.room == g.roomA: return 19 - tilepos if tilepos >= 20 and tilepos < 30 else 30
	if g.trob.room != g.drawnRoom: return 30
	tilepos

fn getTrobRightPosInDrawnRoom(g Game):
	tilepos = g.trob.tilepos
	if g.trob.room == g.drawnRoom: return tilepos + 1 if tilepos % 10 != 9 else 30
	if g.trob.room == g.roomL: return tilepos - 9 if tilepos % 10 == 9 else 30
	if g.trob.room == g.roomA: return 18 - tilepos if tilepos >= 20 and tilepos < 29 else 30
	if g.trob.room == g.roomAL and tilepos == 29: return -1
	30

fn getTrobRightAbovePosInDrawnRoom(g Game):
	tilepos = g.trob.tilepos
	if g.trob.room == g.drawnRoom:
		if tilepos % 10 == 9: return 30
		return -(tilepos + 2) if tilepos < 10 else tilepos - 9
	if g.trob.room == g.roomL:
		if tilepos == 9: return -1
		return tilepos - 19 if tilepos % 10 == 9 else 30
	if g.trob.room == g.roomB: return tilepos + 21 if tilepos < 9 else 30
	if g.trob.room == g.roomBL and tilepos == 9: return 20
	30

fn animateTorch(mut g Game):
	# the torches of the left room's last column show in this room too
	if g.trob.room == g.drawnRoom or (g.trob.room == g.roomL and g.trob.tilepos % 10 == 9):
		g.currModifier = g.getTorchFrame(g.currModifier)
		g.setRedrawAnimRight()
	else:
		g.trob.trobType = -1

fn animatePotion(mut g Game):
	if g.trob.trobType >= 0 and g.isTrobInDrawnRoom():
		kind = g.currModifier & 0xF8
		g.currModifier = bubbleNextFrame(g.currModifier & 7) | kind
		g.setRedrawAnimCurr()

fn animateSword(mut g Game):
	if g.isTrobInDrawnRoom():
		g.currModifier = byte(g.currModifier - 1)
		if g.currModifier == 0:
			g.currModifier = (g.prandom(255) & 0x3F) + 0x28
		g.setRedrawAnimCurr()

fn animateChomper(mut g Game):
	if g.trob.trobType >= 0:
		blood = g.currModifier & 0x80
		frame = (g.currModifier & 0x7F) + 1
		if frame > g.options.opt("chomper_speed"): frame = 1
		g.currModifier = blood | frame
		if frame == 2: g.playSound(soundChomper)
		# stops past frame 6 when the kid left its room or row, or died elsewhere
		if (
			g.trob.room != g.drawnRoom or g.trob.tilepos / 10 != g.kid.currRow or
				(g.kid.alive >= 0 and blood == 0)
		) and
			(g.currModifier & 0x7F) >= 6:
			g.trob.trobType = -1
	if (g.currModifier & 0x7F) < 6:
		g.redrawAtTrob()

fn animateSpike(mut g Game):
	if g.trob.trobType >= 0:
		if g.currModifier == 0xFF: return   # a disabled spike
		if g.currModifier & 0x80 != 0:
			g.currModifier -= 1
			if g.currModifier & 0x7F != 0: return
			g.currModifier = 6
		else:
			g.currModifier += 1
			if g.currModifier == 5:
				g.currModifier = 0x8F
			elif g.currModifier == 9:
				g.currModifier = 0
				g.trob.trobType = -1
	g.redrawTileHeight(0x21)

gateCloseSpeeds = [0, 0, 0, 20, 40, 60, 80, 100, 120]
doorDelta = [255, 4, 4]

# a gate: 0 closing, 1 open, 2 open for good, 3..8 closing fast
fn animateDoor(mut g Game):
	animType = g.trob.trobType
	if animType >= 0:
		if animType >= 3:
			if animType < 8:
				animType += 1
				g.trob.trobType = animType
			newMod = g.currModifier - gateCloseSpeeds[animType]
			g.currModifier = byte(newMod)
			if newMod < 0:
				g.currModifier = 0
				g.trob.trobType = -1
				g.playSound(soundGateClosingFast)
		elif g.currModifier != 0xFF:
			g.currModifier = byte(g.currModifier + doorDelta[animType])
			if animType == 0:
				if g.currModifier != 0:
					if g.currModifier < 188 and (g.currModifier & 3) == 3:
						g.playDoorSoundIfVisible(soundGateClosing)
				else:
					g.gateStop()
			elif g.currModifier < 188:
				if (g.currModifier & 7) == 0: g.playSound(soundGateOpening)
			elif animType < 2:
				# open: stays a while, then closes
				g.currModifier = 238
				g.trob.trobType = 0
				g.playSound(soundGateStop)
			else:
				g.currModifier = 0xFF   # open for good
				g.gateStop()
		else:
			g.gateStop()
	g.drawTrob()

fn gateStop(mut g Game):
	g.trob.trobType = -1
	g.playDoorSoundIfVisible(soundGateStop)

leveldoorCloseSpeeds = [0, 5, 17, 99, 0]

# the level door: 0..2 opening, 3..6 closing
fn animateLeveldoor(mut g Game):
	if g.trob.trobType >= 0:
		if g.trob.trobType >= 3:
			g.trob.trobType += 1
			g.currModifier = byte(g.currModifier - leveldoorCloseSpeeds[g.trob.trobType - 3])
			if sbyte(g.currModifier) < 0:
				g.currModifier = 0
				g.trob.trobType = -1
				g.playSound(soundLeveldoorClosing)
			elif g.trob.trobType == 4:
				g.soundInterruptible[soundLeveldoorSliding] = 1
				g.playSound(soundLeveldoorSliding)
		else:
			g.currModifier = byte(g.currModifier + 1)
			if g.currModifier >= 43:
				g.trob.trobType = -1
				g.stopSounds()
				if g.leveldoorOpen == 0 or g.leveldoorOpen == 2:
					g.leveldoorOpen = 1
					if g.currentLevel == g.options.opt("mirror_level"):
						# special event: the mirror appears
						g.getTile(
							g.options.opt("mirror_room"),
							g.options.opt("mirror_column"),
							g.options.opt("mirror_row")
						)
						g.setRoomTile(g.currTilepos, g.options.opt("mirror_tile"))
			else:
				g.soundInterruptible[soundLeveldoorSliding] = 0
				g.playSound(soundLeveldoorSliding)
	g.setRedrawAnimRight()

fn bubbleNextFrame(curr i64):
	next = curr + 1
	1 if next >= 8 else next

fn getTorchFrame(mut g Game, curr i64):
	next = g.prandom(255)
	if next != curr:
		if next < 9: return next
		next = curr
	next += 1
	0 if next >= 9 else next

# the redraw marks of a tile: -1..-10 for the room above's bottom row
pub fn setRedrawAnim(mut g Game, tilepos i64, frames i64):
	if tilepos >= 30: return
	if tilepos < 0:
		g.redrawFramesAbove[-(tilepos + 1)] = frames
	else:
		g.redrawFramesAnim[tilepos] = frames

pub fn setRedraw2(mut g Game, tilepos i64, frames i64):
	if tilepos >= 30: return
	if tilepos < 0:
		g.redrawFramesAbove[(-tilepos - 1).min(9)] = frames
	else:
		g.redrawFrames2[tilepos] = frames

pub fn setRedrawFloorOverlay(mut g Game, tilepos i64, frames i64):
	if tilepos >= 30: return
	if tilepos < 0:
		g.redrawFramesAbove[-(tilepos + 1)] = frames
	else:
		g.redrawFramesFloorOverlay[tilepos] = frames

pub fn setRedrawFull(mut g Game, tilepos i64, frames i64):
	if tilepos >= 30: return
	if tilepos < 0:
		g.redrawFramesAbove[-(tilepos + 1)] = frames
	else:
		g.redrawFramesFull[tilepos] = frames

pub fn setRedrawFore(mut g Game, tilepos i64, frames i64):
	if tilepos < 30 and tilepos >= 0:
		g.redrawFramesFore[tilepos] = frames

pub fn setWipe(mut g Game, tilepos i64, frames i64):
	if tilepos < 30 and tilepos >= 0:
		if g.wipeFrames[tilepos] != 0:
			g.redrawHeight = g.wipeHeights[tilepos].max(g.redrawHeight)
		g.wipeHeights[tilepos] = sbyte(g.redrawHeight)
		g.wipeFrames[tilepos] = frames

pub fn startAnimTorch(mut g Game, room i64, tilepos i64):
	g.setRoomMod(tilepos, g.prandom(8))
	g.addTrob(room, tilepos, 1)

pub fn startAnimPotion(mut g Game, room i64, tilepos i64):
	m = g.roomMod(tilepos) & 0xF8
	g.setRoomMod(tilepos, m | (g.prandom(6) + 1))
	g.addTrob(room, tilepos, 1)

pub fn startAnimSword(mut g Game, room i64, tilepos i64):
	g.setRoomMod(tilepos, g.prandom(0xFF) & 0x1F)
	g.addTrob(room, tilepos, 1)

fn startAnimChomper(mut g Game, room i64, tilepos i64, modifier i64):
	old = g.roomMod(tilepos)
	if old == 0 or old >= 6:
		g.setRoomMod(tilepos, modifier)
		g.addTrob(room, tilepos, 1)

pub fn startAnimSpike(mut g Game, room i64, tilepos i64):
	old = sbyte(g.roomMod(tilepos))
	if old > 0: return
	if old == 0:
		g.addTrob(room, tilepos, 1)
		g.playSound(soundSpikes)
	elif old != -1:
		g.setRoomMod(tilepos, 0x8F)   # 0xFF is a disabled spike

fn triggerGate(mut g Game, tilepos i64, buttonType i64):
	modifier = g.roomMod(tilepos)
	if buttonType == tileOpener:
		if modifier == 0xFF: return -1   # open for good
		if modifier >= 188:
			g.setRoomMod(tilepos, 238)   # open: keep it open a while
			return -1
		g.setRoomMod(tilepos, (modifier + 3) & 0xFC)
		return 1
	if buttonType == tileDebris:
		if modifier < 188: return 2
		g.setRoomMod(tilepos, 0xFF)
		return -1
	if modifier != 0: return 3   # close fast
	-1

fn trigger1(mut g Game, targetType i64, tilepos i64, buttonType i64):
	if targetType == tileGate: return g.triggerGate(tilepos, buttonType)
	if targetType == tileLevelDoorLeft: return -1 if g.roomMod(tilepos) != 0 else 1
	1 if g.options.isOn("allow_triggering_any_tile") else -1

fn doTriggerList(mut g Game, start i64, buttonType i64):
	index = start
	loop:
		room = g.getDoorlinkRoom(index)
		g.getRoomAddress(room)
		tilepos = g.getDoorlinkTile(index)
		targetType = g.roomTile(tilepos) & 0x1F
		result = sbyte(g.trigger1(targetType, tilepos, buttonType))
		if result >= 0:
			g.addTrob(room, tilepos, result)
		if not g.getDoorlinkNext(index): break
		index += 1

pub fn addTrob(mut g Game, room i64, tilepos i64, trobType i64):
	if g.trobs.len >= 30: return
	trob = Trob(tilepos = byte(tilepos), room = byte(room), trobType = sbyte(trobType))
	g.trob = trob
	for mut t in g.trobs:
		if t.tilepos == trob.tilepos and t.room == trob.room:
			t.trobType = trob.trobType
			return
	g.trobs.push(trob)

pub fn clearTileWipes(mut g Game):
	for i in 0..30:
		g.redrawFramesFull[i] = 0
		g.wipeFrames[i] = 0
		g.wipeHeights[i] = 0
		g.redrawFramesAnim[i] = 0
		g.redrawFramesFore[i] = 0
		g.redrawFrames2[i] = 0
		g.redrawFramesFloorOverlay[i] = 0
		g.tileObjectRedraw[i] = 0
	for i in 0..10:
		g.redrawFramesAbove[i] = 0

# the door links: tile and room of a button's targets, the timer of a button
pub fn getDoorlinkTimer(g Game, index i64) i64:
	i64(g.level.doorLinks2[index]) & 0x1F

fn setDoorlinkTimer(mut g Game, index i64, value i64):
	g.level.doorLinks2[index] = u8.wrap((i64(g.level.doorLinks2[index]) & 0xE0) | (value & 0x1F))

fn getDoorlinkTile(g Game, index i64):
	i64(g.level.doorLinks1[index]) & 0x1F

fn getDoorlinkNext(g Game, index i64):
	(g.level.doorLinks1[index] & 0x80) == 0

fn getDoorlinkRoom(g Game, index i64):
	((i64(g.level.doorLinks1[index]) & 0x60) >> 5) + ((i64(g.level.doorLinks2[index]) & 0xE0) >> 3)

pub fn triggerButton(mut g Game, playsound i64, buttonType i64, modifier i64):
	g.getCurrTile(g.currTilepos)
	kind = g.currTile if buttonType == 0 else buttonType
	m = g.currModifier if modifier == -1 else modifier
	linkTimer = sbyte(g.getDoorlinkTimer(m))
	if linkTimer == 0x1F: return   # jammed
	g.setDoorlinkTimer(m, 5)
	if linkTimer < 2:
		g.addTrob(g.currRoom, g.currTilepos, 1)
		g.redrawTileHeight(0x11)
		g.isGuardNotice = 1
		if playsound != 0: g.playSound(soundButtonPressed)
	g.doTriggerList(m, kind)

pub fn diedOnButton(mut g Game):
	buttonType = g.getCurrTile(g.currTilepos)
	modifier = g.currModifier
	if g.currTile == tileOpener:
		g.setRoomTile(g.currTilepos, tileFloor)
		g.setRoomMod(g.currTilepos, 0)
		buttonType = tileDebris   # open for good
	else:
		g.setRoomTile(g.currTilepos, tileStuck)
	g.triggerButton(1, buttonType, modifier)

fn animateButton(mut g Game):
	if g.trob.trobType >= 0:
		timer = word(g.getDoorlinkTimer(g.currModifier) - 1)
		g.setDoorlinkTimer(g.currModifier, timer)
		if timer < 2:
			g.trob.trobType = -1
			g.redrawTileHeight(0x11)

pub fn startLevelDoor(mut g Game, room i64, tilepos i64):
	g.setRoomMod(tilepos, 43)   # open at first
	g.addTrob(room, tilepos, 3)

fn animateEmpty(mut g Game):
	g.trob.trobType = -1
	g.redrawTileHeight(0x20)

pub fn getCurrTile(mut g Game, tilepos i64) i64:
	g.currModifier = g.roomMod(tilepos)
	g.currTile = g.roomTile(tilepos) & 0x1F
	g.currTile

pub fn playDoorSoundIfVisible(mut g Game, soundId i64):
	tilepos = g.trob.tilepos
	gateRoom = g.trob.room
	visible = tilepos % 10 == 9 if gateRoom == g.roomL
		else gateRoom == g.drawnRoom and tilepos % 10 != 9
	# special event: the closing gates heard on level 3
	if (g.currentLevel == 3 and gateRoom == 2) or visible:
		g.playSound(soundId)
