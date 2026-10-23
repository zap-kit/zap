# What each action does in one frame of the game: the walker's steps and falls, the digger's rows,
# the builder's bricks, the basher's and miner's masks... Each gives whether the lemming is then
# checked against the objects under it. Ported from Lemmix's handlers (DOS Lemmings' rules).

# the animation frame moved on (floating and digging keep their own count), then the action
pub fn handleLemming(mut g Game, mut l Lemming) bool:
	if not l.isOneOf([.Floating, .Digging]):
		l.advanceFrame()
	match l.action:
		Walking: g.handleWalking(l)
		Jumping: g.handleJumping(l)
		Digging: g.handleDigging(l)
		Climbing: g.handleClimbing(l)
		Drowning: g.handleDrowning(l)
		Hoisting: g.handleHoisting(l)
		Building: g.handleBuilding(l)
		Bashing: g.handleBashing(l)
		Mining: g.handleMining(l)
		Falling: g.handleFalling(l)
		Floating: g.handleFloating(l)
		Splatting: g.handleEnding(l)
		Exiting: g.handleExiting(l)
		Vaporizing: g.handleEnding(l)
		Blocking: g.handleBlocking(l)
		Shrugging: g.handleShrugging(l)
		OhNoing: g.handleOhNoing(l)
		Exploding: g.handleExploding(l)

# a lemming above the level's top is set below it and turned around
fn checkTopBoundary(mut g Game, mut l Lemming):
	dy = l.action.frameTopDy()
	if l.y + dy < headMinY:
		l.y = headMinY - 2 - dy
		l.turnAround()
		if l.action == .Jumping:
			g.enter(l, .Walking, false)

fn fallsOut(mut g Game, mut l Lemming):
	if l.y > lemmingMaxY:
		g.removeLemming(l)
		return true
	false

fn handleWalking(mut g Game, mut l Lemming):
	l.x += l.dx
	if l.x < lemmingMinX or l.x > lemmingMaxX:
		l.turnAround()
		return true
	if g.world.hasPixelAtClipY(l.x, l.y, 0):
		dy = 0
		newY = l.y
		while dy <= 6 and g.world.hasPixelAtClipY(l.x, newY - 1, -dy - 1):
			dy += 1
			newY -= 1
		if dy > 6:
			if l.isClimber:
				g.enter(l, .Climbing, false)
			else:
				l.turnAround()
			return true
		if dy >= 3:
			g.enter(l, .Jumping, false)
			newY = l.y - 2
		l.y = newY
		g.checkTopBoundary(l)
		return true
	dy = 1
	while dy <= 3:
		l.y += 1
		if g.world.hasPixelAtClipY(l.x, l.y, dy): break
		dy += 1
	if dy > 3:
		l.y += 1
		g.enter(l, .Falling, false)
	not g.fallsOut(l)

fn handleJumping(mut g Game, mut l Lemming):
	dy = 0
	while dy < 2 and g.world.hasPixelAtClipY(l.x, l.y - 1, -dy - 1):
		dy += 1
		l.y -= 1
	if dy < 2:
		g.enter(l, .Walking, false)
	g.checkTopBoundary(l)
	true

fn handleDigging(mut g Game, mut l Lemming):
	if l.isNewDigger:
		g.world.digRow(l.x, l.y - 2)
		g.world.digRow(l.x, l.y - 1)
		l.isNewDigger = false
	else:
		l.frame += 1
		if l.frame >= 16:
			l.frame -= 16
	if l.frame != 0 and l.frame != 8: return false
	y = l.y
	l.y += 1
	if g.fallsOut(l): return false
	if not g.world.digRow(l.x, y, g.world.readObjectMap(l.x, l.y) == domSteel):
		g.enter(l, .Falling, false)
	elif g.world.readObjectMap(l.x, l.y) == domSteel:
		g.cues.push(.HitsSteel)
		g.enter(l, .Walking, false)
	true

fn handleClimbing(mut g Game, mut l Lemming):
	if l.frame <= 3:
		if not g.world.hasPixelAtClipY(l.x, l.y - 7 - l.frame, 0):
			l.y = l.y - l.frame + 2
			g.enter(l, .Hoisting, false)
			g.checkTopBoundary(l)
		return true
	l.y -= 1
	if l.y + l.action.frameTopDy() < headMinY or g.world.hasPixelAtClipY(l.x - l.dx, l.y - 8, -8):
		g.enter(l, .Falling, true)
		l.x += l.dx * 2
	true

fn handleDrowning(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		g.removeLemming(l)
	elif not g.world.hasPixelAt(l.x + 8 * l.dx, l.y):
		l.x += l.dx
	false

fn handleHoisting(mut g Game, mut l Lemming):
	if l.frame <= 4:
		l.y -= 2
		g.checkTopBoundary(l)
		return true
	if l.endOfAnimation:
		g.enter(l, .Walking, false)
		g.checkTopBoundary(l)
		return true
	false

fn handleBuilding(mut g Game, mut l Lemming):
	if l.frame == 10 and l.bricksLeft <= 3:
		g.cues.push(.BuilderWarning)
	if l.frame == 9 or (l.frame == 10 and l.bricksLeft == 9):
		g.world.layBrick(l.x if l.dx == 1 else l.x - 4, l.y - 1)
		return false
	if l.frame != 0: return true
	l.x += l.dx
	l.y -= 1
	if l.x <= lemmingMinX or l.x > lemmingMaxX or g.world.hasPixelAtClipY(l.x, l.y - 1, -1):
		g.enter(l, .Walking, true)
		g.checkTopBoundary(l)
		return true
	l.x += l.dx
	if g.world.hasPixelAtClipY(l.x, l.y - 1, -1):
		g.enter(l, .Walking, true)
		g.checkTopBoundary(l)
		return true
	l.bricksLeft -= 1
	if l.bricksLeft == 0:
		g.enter(l, .Shrugging, false)
		g.checkTopBoundary(l)
		return true
	if g.world.hasPixelAtClipY(l.x + l.dx * 2, l.y - 9, -9) or l.x <= lemmingMinX or
		l.x > lemmingMaxX:
		g.enter(l, .Walking, true)
		g.checkTopBoundary(l)
		return true
	if l.y + l.action.frameTopDy() < headMinY:
		g.enter(l, .Walking, false)
		g.checkTopBoundary(l)
	true

fn handleBashing(mut g Game, mut l Lemming):
	index = l.frame - 16 if l.frame >= 16 else l.frame
	if index >= 11 and index <= 15:
		l.x += l.dx
		if l.x < lemmingMinX or l.x > lemmingMaxX:
			g.enter(l, .Walking, true)
			return true
		dy = 0
		while dy < 3 and not g.world.hasPixelAtClipY(l.x, l.y, dy):
			dy += 1
			l.y += 1
		if dy == 3:
			g.enter(l, .Falling, false)
			return true
		front = g.world.readObjectMap(l.x + l.dx * 8, l.y - 8)
		if front == domSteel or (front == domOneWayLeft and l.dx != -1) or
			(front == domOneWayRight and l.dx != 1):
			if front == domSteel: g.cues.push(.HitsSteel)
			g.enter(l, .Walking, true)
		return true
	if index >= 2 and index <= 5:
		g.world.applyMask(
			g.bashMasks[0 if l.dx > 0 else 1],
			index - 2,
			l.x + l.action.frameLeftDx(),
			l.y + l.action.frameTopDy()
		)
		if l.frame == 5:
			n = 0
			x = l.x + l.dx * 8
			while n < 4 and not g.world.hasPixelAt(x, l.y - 6):
				n += 1
				x += l.dx
			if n == 4:
				g.enter(l, .Walking, false)
	false

fn handleMining(mut g Game, mut l Lemming):
	side = 0 if l.dx > 0 else 1
	if l.frame == 1:
		g.world.applyMask(
			g.mineMasks[side],
			0,
			l.x + l.action.frameLeftDx(),
			l.y + l.action.frameTopDy()
		)
		return false
	if l.frame == 2:
		g.world.applyMask(
			g.mineMasks[side],
			1,
			l.x + l.dx + l.action.frameLeftDx(),
			l.y + 1 + l.action.frameTopDy()
		)
		return false
	if l.frame == 3 or l.frame == 15:
		l.x += l.dx
		if l.x < lemmingMinX or l.x > lemmingMaxX:
			g.enter(l, .Walking, true)
			return true
		l.x += l.dx
		if l.x < lemmingMinX or l.x > lemmingMaxX:
			g.enter(l, .Walking, true)
			return true
		if l.frame == 3:
			l.y += 1
			if g.fallsOut(l): return false
		if not g.world.hasPixelAtClipY(l.x, l.y, 0):
			g.enter(l, .Falling, false)
			return true
		below = g.world.readObjectMap(l.x, l.y)
		# the original's bug, kept: a one-way wall pointing right is mined from neither side
		if below == domSteel or (below == domOneWayLeft and l.dx != -1) or below == domOneWayRight:
			if below == domSteel: g.cues.push(.HitsSteel)
			g.enter(l, .Walking, true)
		return true
	if l.frame == 0:
		l.y += 1
		return not g.fallsOut(l)
	false

fn handleFalling(mut g Game, mut l Lemming):
	if l.fallen > 16 and l.isFloater:
		g.enter(l, .Floating, false)
		return true
	dy = 0
	while dy < 3 and not g.world.hasPixelAtClipY(l.x, l.y, dy):
		dy += 1
		l.y += 1
		if g.fallsOut(l): return false
	if dy == 3:
		l.fallen += 3
		return true
	if l.fallen > maxFallDistance:
		g.enter(l, .Splatting, false)   # checked against the exit still: the original's drop into it
	else:
		g.enter(l, .Walking, false)
	true

# the floater's sixteen steps: the frame shown and how far it moves, then steps 8..15 again
floatTable = [(3, 1), (3, 2), (3, 3), (3, 5), (-1, 5), (0, 5), (1, 5), (1, 5),
	(2, 5), (2, 6), (2, 7), (2, 7), (2, 6), (2, 5), (2, 4), (2, 4)]

fn handleFloating(mut g Game, mut l Lemming):
	dy, frame = floatTable[l.floatIndex]
	l.frame = frame
	l.floatIndex += 1
	if l.floatIndex >= 16:
		l.floatIndex = 8
	if dy <= 0:
		l.y += dy
	else:
		minY = 0
		while dy > 0:
			if g.world.hasPixelAtClipY(l.x, l.y, minY):
				g.enter(l, .Walking, false)
				return true
			l.y += 1
			dy -= 1
			minY += 1
	not g.fallsOut(l)

fn handleEnding(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		g.removeLemming(l)
	false

fn handleExiting(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		g.removeLemming(l)
		g.saved += 1
	false

fn handleBlocking(mut g Game, mut l Lemming):
	if not g.world.hasPixelAtClipY(l.x, l.y, 0):
		g.enter(l, .Walking, false)
		l.isBlocking = false
		g.restoreMap(l)
	false

fn handleShrugging(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		g.enter(l, .Walking, false)
		return true
	false

fn handleOhNoing(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		g.enter(l, .Exploding, false)
		return false
	dy = 0
	while dy < 3 and not g.world.hasPixelAtClipY(l.x, l.y, dy):
		dy += 1
		l.y += 1
	not g.fallsOut(l)

fn handleExploding(mut g Game, mut l Lemming):
	if l.endOfAnimation:
		if l.isBlocking:
			l.isBlocking = false
			g.restoreMap(l)
		below = g.world.readObjectMap(l.x, l.y)
		if below != domSteel and below != domWater:
			g.world.applyMask(g.explosionMask, 0, l.x - 8, l.y - 14, 1)
		g.explosions.push(
			Explosion(lemming = l.number, x = l.x - 8, y = l.y - 14, iteration = g.iteration)
		)
		g.removeLemming(l)
	false
