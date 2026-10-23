# Mode 7: BG1 one 1024x1024 plane of 8-bit pixels (VRAM's low bytes a 128x128 tilemap, its high
# bytes the tiles' pixels), turned and scaled by the matrix (211B-211E, 8.8 fixed point) about a
# centre (211F-2120), scrolled by 210D-210E as they are written in mode 7 (13-bit signed, a value
# and the latch they share with the matrix), flipped as 211A says and, past the plane, wrapped,
# transparent or tile 0. A line's start is the hardware's sum of the products, each with its low
# six bits cut; its scroll is the one at its first pixel.

mut mode7Matrix i64[4] = [0, 0, 0, 0]   # A, B, C, D, signed
mut mode7Center i64[2] = [0, 0]          # X, Y as written (13 bits signed when used)
mut mode7Scroll i64[2] = [0, 0]          # horizontal, vertical
mut mode7LineScroll i64[2] = [0, 0]      # the scroll the line started with
mut mode7X = 0   # the plane's position at the segment's x 0, 8 fractional bits
mut mode7Y = 0

fn mode7PowerOn():
	mode7Matrix = [0, 0, 0, 0]
	mode7Center = [0, 0]
	mode7Scroll = [0, 0]
	mode7LineScroll = [0, 0]

fn mode7Fields(mut f StateFile):
	for k in 0..4:
		mode7Matrix[k] = f.int(mode7Matrix[k])
	for k in 0..2:
		mode7Center[k] = f.int(mode7Center[k])
		mode7Scroll[k] = f.int(mode7Scroll[k])
		mode7LineScroll[k] = f.int(mode7LineScroll[k])
	mode7X = f.int(mode7X)
	mode7Y = f.int(mode7Y)

# 211B-2120 written: the latch's byte below the value's
fn mode7MatrixWrite(r i64, v u8):
	word = (i64(v) << 8) | matrixLatch
	if r <= 0x1E:
		mode7Matrix[r - 0x1B] = i16.wrap(word)
	else:
		mode7Center[r - 0x1F] = word
	matrixLatch = v

# 210D-210E written: mode 7's scroll from the same latch
fn mode7ScrollWrite(r i64, v u8):
	mode7Scroll[r - 0x0D] = ((i64(v) << 8) | matrixLatch) & 0x1FFF
	matrixLatch = v

fn signed13(v i64):
	(v << 51) >> 51

fn clip10(v i64):
	v | ~0x3FF if v & 0x2000 != 0 else v & 0x3FF

# The plane's position at x 0 of the line, for the pixels drawn from x `from` on.
fn startMode7(from i64):
	if from == 0: mode7LineScroll = mode7Scroll.copy()
	h = signed13(mode7LineScroll[0])
	v = signed13(mode7LineScroll[1])
	cx = signed13(mode7Center[0])
	cy = signed13(mode7Center[1])
	y = 255 - line if ppuRegs[0x1A] & 2 != 0 else line
	if hasMode7Mosaic(): y -= mosaicSize() - mosaicCounter   # the block's first line
	a, b, c, d = mode7Matrix[0], mode7Matrix[1], mode7Matrix[2], mode7Matrix[3]
	mode7X = ((a * clip10(h - cx)) & ~63) + ((b * y) & ~63) + ((b * clip10(v - cy)) & ~63) +
		(cx << 8)
	mode7Y = ((c * clip10(h - cx)) & ~63) + ((d * y) & ~63) + ((d * clip10(v - cy)) & ~63) +
		(cy << 8)

# the mosaic over BG1 in mode 7: only a block wider than a pixel (Mesen 2's rule)
fn hasMode7Mosaic():
	hasMosaic(0) and mosaicSize() > 1

# BG1's pixel at x under the mosaic: the colour of its block's first pixel
fn mode7MosaicPixel(x i64):
	size = mosaicSize()
	if ((x % size) + size) % size == 0: mosaicHeld[0] = mode7Pixel(x)
	mosaicHeld[0]

# BG1's pixel at x: its colour, 0 transparent
fn mode7Pixel(x i64):
	at = 255 - x if ppuRegs[0x1A] & 1 != 0 else x
	px = (mode7X + mode7Matrix[0] * at) >> 8
	py = (mode7Y + mode7Matrix[2] * at) >> 8
	select = ppuRegs[0x1A]
	tile = 0
	if select & 0x80 != 0 and (px < 0 or px > 0x3FF or py < 0 or py > 0x3FF):
		if select & 0x40 == 0: return 0
	else:
		px &= 0x3FF
		py &= 0x3FF
		tile = vram[((py & ~7) << 4) | (px >> 3)] & 0xFF
	i64(vram[(tile << 6) + ((py & 7) << 3) + (px & 7)] >> 8)
