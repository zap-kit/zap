# xWMA files (the RIFF form "XWMA" of XAudio2, Skyrim's music and voices) read and decoded as
# FFmpeg's libavformat/xwma.c and its WMA decoder read them (LGPL 2.1 or later, ffmpeg.org): the
# "fmt " chunk (a WAVEFORMATEX: tag 0x161 WMA version 2, 0x162 WMA Pro), the "dpds" chunk of the
# decoded bytes after each packet (16-bit samples, cumulative), and the "data" chunk of packets of
# blockAlign bytes. xWMA stores no codec flags: WMA version 2 is read with FFmpeg's 31 (exponents
# as deltas, a bit reservoir, blocks of several sizes). WMA Pro is read as a format, not decoded.

parts wma, block, window, vlc, tables, codes

# the codec flags of WMA version 2 in xWMA
xwmaFlags = 31

# WMA version 2's format tag
pub tagWma2 = 0x161
# WMA Pro's
pub tagWmaPro = 0x162

# An xWMA file's format, its packets' decoded sizes and where its packets are.
pub type Format:
	tag i64
	channels i64
	sampleRate i64
	bitRate i64   # as FFmpeg normalizes it: some encoders write a rate the codec did not use
	blockAlign i64   # a packet's bytes
	bitsPerSample i64
	decodedBytes i64[]   # dpds: the bytes of 16-bit samples decoded after each packet, cumulative
	dataAt i64
	dataSize i64

# samples per channel the dpds chunk declares (-1 without one)
pub fn declaredFrames(f Format) i64:
	if f.decodedBytes.isEmpty or f.channels <= 0: return -1
	f.decodedBytes[len - 1] / (f.channels * 2)

# whether the bytes begin as an xWMA file
pub fn isXwma(b ref u8[]) bool:
	b.startsWith("RIFF") and b.matchesAt(8, "XWMA")

# the bit rate FFmpeg decodes WMA version 2 with: encoders wrote some rates the codec did not use
fn normalizedRate(channels i64, rate i64, bitRate i64):
	fake = bitRate == 48_000 or bitRate == 192_000
	if channels == 1:
		if (rate == 22_050 or rate == 32_000) and fake: return 20_000
		if rate == 44_100 and (bitRate == 96_000 or bitRate == 192_000): return 48_000
	elif channels == 2:
		if rate == 22_050 and fake: return 32_000
		if rate == 32_000 and bitRate == 192_000: return 48_000
	bitRate

# The format and chunks of an xWMA file; none when it is not one or a chunk is cut short.
pub fn readXwmaFormat(b ref u8[]) Format?:
	if not isXwma(b) or b.len < 20 or not b.matchesAt(12, "fmt "): return none
	size = i64(b.u32le(16))
	if size < 16 or 20 + size > b.len: return none
	tag = i64(b.u16le(20))
	channels = i64(b.u16le(22))
	rate = i64(b.u32le(24))
	bitRate = i64(b.u32le(28)) * 8
	if tag == tagWma2: bitRate = normalizedRate(channels, rate, bitRate)
	f = Format(
		tag,
		channels,
		sampleRate = rate,
		bitRate,
		blockAlign = b.u16le(32),
		bitsPerSample = b.u16le(34),
		decodedBytes = [],
		dataAt = 0,
		dataSize = 0
	)
	at = 20 + size + (size & 1)
	while at + 8 <= b.len:
		chunk = i64(b.u32le(at + 4))
		if b.matchesAt(at, "data"):
			f.dataAt = at + 8
			f.dataSize = chunk.min(b.len - at - 8)
			return f
		if at + 8 + chunk > b.len: return none
		if b.matchesAt(at, "dpds"):
			for i in 0..chunk / 4:
				f.decodedBytes.push(b.u32le(at + 8 + 4 * i))
		at += 8 + chunk + (chunk & 1)
	none

# An xWMA file decoded packet by packet (WMA version 2): as FFmpeg gives it, the decoder's first
# two frames dropped and the samples it still holds at the end given.
pub type Stream:
	bytes u8[]
	format Format
	decoder Decoder
	packet i64 = 0   # the next packet's index
	skip i64 = 0   # samples per channel still to drop
	flushed bool = false

# A stream over an xWMA file's bytes (moved in); none when it is no xWMA of WMA version 2.
pub fn openXwma(move bytes u8[]) Stream?:
	f = try readXwmaFormat(bytes)
	if f.tag != tagWma2: return none
	d = try newWmaDecoder(f.channels, f.sampleRate, f.bitRate, f.blockAlign, xwmaFlags)
	skip = d.frameLen * 2
	Stream(bytes, format = f, decoder = d, skip)

# Appends the next packet's samples to `out` (interleaved, the file's channels): how many frames,
# 0 at the end. A damaged packet gives none and the stream goes on with the next.
pub fn readXwma(mut s Stream, mut out f32[]) i64:
	f = s.format
	ch = f.channels
	while s.packet * f.blockAlign + f.blockAlign <= f.dataSize:
		at = f.dataAt + s.packet * f.blockAlign
		s.packet += 1
		packet = s.bytes[at..at + f.blockAlign]
		if not s.decoder.decodePacket(packet): continue
		n = s.decoder.pcm.len / ch
		drop = s.skip.min(n)
		s.skip -= drop
		if n > drop:
			out.extend(s.decoder.pcm[drop * ch..])
			return n - drop
	if s.flushed: return 0
	s.flushed = true
	tail = s.decoder.flushDecoder()
	n = tail.len / ch
	drop = s.skip.min(n)
	s.skip -= drop
	out.extend(tail[drop * ch..])
	n - drop

# Back to the first packet.
pub fn rewindXwma(mut s Stream):
	s.decoder.resetDecoder()
	s.packet = 0
	s.skip = s.decoder.frameLen * 2
	s.flushed = false

# ---------- tests: the parts on bytes made here ----------

# the bytes of bits given as (value, length) pairs, the first highest
fn packBits(fields (i64, i64)[]):
	out = []
	acc = 0
	n = 0
	for field in fields:
		value, length = field
		for i in 0..length:
			acc = acc << 1 | (value >> (length - 1 - i)) & 1
			n += 1
			if n == 8:
				out.push(u8(acc))
				acc = 0
				n = 0
	if n > 0: out.push(u8(acc << (8 - n)))
	out

# every code of a table read back as its symbol, the codes written one after another
fn readsBack(codes i64[], lengths i64[], rootBits i64):
	v = newVlc(codes, lengths, (0..codes.len).map(it), rootBits)
	fields = (0..codes.len).map((codes[it], lengths[it]))
	bytes = packBits(fields)
	br = BitReader(d = bytes, high = true)
	for i in 0..codes.len:
		if v.readVlc(br) != i: return false
	br.bitsRead() == lengths.sum()

test "every code of the scale factor, gain and coefficient tables reads back as its symbol":
	expect readsBack(scalefactorCodes, scalefactorLengths, 8)
	expect readsBack(canonicalCodes(hgainLengths), hgainLengths, 9)
	for t in 0..6:
		first = coefStarts[t]
		last = coefStarts[t + 1]
		expect readsBack(coefCodes[first..last], coefLengths[first..last].map(i64(it)), 9)

test "the bits read count across bytes, and a read past the data's end is not counted":
	bytes = packBits([(5, 3), (0x1FF, 9), (1, 1)])
	br = BitReader(d = bytes, high = true)
	expect br.take(3) == 5 and br.bitsRead() == 3
	expect br.take(9) == 0x1FF and br.bitsRead() == 12
	expect br.take(1) == 1 and br.bitsRead() == 13
	# a read past the end is not taken: it gives 0 and marks the reader short
	expect br.take(16) == 0 and br.bitsRead() == 13 and br.short

# an xWMA file's bytes: a WAVEFORMATEX of the tag, a dpds chunk of the sizes, packets of zeros
fn xwmaBytes(tag i64, channels i64, rate i64, bytesPerSecond i64, sizes i64[], packets i64):
	align = 64
	b = "RIFF".bytes().copy()
	b.pushU32le(4 + 26 + 8 + 4 * sizes.len + 8 + align * packets)
	b.extend("XWMAfmt ".bytes())
	b.pushU32le(18)
	b.pushU16le(tag)
	b.pushU16le(channels)
	b.pushU32le(rate)
	b.pushU32le(bytesPerSecond)
	b.pushU16le(align)
	b.pushU16le(16)
	b.pushU16le(0)
	b.extend("dpds".bytes())
	b.pushU32le(4 * sizes.len)
	for s in sizes:
		b.pushU32le(s)
	b.extend("data".bytes())
	b.pushU32le(align * packets)
	b.extend(zeros(align * packets))
	b

test "the container: the format, the decoded sizes, the packets, the bit rate FFmpeg decodes with":
	b = xwmaBytes(tagWma2, 2, 44_100, 6000, [8192, 16_384], 3)
	expect isXwma(b)
	f = readXwmaFormat(b) ?? fail("no format")
	expect f.tag == tagWma2 and f.channels == 2 and f.sampleRate == 44_100
	expect f.bitRate == 48_000 and f.blockAlign == 64 and f.bitsPerSample == 16
	expect f.decodedBytes == [8192, 16_384] and f.declaredFrames() == 4096
	expect f.dataSize == 192 and b.matchesAt(f.dataAt - 8, "data")
	monoBytes = xwmaBytes(tagWma2, 1, 22_050, 6000, [4], 1)
	mono = readXwmaFormat(monoBytes) ?? fail("no format")
	expect mono.bitRate == 20_000
	cut = b[..40]
	expect readXwmaFormat(cut) == none
	wave = "RIFF....WAVEfmt ".bytes()
	expect not isXwma(wave)

test "WMA Pro is read as a format, not decoded; packets that are no WMA decode to silence":
	pro = xwmaBytes(tagWmaPro, 2, 44_100, 6000, [4], 1)
	expect (readXwmaFormat(pro) ?? fail("no format")).tag == tagWmaPro
	expect openXwma(move pro) == none
	s = openXwma(xwmaBytes(tagWma2, 2, 44_100, 6000, [4], 3)) ?? fail("not opened")
	out = []
	while s.readXwma(out) > 0:
		pass
	expect out.all(it == 0.0)
