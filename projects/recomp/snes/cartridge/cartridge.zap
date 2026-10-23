# The cartridge's header and its map: where in the 24-bit address space the ROM's bytes are
# seen. LoROM (header at 7FC0: a bank's upper half a 32 KB page, banks 00-7D and 80-FF) or HiROM
# (header at FFC0: banks 40-7D and C0-FF the ROM whole, 00-3F and 80-BF its upper halves). Read
# once by the recompiler (snes) and by the console, both of which map addresses through it.

import fs

# The cartridge's bytes from a dump file, a copier's 512-byte header (a .smc's) dropped; none
# when the file cannot be read, error saying why.
pub fn readRom(path str) u8[] ? fs.Error:
	bytes = try fs.readBytes(path)
	bytes[(len % 0x400)..].copy()

pub type Header:
	title str
	hirom bool
	fast bool   # the ROM's upper banks are fast (3.58 MHz) when 420D asks
	sramBytes i64
	pal bool   # a European cartridge: the console it runs on draws 312 lines at 50 Hz
	chip str   # the coprocessor the cartridge carries (chipOf), "" none

# the header the ROM carries, at 7FC0 or FFC0: the one whose checksum and its complement agree,
# else the map byte's word
pub fn readHeader(rom u8[]) Header:
	hirom = looksHiRom(rom)
	base = 0xFFC0 if hirom else 0x7FC0
	title = rom[base..base + 21].map(it if it >= 32 and it < 127 else u8(32)).text().trimmed()
	kb = i64(rom[base + 0x18])
	Header(
		title = title.copy(),
		hirom = hirom,
		fast = rom[base + 0x15] & 0x10 != 0,
		sramBytes = 1024 << kb if kb > 0 and kb < 8 else 0,
		pal = isPalDestination(rom[base + 0x19]),
		chip = chipOf(rom, base)
	)

# The coprocessor named by the header's ROM type (FFD6) and, for the custom ones, its cartridge
# type (FFBF), as Mesen 2 reads them; the DSP's version and the ST01x's by the game's title.
fn chipOf(rom u8[], base i64):
	romType = i64(rom[base + 0x16])
	if romType & 0x0F < 3: return ""
	title = rom[base..base + 21].text().trimmed()
	match romType >> 4:
		0:
			if title == "DUNGEON MASTER": return "dsp2"
			if title == "PILOTWINGS": return "dsp1"
			if title.startsWith("SD") and title.endsWith("GX"): return "dsp3"
			if title == "PLANETS CHAMP TG3000" or title == "TOP GEAR 3000": return "dsp4"
			"dsp1b"
		1: "superfx"
		2: "obc1"
		3: "sa1"
		4: "sdd1"
		5: "rtc"
		0xF:
			match i64(rom[base - 1]):
				0x00: "spc7110"
				0x01: "st011" if title == "2DAN MORITA SHOUGI" else "st010"
				0x02: "st018"
				0x10: "cx4"
				_: ""
		_: ""

# the destination codes of PAL consoles (Europe, Australia...), as Mesen 2 reads them
fn isPalDestination(code i64):
	(code >= 0x02 and code <= 0x0C) or code == 0x11 or code == 0x12

fn checksumAgrees(rom u8[], base i64):
	if base + 0x20 > rom.len: return false
	complement = rom[base + 0x1C] | (i64(rom[base + 0x1D]) << 8)
	checksum = rom[base + 0x1E] | (i64(rom[base + 0x1F]) << 8)
	complement ^ checksum == 0xFFFF

fn looksHiRom(rom u8[]):
	lo = checksumAgrees(rom, 0x7FC0)
	hi = checksumAgrees(rom, 0xFFC0)
	if hi != lo: return hi
	rom.len > 0xFFD5 and rom[0xFFD5] & 1 != 0

# The map the loaded cartridge uses, set by whoever reads the ROM (hirom until then, as the
# first game was).
pub mut hirom = true

# the ROM's offset of an address (a mirror the same as what it mirrors)
pub fn romOffset(at i64) i64:
	if hirom: return ((at >> 16) & 0x3F) << 16 | (at & 0xFFFF)
	((at >> 16) & 0x7F) << 15 | (at & 0x7FFF)

# whether the address is where the ROM is seen (the work RAM's banks and the low halves of the
# system banks are not)
pub fn isRomAddress(at i64) bool:
	bank = (at >> 16) & 0xFF
	if bank == 0x7E or bank == 0x7F: return false
	if at & 0xFFFF >= 0x8000: return true
	hirom and bank & 0x40 != 0

# the address in the upper banks (80-FF) a lower one (00-7D) mirrors: one name for one place
pub fn canonical(at i64) i64:
	bank = at >> 16
	at | 0x80_0000 if bank < (0x40 if hirom else 0x7E) else at

# the SRAM's offset of an address, -1 where none is: HiROM 20-3F/A0-BF:6000-7FFF, LoROM
# 70-7D/F0-FF:0000-7FFF
pub fn sramOffset(at i64, sramBytes i64) i64:
	if sramBytes == 0: return -1
	bank = (at >> 16) & 0x7F
	off = at & 0xFFFF
	if hirom:
		if bank < 0x20 or bank >= 0x40 or off < 0x6000 or off >= 0x8000: return -1
		return (((bank & 0x0F) << 13) | (off - 0x6000)) % sramBytes
	if bank < 0x70 or bank > 0x7D or off >= 0x8000: return -1
	(((bank - 0x70) << 15) | off) % sramBytes
