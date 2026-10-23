# The header of a NIF file of Gamebryo 20.2.0.7 as Bethesda writes it (Skyrim Special Edition: user
# version 12, BS version 100): the text line "Gamebryo File Format, Version 20.2.0.7\n", the version
# (u32), the endianness (u8, 1 little), the user version, the block count and the BS version (u32
# each), the export info (three or four strings of a length byte), the block type names (a u16
# count, u32-length strings), each block's type (u16 indices into those names), each block's size
# (u32), the string table (a u32 count, the u32 longest length, u32-length strings) and the groups
# (a u32 count, u32s). The blocks follow one after the other at their sizes, then the footer (the
# root blocks: a u32 count, references).

pub version20207 = 0x1402_0007

pub type Header:
	version i64
	userVersion i64
	bsVersion i64
	blockKinds i64[]   # each block's index into types
	types str[]
	sizes i64[]
	strings str[]   # the names blocks index
	start i64   # where the first block begins

# an export string: a length byte then the text, its NUL counted
fn skipExportString(mut s Reader):
	s.skip(s.u8())

fn readStrings(mut s Reader, count i64):
	out = []
	loop count:
		if s.short: break
		out.push(s.sized())
	out

# the header of the bytes held by s, the reader left at the first block
pub fn readHeader(mut s Reader) Header ? str:
	line = 0
	while line < s.d.len and s.d[line] != '\n':
		line += 1
	if not s.d.startsWith("Gamebryo File Format") or line >= s.d.len:
		return "not a NIF of Gamebryo (no header line)"
	s.at = line + 1
	version = s.u32()
	if version != version20207: return "NIF version 0x{version:08X} is not read (20.2.0.7 is)"
	if s.u8() != 1: return "a big-endian NIF is not read"
	userVersion = s.u32()
	blocks = s.u32()
	bsVersion = s.u32()
	loop (4 if bsVersion >= 103 else 3):
		s.skipExportString()
	types = s.readStrings(s.u16())
	if not s.has(blocks * 6): return "the block table is cut short"
	blockKinds = s.numbers(blocks, u16(0)).map(i64(it))
	sizes = s.numbers(blocks, u32(0)).map(i64(it))
	stringCount = s.u32()
	s.skip(4)   # the longest string's length
	strings = s.readStrings(stringCount)
	s.skip(s.u32() * 4)
	if s.short: return "the header is cut short"
	for k in blockKinds:
		if k >= types.len: return "a block of type {k} of {types.len}"
	Header(version, userVersion, bsVersion, blockKinds, types, sizes, strings, start = s.at)
