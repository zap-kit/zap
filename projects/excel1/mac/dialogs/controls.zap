# The Control Manager: controls as ControlRecords in handles (nextControl, contrlOwner, contrlRect,
# contrlVis, contrlHilite, contrlValue, contrlMin, contrlMax, the CDEF's handle with the variation
# in its top byte, contrlData, contrlAction, contrlRfCon, contrlTitle), listed from their window's
# controlList and drawn by their CDEF (the System's code, run) in their window's port.

import cpu

pub cNext u32 = 0
pub cOwner u32 = 4
pub cRect u32 = 8
pub cVisible u32 = 16
pub cHilite u32 = 17
pub cValue u32 = 18
pub cMin u32 = 20
pub cMax u32 = 22
pub cDefProc u32 = 24
pub cData u32 = 28
pub cAction u32 = 32
pub cRefCon u32 = 36
pub cTitle u32 = 40
controlSize = 296

drawCntl = 0
testCntl = 1
calcCRgns = 2
initCntl = 3
dispCntl = 4
cdefType = 0x4344_4546   # 'CDEF'

# the control's record: its handle dereferenced
pub fn ctl(c u32) u32:
	address(cpu.read32(c))

fn callCdef(c u32, message i64, param u32):
	h = cpu.read32(ctl(c) + cDefProc)
	code = address(cpu.read32(address(h)))
	saved = thePort()
	setPort(cpu.read32(ctl(c) + cOwner))
	r = callPascal(code, [(h >> 24, 2), (c, 4), (u32(message), 2), (param, 4)], 4)
	setPort(saved)
	r

pub fn isControlVisible(c u32) bool:
	cpu.read8(ctl(c) + cVisible) != 0

# NewControl: the control made, first in its window's list, drawn when visible
pub fn newControl(
	window u32,
	bounds Rect,
	title u8[],
	isShown bool,
	value i64,
	min i64,
	max i64,
	procId i64,
	refCon u32
) u32:
	c = newHandle(theZone(), u32(controlSize))
	p = ctl(c)
	cpu.write32(p + cNext, cpu.read32(window + wControls))
	cpu.write32(p + cOwner, window)
	writeRect(p + cRect, bounds)
	cpu.write8(p + cVisible, 0xFF if isShown else 0)
	cpu.write8(p + cHilite, 0)
	setWord(p + cValue, value)
	setWord(p + cMin, min)
	setWord(p + cMax, max)
	def = getResource(cdefType, procId >> 4, [], false)
	if def == 0: cpu.stop("no CDEF {procId >> 4}")
	setFlag(def, lockedBit, true)
	cpu.write32(p + cDefProc, def | u32(procId & 15) << 24)
	cpu.write32(p + cData, 0)
	cpu.write32(p + cAction, 0)
	cpu.write32(p + cRefCon, refCon)
	writePascal(p + cTitle, title)
	cpu.write32(window + wControls, c)
	callCdef(c, initCntl, 0)
	if isShown: drawControl(c)
	c

# GetNewControl: a control from a CNTL resource (bounds, value, visible, max, min, procID, refCon,
# title)
pub fn getNewControl(id i64, window u32) u32:
	h = getResource(0x434E_544C, id, [], false)
	if h == 0: return 0
	p = address(cpu.read32(h))
	newControl(
		window,
		readRect(p),
		pascalAt(p + 22),
		cpu.read8(p + 10) != 0,
		word(p + 8),
		word(p + 14),
		word(p + 12),
		word(p + 16),
		cpu.read32(p + 18)
	)

pub fn drawControl(c u32):
	if isControlVisible(c): callCdef(c, drawCntl, 0)

pub fn drawControls(window u32):
	list = []
	c = cpu.read32(window + wControls)
	while c != 0:
		list.push(c)
		c = cpu.read32(ctl(c) + cNext)
	# drawn in the order they were made, the last made on top
	for k in 0..list.len:
		drawControl(list[len - 1 - k])

pub fn setControlField(c u32, field u32, v i64):
	setWord(ctl(c) + field, v)
	drawControl(c)

# SetCtlValue: the value pinned to the control's range, then drawn
pub fn setControlValue(c u32, v i64):
	p = ctl(c)
	setControlField(c, cValue, v.clamp(word(p + cMin), word(p + cMax).max(word(p + cMin))))

pub fn hiliteControl(c u32, state i64):
	cpu.write8(ctl(c) + cHilite, state & 0xFF)
	drawControl(c)

pub fn showControl(c u32, isShown bool):
	cpu.write8(ctl(c) + cVisible, 0xFF if isShown else 0)
	if isShown:
		drawControl(c)
	else:
		window = cpu.read32(ctl(c) + cOwner)
		r = readRect(ctl(c) + cRect)
		saved = thePort()
		setPort(window)
		paintArea(window, r.rectToArea(), window + portBkPat, patCopy)
		changeUpdate(window, r.rectToArea(), true)
		setPort(saved)

fn unlink(c u32):
	window = cpu.read32(ctl(c) + cOwner)
	next = cpu.read32(ctl(c) + cNext)
	first = cpu.read32(window + wControls)
	if first == c:
		cpu.write32(window + wControls, next)
		return
	v = first
	while v != 0:
		if cpu.read32(ctl(v) + cNext) == c:
			cpu.write32(ctl(v) + cNext, next)
			return
		v = cpu.read32(ctl(v) + cNext)

pub fn disposeControl(c u32):
	if isControlVisible(c): showControl(c, false)
	callCdef(c, dispCntl, 0)
	unlink(c)
	disposeHandle(c)

pub fn killControls(window u32):
	while cpu.read32(window + wControls) != 0:
		disposeControl(cpu.read32(window + wControls))

# the part of a visible, active control at a local point, 0 for none
pub fn testControl(c u32, v i64, h i64) i64:
	if not isControlVisible(c) or cpu.read8(ctl(c) + cHilite) == 255: return 0
	(callCdef(c, testCntl, pointValue(v, h)) & 0xFFFF)

# FindControl: the control of the window at a local point and its part
pub fn findControl(window u32, v i64, h i64) (u32, i64):
	c = cpu.read32(window + wControls)
	while c != 0:
		part = testControl(c, v, h)
		if part != 0: return (c, part)
		c = cpu.read32(ctl(c) + cNext)
	(0, 0)
