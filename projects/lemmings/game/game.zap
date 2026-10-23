# A level being played: the lemmings released and moved 17 times a second, the skills given, the
# objects animated, the count of the saved. The mechanics are DOS Lemmings' as Lemmix (Eric
# Langedijk, from ccexplore's reading of the game) has them, written as Zap.

import dos.lemmings
import image

clockIterations = 17   # the iterations of one second on the game's clock
# the game's pace: an iteration each fifth tick of its timer (1193182 / 16384 ticks a second), so
# a second on its clock lasts 17 iterations, 1.17 seconds (the oracle's count of its frames)
pub iterationsPerSecond = 1_193_182.0 / 16_384.0 / 5.0
maxFallDistance = 59
headMinY = -5
lemmingMinX = 0
lemmingMaxX = 1647
lemmingMaxY = 163

# the skills in the panel's order
pub type Skill:
	Climber
	Floater
	Bomber
	Blocker
	Builder
	Basher
	Miner
	Digger

pub skills Skill[] = [.Climber, .Floater, .Bomber, .Blocker, .Builder, .Basher, .Miner, .Digger]

pub fn skillIndex(s Skill) i64:
	match s:
		Climber: 0
		Floater: 1
		Bomber: 2
		Blocker: 3
		Builder: 4
		Basher: 5
		Miner: 6
		Digger: 7

# what the game plays a sound for (Lemmix's cues); a trap's sound is its own, the set's number
pub type Cue:
	LetsGo
	Entrance
	AssignSkill
	SkillButton
	Splat
	Yippee
	OhNo
	Explosion
	Drowning
	Vaporizing
	HitsSteel
	BuilderWarning
	Trap(sound i64)

# the iterations a bomber counts down for (the oracle: the digit is gone and the lemming says
# oh no one iteration before a count of 79)
bombTimerStart = 78

# a lemming blown up: where its particles start, and when
pub type Explosion:
	lemming i64
	x i64
	y i64
	iteration i64

# an object placed in the level as it animates
pub type PlacedState:
	placed lemmings.PlacedObject
	kind i64
	frame i64
	triggered bool

pub type Game:
	level lemmings.Level
	set lemmings.GraphicsSet
	world World
	bashMasks lemmings.Mask[2]
	mineMasks lemmings.Mask[2]
	explosionMask lemmings.Mask
	lemmingSheets image.Image[]   # main.dat's animations in the level's palette
	lemmings Lemming[] = []
	objects PlacedState[] = []   # every object but the entrances, in the level's order
	entrances PlacedState[] = []
	entranceOrder i64[4] = [0, 0, 0, 0]
	iteration i64 = 0
	clockFrame i64 = 0
	minutes i64
	seconds i64 = 0
	releaseRate i64
	skillsLeft i64[8]
	selected Skill = .Climber
	released i64 = 0
	out i64 = 0
	saved i64 = 0
	removedCount i64 = 0
	nextLemming i64 = 20
	entrancesOpened bool = false
	entranceDone bool = false
	nuked bool = false
	nukeNext i64 = 0
	nuking bool = false
	finished bool = false
	timeUp bool = false
	paused bool = false
	explosions Explosion[] = []   # every lemming blown up, where and when
	rateChange i64 = 0   # -1 slowing, 1 speeding while a rate button is held
	cues Cue[] = []   # the sounds asked for since the player took them

# the rating (--rating 0..3) of the level a tool's command line names, Fun when none
pub fn chosenRating() i64:
	i64.parse(args.option("--rating") ?? "0") ?? 0

# the number from 0 (--level 1..30) of the level a tool's command line names, the first when none
pub fn chosenNumber() i64:
	(i64.parse(args.option("--level") ?? "1") ?? 1) - 1

# a new game of the level of this rating and number in the install at dir
pub fn levelGame(dir str, rating i64, number i64, main lemmings.MainData) Game:
	level = lemmings.loadLevel(dir, rating, number)
	set = lemmings.loadGraphicsSet(dir, level.graphicsSet, level.special)
	newGame(level, set, main)

# a new game of the level a tool's command line names, in the install at dir
pub fn chosenGame(dir str) Game:
	levelGame(dir, chosenRating(), chosenNumber(), lemmings.loadMainData(dir))

pub fn newGame(
	move level lemmings.Level,
	move set lemmings.GraphicsSet,
	main lemmings.MainData
) Game:
	world = level.buildWorld(set)
	minutes = level.minutes
	releaseRate = level.releaseRate
	skillsLeft = level.skills
	g = Game(
		level,
		set,
		world,
		bashMasks = main.bashMasks.copy(),
		mineMasks = main.mineMasks.copy(),
		explosionMask = main.explosionMask.copy(),
		lemmingSheets = main.animations.map(.sheetIn(set.palette)),
		minutes,
		releaseRate,
		skillsLeft
	)
	for o in g.level.objects:
		if o.kind >= g.set.objects.len: continue
		k = g.set.objects[o.kind]
		frame = k.startFrame
		# the DOS game animates the looping objects twice before its first iteration (the oracle)
		if not k.triggered and o.kind != lemmings.entranceKind:
			frame = (frame + 2) % k.frames
		state = PlacedState(placed = o, kind = o.kind, frame, triggered = false)
		if o.kind == lemmings.entranceKind:
			g.entrances.push(state)
		else:
			g.objects.push(state)
	g.entranceOrder = match g.entrances.len:
		2: [0, 1, 1, 0]
		3: [0, 1, 2, 1]
		4: [0, 1, 2, 3]
		_: [0, 0, 0, 0]
	g

pub fn skillsLeft(g Game, s Skill) i64:
	g.skillsLeft[s.skillIndex()]

fn takeSkill(mut g Game, s Skill):
	g.skillsLeft[s.skillIndex()] -= 1

# ---------- the object map around a lemming ----------

fn saveMap(mut g Game, mut l Lemming):
	k = 0
	for dy in [-6, -2, 2]:
		for dx in [-4, 0, 4]:
			l.savedMap[k] = u8(g.world.readObjectMap(l.x + dx, l.y + dy))
			k += 1

fn restoreMap(mut g Game, l Lemming):
	k = 0
	for dy in [-6, -2, 2]:
		for dx in [-4, 0, 4]:
			g.world.writeObjectMap(l.x + dx, l.y + dy, l.savedMap[k])
			k += 1

fn setBlockerField(mut g Game, l Lemming):
	for dy in [-6, -2, 2]:
		g.world.writeObjectMap(l.x - 4, l.y + dy, domForceLeft)
		g.world.writeObjectMap(l.x, l.y + dy, domBlocker)
		g.world.writeObjectMap(l.x + 4, l.y + dy, domForceRight)

fn overlapsField(g Game, l Lemming):
	for dy in [-6, -2, 2]:
		for dx in [-4, 0, 4]:
			v = g.world.readObjectMap(l.x + dx, l.y + dy)
			if v in [domForceLeft, domBlocker, domForceRight]: return true
	false

# a transition with what the game does on entering some states
fn enter(mut g Game, mut l Lemming, a Action, turn bool):
	was = l.action
	l.transition(a, turn)
	if was == a: return
	if a == .Blocking:
		g.saveMap(l)
		g.setBlockerField(l)
	elif a == .Splatting:
		g.cues.push(.Splat)
	elif a == .Exiting:
		g.cues.push(.Yippee)
	elif a == .OhNoing and not g.nuked:
		g.cues.push(.OhNo)
	elif a == .Exploding:
		g.cues.push(.Explosion)

fn removeLemming(mut g Game, mut l Lemming):
	l.removed = true
	g.out -= 1
	g.removedCount += 1

# ---------- giving skills ----------

# whether the skill went to the lemming (the counts and the lemming's state changed)
pub fn assignSkill(mut g Game, i i64, s Skill) bool:
	l = g.lemmings[i]
	if g.skillsLeft(s) == 0: return false
	given = match s:
		Climber:
			if l.isClimber or l.isOneOf([.Blocking, .Splatting, .Exploding]): return false
			l.isClimber = true
			if l.action == .Shrugging:
				l.action = .Walking   # the original's bug, kept
			true
		Floater:
			if l.isFloater or l.isOneOf([.Blocking, .Splatting, .Exploding]): return false
			l.isFloater = true
			true
		Bomber:
			if l.explosionTimer != 0 or l.isOneOf([.OhNoing, .Exploding, .Vaporizing, .Splatting]):
				return false
			l.explosionTimer = bombTimerStart
			true
		Blocker:
			if not l.isOneOf([.Walking, .Shrugging, .Building, .Bashing, .Mining, .Digging]) or
				g.overlapsField(l):
				return false
			g.enter(l, .Blocking, false)
			true
		Builder:
			if l.y + l.action.frameTopDy() < headMinY: return false
			if not l.isOneOf([.Walking, .Shrugging, .Bashing, .Mining, .Digging]): return false
			g.enter(l, .Building, false)
			true
		Basher:
			if not l.isOneOf([.Walking, .Shrugging, .Building, .Mining, .Digging]): return false
			if l.objectInFront == domSteel: return false
			if l.objectInFront == domOneWayLeft and l.dx != -1: return false
			if l.objectInFront == domOneWayRight and l.dx != 1: return false
			g.enter(l, .Bashing, false)
			true
		Miner:
			if not l.isOneOf([.Walking, .Shrugging, .Building, .Bashing, .Digging]): return false
			if l.objectInFront == domSteel or l.objectBelow == domSteel: return false
			if l.objectInFront == domOneWayLeft and l.dx != -1: return false
			if l.objectInFront == domOneWayRight and l.dx != 1: return false
			g.enter(l, .Mining, false)
			true
		Digger:
			if l.objectBelow == domSteel: return false
			if not l.isOneOf([.Walking, .Shrugging, .Building, .Bashing, .Mining]): return false
			g.enter(l, .Digging, false)
			true
	if given:
		g.takeSkill(s)
		g.cues.push(.AssignSkill)
		g.lemmings[i] = l
	given

# a click hits a lemming whose frame's box is 12 by 12 (Lemmix's hit test) when the DOS cursor's
# point is in it, the box starting this far right of the frame's left and this far below its top
# (read from the DOS game's own hit variable over Fun 25's crowd: the cursor less a walker's foot
# is 4 to 8 across and -11 to 1 down)
clickLeft = 4
clickTop = -1
clickW = 12
clickH = 12

# the lemmings under the cursor: the one doing something first (blocking, building...), then any
# other; the second is the other one when both are there
pub fn lemmingsAt(g Game, cx i64, cy i64) (i64?, i64?, i64):
	prioritized i64? = none
	other i64? = none
	hits = 0
	for i, l in g.lemmings:
		if l.removed: continue
		x = l.x + l.action.frameLeftDx() + clickLeft
		y = l.y + l.action.frameTopDy() + clickTop
		if x <= cx and cx <= x + clickW and y <= cy and cy <= y + clickH:
			hits += 1
			if l.isOneOf([.Blocking, .Building, .Shrugging, .Bashing, .Mining, .Digging, .OhNoing]):
				prioritized = i
			else:
				other = i
	first = prioritized ?? other
	(first, other, hits)

# a click at (cx, cy) of the world with the selected skill
pub fn clickAt(mut g Game, cx i64, cy i64, rightHeld bool) bool:
	first, other, hits = g.lemmingsAt(cx, cy)
	if hits == 0: return false
	pick i64? = (other ?? first) if rightHeld else first
	i = pick ?? return false
	if g.assignSkill(i, g.selected): return true
	second = other ?? return false
	if second == i: return false
	g.fallsToSecond(g.lemmings[i], g.selected) and g.assignSkill(second, g.selected)

# whether the original tries the second lemming under the cursor: only for the four skills that
# turn a walker, and only when the first one's action cannot take the skill (steel, a head too
# high or a one-way wall in front end the try)
fn fallsToSecond(g Game, l Lemming, s Skill):
	match s:
		Builder:
			l.y + l.action.frameTopDy() >= headMinY and
				not l.isOneOf([.Walking, .Shrugging, .Bashing, .Mining, .Digging])
		Basher: not l.isOneOf([.Walking, .Shrugging, .Building, .Mining, .Digging])
		Miner: not l.isOneOf([.Walking, .Shrugging, .Building, .Bashing, .Digging])
		Digger:
			l.objectBelow != domSteel and
				not l.isOneOf([.Walking, .Shrugging, .Building, .Bashing, .Mining])
		_: false

# ---------- one step of the game ----------

fn checkFinished(mut g Game):
	if g.finished: return
	if g.minutes <= 0 and g.seconds <= 0:
		g.timeUp = true
		g.finished = true
		return
	n = g.level.lemmings
	if g.saved >= n or g.removedCount >= n or (g.nuked and g.out == 0):
		g.finished = true

fn incrementIteration(mut g Game):
	g.iteration += 1
	g.clockFrame += 1
	if g.clockFrame >= clockIterations:
		g.clockFrame = 0
		g.seconds -= 1
		if g.seconds < 0:
			if g.minutes > 0:
				g.minutes -= 1
				g.seconds = 59
			else:
				g.minutes = 0
				g.seconds = 0
	# the DOS game's fixed moments (Lemmix's numbers)
	if g.iteration == 15:
		g.cues.push(.LetsGo)
	if g.iteration == 34:
		g.cues.push(.Entrance)
	if g.iteration == 35:
		g.entrancesOpened = true
		for mut e in g.entrances:
			e.triggered = true
			e.frame = 1

# frames between two releases at the rate: (99 - rate) / 2 + 4
fn releaseCountdown(g Game):
	r = 99 - g.releaseRate
	if r < 0:
		r += 256
	r / 2 + 4

fn spawnLemming(mut g Game):
	if not g.entrancesOpened or g.nuked: return
	g.nextLemming -= 1
	if g.nextLemming != 0: return
	g.nextLemming = g.releaseCountdown()
	if g.released >= g.level.lemmings or g.entrances.isEmpty: return
	e = g.entrances[g.entranceOrder[g.released % 4]]
	l = Lemming(
		x = e.placed.x + 24,
		y = e.placed.y + 14,
		born = g.iteration,
		number = g.lemmings.len
	)
	l.transition(.Falling, false)
	g.lemmings.push(l)
	g.released += 1
	g.out += 1

fn updateNuking(mut g Game):
	if not (g.nuked and g.nuking): return
	while g.nukeNext < g.released and g.lemmings[g.nukeNext].removed:
		g.nukeNext += 1
	if g.nukeNext > g.released - 1:
		g.nuking = false
		return
	l = g.lemmings[g.nukeNext]
	if l.explosionTimer == 0 and not l.isOneOf([.Splatting, .Exploding]):
		g.lemmings[g.nukeNext].explosionTimer = bombTimerStart
	g.nukeNext += 1

fn updateObjects(mut g Game):
	if not g.entranceDone and g.iteration >= 35:
		for i in 0..g.entrances.len:
			e = g.entrances[i]
			if e.triggered:
				frames = g.set.objects[e.kind].frames
				e.frame += 1
				if e.frame >= frames:
					e.frame = 0   # the open hatch: the file's start frame is the closed one
					e.triggered = false
					g.entranceDone = true
			g.entrances[i] = e
	for i in 0..g.objects.len:
		o = g.objects[i]
		k = g.set.objects[o.kind]
		if o.triggered or (not k.triggered and k.frames > 1):
			o.frame += 1
		if o.frame >= k.frames:
			o.frame = 0
			o.triggered = false
		g.objects[i] = o

fn adjustReleaseRate(mut g Game, delta i64):
	g.releaseRate = (g.releaseRate + delta).clamp(g.level.releaseRate, 99)

# whether the countdown reached zero this step (the lemming then changes state and moves no more)
fn updateExplosionTimer(mut g Game, mut l Lemming):
	l.explosionTimer -= 1
	if l.explosionTimer > 0: return false
	if l.isOneOf([.Vaporizing, .Drowning, .Floating, .Falling]):
		g.enter(l, .Exploding, false)
	else:
		g.enter(l, .OhNoing, false)
	true

fn checkLemmings(mut g Game):
	for i in 0..g.lemmings.len:
		l = g.lemmings[i]
		if l.removed: continue
		if l.explosionTimer != 0 and g.updateExplosionTimer(l):
			g.lemmings[i] = l
			continue
		if g.handleLemming(l):
			g.checkObjects(l)
		g.lemmings[i] = l

# the game moved one frame on
pub fn step(mut g Game):
	if g.finished: return
	g.checkFinished()
	if g.rateChange != 0:
		g.adjustReleaseRate(g.rateChange)
	if g.paused: return
	g.world.ageLingering()
	g.incrementIteration()
	g.spawnLemming()
	g.checkLemmings()
	g.updateNuking()
	g.updateObjects()

pub fn nuke(mut g Game):
	if g.nuked: return
	g.nuked = true
	g.nuking = true
	g.nukeNext = 0

# the saved share in percent, counted over the level's lemmings
pub fn savedPercent(g Game) i64:
	g.saved * 100 / g.level.lemmings.max(1)

pub fn neededPercent(g Game) i64:
	g.level.toRescue * 100 / g.level.lemmings.max(1)

# ---------- what a lemming meets ----------

fn checkObjects(mut g Game, mut l Lemming):
	l.objectBelow = g.world.readObjectMap(l.x, l.y)
	l.objectInFront = g.world.readObjectMap(l.x + 8 * l.dx, l.y - 8)
	below = l.objectBelow
	if below == domNone: return
	if below < 128:
		if below < g.objects.len and not g.objects[below].triggered:
			g.objects[below].triggered = true
			g.objects[below].frame = 0
			g.removeLemming(l)
			g.cues.push(.Trap(g.set.objects[g.objects[below].kind].sound))
	elif below == domExit:
		if l.action != .Falling:
			g.enter(l, .Exiting, false)
	elif below == domForceLeft:
		if l.dx > 0: l.turnAround()
	elif below == domForceRight:
		if l.dx < 0: l.turnAround()
	elif below == domWater:
		g.enter(l, .Drowning, false)
		g.cues.push(.Drowning)
	elif below == domFire:
		g.enter(l, .Vaporizing, false)
		g.cues.push(.Vaporizing)
