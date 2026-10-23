# Deflate inside zlib (RFC 1950 and 1951), both ways: reading a stream and writing one, with LZ77 matches found through a hash of three
# bytes and coded with deflate's fixed Huffman codes, in one block: not the smallest a
# compressor can reach (no dynamic codes), but a few lines and fast.

# ---------- writing ----------

windowSize = 32_768
hashSize = 65_536
longestMatch = 258
chainLimit = 24   # candidates tried per position: longer searches gain little

type BitWriter:
	out u8[]
	bits i64   # waiting to be written, the first in the lowest bit
	count i64

# `count` bits of v, the lowest first (deflate's extra bits and header fields)
fn putBits(mut w BitWriter, v i64, count i64):
	w.bits |= v << w.count
	w.count += count
	while w.count >= 8:
		w.out.push(w.bits & 255)
		w.bits >>= 8
		w.count -= 8

# a Huffman code of `length` bits, its highest bit first
fn putCode(mut w BitWriter, code i64, length i64):
	reversed = 0
	for i in 0..length:
		reversed |= (code >> i & 1) << (length - 1 - i)
	w.putBits(reversed, length)

# the fixed code of a literal byte or a length symbol (0..287)
fn putSymbol(mut w BitWriter, s i64):
	if s < 144:
		w.putCode(0x30 + s, 8)
	elif s < 256:
		w.putCode(0x190 + s - 144, 9)
	elif s < 280:
		w.putCode(s - 256, 7)
	else:
		w.putCode(0xC0 + s - 280, 8)

# the code (0..) of a value in a table of bases: the last base not above it
fn codeOf(bases i64[], v i64):
	k = 0
	while k + 1 < bases.len and bases[k + 1] <= v:
		k += 1
	k

fn putMatch(mut w BitWriter, length i64, distance i64):
	lc = codeOf(lengthBase, length)
	w.putSymbol(257 + lc)
	w.putBits(length - lengthBase[lc], lengthExtra[lc])
	dc = codeOf(distBase, distance)
	w.putCode(dc, 5)
	w.putBits(distance - distBase[dc], distExtra[dc])

fn hash3(d u8[], at i64):
	(i64(d[at]) << 10 ^ i64(d[at + 1]) << 5 ^ d[at + 2]) & (hashSize - 1)

# The bytes as a zlib stream: a deflate block of literals and matches, then the Adler-32 sum.
pub fn deflateZlib(d u8[]) u8[]:
	w = BitWriter(out = [120, 1], bits = 0, count = 0)
	w.putBits(1, 1)   # the last block
	w.putBits(1, 2)   # with the fixed codes
	head i64[] = fill(hashSize, -1)   # the latest position of each hash
	previous i64[] = fill(windowSize, -1)   # the one before it, by position in the window
	n = d.len
	at = 0
	while at < n:
		bestLength = 0
		bestDistance = 0
		if at + 2 < n:
			h = hash3(d, at)
			candidate = head[h]
			tries = 0
			while candidate >= 0 and at - candidate <= windowSize and tries < chainLimit:
				limit = longestMatch.min(n - at)
				length = 0
				while length < limit and d[candidate + length] == d[at + length]:
					length += 1
				if length > bestLength:
					bestLength = length
					bestDistance = at - candidate
				candidate = previous[candidate % windowSize]
				tries += 1
		step = bestLength if bestLength >= 3 else 1
		if bestLength >= 3:
			w.putMatch(bestLength, bestDistance)
		else:
			w.putSymbol(d[at])
		# every position passed goes into the hash chains
		for k in at..at + step:
			if k + 2 < n:
				h = hash3(d, k)
				previous[k % windowSize] = head[h]
				head[h] = k
		at += step
	w.putSymbol(256)   # the end of the block
	if w.count > 0:
		w.putBits(0, 8 - w.count)   # the last byte filled
	w.out.pushU32be(adler32(d))
	w.out

# ---------- reading ----------

# The reading never stops the program (`use noStops`): a damaged or hostile stream fails with a
# reason, each index checked against its list's length where the decoding does not prove it. The
# bits come through a BitReader, whose `short` also notes a stream found damaged.

# A canonical Huffman code: how many codes of each length and the symbols in code order, and a
# table of the codes of up to fastBits bits read at once: by the next fastBits bits of the stream,
# the symbol << 4 | its length, 0 for a longer code (read a bit at a time).
type Huffman:
	counts u32[]
	symbols i64[]
	fast i64[]

fastBits = 10

lengthBase = [
	3,
	4,
	5,
	6,
	7,
	8,
	9,
	10,
	11,
	13,
	15,
	17,
	19,
	23,
	27,
	31,
	35,
	43,
	51,
	59,
	67,
	83,
	99,
	115,
	131,
	163,
	195,
	227,
	258
]
lengthExtra = [
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	3,
	3,
	3,
	3,
	4,
	4,
	4,
	4,
	5,
	5,
	5,
	5,
	0
]
distBase = [
	1,
	2,
	3,
	4,
	5,
	7,
	9,
	13,
	17,
	25,
	33,
	49,
	65,
	97,
	129,
	193,
	257,
	385,
	513,
	769,
	1025,
	1537,
	2049,
	3073,
	4097,
	6145,
	8193,
	12_289,
	16_385,
	24_577
]
distExtra = [
	0,
	0,
	0,
	0,
	1,
	1,
	2,
	2,
	3,
	3,
	4,
	4,
	5,
	5,
	6,
	6,
	7,
	7,
	8,
	8,
	9,
	9,
	10,
	10,
	11,
	11,
	12,
	12,
	13,
	13
]
codeOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

# the data of a zlib stream (a two-byte header, deflate blocks, a checksum not checked), of about
# `expected` bytes; the error says why it stopped short
pub fn inflateZlib(d u8[], expected i64 = 0) u8[] ? str:
	if d.len < 2 or (d[0] & 15) != 8: return "not a deflate stream"
	inflateFrom(d, 2, expected)

# the data of a gzip file's member (its header, deflate blocks, a checksum and a size not checked),
# of about `expected` bytes; the error says why it stopped short
pub fn inflateGzip(d u8[], expected i64 = 0) u8[] ? str:
	if d.len < 18 or d[0] != 0x1F or d[1] != 0x8B or d[2] != 8: return "not a gzip stream"
	flags = d[3]
	at = 10
	if (flags & 4) != 0:   # an extra field: its length, then its bytes
		at += 2 + (d[at] | i64(d[at + 1]) << 8)
	for bit in [8, 16]:   # a name, a comment: each ends with a zero byte
		if (flags & u8(bit)) != 0:
			while at < d.len and d[at] != 0:
				at += 1
			at += 1
	if (flags & 2) != 0:   # the header's checksum
		at += 2
	if at >= d.len: return "the gzip header is damaged"
	inflateFrom(d, n64(at), expected)

# the deflate blocks from byte `at`
fn inflateFrom(d u8[], at n64, expected i64) u8[] ? str:
	use noStops
	out u8[] = zeros(expected.clamp(1024, 1 << 30))
	n n64 = 0   # the bytes decoded, at the start of out
	b = BitReader(d, at)
	last = false
	lens = huffman(fixedLengths())
	dists = huffman(fill(30, 5))
	while not last and not b.short:
		last = b.take(1) == 1
		kind = b.take(2)
		if kind == 0:
			n = b.stored(out, n)
		elif kind == 1:
			n = b.codes(out, n, lens, dists)
		elif kind == 2:
			n = b.dynamic(out, n)
		else:
			b.short = true
	if b.short: return "the compressed data is damaged"
	out.truncate(n)
	out

# room in out for `more` bytes past n: grown (doubled at least) when there is not
fn room(mut out u8[], n n64, more i64):
	if n > out.len: return
	need = n + more.clamp(0, 1_073_741_824)
	if need > out.len: out.extend(zeros((need - out.len).max(out.len)))

# a stored block: its bytes copied as they are, from the byte after the bits read; the bytes
# decoded after it
fn stored(mut b BitReader, mut out u8[], n n64) n64:
	start = b.byteAligned()
	if b.d.len - start < 4:
		b.short = true
		return n
	size = b.d[start] | i64(b.d[start + 1]) << 8
	out.room(n, size)
	at n64 = n
	k n64 = start + 4
	loop size:
		if k >= b.d.len or at >= out.len:
			b.short = true
			return at
		out[at] = b.d[k]
		at += 1
		k += 1
	b.at = k
	at

# the code whose lengths are given, by symbol (0: no code); each length below 16
fn huffman(lengths i64[]):
	counts u32[] = zeros(16)
	for l in lengths:
		if l > 0 and l < counts.len: counts[l] += 1
	offsets u32[] = zeros(16)
	for l in 1..15:
		if l + 1 < offsets.len and l < counts.len:
			offsets[l + 1] = offsets[l] + counts[l]
	symbols = zeros(lengths.len)
	for s, l in lengths:
		if l > 0 and l < offsets.len:
			at = offsets[l]
			if at < symbols.len: symbols[at] = s
			offsets[l] = at + 1
	# the codes of fastBits bits or fewer in the table: each code (canonical: by length, then by
	# symbol) read lowest bit first, at every entry whose low bits are it
	fast = zeros(1 << fastBits)
	next u32[] = zeros(16)
	code = 0
	for l in 1..16:
		if l < counts.len and l < next.len:
			code = (code + counts[l - 1]) << 1
			next[l] = code
	for s, l in lengths:
		if l <= 0 or l >= next.len: continue
		c = next[l]
		next[l] = c + 1
		if l <= fastBits:
			reversed u32 = 0
			for i in 0..l:
				reversed = reversed << 1 | (c >> u32(i) & 1)
			k = reversed
			while k < fast.len:
				fast[k] = s << 4 | l
				k += 1 << u32(l)
	Huffman(counts, symbols, fast)

# the next symbol of code h: from the table, or for a longer code a bit at a time (codes are
# stored first bit highest); -1 when the bits name none
fn decodeSymbol(mut b BitReader, h Huffman):
	at = b.peek(fastBits)
	e = h.fast[at] if at < h.fast.len else 0
	if e > 0:
		b.skip(e & 15)
		return e >> 4
	code u32 = 0
	first u32 = 0
	index u32 = 0
	for length in 1..16:
		code |= u32(b.take(1))
		count u32 = h.counts[length] if length < h.counts.len else 0
		if code - first < count:
			k = index + (code - first)
			return h.symbols[k] if k < h.symbols.len else -1
		index += count
		first = (first + count) << 1
		code <<= 1
	b.short = true
	-1

fn fixedLengths():
	l = fill(144, 8)
	l.extend(fill(112, 9))
	l.extend(fill(24, 7))
	l.extend(fill(8, 8))
	l

# a block of dynamic codes: the code lengths of the code lengths, then the lengths of its
# literals and lengths and of its distances, coded with them; the bytes decoded after it
fn dynamic(mut b BitReader, mut out u8[], n n64) n64:
	nlen = b.take(5) + 257
	ndist = b.take(5) + 1
	ncode = b.take(4) + 4
	codeLengths = zeros(19)
	for i in 0..ncode.min(19):
		at = codeOrder[i]
		if at >= 0 and at < codeLengths.len: codeLengths[at] = b.take(3)
	lencode = huffman(codeLengths)
	total = nlen + ndist
	lengths = []
	while lengths.len < total and not b.short:
		sym = b.decodeSymbol(lencode)
		if sym < 16:
			lengths.push(sym)
			continue
		value = 0
		repeat = 0
		if sym == 16:
			if lengths.isEmpty:
				b.short = true
				return n
			value = lengths[len - 1]
			repeat = 3 + b.take(2)
		elif sym == 17:
			repeat = 3 + b.take(3)
		else:
			repeat = 11 + b.take(7)
		lengths.extend(fill(repeat, value))
	if b.short or lengths.len != total or nlen > lengths.len:
		b.short = true
		return n
	b.codes(out, n, huffman(lengths[..nlen]), huffman(lengths[nlen..]))

# the symbols of a block: literal bytes, and lengths with distances that copy what came before;
# the bytes decoded after it
fn codes(mut b BitReader, mut out u8[], n0 n64, lens Huffman, dists Huffman) n64:
	n n64 = n0
	while not b.short:
		sym = b.decodeSymbol(lens)
		if sym < 0:
			b.short = true
			return n
		if sym < 256:
			if n >= out.len:
				out.room(n, 1)
			if n < out.len:
				out[n] = sym & 255
				n += 1
			continue
		if sym <= 256: return n   # the end of the block
		li = sym - 257
		if li >= 29:
			b.short = true
			return n
		# (the tables' values clamped to what they hold, so the sums stay small)
		length = lengthBase[li].clamp(3, 258) + b.take(lengthExtra[li])
		di = b.decodeSymbol(dists)
		if di < 0 or di >= 30:
			b.short = true
			return n
		dist = distBase[di].clamp(1, 24_577) + b.take(distExtra[di])
		back = n - dist
		if back < 0:
			b.short = true
			return n
		out.room(n, length)
		at n64 = n
		from n64 = back
		loop length:
			if at >= out.len or from >= out.len:
				b.short = true
				return at
			out[at] = out[from]
			at += 1
			from += 1
		n = at
	n

# the Adler-32 checksum of the bytes: the sums reduced once every 5,552 bytes, the most before b
# could pass 2^32
fn adler32(d u8[]):
	a = 1
	b = 0
	at = 0
	while at < d.len:
		end = (at + 5552).min(d.len)
		for x in d[at..end]:
			a += x
			b += a
		a %= 65_521
		b %= 65_521
		at = end
	(b << 16) | a

test "deflated bytes inflate back the same, smaller when they repeat":
	d u8[] = []
	for i in 0..5000:
		d.push((i * i) % 7 + (i / 100) % 3)
	packed = deflateZlib(d)
	print("{(inflateZlib(packed) ?? []) == d} {packed.len < d.len / 4}")
	match inflateZlib([1, 2, 3].map(u8(it))):
		error: print(error)
		out: print(out)
	prints """
		true true
		not a deflate stream
		"""

test "a gzip member, its header's name skipped, inflates":
	packed u8[] = [
		31,
		139,
		8,
		8,
		0,
		0,
		0,
		0,
		2,
		255,
		97,
		46,
		116,
		120,
		116,
		0,
		171,
		74,
		44,
		80,
		168,
		130,
		96,
		29,
		133,
		146,
		212,
		188,
		226,
		252,
		162,
		98,
		133,
		252,
		60,
		133,
		146,
		140,
		84,
		5,
		247,
		128,
		80,
		174,
		42,
		10,
		229,
		1,
		92,
		152,
		30,
		255,
		96,
		0,
		0,
		0
	]
	text = str(inflateGzip(packed) ?? [])
	print("{text.len} {text.lines()[2]}")
	broken u8[] = [1, 2, 3]
	match inflateGzip(broken):
		bytes: print(bytes.len)
		error: print(error)
	prints """
		96 zap zap zap, tensors on the GPU
		not a gzip stream
		"""
