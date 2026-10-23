# The cartridge: the bytes of the user's own dump of Super Mario 64 (USA), read as the console
# reads them (big-endian). A dump may come in the console's order (.z64), with each pair of bytes
# swapped (.v64) or each word reversed (.n64): the first word tells which, and the bytes are put
# back in the console's order. Nothing is taken from the dump but what the program reads while
# it runs.

import fs

pub type Rom:
	bytes u8[]

# where the user's dump is read from (never committed)
pub romPath = "projects/mario/rom/sm64.us.z64"

# the first word of a cartridge in the console's order
z64Magic = 0x8037_1240

# the dump at path in the console's order, or why it cannot be read
pub fn loadRom(path str) Rom ? str:
	b = fs.readBytes(path) ?? return "cannot read {path}"
	if b.len < 0x1000: return "{path} is too small to be a cartridge"
	first = b.u32be(0)
	if first == 0x3780_4012:
		for i in 0..b.len / 2:
			t = b[2 * i]
			b[2 * i] = b[2 * i + 1]
			b[2 * i + 1] = t
	elif first == 0x4012_3780:
		for i in 0..b.len / 4:
			a0, a1, a2, a3 = b[4 * i], b[4 * i + 1], b[4 * i + 2], b[4 * i + 3]
			b[4 * i] = a3
			b[4 * i + 1] = a2
			b[4 * i + 2] = a1
			b[4 * i + 3] = a0
	elif first != z64Magic:
		return "{path} is not a Nintendo 64 cartridge"
	rom = Rom(bytes = b)
	if rom.romName().trimmed() != "SUPER MARIO 64" or rom.bytes[0x3E] != 'E':
		return "{path} is not Super Mario 64 (USA): it is '{rom.romName().trimmed()}'"
	rom

# The user's cartridge and Castle Grounds read from it, what every program here starts from; it
# stops, saying where the dump goes, when the dump cannot be read.
pub fn readCastleGrounds() (Rom, Level):
	rom = loadRom(romPath) ?? fail("{error} (the cartridge dump goes in {romPath})")
	lv = rom.readLevel(levelCastleGrounds)
	(rom, lv)

# the game's name in the header (padded with spaces)
pub fn romName(r Rom) str:
	r.bytes.cStringAt(0x20, 0x14)

# the bytes from `start` to `end` of the cartridge
pub fn romSlice(r Rom, start i64, end i64) ref u8[]:
	if start < 0 or end > r.bytes.len or end < start:
		fail("rom: bytes {start}..{end} are outside the cartridge")
	r.bytes[start..end]
