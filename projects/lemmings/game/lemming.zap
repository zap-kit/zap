# One lemming: its place, what it is doing and the frame of its animation. The actions, their
# frames and foot points are DOS Lemmings' (main.dat's animations, Lemmix's table).

pub type Action:
	Walking
	Jumping
	Digging
	Climbing
	Drowning
	Hoisting
	Building
	Bashing
	Mining
	Falling
	Floating
	Splatting
	Exiting
	Vaporizing
	Blocking
	Shrugging
	OhNoing
	Exploding

pub type Lemming:
	x i64
	y i64
	dx i64 = 1   # 1 right, -1 left
	number i64 = 0   # its place in the order they came out, the order they are drawn in
	action Action = .Falling
	frame i64 = 0
	endOfAnimation bool = false
	fallen i64 = 0
	bricksLeft i64 = 0
	isClimber bool = false
	isFloater bool = false
	isBlocking bool = false
	isNewDigger bool = false
	removed bool = false
	explosionTimer i64 = 0
	floatIndex i64 = 0
	savedMap u8[9] = fill(9, u8(128))
	objectBelow i64 = 128
	objectInFront i64 = 128
	born i64 = 0

# the animations of an action in main.dat's order, facing right and facing left (the same one
# when the action has no left-facing animation)
fn animations(a Action):
	match a:
		Walking: (0, 2)
		Jumping: (1, 3)
		Digging: (4, 4)
		Climbing: (5, 6)
		Drowning: (7, 7)
		Hoisting: (8, 9)
		Building: (10, 11)
		Bashing: (12, 13)
		Mining: (14, 15)
		Falling: (16, 17)
		Floating: (18, 19)
		Splatting: (20, 20)
		Exiting: (21, 21)
		Vaporizing: (22, 22)
		Blocking: (23, 23)
		Shrugging: (24, 25)
		OhNoing: (26, 26)
		Exploding: (27, 27)

# the index of the lemming's animation in main.dat's order
pub fn animationIndex(l Lemming) i64:
	right, left = l.action.animations()
	left if l.dx < 0 else right

pub fn frameCount(a Action) i64:
	match a:
		Walking: 8
		Jumping: 1
		Digging: 16
		Climbing: 8
		Drowning: 16
		Hoisting: 8
		Building: 16
		Bashing: 32
		Mining: 24
		Falling: 4
		Floating: 8
		Splatting: 16
		Exiting: 8
		Vaporizing: 14
		Blocking: 16
		Shrugging: 8
		OhNoing: 16
		Exploding: 1

pub fn playsOnce(a Action) bool:
	match a:
		Jumping, Drowning, Hoisting, Splatting, Exiting, Vaporizing, Shrugging, OhNoing, Exploding: true
		_: false

# where the animation frame's corner lies relative to the lemming's foot point
pub fn frameLeftDx(a Action) i64:
	-16 if a == .Exploding else -8

pub fn frameTopDy(a Action) i64:
	match a:
		Digging, Climbing, Hoisting: -12
		Building, Mining: -13
		Floating: -16
		Exiting: -13
		Vaporizing: -14
		Exploding: -25
		_: -10

# the actions a skill is given to: the lemming must be in one of them
pub fn isOneOf(l Lemming, actions Action[]) bool:
	l.action in actions

# the lemming's state turned to a new action (and around when asked), as DOS does it
pub fn transition(mut l Lemming, a Action, turn bool):
	if l.action == a and not turn: return
	if turn:
		l.dx = -l.dx
	if l.action == a: return
	l.action = a
	l.frame = 0
	l.endOfAnimation = false
	l.fallen = 0
	l.bricksLeft = 0
	if a == .Splatting:
		l.explosionTimer = 0
		l.dx = 0
	elif a == .Blocking: l.isBlocking = true
	elif a == .Digging: l.isNewDigger = true
	elif a == .Falling: l.fallen = 3   # the original starts a faller three pixels down
	elif a == .Building: l.bricksLeft = 12
	elif a == .Floating: l.floatIndex = 0
	elif a == .Mining: l.y += 1

pub fn turnAround(mut l Lemming):
	l.dx = -l.dx

# the frame moved on: the last frame of an animation played once stays; a loop starts over
pub fn advanceFrame(mut l Lemming):
	if l.frame < l.action.frameCount() - 1:
		l.endOfAnimation = false
		l.frame += 1
	else:
		l.endOfAnimation = true
		if not l.action.playsOnce():
			l.frame = 0
