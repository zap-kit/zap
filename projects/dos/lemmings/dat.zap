# The compressed .DAT container of DOS Lemmings (level, graphics, main and special files): sections
# one after another, each a 10-byte header and its compressed bytes, decoded as ccexplore's document
# describes it (camanis.net, "How to Decompress and Compress .DAT Files Used in PC Lemmings").

# a section's bytes once decompressed
pub type Section:
	bytes u8[]

# one word of a header, big-endian
fn headerWord(file u8[], at i64):
	i64(file[at]) << 8 | file[at + 1]

# every section of a .DAT file, decompressed
pub fn sectionsOf(file u8[]) Section[]:
	out = []
	at = 0
	while at + 10 <= file.len:
		firstBits = i64(file[at])
		size = headerWord(file, at + 4)
		packed = headerWord(file, at + 8)
		if packed < 10 or at + packed > file.len:
			fail("a .DAT section at {at} claims {packed} bytes of {file.len}")
		out.push(Section(bytes = unpack(file[at + 10..at + packed], firstBits, size)))
		at += packed
	out

# the bits of a section's compressed bytes, pulled from its last byte towards its first, each
# byte's low bit first; the last byte gives only `firstBits` bits
type BitSource:
	bytes u8[]
	at i64
	held i64
	left i64

	fn bit():
		if left == 0:
			if at == 0: fail("a .DAT section ran out of bits")
			at -= 1
			held = bytes[at]
			left = 8
		b = held & 1
		held >>= 1
		left -= 1
		b

	# n bits, the first pulled the most significant
	mut fn bits(n i64):
		v = 0
		loop n:
			v = v << 1 | self.bit()
		v

# `size` bytes decoded backwards from the stream: raw runs and references to bytes decoded before
fn unpack(packed u8[], firstBits i64, size i64):
	out u8[] = zeros(size)
	src = BitSource(bytes = packed.copy(), at = packed.len - 1, held = 0, left = 0)
	if not packed.isEmpty:
		src.held = packed[len - 1]
		src.left = firstBits
	pos = size
	while pos > 0:
		if src.bit() == 0:
			if src.bit() == 0:
				pos = out.rawRun(src, pos, src.bits(3) + 1)
			else:
				pos = out.reference(src, pos, 2, src.bits(8) + 1)
		elif src.bit() == 0:
			if src.bit() == 0:
				pos = out.reference(src, pos, 3, src.bits(9) + 1)
			else:
				pos = out.reference(src, pos, 4, src.bits(10) + 1)
		elif src.bit() == 0:
			n = src.bits(8) + 1
			pos = out.reference(src, pos, n, src.bits(12) + 1)
		else:
			pos = out.rawRun(src, pos, src.bits(8) + 9)
	out

# n raw bytes, the first read the last in the output
fn rawRun(mut out u8[], mut src BitSource, pos i64, n i64):
	p = pos
	loop n:
		if p == 0: fail("a .DAT section decodes past its start")
		p -= 1
		out[p] = u8(src.bits(8))
	p

# n bytes copied from the block ending `offset` bytes after the current position
fn reference(mut out u8[], src BitSource, pos i64, n i64, offset i64):
	p = pos
	loop n:
		if p == 0: fail("a .DAT section decodes past its start")
		p -= 1
		if p + offset >= out.len: fail("a .DAT reference points past the end")
		out[p] = out[p + offset]
	p

# the stream of bits of a test, written as the document writes them, packed as a file holds them:
# the bits fill bytes from the last backwards, each byte low bit first
fn packedOf(stream str):
	digits = []
	for c in stream.bytes():
		if c == '0' or c == '1':
			digits.push(c - '0')
	count = (digits.len + 7) / 8
	first = digits.len - (count - 1) * 8
	bytes u8[] = zeros(count)
	for i, d in digits:
		byteAt = count - 1 if i < first else count - 2 - (i - first) / 8
		bitAt = i if i < first else (i - first) % 8
		bytes[byteAt] |= u8(i64(d) << bitAt)
	(bytes, first)

test "the document's raw, two-byte, three-byte and long examples":
	packed, first = packedOf("00 100 11111111 10101010 00001111 11110000 00000000")
	expect unpack(packed, first, 5) == [0x00, 0xF0, 0x0F, 0xAA, 0xFF]
	packed2, first2 = packedOf("111 00000000 00000001 00000010 00000011 00000100 00000101 00000110 00000111 00001000 00001001 101 0000000111 01 00000001 00 001 00000001 11111111 110 00000110 000000000010 100 000001110")
	expect unpack(packed2, first2, 27) == [
		0x04, 0x03, 0x02, 0x05, 0xFF, 0x01, 0x05, 0xFF, 0x01, 0x05, 0xFF, 0x01, 0x05, 0x04, 0x05,
		0x04, 0x03, 0x02, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01
	]

# where the DOS game is installed (the player's own copy, never committed)
pub defaultInstall = "C:/Games/Lemmings"
