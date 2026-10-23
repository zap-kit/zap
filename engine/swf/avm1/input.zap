# The pointer as Flash Player gives it to AVM1 (Ruffle's core/src/player.rs, mouse events): Mouse's
# listeners hear onMouseMove, onMouseDown and onMouseUp; the topmost clip under the pointer that
# has a button handler (onPress, onRelease, onReleaseOutside, onRollOver, onRollOut), found by
# its bounds, gets onRollOver and onRollOut as the pointer enters and leaves it, onPress when it
# is pressed over it and onRelease (or onReleaseOutside) when it is let go.

import engine.swf

buttonEvents = ["onPress", "onRelease", "onReleaseOutside", "onRollOver", "onRollOut"]

# the BUTTONCONDACTION condition of each of those events
buttonConditions = [4, 8, 0x40, 1, 2]

# the pointer at (x, y) in the window's pixels, pressed or not
pub fn pointer(mut p Player, x f64, y f64, down bool):
	p.prog.pointerEvent(p.m, x, y, down)

fn pointerEvent(prog Program, mut m Machine, x f64, y f64, down bool):
	at = prog.toScreen(m).inverse().apply(Vec2(f32(x), f32(y))) / 20.0
	moved = at != m.mouse
	m.mouse = at
	if moved: prog.tellListeners(m, "onMouseMove")
	over = prog.buttonAt(m, 0, at * 20.0) ?? -1
	if over != m.hovered:
		if m.hovered >= 0: prog.clipEvent(m, m.hovered, "onRollOut")
		if over >= 0: prog.clipEvent(m, over, "onRollOver")
		m.hovered = over
	if down != m.mouseDown:
		m.mouseDown = down
		prog.tellListeners(m, "onMouseDown" if down else "onMouseUp")
		if down:
			m.pressed = over
			if over >= 0: prog.clipEvent(m, over, "onPress")
		elif m.pressed >= 0:
			prog.clipEvent(m, m.pressed, "onRelease" if m.pressed == over else "onReleaseOutside")
			m.pressed = -1
	prog.runJobs(m)

fn tellListeners(prog Program, mut m Machine, name str):
	for who in m.heap[m.mouseListeners].items.copy():
		prog.callNamed(m, who, name)

# an event of a clip or button: its method of that name, a button's code of that condition run in
# the timeline holding it
fn clipEvent(prog Program, mut m Machine, n i64, name str):
	if n >= m.stage.nodes.len or not m.stage.nodes[n].alive: return
	prog.callNamed(m, .Obj(m.objectOfNode(prog, n)), name)
	handlers = prog.buttonBlocks.get(m.stage.nodes[n].placed.character) ?? return
	for k, event in buttonEvents:
		if event != name: continue
		for h in handlers:
			if (h.events & buttonConditions[k]) != 0:
				m.jobs.push(.Run(m.stage.nodes[n].parent, h.block))

# the value's method of that name called with no arguments, when it has one
fn callNamed(prog Program, mut m Machine, who Value, name str):
	f, home = prog.methodOf(m, who, name) ?? return
	if not f.isObject(): return
	match prog.callValue(m, f, who, [], home):
		error: m.fault("in {name}: {prog.describe(m, error.value)}")
		_: pass

# the topmost visible node under the stage point (twips) whose object has a button handler
fn buttonAt(prog Program, mut m Machine, n i64, at Vec2) i64?:
	kids = m.stage.nodes[n].children.copy()
	for k in 0..kids.len:
		c = kids[len - 1 - k]
		if not m.stage.nodes[c].placed.visible or m.stage.nodes[c].placed.clipDepth > 0: continue
		if prog.buttonAt(m, c, at) is found: return found
	if n == 0 or m.stage.nodes[n].object < 0: return none
	id = m.stage.nodes[n].object
	handled = prog.buttonBlocks.get(m.stage.nodes[n].placed.character) != none
	for name in buttonEvents:
		if m.holderOf(id, name) != none: handled = true
	if not handled: return none
	b = try prog.scene.boundsOf(m.stage, n, m.stage.stageMatrix(n))
	if at.x >= b.xmin and at.x <= b.xmax and at.y >= b.ymin and at.y <= b.ymax: return n
	none
