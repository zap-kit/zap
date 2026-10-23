# LZ4 (block and frame formats), read: a block is a run of sequences (a token whose high nibble
# is the literal count and low nibble the match length minus 4, each 15 followed by extra bytes
# that add up until one is not 255; the literals; a 2-byte little-endian offset), the last
# sequence only literals. A frame is the magic, a descriptor and blocks, each a size (its top
# bit set when stored as it is) and bytes, ended by a zero size. Checksums are not checked.

frameMagic = 0x184D_2204
storedBit = 0x8000_0000
flagBlockChecksum = 16
flagContentSize = 8
flagContentChecksum = 4
flagDictionary = 1

# a length continued by extra bytes from `at`: its new value and position, or -1 when cut short
fn extended(src u8[], at i64, end i64, base i64):
	n = base
	p = at
	while true:
		if p >= end: return (-1, p)
		b = i64(src[p])
		p += 1
		n += b
		if b != 255: break
	(n, p)

# the block src[start..end] decoded onto the end of out (a match may reach back into what out
# already holds, as linked blocks need), or why it is damaged
fn blockInto(mut out u8[], src u8[], start i64, end i64) ? str:
	at = start
	while at < end:
		token = i64(src[at])
		at += 1
		lit = token >> 4
		if lit == 15:
			lit, at = extended(src, at, end, 15)
			if lit < 0: return "lz4: a literal count is cut short"
		if at + lit > end: return "lz4: literals run past the block"
		for i in 0..lit:
			out.push(src[at + i])
		at += lit
		if at == end: break   # the last sequence has no match
		if at + 2 > end: return "lz4: a match offset is cut short"
		offset = src[at] | i64(src[at + 1]) << 8
		at += 2
		length = token & 15
		if length == 15:
			length, at = extended(src, at, end, 15)
			if length < 0: return "lz4: a match length is cut short"
		length += 4
		if offset == 0 or offset > out.len: return "lz4: a match reaches before the data"
		loop length:
			out.push(out[len - offset])

# The data of one LZ4 block, of `expected` bytes (0 when not known).
pub fn decodeBlock(src u8[], expected i64) u8[] ? str:
	out = []
	try blockInto(out, src, 0, src.len)
	if expected > 0 and out.len != expected:
		return "lz4: {out.len} bytes where {expected} were expected"
	out

# The data of an LZ4 frame (independent or linked blocks, checksums skipped), of about
# `expected` bytes (0 when not known; the frame's own content size is checked when it has one).
pub fn decodeFrame(src u8[], expected i64 = 0) u8[] ? str:
	if src.len < 7 or src.u32le(0) != frameMagic: return "lz4: not an LZ4 frame"
	flags = i64(src[4])
	if (flags >> 6) != 1: return "lz4: frame version {flags >> 6} is not read"
	at = 6   # past the flags and the block descriptor
	size = -1
	if (flags & flagContentSize) != 0:
		if src.len < at + 8: return "lz4: the frame descriptor is cut short"
		size = src.u32le(at) + (i64(src.u32le(at + 4)) << 32)
		at += 8
	if (flags & flagDictionary) != 0: at += 4
	at += 1   # the descriptor's checksum
	out = []
	while true:
		if at + 4 > src.len: return "lz4: the frame is cut short"
		word = i64(src.u32le(at))
		at += 4
		if word == 0: break
		stored = (word & storedBit) != 0
		n = word & (storedBit - 1)
		if at + n > src.len: return "lz4: a block is cut short"
		if stored:
			for i in 0..n:
				out.push(src[at + i])
		else:
			try blockInto(out, src, at, at + n)
		at += n
		if (flags & flagBlockChecksum) != 0: at += 4
	if (flags & flagContentChecksum) != 0 and at + 4 > src.len: return "lz4: the frame is cut short"
	if size >= 0 and out.len != size: return "lz4: the frame holds {out.len} bytes, not {size}"
	if expected > 0 and out.len != expected:
		return "lz4: {out.len} bytes where {expected} were expected"
	out

hashBits = 14
# a match must start this many bytes before the end, and leave the last 5 as literals
endGuard = 12
lastLiterals = 5

fn hashOf(word i64):
	((word * 2_654_435) >> 10) & ((1 << hashBits) - 1)

# a length past its nibble's 15 as the extra bytes: 255 each, then the rest
fn pushExtra(mut out u8[], rest i64):
	r = rest
	while r >= 255:
		out.push(255)
		r -= 255
	out.push(u8(r))

# one sequence: the literals src[from..to], then the match `length` long `offset` back (0 for none)
fn pushSequence(mut out u8[], src u8[], from i64, to i64, offset i64, length i64):
	lit = to - from
	token = lit.min(15) << 4
	if offset > 0: token |= (length - 4).min(15)
	out.push(u8(token))
	if lit >= 15: out.pushExtra(lit - 15)
	for k in from..to:
		out.push(src[k])
	if offset == 0: return
	out.push(offset & 255)
	out.push(u8(offset >> 8))
	if length - 4 >= 15: out.pushExtra(length - 4 - 15)

# The data as one LZ4 block (what decodeBlock reads): matches found by a hash of four bytes, the
# nearest earlier place of the same four within 64 KiB, the longest run from there.
pub fn encodeBlock(src u8[]) u8[]:
	out u8[] = []
	n = src.len
	table = (0..1 << hashBits).map(_: -1)
	anchor = 0
	at = 0
	while at < n - endGuard:
		word = i64(src.u32le(at))
		h = hashOf(word)
		found = table[h]
		table[h] = at
		if found < 0 or at - found > 65_535 or src.u32le(found) != word:
			at += 1
			continue
		length = 4
		room = n - lastLiterals - at
		while length < room and src[found + length] == src[at + length]:
			length += 1
		out.pushSequence(src, anchor, at, at - found, length)
		at += length
		anchor = at
	out.pushSequence(src, anchor, n, 0, 0)
	out

# the decoded text, or the error
fn shown(r u8[] ? str):
	match r:
		error: error
		out: out.cStringAt(0, out.len)

test "a block of literals only decodes as it is":
	block u8[] = [0x50, 104, 101, 108, 108, 111]
	expect shown(decodeBlock(block, 5)) == "hello"
	expect shown(decodeBlock(block, 0)) == "hello"

test "a block with a match copies from behind, overlapping itself":
	block u8[] = [0x35, 97, 98, 99, 3, 0, 0x10, 33]
	expect shown(decodeBlock(block, 13)) == "abcabcabcabc!"

test "a long literal run and a long match carry extra length bytes":
	block u8[] = [
		0xFF,
		2,
		97,
		98,
		99,
		100,
		101,
		102,
		103,
		104,
		105,
		106,
		107,
		108,
		109,
		110,
		111,
		112,
		113,
		1,
		0,
		1
	]
	out = decodeBlock(block, 0) ?? []
	expect out.len == 17 + 15 + 1 + 4
	expect out[len - 1] == 113

test "a damaged block is an error, not a crash":
	expect shown(decodeBlock([0x50, 1, 2], 0)).startsWith("lz4:")
	expect shown(decodeBlock([0x11, 1, 9, 0], 0)).startsWith("lz4:")
	expect shown(decodeBlock([0x50, 104, 101, 108, 108, 111], 7)).startsWith("lz4:")

test "a minimal frame, its descriptor and end mark read, decodes":
	frame u8[] = [
		4,
		0x22,
		0x4D,
		0x18,
		0x60,
		0x40,
		0x82,
		6,
		0,
		0,
		0,
		0x50,
		104,
		101,
		108,
		108,
		111,
		0,
		0,
		0,
		0
	]
	expect shown(decodeFrame(frame)) == "hello"
	expect shown(decodeFrame(frame, 5)) == "hello"
	expect shown(decodeFrame([1, 2, 3, 4, 5, 6, 7])).startsWith("lz4:")

test "a stored block and a content size in a frame":
	frame u8[] = [
		4,
		0x22,
		0x4D,
		0x18,
		0x68,
		0x40,
		3,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0x82,
		3,
		0,
		0,
		0x80,
		97,
		98,
		99,
		0,
		0,
		0,
		0
	]
	expect shown(decodeFrame(frame)) == "abc"

test "encoded data decodes back to itself, repeats packed":
	text = "the quick brown fox jumps over the lazy dog. ".repeat(40)
	src = text.toBytes()
	packed = encodeBlock(src)
	expect packed.len < src.len / 4
	expect (decodeBlock(packed, src.len) ?? []) == src

test "short, empty and incompressible data round trip":
	for text in ["", "a", "hello", "abcdefghijklmnopqrstuvwxyz0123456789"]:
		src = text.toBytes()
		expect (decodeBlock(encodeBlock(src), src.len) ?? []) == src
	noise u8[] = (0..5000).map(u8((it * 7919 + it / 3) & 255))
	expect (decodeBlock(encodeBlock(noise), noise.len) ?? []) == noise
