# The Event Manager: the events posted (the input a run is given: keys and clicks), the activate
# and deactivate events the Window Manager leaves in CurActivate and CurDeactive, and the update
# events of windows whose update regions are not empty, handed out as EventRecords (what, message,
# when, where, modifiers). The clock (Ticks) moves one tick each time the program asks for an event
# or the time, so a run is the same each time.

import cpu

pub nullEvent = 0
pub mouseDown = 1
pub mouseUp = 2
pub keyDown = 3
pub keyUp = 4
pub autoKey = 5
pub updateEvt = 6
pub activateEvt = 8

pub type Event:
	what i64
	message u32
	where u32 = 0
	modifiers i64 = 0

pub mut queue Event[] = []
pub mut idleCount = 0   # null events given in a row: the program is waiting for input
pub mut mouseV = 100
pub mut mouseH = 100
pub mut isButtonDown = false

# The input a run is given (main.zap's --input): the mouse pressed, moved and released at screen
# points, and keys. Each is given when the program has waited idleLimit null events for it; a
# move or a release also when the program follows the held button (StillDown, MenuSelect).
pub type Input:
	what i64   # mouseDown, mouseUp or keyDown; nullEvent for a move
	v i64
	h i64
	key i64 = 0

pub mut inputs Input[] = []

# the inputs of a script: "down v h", "move v h", "up v h" and "key c", separated by ';'
pub fn parseInputs(script str) Input[] ? str:
	out = []
	for part in script.split(";"):
		words = part.trimmed().split(" ").filter(it != "")
		if words.isEmpty: continue
		if words[0] == "key" and words.len == 2:
			out.push(Input(what = keyDown, v = 0, h = 0, key = words[1].bytes()[0]))
			continue
		if words.len != 3:
			return "an input is \"down v h\", \"move v h\", \"up v h\" or \"key c\": \"{part}\""
		v = i64.parse(words[1]) ?? return "not a number: {words[1]}"
		h = i64.parse(words[2]) ?? return "not a number: {words[2]}"
		what = match words[0]:
			"down": mouseDown
			"up": mouseUp
			"move": nullEvent
			_: return "no input \"{words[0]}\""
		out.push(Input(what, v, h))
	out

# The next input given: the mouse moved, the button pressed or released, a key's event posted;
# false when none is left.
pub fn giveInput() bool:
	if inputs.isEmpty: return false
	i = inputs.remove(0)
	idleCount = 0
	if i.what == keyDown:
		postEvent(Event(what = keyDown, message = u32(i.key)))
		return true
	mouseV = i.v
	mouseH = i.h
	if i.what != nullEvent:
		isButtonDown = i.what == mouseDown
		postEvent(Event(what = i.what, message = 0, where = pointValue(i.v, i.h)))
	true

# The held button followed: the next move or release given; false when the button is up or no
# move or release comes next (the hand stays where it is).
pub fn followMouse() bool:
	if isLive:
		poll(true)
		return isButtonDown
	if not isButtonDown or inputs.isEmpty: return false
	if inputs[0].what != nullEvent and inputs[0].what != mouseUp: return false
	giveInput()

# whether the run goes on after a null event: the next input given once the program has waited
# idleLimit null events; false when none is left
pub fn waitsForInput() bool:
	if idleLimit < 0 or idleCount < idleLimit: return true
	giveInput()

# A run on a live screen (main.zap without its headless options): `poll` shows the screen and
# turns the real mouse and keys into events and the clock into Ticks, a sixtieth of a second
# each; told the program waits, it sleeps to the next frame first.
pub mut isLive = false
pub mut livePoll fn(bool) = (_): pass

fn poll(isWaiting bool):
	turn = livePoll
	turn(isWaiting)

pub fn tick() u32:
	if isLive: return cpu.read32(ticksAt)
	t = cpu.read32(ticksAt) + 1
	cpu.write32(ticksAt, t)
	t

pub fn postEvent(e Event):
	queue.push(e)

fn writeEvent(at u32, e Event):
	setWord(at, e.what)
	cpu.write32(at + 2, e.message)
	cpu.write32(at + 6, cpu.read32(ticksAt))
	cpu.write32(at + 10, e.where if e.where != 0 else pointValue(mouseV, mouseH))
	setWord(at + 14, e.modifiers | (0x80 if not isButtonDown else 0))

fn isWanted(mask i64, what i64):
	mask >> what & 1 != 0

# the next event of the mask, taken out of the queue when `isTaken`; a null event when none
pub fn nextEvent(mask i64, isTaken bool) Event:
	deactivated = cpu.read32(curDeactiveAt)
	if deactivated != 0 and isWanted(mask, activateEvt):
		if isTaken: cpu.write32(curDeactiveAt, 0)
		return Event(what = activateEvt, message = deactivated)
	activated = cpu.read32(curActivateAt)
	if activated != 0 and isWanted(mask, activateEvt):
		if isTaken: cpu.write32(curActivateAt, 0)
		return Event(what = activateEvt, message = activated, modifiers = 1)
	for i, e in queue:
		if isWanted(mask, e.what):
			if isTaken: return queue.remove(i)
			return e.copy()
	if isWanted(mask, updateEvt):
		w = firstWindow()
		while w != 0:
			if isVisible(w) and not areaOfHandle(cpu.read32(w + wUpdateRgn)).isEmpty:
				return Event(what = updateEvt, message = w)
			w = nextWindow(w)
	Event(what = nullEvent, message = 0)

# GetNextEvent and EventAvail: whether an event of the mask was there, written at `at`
pub fn getEvent(mask i64, at u32, isTaken bool) bool:
	tick()
	poll(false)
	e = nextEvent(mask, isTaken)
	writeEvent(at, e)
	if e.what == nullEvent:
		# a program waits in GetNextEvent; EventAvail is its look for input while it works
		if isTaken:
			idleCount += 1
			poll(true)
		return false
	idleCount = 0
	if traceTraps: eprint("  event {e.what} {e.message:x} at {e.where:x}")
	if not isLive and e.what == mouseDown: isButtonDown = true
	if not isLive and e.what == mouseUp: isButtonDown = false
	true

# FlushEvents: the queued events of the mask taken out, up to the first of the stop mask
pub fn flushEvents(mask i64, stopMask i64):
	kept = []
	isStopped = false
	for e in queue:
		if isWanted(stopMask, e.what): isStopped = true
		if isStopped or not isWanted(mask, e.what): kept.push(e.copy())
	queue = kept
