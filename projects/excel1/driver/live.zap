# The live screen: the Mac's 512 x 342 screen in a window, scaled up by whole pixels, the real
# mouse and keys turned into the Mac's events, its clock (Ticks) the real one. Closing the window
# ends the run.

import cpu
import engine
import mac

type Screen:
	window engine.Window
	frames engine.Frames
	renderer engine.Renderer
	picture engine.GpuTexture

mut screens Screen[] = []
mut startedAt f64 = 0.0
mut nextFrameAt f64 = 0.0
mut startTicks u32 = 0
mut wasDown = false

scale = 2
frameSeconds = 1.0 / 60.0

# opens the window: the run from here on is live
pub fn openLiveScreen():
	screens.push(Screen(
		window = engine.openWindow(
			"Microsoft Excel 1.00 (Zap)",
			mac.screenWidth * scale,
			mac.screenHeight * scale
		),
		frames = engine.newFrames(),
		renderer = engine.newRenderer(),
		picture = mac.screenImage().newTexture()
	))
	startedAt = clockSeconds()
	nextFrameAt = startedAt
	startTicks = cpu.read32(mac.ticksAt)
	mac.isLive = true
	mac.idleLimit = -1
	mac.livePoll = pollScreen

# The live screen's turn: the clock moved on; at each frame's time the screen shown and the input
# read; when the program waits, a sleep to the next frame first.
fn pollScreen(isWaiting bool):
	now = clockSeconds()
	if isWaiting and now < nextFrameAt: sleepMs(i64((nextFrameAt - now) * 1000.0) + 1)
	now2 = clockSeconds()
	cpu.write32(mac.ticksAt, startTicks + u32((now2 - startedAt) * 60.0))
	if now2 < nextFrameAt: return
	nextFrameAt = now2 + frameSeconds
	screens[0].show()

fn show(mut s Screen):
	if not s.window.nextFrame(s.frames, escEnds = false): exit(0)
	readMouse(s.window.width, s.window.height)
	readKeys()
	s.picture.updateTexture(mac.screenImage())
	s.renderer.beginFrame(
		s.window.width,
		s.window.height,
		Vec4(0.0, 0.0, 0.0, 1.0),
		engine.Camera()
	)
	# the largest whole scale that fits, centred
	k = (s.window.width / mac.screenWidth).min(s.window.height / mac.screenHeight).max(1)
	w = mac.screenWidth * k
	h = mac.screenHeight * k
	left = (s.window.width - w) / 2
	top = (s.window.height - h) / 2
	s.renderer.drawQuad(s.picture.texture(), f32(left), f32(top), f32(w), f32(h))
	s.renderer.showFrame(s.window, s.frames)

# the mouse at its place on the Mac's screen; a press or release posted
fn readMouse(width i64, height i64):
	k = (width / mac.screenWidth).min(height / mac.screenHeight).max(1)
	left = (width - mac.screenWidth * k) / 2
	top = (height - mac.screenHeight * k) / 2
	at = engine.mousePosition()
	mac.mouseH = ((at.x - left) / k).clamp(0, mac.screenWidth - 1)
	mac.mouseV = ((at.y - top) / k).clamp(0, mac.screenHeight - 1)
	down = engine.isMouseDown(0)
	if down == wasDown: return
	wasDown = down
	mac.isButtonDown = down
	where = mac.pointValue(mac.mouseV, mac.mouseH)
	mac.postEvent(
		mac.Event(
			what = mac.mouseDown if down else mac.mouseUp,
			message = 0,
			where,
			modifiers = modifiers()
		)
	)

# the Mac's modifier bits: Command (Ctrl), Shift
fn modifiers():
	(0x100 if engine.isKeyDown(.Char(17)) else 0) | (0x200 if engine.isKeyDown(.Shift) else 0)

# each key pressed this frame posted as a keyDown of its character (a US keyboard)
fn readKeys():
	isShifted = engine.isKeyDown(.Shift)
	for vk in 8..223:
		if not engine.isKeyPressed(.Char(vk)): continue
		c = character(vk, isShifted)
		if c < 0: continue
		mac.postEvent(mac.Event(what = mac.keyDown, message = u32(c), modifiers = modifiers()))

# the character a virtual key gives, -1 for none
fn character(vk i64, isShifted bool):
	if vk >= 'A' and vk <= 'Z': return vk if isShifted else vk + 32
	if vk >= '0' and vk <= '9': return ")!@#$%^&*("[vk - '0'] if isShifted else vk
	if vk >= 0x60 and vk <= 0x69: return vk - 0x60 + '0'   # the keypad's digits
	match vk:
		8: 8
		9: 9
		13: 13
		27: 27
		32: 32
		37: 0x1C   # the arrows, as the Mac's keyboard gives them
		39: 0x1D
		38: 0x1E
		40: 0x1F
		46: 0x7F
		0x6A: '*'
		0x6B: '+'
		0x6D: '-'
		0x6E: '.'
		0x6F: '/'
		0xBA: ':' if isShifted else ';'
		0xBB: '+' if isShifted else '='
		0xBC: '<' if isShifted else ','
		0xBD: '_' if isShifted else '-'
		0xBE: '>' if isShifted else '.'
		0xBF: '?' if isShifted else '/'
		0xC0: '~' if isShifted else '`'
		0xDB: '{' if isShifted else '['
		0xDC: '|' if isShifted else '\\'
		0xDD: '}' if isShifted else ']'
		0xDE: '"' if isShifted else '\''
		_: -1
