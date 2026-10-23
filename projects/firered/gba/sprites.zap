# The sprites of a line, and the line composed: the windows, the two top layers and their blend.

# the sprites' sizes by shape (square, wide, tall) and size: width then height
spriteWidths = [8, 16, 32, 64, 16, 32, 32, 64, 8, 8, 16, 32]
spriteHeights = [8, 16, 32, 64, 8, 8, 16, 32, 16, 32, 32, 64]

fn drawSprites(y i64, control u32):
	for x in 0..screenWidth:
		objColor[x] = transparent
		objPriority[x] = 4
		objSemi[x] = false
		objWindow[x] = false
	if control & 0x1000 == 0: return
	oneDimension = control & 0x40 != 0
	bitmapMode = control & 7 >= 3
	for n in 0..128:
		a0 = i64(oam.u16le(n * 8))
		affineMode = (a0 >> 8) & 3
		if affineMode == 2: continue
		a1 = i64(oam.u16le(n * 8 + 2))
		a2 = i64(oam.u16le(n * 8 + 4))
		shape = (a0 >> 14) & 3
		if shape == 3: continue
		w = spriteWidths[shape * 4 + ((a1 >> 14) & 3)]
		h = spriteHeights[shape * 4 + ((a1 >> 14) & 3)]
		double = affineMode == 3
		boxW = w * 2 if double else w
		boxH = h * 2 if double else h
		top = a0 & 0xFF
		if top + boxH > 256: top -= 256
		if y < top or y >= top + boxH: continue
		left = a1 & 0x1FF
		if left >= 240: left -= 512
		tile = a2 & 0x3FF
		if bitmapMode and tile < 512: continue
		priority = (a2 >> 10) & 3
		kind = (a0 >> 10) & 3
		colors256 = a0 & 0x2000 != 0
		pal = (a2 >> 12) * 16 + 256
		pa = 256
		pb = 0
		pc = 0
		pd = 256
		if affineMode & 1 == 1:
			p = ((a1 >> 9) & 31) * 32
			pa = i16.wrap(oam.u16le(p + 6))
			pb = i16.wrap(oam.u16le(p + 14))
			pc = i16.wrap(oam.u16le(p + 22))
			pd = i16.wrap(oam.u16le(p + 30))
		rowStride = (w >> 3) * (2 if colors256 else 1) if oneDimension else 32
		dy = y - top - boxH / 2
		for bx in 0..boxW:
			x = left + bx
			if x < 0 or x >= screenWidth: continue
			dx = bx - boxW / 2
			tx = (pa * dx + pb * dy) >> 8
			ty = (pc * dx + pd * dy) >> 8
			tx += w / 2
			ty += h / 2
			if affineMode == 0:
				tx = bx
				ty = y - top
				if a1 & 0x1000 != 0: tx = w - 1 - tx
				if a1 & 0x2000 != 0: ty = h - 1 - ty
			if tx < 0 or ty < 0 or tx >= w or ty >= h: continue
			index = spriteTexel(tile, tx, ty, colors256, rowStride, pal)
			if index < 0: continue
			if kind == 2:
				objWindow[x] = true
				continue
			if objColor[x] == transparent or priority < objPriority[x]:
				objColor[x] = color(index)
				objPriority[x] = priority
				objSemi[x] = kind == 1

# the palette index of a sprite's texel, -1 where it is transparent
fn spriteTexel(tile i64, tx i64, ty i64, colors256 bool, rowStride i64, pal i64):
	if colors256:
		t = (tile & ~1) + (ty >> 3) * rowStride + (tx >> 3) * 2
		b = i64(vram[0x1_0000 + ((t * 32 + (ty & 7) * 8 + (tx & 7)) & 0x7FFF)])
		return -1 if b == 0 else 256 + b
	t = tile + (ty >> 3) * rowStride + (tx >> 3)
	b = i64(vram[0x1_0000 + ((t * 32 + (ty & 7) * 4 + ((tx & 7) >> 1)) & 0x7FFF)])
	nibble = (b >> 4) if tx & 1 == 1 else b & 15
	-1 if nibble == 0 else pal + nibble

fn isInside(v i64, range u32):
	low = i64(range >> 8)
	high = i64(range & 0xFF)
	if low <= high: return v >= low and v < high
	v >= low or v < high

# the layers (bits 0 to 3 the backgrounds, 4 the sprites, 5 the effects) shown at x
fn windowMask(x i64, y i64, control u32) u32:
	if control & 0xE000 == 0: return 0x3F
	if control & 0x2000 != 0 and isInside(x, ioHalf(0x40)) and isInside(y, ioHalf(0x44)):
		return ioHalf(0x48) & 0x3F
	if control & 0x4000 != 0 and isInside(x, ioHalf(0x42)) and isInside(y, ioHalf(0x46)):
		return (ioHalf(0x48) >> 8) & 0x3F
	if control & 0x8000 != 0 and objWindow[x]: return (ioHalf(0x4A) >> 8) & 0x3F
	ioHalf(0x4A) & 0x3F

fn blendAlpha(a u32, b u32, eva u32, evb u32):
	out u32 = 0
	for shift in [0, 5, 10]:
		v = (((a >> shift) & 31) * eva + ((b >> shift) & 31) * evb) >> 4
		out |= v.min(31) << shift
	out

fn brighten(a u32, evy u32):
	out u32 = 0
	for shift in [0, 5, 10]:
		c = (a >> shift) & 31
		out |= (c + (((31 - c) * evy) >> 4)) << shift
	out

fn darken(a u32, evy u32):
	out u32 = 0
	for shift in [0, 5, 10]:
		c = (a >> shift) & 31
		out |= (c - ((c * evy) >> 4)) << shift
	out

# the line's pixels: at each, the top two layers the window shows (a sprite before a background
# of its priority, a background before those numbered after it, the backdrop last), blended as
# BLDCNT says
fn compose(y i64, control u32):
	bldcnt = ioHalf(0x50)
	effect = (bldcnt >> 6) & 3
	alpha = ioHalf(0x52)
	eva = (alpha & 31).min(16)
	evb = ((alpha >> 8) & 31).min(16)
	evy = (ioHalf(0x54) & 31).min(16)
	backdrop = color(0)
	priorities = (0..4).map(i64(ioHalf(0x08 + 2 * it) & 3))
	row = y * screenWidth
	for x in 0..screenWidth:
		mask = windowMask(x, y, control)
		first = backdrop
		firstLayer = 5
		second = backdrop
		secondLayer = 5
		found = 0
		for p in 0..4:
			if found == 2: break
			if mask & 0x10 != 0 and objColor[x] != transparent and objPriority[x] == p:
				if found == 0:
					first = objColor[x]
					firstLayer = 4
				else:
					second = objColor[x]
					secondLayer = 4
				found += 1
			for bg in 0..4:
				if found == 2: break
				if priorities[bg] != p or mask & (u32(1) << u32(bg)) == 0: continue
				c = layers[bg, x]
				if c == transparent: continue
				if found == 0:
					first = c
					firstLayer = bg
				else:
					second = c
					secondLayer = bg
				found += 1
		if found == 1:
			second = backdrop
			secondLayer = 5
		out = first
		firstTarget = bldcnt & (u32(1) << u32(firstLayer)) != 0
		secondTarget = bldcnt & (u32(0x100) << u32(secondLayer)) != 0
		if firstLayer == 4 and objSemi[x] and secondTarget:
			out = blendAlpha(first, second, eva, evb)
		elif mask & 0x20 != 0 and firstTarget:
			match effect:
				1: out = blendAlpha(first, second, eva, evb) if secondTarget else first
				2: out = brighten(first, evy)
				3: out = darken(first, evy)
				_: pass
		screen[row + x] = u16(out)
