# The PPU as a program drives it: VRAM, CGRAM and OAM filled through their ports (and by DMA),
# then the frame run and the picture's pixels read back.

import recomp.snes.console

red = 0x001F
green = 0x03E0
blue = 0x7C00

fn poke(addr u32, v u8):
	console.write8(addr, v)

# a register written twice, low byte then high (the scrolls, CGRAM's data)
fn twice(addr u32, v i64):
	poke(addr, v & 0xFF)
	poke(addr, u8(v >> 8))

# a word into two registers side by side
fn pokeWord(addr u32, v i64):
	poke(addr, v & 0xFF)
	poke(addr + 1, u8(v >> 8))

# words into VRAM from `at`, the address stepping after the high byte by 1 (2115 = 0x80) or 32
fn setVram(at i64, words i64[], stepBy32 bool = false):
	poke(0x2115, 0x81 if stepBy32 else 0x80)
	poke(0x2116, at & 0xFF)
	poke(0x2117, u8(at >> 8))
	for w in words:
		poke(0x2118, w & 0xFF)
		poke(0x2119, u8(w >> 8))

fn setColor(index i64, c i64):
	poke(0x2121, u8(index))
	twice(0x2122, c)

fn pixel(x i64, y i64):
	console.pixelAt(x, y)

fn frame():
	console.runFrame(l: pass)

# A 4-bit tile, its 8 rows alike: colour 3 on the left half, 1 on the right.
fn halfTile():
	words = fill(16, 0)
	for row in 0..8:
		words[row] = 0xF0FF
	words

# Mode 1, BG1's tilemap at word 0x1000 (32x32), its characters at 0, tile 1 the half tile, the
# backdrop blue, palette 2's colours 1 red and 3 green; the screen on, BG1 on the main screen.
fn setUpBackground(entry i64):
	console.powerOn()
	poke(0x2105, 0x01)
	poke(0x2107, 0x10)
	poke(0x210B, 0x00)
	setVram(16, halfTile())
	setVram(0x1000, [entry])
	setColor(0, blue)
	setColor(33, red)
	setColor(35, green)
	poke(0x212C, 0x01)

test "a background tile, scrolled, over the backdrop":
	setUpBackground(0x0801)
	twice(0x210E, 0x3FF)   # one line up: the tilemap's row 0 on the picture's row 0
	poke(0x2100, 0x0F)
	frame()
	print("{pixel(0, 0):06X} {pixel(5, 7):06X} {pixel(8, 0):06X} {pixel(0, 8):06X}")
	twice(0x210D, 0x3FC)   # the background four pixels right
	frame()
	print("{pixel(0, 0):06X} {pixel(4, 0):06X} {pixel(8, 0):06X}")
	prints """
		00FF00 FF0000 0000FF 0000FF
		0000FF 00FF00 FF0000
		"""

test "a flipped tile, brightness, forced blank":
	setUpBackground(0x4801)
	twice(0x210E, 0x3FF)
	poke(0x2100, 0x07)
	frame()
	print("{pixel(0, 0):06X} {pixel(7, 0):06X}")
	poke(0x2100, 0x8F)
	frame()
	print("{pixel(7, 0):06X}")
	prints """
		730000 007300
		000000
		"""

# OAM's 544 bytes through 2104: every sprite below the picture but sprite 0
fn setSprites(x i64, y i64, tile i64, flags i64, high u8):
	pokeWord(0x2102, 0)
	for n in 0..128:
		for b in [x, y, tile, flags] if n == 0 else [0, 240, 0, 0]:
			poke(0x2104, u8(b))
	for n in 0..32:
		poke(0x2104, high if n == 0 else 0)

test "a sprite over the background, its size, its flip, its edge":
	setUpBackground(0x0801)
	setVram(0x20, halfTile())          # sprite tile 2 (OBSEL's base 0)
	setColor(128 + 16 + 1, blue | red)
	setColor(128 + 16 + 3, red | green)
	setSprites(4, 2, 2, 0x32, 0)       # palette 1, priority 3, small (8x8)
	poke(0x212C, 0x11)
	poke(0x2100, 0x0F)
	frame()
	print("{pixel(4, 2):06X} {pixel(8, 9):06X} {pixel(4, 10):06X} {pixel(3, 2):06X}")
	setSprites(252, 2, 2, 0x72, 0x01)  # x -4, flipped: its right half (colour 3) on the left edge
	frame()
	print("{pixel(0, 2):06X} {pixel(3, 2):06X} {pixel(4, 2):06X}")
	setSprites(0, 2, 2, 0x32, 0x02)    # large (16x16): tiles 2, 3, 18, 19, only 2 drawn
	frame()
	print("{pixel(0, 9):06X} {pixel(8, 2):06X}")
	prints """
		FFFF00 FF00FF 0000FF 00FF00
		FFFF00 FFFF00 FF0000
		FFFF00 0000FF
		"""

test "HDMA changes the scroll at a line":
	setUpBackground(0x0801)
	setVram(0x1000, fill(32, 0x0801), stepBy32 = true)   # the tile down the first column
	# the table in WRAM: 50 lines at 0, then one line of -8 held to the end
	table i64[] = [50, 0, 0, 1, 0xF8, 0x03, 0]
	for i, b in table:
		poke(0x7E_2000 + u32(i), u8(b))
	poke(0x4300, 0x02)                 # direct, two bytes to one register
	poke(0x4301, 0x0D)                 # BG1HOFS
	pokeWord(0x4302, 0x2000)
	poke(0x4304, 0x7E)
	poke(0x420C, 0x01)
	poke(0x2100, 0x0F)
	frame()   # the frame HDMA started on blank lines
	frame()
	print("{pixel(0, 10):06X} {pixel(8, 10):06X} {pixel(0, 49):06X}")
	print("{pixel(0, 50):06X} {pixel(8, 50):06X} {pixel(8, 223):06X}")
	prints """
		00FF00 0000FF 00FF00
		0000FF 00FF00 00FF00
		"""

test "a mid-frame write splits the line at its dot":
	setUpBackground(0x0801)
	setVram(0x1000, fill(1024, 0x0801))
	poke(0x2100, 0x0F)
	console.runFrame(l:
		if l == 100:
			console.cycles += 4 * (22 + 128)   # past dot 150: x 128 and on
			twice(0x210D, 0x3FC)
	)
	print("{pixel(120, 99):06X} {pixel(200, 99):06X} {pixel(200, 98):06X} {pixel(0, 100):06X}")
	prints "00FF00 FF0000 00FF00 FF0000"

test "colour math: the sub screen added and halved, the fixed colour subtracted, a window":
	setUpBackground(0x0801)
	poke(0x2108, 0x14)                 # BG2's tilemap at 0x1400, the same characters
	setVram(0x1400, [0x0C01])          # palette 3
	setColor(49, blue & 0x4210)        # half blue
	setColor(51, blue & 0x4210)
	poke(0x212C, 0x01)
	poke(0x212D, 0x02)
	poke(0x2130, 0x02)                 # add the sub screen
	poke(0x2131, 0x41)                 # on BG1, halved
	twice(0x210E, 0x3FF)
	twice(0x2110, 0x3FF)
	poke(0x2100, 0x0F)
	frame()
	print("{pixel(0, 0):06X} {pixel(5, 0):06X} {pixel(8, 0):06X}")
	poke(0x2130, 0x00)                 # the fixed colour
	poke(0x2132, 0x2F)                 # red 15
	poke(0x2131, 0x81)                 # subtracted from BG1
	frame()
	print("{pixel(5, 0):06X} {pixel(0, 0):06X}")
	poke(0x2131, 0x00)
	poke(0x2126, 2)
	poke(0x2127, 5)
	poke(0x2123, 0x02)                 # window 1 on BG1
	poke(0x212E, 0x01)                 # masking the main screen
	frame()
	print("{pixel(1, 0):06X} {pixel(2, 0):06X} {pixel(5, 0):06X} {pixel(6, 0):06X}")
	prints """
		007B42 7B0042 0000FF
		840000 00FF00
		00FF00 0000FF 0000FF FF0000
		"""
