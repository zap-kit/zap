# The Window Manager: the desktop (GrayRgn, the screen less the menu bar, its corners rounded) in
# the Window Manager's port, the windows in a list from the front (WindowList), each a WindowRecord
# (a GrafPort, then windowKind, visible, hilited, goAwayFlag, strucRgn, contRgn and updateRgn in
# global coordinates, its WDEF's handle with the variation in the top byte, its title, controls,
# next window and refCon). A window's frame is drawn by its WDEF (the System's code, run), its
# content erased and added to its update region; its visRgn is its content less the windows in
# front, in its local coordinates.

import cpu

pub wKind u32 = 108
pub wVisible u32 = 110
pub wHilited u32 = 111
pub wGoAway u32 = 112
pub wStrucRgn u32 = 114
pub wContRgn u32 = 118
pub wUpdateRgn u32 = 122
pub wDefProc u32 = 126
pub wDataHandle u32 = 130
pub wTitle u32 = 134
pub wTitleWidth u32 = 138
pub wControls u32 = 140
pub wNext u32 = 144
pub wPic u32 = 148
pub wRefCon u32 = 152
pub windowSize = 156

wDraw = 0
wHit = 1
wCalcRgns = 2
wNew = 3
wDispose = 4
wDrawGIcon = 6
wdefType = 0x5744_4546   # 'WDEF'

pub fn wMgrPort() u32:
	cpu.read32(wMgrPortAt)

pub fn grayArea() Area:
	areaOfHandle(cpu.read32(grayRgnAt))

pub fn firstWindow() u32:
	cpu.read32(windowListAt)

pub fn nextWindow(w u32) u32:
	cpu.read32(w + wNext)

pub fn isVisible(w u32) bool:
	cpu.read8(w + wVisible) != 0

fn regionOf(w u32, field u32):
	areaOfHandle(cpu.read32(w + field))

# the screen less the menu bar, its four corners rounded as the Mac Plus's screen is
fn desktopArea():
	screen = Rect(top = 0, left = 0, bottom = screenHeight, right = screenWidth)
	rounded = screen.roundRectArea(16, 16)
	rounded.combine(rectArea(0, 0, word(mBarHeightAt), screenWidth), 2)

# InitWindows: the Window Manager's port over the screen, the desktop painted, the menu bar drawn
pub fn initWindows():
	port = newPtr(theZone(), u32(portSize))
	openPort(port)
	cpu.write32(wMgrPortAt, port)
	gray = newRegion()
	writeArea(gray, desktopArea())
	cpu.write32(grayRgnAt, gray)
	cpu.write32(windowListAt, 0)
	cpu.write8(saveUpdateAt, 0xFF)
	cpu.write8(paintWhiteAt, 0xFF)
	cpu.write32(curActivateAt, 0)
	cpu.write32(curDeactiveAt, 0)
	screen = Rect(top = 0, left = 0, bottom = screenHeight, right = screenWidth)
	# the screen black first: the corners stay so
	paintArea(port, screen.rectToArea(), blackPattern(), patCopy)
	desktopArea().paintDesktop()
	drawMenuBar()

# the desktop's pattern in the part of the area outside every visible window
fn paintDesktop(a Area):
	port = wMgrPort()
	setPort(port)
	paintArea(port, a.combine(grayArea(), 1), deskPatternAt, patCopy)

# calls the window's WDEF with a message and a parameter: its result
fn callDefProc(w u32, message i64, param u32):
	h = cpu.read32(w + wDefProc)
	variant = h >> 24
	code = address(cpu.read32(address(h)))
	saved = thePort()
	setPort(wMgrPort())
	r = callPascal(code, [(variant, 2), (w, 4), (u32(message), 2), (param, 4)], 4)
	setPort(saved)
	r

# the union of the structures of the visible windows in front of w
fn frontStructures(w i64):
	out = emptyArea()
	v = firstWindow()
	while v != w and v != 0:
		if isVisible(v): out = out.combine(regionOf(v, wStrucRgn), 0)
		v = nextWindow(v)
	out

# the window's global origin: where its local (0, 0) lies on the screen
pub fn originOf(w u32) (i64, i64):
	b = readRect(w + portBounds)
	(-b.left, -b.top)

# CalcVis: the window's visRgn, its content less the windows in front, in local coordinates
pub fn calcVis(w u32):
	vis = cpu.read32(w + portVisRgn)
	if not isVisible(w):
		writeArea(vis, emptyArea())
		return
	a = regionOf(w, wContRgn).combine(grayArea(), 1).combine(frontStructures(w), 2)
	h, v = originOf(w)
	writeArea(vis, a.offset(-h, -v))

pub fn calcVisBehind(start u32):
	w = start
	while w != 0:
		calcVis(w)
		w = nextWindow(w)

# PaintOne: the part of the clobbered area in the window drawn again: its frame by the WDEF, its
# content erased and added to its update region; the desktop's part when w is 0
pub fn paintOne(w u32, clobbered Area):
	if w == 0:
		covered = emptyArea()
		v = firstWindow()
		while v != 0:
			if isVisible(v): covered = covered.combine(regionOf(v, wStrucRgn), 0)
			v = nextWindow(v)
		clobbered.combine(covered, 2).paintDesktop()
		return
	if not isVisible(w): return
	area = clobbered.combine(regionOf(w, wStrucRgn), 1).combine(frontStructures(w), 2)
	area2 = area.combine(grayArea(), 1)
	if area2.isEmpty: return
	port = wMgrPort()
	clip = cpu.read32(port + portClipRgn)
	writeArea(clip, area2)
	callDefProc(w, wDraw, 0)
	setRectRegion(clip, Rect(top = -32_767, left = -32_767, bottom = 32_767, right = 32_767))
	content = area2.combine(regionOf(w, wContRgn), 1)
	if not content.isEmpty:
		if cpu.read8(paintWhiteAt) != 0: paintArea(port, content, whitePattern(), patCopy)
		update = cpu.read32(w + wUpdateRgn)
		writeArea(update, areaOfHandle(update).combine(content, 0))

pub fn paintBehind(start u32, clobbered Area):
	rest = clobbered.copy()
	w = start
	while w != 0:
		paintOne(w, rest)
		if isVisible(w): rest = rest.combine(regionOf(w, wStrucRgn), 2)
		w = nextWindow(w)
	paintOne(0, rest)

fn insertWindow(w u32, behind u32):
	front = firstWindow()
	if behind == 0xFFFF_FFFF or front == 0:
		cpu.write32(w + wNext, front)
		cpu.write32(windowListAt, w)
		return
	if behind == 0:
		last = front
		while nextWindow(last) != 0:
			last = nextWindow(last)
		cpu.write32(last + wNext, w)
		cpu.write32(w + wNext, 0)
		return
	cpu.write32(w + wNext, nextWindow(behind))
	cpu.write32(behind + wNext, w)

fn removeWindow(w u32):
	if firstWindow() == w:
		cpu.write32(windowListAt, nextWindow(w))
		return
	v = firstWindow()
	while v != 0 and nextWindow(v) != w:
		v = nextWindow(v)
	if v != 0: cpu.write32(v + wNext, nextWindow(w))

# NewWindow: the window made in `storage` (allocated when 0), in the list behind `behind` (-1 the
# front), shown when visible
pub fn newWindow(
	storage u32,
	bounds Rect,
	title u8[],
	isShown bool,
	procId i64,
	behind u32,
	hasGoAway bool,
	refCon u32
) u32:
	w = storage if storage != 0 else newPtr(theZone(), u32(windowSize))
	if not callPatched(0xA86F, [(w, 4)]): openPort(w)
	writeRect(
		w + portRect,
		Rect(
			top = 0,
			left = 0,
			bottom = bounds.bottom - bounds.top,
			right = bounds.right - bounds.left
		)
	)
	writeRect(
		w + portBounds,
		Rect(
			top = -bounds.top,
			left = -bounds.left,
			bottom = screenHeight - bounds.top,
			right = screenWidth - bounds.left
		)
	)
	setWord(w + wKind, 8)
	cpu.write8(w + wVisible, 0)
	cpu.write8(w + wHilited, 0)
	cpu.write8(w + wGoAway, 0xFF if hasGoAway else 0)
	cpu.write8(w + wGoAway + 1, 0)
	cpu.write32(w + wStrucRgn, newRegion())
	cpu.write32(w + wContRgn, newRegion())
	cpu.write32(w + wUpdateRgn, newRegion())
	def = getResource(wdefType, procId >> 4, [], false)
	if def == 0: cpu.stop("no WDEF {procId >> 4}")
	setFlag(def, lockedBit, true)
	cpu.write32(w + wDefProc, def | u32(procId & 15) << 24)
	cpu.write32(w + wDataHandle, 0)
	titleHandle = newHandle(theZone(), u32(title.len + 1))
	writePascal(address(cpu.read32(titleHandle)), title)
	cpu.write32(w + wTitle, titleHandle)
	setWord(w + wTitleWidth, 0)
	cpu.write32(w + wControls, 0)
	cpu.write32(w + wPic, 0)
	cpu.write32(w + wRefCon, refCon)
	insertWindow(w, behind)
	callDefProc(w, wNew, 0)
	setTitleWidth(w)
	callDefProc(w, wCalcRgns, 0)
	if isShown:
		showWindow(w)
	else:
		calcVis(w)
	setPort(w)
	w

fn setTitleWidth(w u32):
	saved = thePort()
	port = wMgrPort()
	setPort(port)
	setWord(port + portTxFont, 0)
	setWord(port + portTxSize, 0)
	cpu.write8(port + portTxFace, 0)
	setWord(w + wTitleWidth, textWidth(port, pascalAt(address(cpu.read32(cpu.read32(w + wTitle))))))
	setPort(saved)

# ShowWindow: the window drawn; when it comes out frontmost it is highlighted and activated, the
# window active before unhighlighted and deactivated
pub fn showWindow(w u32):
	if isVisible(w): return
	before = frontVisibleWindow()
	cpu.write8(w + wVisible, 0xFF)
	isFront = frontVisibleWindow() == w
	if isFront and before != 0:
		hiliteWindow(before, false)
		cpu.write32(curDeactiveAt, before)
	if isFront: hiliteWindow(w, true)
	callDefProc(w, wCalcRgns, 0)
	paintOne(w, regionOf(w, wStrucRgn))
	calcVisBehind(w)
	if isFront: cpu.write32(curActivateAt, w)

pub fn hideWindow(w u32):
	if not isVisible(w): return
	isFront = frontVisibleWindow() == w
	cpu.write8(w + wVisible, 0)
	clobbered = regionOf(w, wStrucRgn)
	paintBehind(nextWindow(w), clobbered)
	calcVisBehind(firstWindow())
	if isFront:
		cpu.write32(curDeactiveAt, w)
		next = frontVisibleWindow()
		if next != 0:
			hiliteWindow(next, true)
			cpu.write32(curActivateAt, next)

pub fn frontVisibleWindow() u32:
	w = firstWindow()
	while w != 0 and not isVisible(w):
		w = nextWindow(w)
	w

pub fn hiliteWindow(w u32, on bool):
	if (cpu.read8(w + wHilited) != 0) == on: return
	cpu.write8(w + wHilited, 0xFF if on else 0)
	if isVisible(w): paintOne(w, regionOf(w, wStrucRgn).combinedWith(regionOf(w, wContRgn), 2))

pub fn combinedWith(area Area, b Area, op i64) Area:
	area.combine(b, op)

# SelectWindow: the window brought to the front, highlighted and activated
pub fn selectWindow(w u32):
	front = frontVisibleWindow()
	if front != w and front != 0:
		hiliteWindow(front, false)
		cpu.write32(curDeactiveAt, front)
	bringToFront(w)
	hiliteWindow(w, true)
	cpu.write32(curActivateAt, w)

pub fn bringToFront(w u32):
	if firstWindow() == w: return
	covered = regionOf(w, wStrucRgn).combine(frontStructures(w), 1)
	removeWindow(w)
	insertWindow(w, 0xFFFF_FFFF)
	if isVisible(w): paintOne(w, covered)
	calcVisBehind(w)

pub fn disposeWindow(w u32, isStorageOurs bool):
	hideWindow(w)
	removeWindow(w)
	callDefProc(w, wDispose, 0)
	disposeHandle(cpu.read32(w + wStrucRgn))
	disposeHandle(cpu.read32(w + wContRgn))
	disposeHandle(cpu.read32(w + wUpdateRgn))
	disposeHandle(cpu.read32(w + wTitle))
	closePort(w)
	if isStorageOurs: disposePtr(w)

pub fn drawGrowIcon(w u32):
	if isVisible(w): callDefProc(w, wDrawGIcon, 0)

# the part of the window at a global point, as the WDEF's hit test says (0 none)
pub fn windowHit(w u32, v i64, h i64) i64:
	callDefProc(w, wHit, pointValue(v, h))

pub fn containsPoint(a Area, v i64, h i64) bool:
	match a.spansAt(v):
		xs: inSpans(xs, h)
		none: false

# FindWindow: the part of the screen at a global point (0 the desk, 1 the menu bar, 3 a window's
# content, 4 its drag region, 5 its grow box, 6 its close box) and the window there (0 for none)
pub fn findWindow(v i64, h i64) (i64, u32):
	if v < word(mBarHeightAt): return (1, 0)
	w = firstWindow()
	while w != 0:
		if isVisible(w) and regionOf(w, wStrucRgn).containsPoint(v, h):
			hit = windowHit(w, v, h)
			return (hit + 2 if hit > 0 else 0, w)
		w = nextWindow(w)
	(0, 0)

# the window's update region with a local rectangle or region added (Inval) or taken out (Valid)
pub fn changeUpdate(w u32, local Area, isAdded bool):
	h, v = originOf(w)
	update = cpu.read32(w + wUpdateRgn)
	global = local.offset(h, v)
	writeArea(update, areaOfHandle(update).combine(global, 0 if isAdded else 2))

# BeginUpdate: the visRgn cut to the update region, which is emptied; EndUpdate puts it back
mut savedVis = emptyArea()

pub fn beginUpdate(w u32):
	vis = cpu.read32(w + portVisRgn)
	savedVis = areaOfHandle(vis)
	h, v = originOf(w)
	update = areaOfHandle(cpu.read32(w + wUpdateRgn)).offset(-h, -v)
	writeArea(vis, savedVis.combine(update, 1))
	writeArea(cpu.read32(w + wUpdateRgn), emptyArea())

pub fn endUpdate(w u32):
	kept = savedVis.copy()
	writeArea(cpu.read32(w + portVisRgn), kept)

pub fn moveWindow(w u32, h i64, v i64, isFront bool):
	oldH, oldV = originOf(w)
	if oldH == h and oldV == v:
		if isFront: selectWindow(w)
		return
	old = regionOf(w, wStrucRgn)
	r = readRect(w + portBounds)
	dh = h - oldH
	dv = v - oldV
	writeRect(
		w + portBounds,
		Rect(top = r.top - dv, left = r.left - dh, bottom = r.bottom - dv, right = r.right - dh)
	)
	callDefProc(w, wCalcRgns, 0)
	if isVisible(w):
		paintBehind(nextWindow(w), old)
		paintOne(w, regionOf(w, wStrucRgn))
	calcVisBehind(firstWindow())
	if isFront: selectWindow(w)

pub fn sizeWindow(w u32, width i64, height i64, isUpdated bool):
	old = regionOf(w, wStrucRgn)
	oldContent = regionOf(w, wContRgn)
	r = readRect(w + portRect)
	writeRect(w + portRect, Rect(..r, bottom = r.top + height, right = r.left + width))
	callDefProc(w, wCalcRgns, 0)
	if isVisible(w):
		paintBehind(nextWindow(w), old.combine(regionOf(w, wStrucRgn), 2))
		paintOne(w, regionOf(w, wStrucRgn).combine(oldContent, 2))
		if not isUpdated:
			update = cpu.read32(w + wUpdateRgn)
			writeArea(update, areaOfHandle(update).combine(oldContent, 2))
	calcVisBehind(firstWindow())

pub fn setWindowTitle(w u32, title u8[]):
	h = cpu.read32(w + wTitle)
	setHandleSize(h, u32(title.len + 1))
	writePascal(address(cpu.read32(h)), title)
	setTitleWidth(w)
	if isVisible(w): paintOne(w, regionOf(w, wStrucRgn).combine(regionOf(w, wContRgn), 2))
