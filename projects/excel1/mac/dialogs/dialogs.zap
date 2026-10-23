# The Dialog Manager: a dialog is a window (windowKind 2) followed by its item list's handle, the
# edit record of its text field, the field's number and the default item; an item list is a count
# less one, then per item a handle (or a procedure), a rectangle, a type (4-7 controls, 8 static
# text, 16 editable text, 32 an icon, 64 a picture, 0 a user's item; +128 disabled) and its data.

import cpu

pub dItems u32 = 156
pub dTextH u32 = 160
pub dEditField u32 = 164
pub dDefItem u32 = 168
dialogSize = 170
dialogKind = 2

pub type Item:
	at u32   # the item's first byte: its handle field
	box Rect
	kind i64   # the type, without the disabled bit
	isEnabled bool
	data u8[]

fn itemsOf(d u32):
	h = cpu.read32(d + dItems)
	p = address(cpu.read32(h))
	count = word(p) + 1
	out = []
	at = p + 2
	loop count:
		t = i64(cpu.read8(at + 12))
		length = i64(cpu.read8(at + 13))
		out.push(
			Item(
				at,
				box = readRect(at + 4),
				kind = t & 127,
				isEnabled = t & 128 == 0,
				data = bytesAt(at + 14, length)
			)
		)
		at += 14 + u32(length + (length & 1))
	out

pub fn itemCountOf(d u32) i64:
	itemsOf(d).len

# the text of a static item with ^0 to ^3 replaced by ParamText's strings
fn substituted(text u8[]):
	out = []
	i = 0
	while i < text.len:
		c = text[i]
		if c == '^' and i + 1 < text.len and text[i + 1] >= '0' and text[i + 1] <= '3':
			h = cpu.read32(daStringsAt + 4 * u32(text[i + 1] - '0'))
			if h != 0: out.extend(pascalAt(address(cpu.read32(h))))
			i += 2
		else:
			out.push(c)
			i += 1
	out

fn handleOfText(text u8[]):
	h = newHandle(theZone(), u32(text.len))
	at = address(cpu.read32(h))
	for i, b in text:
		cpu.write8(at + u32(i), b)
	h

# the text an item's handle holds (static and editable text keep it there)
pub fn dialogItemText(item Item) u8[]:
	h = cpu.read32(item.at)
	if h == 0: return []
	bytesAt(address(cpu.read32(h)), handleSize(h))

fn makeItem(d u32, n i64, item Item):
	match item.kind:
		4, 5, 6:
			c = newControl(d, item.box, item.data, true, 0, 0, 1, item.kind - 4, 0)
			cpu.write32(item.at, c)
		7:
			id = i64(i16.wrap(i64(item.data.u16be(0))))
			c = getNewControl(id, d)
			if c != 0: writeRect(ctl(c) + cRect, item.box)
			cpu.write32(item.at, c)
		8, 16:
			cpu.write32(item.at, handleOfText(item.data))
			if item.kind == 16 and cpu.read32(d + dTextH) == 0:
				te = item.box.teNew(item.box)
				teSetText(te, item.data)
				teSetSelect(te, 0, item.data.len)
				cpu.write32(d + dTextH, te)
				setWord(d + dEditField, n - 1)
		32: cpu.write32(
			item.at,
			getResource(0x4943_4F4E, i16.wrap(i64(item.data.u16be(0))), [], false)
		)
		64: cpu.write32(
			item.at,
			getResource(0x5049_4354, i16.wrap(i64(item.data.u16be(0))), [], false)
		)
		_: pass

# NewDialog: the window made hidden, its items' controls, texts and icons made, then shown
pub fn newDialog(
	storage u32,
	bounds Rect,
	title u8[],
	isShown bool,
	procId i64,
	behind u32,
	hasGoAway bool,
	refCon u32,
	items u32
) u32:
	d = storage if storage != 0 else newPtr(theZone(), u32(dialogSize))
	newWindow(d, bounds, title, false, procId, behind, hasGoAway, refCon)
	setWord(d + wKind, dialogKind)
	cpu.write32(d + dItems, items)
	cpu.write32(d + dTextH, 0)
	setWord(d + dEditField, -1)
	setWord(d + 166, 0)
	setWord(d + dDefItem, 1)
	setPort(d)
	setWord(d + portTxFont, word(dlgFontAt))
	for n, item in itemsOf(d):
		makeItem(d, n + 1, item)
	if isShown: showWindow(d)
	d

# GetNewDialog: a dialog from its DLOG (bounds, procID, visible, goAway, refCon, the item list's
# DITL and the title), the item list a copy of its own
pub fn getNewDialog(id i64, storage u32, behind u32) u32:
	h = getResource(0x444C_4F47, id, [], false)
	if h == 0: return 0
	p = address(cpu.read32(h))
	ditl = getResource(0x4449_544C, word(p + 18), [], false)
	if ditl == 0: return 0
	items = newHandle(theZone(), handleSize(ditl))
	moveBytes(address(cpu.read32(items)), address(cpu.read32(ditl)), handleSize(ditl))
	p2 = address(cpu.read32(h))
	newDialog(
		storage,
		readRect(p2),
		pascalAt(p2 + 20),
		cpu.read8(p2 + 10) != 0,
		word(p2 + 8),
		behind,
		cpu.read8(p2 + 12) != 0,
		cpu.read32(p2 + 14),
		items
	)

pub fn plotIcon(port u32, r Rect, icon u32):
	if icon == 0: return
	p = address(cpu.read32(icon))
	c = canvasOf(port)
	clip = clipOf(port)
	for y in 0..32:
		row = cpu.read32(p + u32(4 * y))
		for x in 0..32:
			px = r.left + x * (r.right - r.left) / 32
			py = r.top + y * (r.bottom - r.top) / 32
			if clip.containsPoint(px, py): c.transfer(px, py, row >> (31 - x) & 1 != 0, 0)

# DrawDialog: every item drawn: its control, its text, the frame of the editable text, its icon;
# a user item's procedure called
pub fn drawDialog(d u32):
	saved = thePort()
	setPort(d)
	for n, item in itemsOf(d):
		match item.kind:
			8: textBox(d, substituted(dialogItemText(item)), item.box, 0)
			16:
				te = cpu.read32(d + dTextH)
				r = item.box
				drawShapeFrame(
					d,
					Rect(
						top = r.top - 3,
						left = r.left - 3,
						bottom = r.bottom + 3,
						right = r.right + 3
					)
				)
				if te != 0 and word(d + dEditField) == n:
					teUpdate(te)
				else:
					textBox(d, dialogItemText(item), r, 0)
			32: plotIcon(d, item.box, cpu.read32(item.at))
			0:
				procedure = cpu.read32(item.at)
				if procedure != 0: callPascal(procedure, [(d, 4), (u32(n + 1), 2)], 0)
			_: pass
	drawControls(d)
	setPort(saved)

fn drawShapeFrame(port u32, r Rect):
	outer = r.rectToArea()
	inner = rectArea(r.top + 1, r.left + 1, r.bottom - 1, r.right - 1)
	paintArea(port, outer.combine(inner, 2), blackPattern(), patCopy)

# the enabled item at a local point (1 the first), 0 for none
pub fn itemAt(d u32, v i64, h i64) i64:
	for n, item in itemsOf(d):
		b = item.box
		if v >= b.top and v < b.bottom and h >= b.left and h < b.right and item.isEnabled:
			return n + 1
	0

pub fn disposeDialog(d u32, isStorageOurs bool):
	te = cpu.read32(d + dTextH)
	if te != 0: teDispose(te)
	killControls(d)
	disposeWindow(d, isStorageOurs)
