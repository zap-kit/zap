# The Menu Manager: menus as MenuInfo records in handles (menuID, menuWidth, menuHeight, the MDEF's
# handle, enableFlags, then the title and the items: each its text, icon, key, mark and style,
# a zero byte after the last), the menu bar's list in MenuList (the last entry's offset, the bar's
# right end, then each menu's handle and left edge), and the bar drawn along the screen's top.

import cpu

pub menuId u32 = 0
pub menuWidth u32 = 2
pub menuHeight u32 = 4
pub menuProc u32 = 6
pub menuEnable u32 = 10
pub menuData u32 = 14
listHeader u32 = 6
listEntry u32 = 6
barLeft = 10
titlePad = 13

pub fn menuList() u32:
	cpu.read32(menuListAt)

pub fn initMenus():
	h = newHandle(theZone(), listHeader)
	p = deref(h)
	setWord(p, 0)
	setWord(p + 2, barLeft)
	setWord(p + 4, 0)
	cpu.write32(menuListAt, h)
	drawMenuBar()

pub fn menuCount() i64:
	h = menuList()
	if h == 0: return 0
	word(deref(h)) / 6

pub fn menuAt(i i64) u32:
	cpu.read32(deref(menuList()) + listHeader + u32(i * 6))

fn menuLeftAt(i i64):
	word(deref(menuList()) + listHeader + u32(i * 6) + 4)

pub fn menuTitle(m u32) u8[]:
	pascalAt(deref(m) + menuData)

fn titleWidthOf(m u32):
	port = wMgrPort()
	setWord(port + portTxFont, 0)
	setWord(port + portTxSize, 0)
	cpu.write8(port + portTxFace, 0)
	textWidth(port, menuTitle(m))

# the menus' left edges laid out again from the left of the bar
fn layOut():
	p0 = deref(menuList())
	left = barLeft
	for i in 0..menuCount():
		setWord(p0 + listHeader + u32(i * 6) + 4, left)
		left += titleWidthOf(menuAt(i)) + titlePad
	setWord(deref(menuList()) + 2, left)

# InsertMenu: the menu in the bar before the menu of that ID (at the end for 0 or one not there)
pub fn insertMenu(m u32, beforeId i64):
	n = menuCount()
	for i in 0..n:
		if word(deref(menuAt(i))) == word(deref(m)): return
	at = n
	for i in 0..n:
		if word(deref(menuAt(i))) == beforeId:
			at = i
			break
	h = menuList()
	setHandleSize(h, listHeader + u32((n + 1) * 6))
	p = deref(h)
	moveBytes(p + listHeader + u32((at + 1) * 6), p + listHeader + u32(at * 6), (n - at) * 6)
	cpu.write32(p + listHeader + u32(at * 6), m)
	setWord(p, (n + 1) * 6)
	layOut()

pub fn deleteMenu(id i64):
	n = menuCount()
	for i in 0..n:
		if word(deref(menuAt(i))) == id:
			p = deref(menuList())
			moveBytes(
				p + listHeader + u32(i * 6),
				p + listHeader + u32((i + 1) * 6),
				(n - i - 1) * 6
			)
			setWord(p, (n - 1) * 6)
			setHandleSize(menuList(), listHeader + u32((n - 1) * 6))
			layOut()
			return

pub fn clearMenuBar():
	h = menuList()
	setHandleSize(h, listHeader)
	setWord(deref(h), 0)
	setWord(deref(h) + 2, barLeft)

# GetMenuBar: a copy of the menu list in a new handle
pub fn copyMenuBar() u32:
	from = menuList()
	size = handleSize(from)
	h = newHandle(theZone(), size)
	moveBytes(deref(h), deref(from), size)
	h

# SetMenuBar: the menu list made a copy of the list in the handle
pub fn setMenuBar(list u32):
	size = handleSize(list)
	h = menuList()
	setHandleSize(h, size)
	moveBytes(deref(h), deref(list), size)

# GetNewMBar: a menu list of the MBAR resource's menus (its count, then each MENU's ID), the
# current menu bar left as it was
pub fn getNewMenuBar(id i64) u32:
	bar = getResource(0x4D42_4152, id, [], false)
	if bar == 0: return 0
	saved = copyMenuBar()
	clearMenuBar()
	for i in 0..word(deref(bar)):
		insertMenu(getMenu(word(deref(bar) + 2 + u32(i * 2))), 0)
	made = copyMenuBar()
	setMenuBar(saved)
	disposeHandle(saved)
	made

# AddResMenu: an item for each resource of the type whose name starts with neither '.' nor '%',
# in the order the open resource files list them
pub fn addResMenu(m u32, kind i64):
	for r in resourcesOfType(kind, false):
		name = r.resourceName()
		if name.isEmpty or name[0] == '.' or name[0] == '%': continue
		addItem(m, name, [0, 0, 0, 0])
		setEnabled(m, itemCount(m), true)

# Calls the menu's MDEF (the System's code, run) with a message, the menu's rectangle and the
# point; the rectangle and the item after the call. The rectangle and item live on the stack.
fn callMenuDef(m u32, message i64, r Rect, hit u32, item i64):
	cpu.a7 -= 10
	rectAt = cpu.a7
	itemAt = cpu.a7 + 8
	writeRect(rectAt, r)
	setWord(itemAt, item)
	code = address(cpu.read32(address(cpu.read32(deref(m) + menuProc))))
	saved = thePort()
	setPort(wMgrPort())
	callPascal(code, [(u32(message), 2), (m, 4), (rectAt, 4), (hit, 4), (itemAt, 4)], 0)
	setPort(saved)
	out = readRect(rectAt), word(itemAt)
	cpu.a7 += 10
	out

# CalcMenuSize: the menu's width and height as its MDEF measures them (mSizeMsg)
pub fn calcMenuSize(m u32) Tuple2<Rect, i64>:
	callMenuDef(m, 2, Rect(top = 0, left = 0, bottom = 0, right = 0), 0, 0)

# a title's inverted rectangle: nine pixels each side of the title's text, below the bar's top
# line and above its bottom one
fn titleRect(i i64):
	left = menuLeftAt(i)
	Rect(
		top = 1,
		left = left - 1,
		bottom = word(mBarHeightAt) - 1,
		right = left + titleWidthOf(menuAt(i)) + 17
	)

fn invertTitle(i i64):
	port = wMgrPort()
	saved = thePort()
	setPort(port)
	paintArea(port, titleRect(i).rectToArea(), blackPattern(), 10)
	setPort(saved)

fn indexOfId(id i64):
	for i in 0..menuCount():
		if word(deref(menuAt(i))) == id: return i
	-1

# HiliteMenu: the title of the menu of that ID inverted, the one inverted before back to normal
# (TheMenu holds the ID; 0 none)
pub fn hiliteMenu(id i64):
	old = word(theMenuAt)
	if old == id: return
	if old != 0 and indexOfId(old) >= 0: invertTitle(indexOfId(old))
	if id != 0 and indexOfId(id) >= 0: invertTitle(indexOfId(id))
	setWord(theMenuAt, id if indexOfId(id) >= 0 else 0)

# the menu whose title is under a global point in the bar, -1 for none
fn titleAt(v i64, h i64):
	if v < 0 or v >= word(mBarHeightAt): return -1
	for i in 0..menuCount():
		r = titleRect(i)
		if h >= r.left and h < r.right: return i
	-1

# A menu pulled down: its rectangle under its title, its frame and shadow drawn and its items by
# its MDEF; the screen's bytes it covers kept to put back.
type Pulled:
	index i64
	rect Rect
	under u8[]
	item i64

fn screenRows(r Rect):
	(r.top.max(0), r.bottom.min(screenHeight))

fn pullDown(i i64):
	m = menuAt(i)
	if word(deref(m) + menuWidth) <= 0: calcMenuSize(m)
	top = word(mBarHeightAt)
	left = menuLeftAt(i)
	r = Rect(
		top,
		left,
		bottom = top + word(deref(m) + menuHeight),
		right = left + word(deref(m) + menuWidth)
	)
	from, to = screenRows(Rect(..r, top = r.top - 1, bottom = r.bottom + 2))
	under = (from * screenRowBytes..to * screenRowBytes).map(cpu.mem[screenBase + it])
	port = wMgrPort()
	saved = thePort()
	setPort(port)
	outer = Rect(top = r.top - 1, left = r.left - 1, bottom = r.bottom + 1, right = r.right + 1)
	paintArea(port, outer.rectToArea(), whitePattern(), patCopy)
	frame = outer
		.rectToArea()
		.combine(
			Rect(top = r.top, left = r.left, bottom = r.bottom, right = r.right).rectToArea(),
			2
		)
	shadow = rectArea(outer.top + 2, outer.right, outer.bottom + 1, outer.right + 1).combine(
		rectArea(outer.bottom, outer.left + 2, outer.bottom + 1, outer.right + 1),
		0
	)
	paintArea(port, frame.combine(shadow, 0), blackPattern(), patCopy)
	setPort(saved)
	callMenuDef(m, 0, r, 0, 0)
	Pulled(index = i, rect = r, under, item = 0)

fn putBack(p Pulled):
	from, _ = screenRows(Rect(..p.rect, top = p.rect.top - 1))
	for k, b in p.under:
		cpu.mem[screenBase + from * screenRowBytes + k] = b

# MenuSelect: the menus pulled down under the held mouse from the start point, the item under it
# when the button is released chosen (its menu's title left inverted): the menu's ID in the high
# word and the item in the low one, 0 when none was chosen.
pub fn menuSelect(v0 i64, h0 i64) u32:
	pulled Pulled? = none
	v = v0
	h = h0
	while true:
		i = titleAt(v, h)
		current = -1
		if pulled is p:
			current = p.index
		if i >= 0 and i != current:
			if pulled is p:
				p.putBack()
			hiliteMenu(word(deref(menuAt(i))))
			pulled = pullDown(i)
		if pulled is p:
			_, item = callMenuDef(menuAt(p.index), 1, p.rect, pointValue(v, h), p.item)
			pulled = Pulled(..p, item)
		if not followMouse():
			isButtonDown = false
			break
		v = mouseV
		h = mouseH
	match pulled:
		p:
			p.putBack()
			id = word(deref(menuAt(p.index)))
			if p.item > 0: return u32(id) << 16 | u32(p.item)
			hiliteMenu(0)
			0
		none: 0

pub fn menuWithId(id i64) u32:
	for i in 0..menuCount():
		if word(deref(menuAt(i))) == id: return menuAt(i)
	0

# DrawMenuBar: the bar white with its line below, each title in the system font
pub fn drawMenuBar():
	port = wMgrPort()
	saved = thePort()
	setPort(port)
	height = word(mBarHeightAt)
	clip = cpu.read32(port + portClipRgn)
	setRectRegion(clip, Rect(top = -32_767, left = -32_767, bottom = 32_767, right = 32_767))
	bar = rectArea(0, 0, height - 1, screenWidth).combine(
		roundRectArea(Rect(top = 0, left = 0, bottom = screenHeight, right = screenWidth), 16, 16),
		1
	)
	paintArea(port, bar, whitePattern(), patCopy)
	paintArea(port, rectArea(height - 1, 0, height, screenWidth), blackPattern(), patCopy)
	setWord(port + portTxFont, 0)
	setWord(port + portTxSize, 0)
	cpu.write8(port + portTxFace, 0)
	setWord(port + portTxMode, srcOr)
	for i in 0..menuCount():
		m = menuAt(i)
		setWord(port + portPnLoc, 14)
		setWord(port + portPnLoc + 2, menuLeftAt(i) + 8)
		drawTextVia(port, menuTitle(m))
		if cpu.read32(deref(m) + menuEnable) & 1 == 0:
			left = menuLeftAt(i)
			paintArea(
				port,
				rectArea(1, left, height - 1, left + titleWidthOf(m) + titlePad),
				grayPattern(),
				11
			)
	setPort(saved)

# the bytes after the title: each item's text, then its icon, key, mark and style bytes
fn itemsAt(m u32):
	p = deref(m) + menuData
	p + 1 + cpu.read8(p)

# the offset in the menu's handle of item n (1 the first), -1 when there is none
pub fn itemOffset(m u32, n i64) i64:
	p = deref(m)
	at = itemsAt(m)
	i = 1
	while cpu.read8(at) != 0:
		if i == n: return at - p
		at += 1 + cpu.read8(at) + 4
		i += 1
	-1

pub fn itemCount(m u32) i64:
	at = itemsAt(m)
	i = 0
	while cpu.read8(at) != 0:
		at += 1 + cpu.read8(at) + 4
		i += 1
	i

# the item's text, and its icon, key, mark and style
pub fn itemText(m u32, n i64) u8[]:
	at = itemOffset(m, n)
	if at < 0: return []
	pascalAt(deref(m) + u32(at))

pub fn itemField(m u32, n i64, field i64) u32:
	at = itemOffset(m, n)
	if at < 0: return 0
	p = deref(m) + u32(at)
	cpu.read8(p + 1 + cpu.read8(p) + u32(field))

pub fn setItemField(m u32, n i64, field i64, v u32):
	at = itemOffset(m, n)
	if at < 0: return
	p = deref(m) + u32(at)
	cpu.write8(p + 1 + cpu.read8(p) + u32(field), v)

pub fn setEnabled(m u32, n i64, on bool):
	at = deref(m) + menuEnable
	flags = cpu.read32(at)
	bit = u32(1) << n.min(31)
	cpu.write32(at, flags | bit if on else flags & ~bit)

# AppendMenu: items from text, separated by ';' or a return, with their metacharacters: '^' an
# icon, '!' a mark, '<' a style, '/' a key, '(' the item disabled
pub fn appendMenu(m u32, data u8[]):
	items u8[,] = [[]]
	for c in data:
		if c == ';' or c == 13:
			items.push([])
		else:
			items[len - 1].push(c)
	for text in items:
		appendItem(m, text)

fn appendItem(m u32, spec u8[]):
	name = []
	icon u32 = 0
	key u32 = 0
	mark u32 = 0
	style u32 = 0
	isEnabled = true
	i = 0
	while i < spec.len:
		c = spec[i]
		hasNext = i + 1 < spec.len
		if c == '^' and hasNext:
			icon = u32(spec[i + 1]) - u32('0')
			i += 2
		elif c == '!' and hasNext:
			mark = spec[i + 1]
			i += 2
		elif c == '/' and hasNext:
			key = spec[i + 1]
			i += 2
		elif c == '<' and hasNext:
			style |= styleBit(spec[i + 1])
			i += 2
		elif c == '(':
			isEnabled = false
			i += 1
		else:
			name.push(c)
			i += 1
	if name.isEmpty: return
	addItem(m, name, [icon, key, mark, style])
	setEnabled(m, itemCount(m), isEnabled)

# an item of the text and the icon, key, mark and style bytes after the menu's last
fn addItem(m u32, name u8[], fields u32[]):
	old = i64(handleSize(m))
	# the zero byte that ends the items moves after the new item
	setHandleSize(m, u32(old + name.len + 5))
	p = deref(m) + u32(old - 1)
	writePascal(p, name)
	q = p + 1 + u32(name.len)
	for i, v in fields:
		cpu.write8(q + u32(i), v)
	cpu.write8(q + 4, 0)

# SetItem: item n's text replaced, its other bytes kept
pub fn setItemText(m u32, n i64, text u8[]):
	at = itemOffset(m, n)
	if at < 0: return
	oldLength = i64(cpu.read8(deref(m) + u32(at)))
	size = i64(handleSize(m))
	tail = at + 1 + oldLength
	if text.len > oldLength: setHandleSize(m, u32(size + text.len - oldLength))
	p = deref(m)
	moveBytes(p + u32(at + 1 + text.len), p + u32(tail), size - tail)
	if text.len < oldLength: setHandleSize(m, u32(size + text.len - oldLength))
	writePascal(deref(m) + u32(at), text)

fn styleBit(c u8) u32:
	match c:
		'B': 1
		'I': 2
		'U': 4
		'O': 8
		'S': 16
		_: 0

# NewMenu: an empty menu of the title, drawn by MDEF 0
pub fn newMenu(id i64, title u8[]) u32:
	h = newHandle(theZone(), menuData + u32(title.len + 2))
	p = deref(h)
	setWord(p + menuId, id)
	setWord(p + menuWidth, 0)
	setWord(p + menuHeight, 0)
	cpu.write32(p + menuProc, getResource(0x4D44_4546, 0, [], false))
	cpu.write32(p + menuEnable, 0xFFFF_FFFF)
	writePascal(p + menuData, title)
	cpu.write8(p + menuData + 1 + u32(title.len), 0)
	h

# GetMenu: a MENU resource as the menu itself, its MDEF's ID turned into the MDEF's handle
pub fn getMenu(id i64) u32:
	h = getResource(0x4D45_4E55, id, [], false)
	if h == 0: return 0
	p = deref(h)
	procId = i64(cpu.read16(p + menuProc + 2))
	if cpu.read32(p + menuProc) <= 0xFFFF:
		cpu.write32(deref(h) + menuProc, getResource(0x4D44_4546, procId, [], false))
	h
