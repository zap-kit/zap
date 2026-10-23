# The GBA's hardware as the recompiled code meets it: the memory map, the BIOS's calls, the
# save's flash and a line of the picture.

import cpu
import gba

test "words, halfwords and bytes through the memory map":
	gba.store32(0x0200_0010, 0x1122_3344)
	gba.store8(0x0300_0001, 0xAB)
	print("{gba.load32(0x0200_0010):X} {gba.load32(0x0200_0011):X} {gba.load16(0x0200_0012):X}")
	print("{gba.load16(0x0200_0011):X} {gba.loadS8(0x0200_0013):X} {gba.load8(0x0300_0001):X}")
	print("{gba.load32(0x0204_0010):X} {gba.load8(0x0300_8001):X}")
	prints """
		11223344 44112233 1122
		44000033 11 AB
		11223344 AB
		"""

test "a byte into the palette fills its halfword; into the sprites' attributes, nothing":
	gba.store8(0x0500_0003, 0x1F)
	gba.store8(0x0700_0000, 0x55)
	print("{gba.load16(0x0500_0002):X} {gba.load16(0x0700_0000):X}")
	prints "1F1F 0"

test "the BIOS divides, takes roots and angles":
	cpu.r0 = u32(i32(-7))
	cpu.r1 = 2
	gba.swi(6)
	print("{i32(cpu.r0)} {i32(cpu.r1)} {cpu.r3}")
	cpu.r0 = 1_000_000
	gba.swi(8)
	print(cpu.r0)
	for (x, y) in [(0x4000, 0), (0, 0x4000), (-0x4000, 0), (0x4000, 0x4000)]:
		cpu.r0 = u32(i32(x))
		cpu.r1 = u32(i32(y))
		gba.swi(0x0A)
		print(cpu.r0)
	prints """
		-3 -1 3
		1000
		0
		16384
		32768
		8192
		"""

test "the BIOS unpacks LZ77 into work RAM":
	# 8 bytes: a literal 'A', then a copy of 7 from 1 back
	packed u8[] = [0x10, 8, 0, 0, 0x40, 0x41, 0x40, 0x00]
	for i, b in packed:
		gba.store8(0x0200_1000 + u32(i), b)
	cpu.r0 = 0x0200_1000
	cpu.r1 = 0x0200_2000
	gba.swi(0x11)
	expect (0..9).map(gba.load8(0x0200_2000 + u32(it))) == [65, 65, 65, 65, 65, 65, 65, 65, 0]

fn flashCommand(command u32):
	gba.flashWrite(0x0E00_5555, 0xAA)
	gba.flashWrite(0x0E00_2AAA, 0x55)
	gba.flashWrite(0x0E00_5555, command)

test "the flash tells its maker, writes a byte, erases a sector":
	flashCommand(0x90)
	print("{gba.flashRead(0x0E00_0000):X} {gba.flashRead(0x0E00_0001):X}")
	flashCommand(0xF0)
	flashCommand(0xA0)
	gba.flashWrite(0x0E00_1234, 0x5A)
	print("{gba.flashRead(0x0E00_1234):X}")
	flashCommand(0x80)
	gba.flashWrite(0x0E00_5555, 0xAA)
	gba.flashWrite(0x0E00_2AAA, 0x55)
	gba.flashWrite(0x0E00_1000, 0x30)
	print("{gba.flashRead(0x0E00_1234):X}")
	prints """
		C2 9
		5A
		FF
		"""

test "a text background's tile drawn on a line":
	gba.store16(0x0400_0000, 0x0100)   # mode 0, background 0
	gba.store16(0x0400_0008, 0x0100)   # its tiles at 0, its map at 0x800
	gba.store16(0x0500_0002, 0x001F)   # color 1: red
	gba.store16(0x0500_0000, 0x7C00)   # the backdrop: blue
	gba.store16(0x0600_0800, 1)   # the map's first entry: tile 1
	gba.store32(0x0600_0020, 0x0000_0011)   # tile 1's first row: two red pixels, then nothing
	gba.drawLine(0)
	expect (0..10).map("{gba.screen[it]:X}").join(" ") ==
		"1F 1F 7C00 7C00 7C00 7C00 7C00 7C00 7C00 7C00"
