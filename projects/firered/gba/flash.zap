# The cartridge's save: 128 KB of flash in two banks of 64 KB (a Macronix MX29L010, as FireRed's
# cartridge has), read a byte at a time and written through the chip's commands: 0xAA at 0x5555
# and 0x55 at 0x2AAA, then the command at 0x5555 (the chip's identity, an erase, a byte
# written, a bank chosen).

pub mut flash u8[] = fill(0x2_0000, 0xFF)
pub mut flashChanged = false

mut unlockStep = 0   # 0, 1 after 0xAA, 2 after 0x55
mut showsId = false
mut erasing = false
mut writingByte = false
mut choosingBank = false
mut bank = 0

flashMaker u32 = 0xC2
flashDevice u32 = 0x09

pub fn flashRead(a u32) u32:
	off = i64(a & 0xFFFF)
	if showsId and off < 2: return flashMaker if off == 0 else flashDevice
	flash[bank * 0x1_0000 + off]

pub fn flashWrite(a u32, v u32):
	off = i64(a & 0xFFFF)
	if writingByte:
		flash[bank * 0x1_0000 + off] &= u8.wrap(v)
		writingByte = false
		flashChanged = true
		return
	if choosingBank and off == 0:
		bank = v & 1
		choosingBank = false
		return
	if off == 0x5555 and v == 0xAA:
		unlockStep = 1
		return
	if unlockStep == 1 and off == 0x2AAA and v == 0x55:
		unlockStep = 2
		return
	if unlockStep != 2:
		unlockStep = 0
		return
	unlockStep = 0
	if erasing and v == 0x30:
		start = bank * 0x1_0000 + (off & 0xF000)
		for i in start..start + 0x1000:
			flash[i] = 0xFF
		erasing = false
		flashChanged = true
		return
	if off != 0x5555: return
	match v:
		0x90: showsId = true
		0xF0: showsId = false
		0x80: erasing = true
		0x10:
			if erasing:
				for i in 0..flash.len:
					flash[i] = 0xFF
				erasing = false
				flashChanged = true
		0xA0: writingByte = true
		0xB0: choosingBank = true
		_: pass
