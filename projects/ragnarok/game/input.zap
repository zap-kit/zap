# The player's input of a frame: the mouse as the window reads it, or, for a test that needs no
# one at the screen, replayed from a script (engine/replay.zap: `--replay
# "30:move 700 400;31:ldown;33:lup"`): at frame N, `move x y` puts the cursor, `ldown`/`lup` and
# `rdown`/`rup` press and release a button, `drag dx dy` moves the held mouse that frame, `wheel n`
# turns the wheel n notches.

import engine

pub type Input:
	x i64   # the cursor in the window (pixels)
	y i64
	left bool
	leftPressed bool   # went down this frame
	right bool
	rightPressed bool
	rightReleased bool
	moveX f32   # the held mouse's motion this frame (pixels)
	moveY f32
	wheel f32   # notches turned this frame, with fractions
	scripted bool

pub type InputSource:
	steps engine.ReplayStep[]
	scripted bool
	held Input   # the replay's state, and last frame's

fn noInput(scripted bool):
	Input(
		x = 0,
		y = 0,
		left = false,
		leftPressed = false,
		right = false,
		rightPressed = false,
		rightReleased = false,
		moveX = 0.0,
		moveY = 0.0,
		wheel = 0.0,
		scripted)

# the window's input, or the script after --replay when there is one
pub fn newInputSource() InputSource:
	steps = engine.replaySteps()
	held = noInput(not steps.isEmpty)
	at = engine.mousePosition()
	held.x = at.x
	held.y = at.y
	InputSource(steps, scripted = not steps.isEmpty, held)

# the input of frame `frame`
pub fn readInput(mut s InputSource, frame i64) Input:
	wasRight = s.held.right
	wasLeft = s.held.left
	i = s.held
	i.moveX = 0.0
	i.moveY = 0.0
	i.wheel = 0.0
	if s.scripted:
		for st in s.steps:
			if st.frame != frame: continue
			if st.verb == "move":
				i.x = st.number(0)
				i.y = st.number(1)
			elif st.verb == "ldown":
				i.left = true
			elif st.verb == "lup":
				i.left = false
			elif st.verb == "rdown":
				i.right = true
			elif st.verb == "rup":
				i.right = false
			elif st.verb == "drag":
				i.moveX += f32(st.number(0))
				i.moveY += f32(st.number(1))
			elif st.verb == "wheel":
				i.wheel += f32(st.number(0))
		i.leftPressed = i.left and not wasLeft
	else:
		at = engine.mousePosition()
		i.x = at.x
		i.y = at.y
		i.left = engine.isMouseDown(0)
		i.leftPressed = engine.isMousePressed(0)
		i.right = engine.isMouseDown(1)
		motion = engine.mouseMotion()
		i.moveX = f32(motion.x)
		i.moveY = f32(motion.y)
		i.wheel = engine.wheelTurn()
	i.rightPressed = (i.right and not wasRight) or (not i.scripted and engine.isMousePressed(1))
	i.rightReleased = not i.right and wasRight
	s.held = i
	i
