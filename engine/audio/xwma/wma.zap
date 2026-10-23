# A WMA version 2 decoder (format tag 0x161), a port of FFmpeg's libavcodec/wmadec.c, wma.c and
# wma_common.c (LGPL 2.1 or later, ffmpeg.org): the superframes with their bit reservoir, the
# frames of one to five block sizes, the exponents (coded as deltas through AAC's scale factor
# code, or as line spectral pairs), the run-level coded coefficients, the noise of the high bands,
# mid/side stereo, the inverse MDCT and the sine windows' overlap (block.zap). The tables are in
# tables.zap and codes.zap.

import engine.audio.mdct

blockMinBits = 7
noiseTableSize = 8192

# the codes of one of the two coefficient tables a stream uses: a code's run and level
type CoefCode:
	vlc Vlc
	runs i64[]
	levels f32[]

# A WMA version 2 stream's decoder: its setup from the format, and the state one frame leaves
# to the next. decodePacket() leaves a packet's samples in `pcm`.
pub type Decoder:
	channels i64 in 1..=2
	sampleRate i64
	blockAlign i64
	useExpVlc bool
	useBitReservoir bool
	useVariableBlockLen bool
	useNoiseCoding bool = true
	byteOffsetBits i64 = 0
	frameLenBits i64 = 11
	frameLen i64 = 2048
	blockSizes i64 = 1
	exponentBands i64[,] = []   # per block size, the widths of its exponents' bands
	highBandStart i64[] = []
	coefsEnd i64[] = []
	highBands i64[,] = []   # per block size, the widths of its bands above highBandStart
	coefCodes CoefCode[] = []
	expVlc Vlc = Vlc(rootBits = 8)
	hgainVlc Vlc = Vlc(rootBits = 9)
	windows f32[,] = []
	mdcts mdct.Mdct[] = []
	noiseTable f32[] = []
	noiseIndex i64 = 0
	noiseMult f32 = 0.0
	lspCosTable f32[] = []
	# the blocks
	resetBlockLengths bool = true
	blockLenBits i64 = 11
	nextBlockLenBits i64 = 11
	prevBlockLenBits i64 = 11
	blockLen i64 = 2048
	blockPos i64 = 0
	msStereo bool = false
	channelCoded bool[2] = [false, false]
	exponentsBsize i64[2] = [0, 0]
	exponentsInitialized bool[2] = [false, false]
	exponents f32[,] = []
	maxExponent f32[2] = [1.0, 1.0]
	highBandCoded bool[,] = []
	highBandValues i64[,] = []
	coefs1 f32[,] = []
	coefs f32[,] = []
	output f32[] = []
	scratch f32[] = []
	frameOut f32[,] = []
	# the superframes
	lastSuperframe u8[] = []
	lastBitoffset i64 = 0
	pcm f32[] = []   # the last packet's samples, interleaved

# the log2 of a frame's samples (ff_wma_get_frame_len_bits for versions 1 and 2)
fn frameLenBitsFor(sampleRate i64):
	if sampleRate <= 16_000: return 9
	if sampleRate <= 22_050: return 10
	11

# FFmpeg's av_log2: the index of the highest bit set (0 for 0)
fn log2Floor(x i64):
	n = 0
	v = x
	while v > 1:
		v >>= 1
		n += 1
	n

# A decoder of WMA version 2 for the format's channels, rate, bits a second and packet size;
# `flags` are the codec's flags (31 in xWMA, which stores none); none when they are out of range.
pub fn newWmaDecoder(channels i64, sampleRate i64, bitRate i64, blockAlign i64, flags i64) Decoder?:
	if sampleRate <= 0 or sampleRate > 50_000 or bitRate <= 0 or blockAlign <= 0: return none
	if channels < 1 or channels > 2: return none
	bits = frameLenBitsFor(sampleRate)
	d = Decoder(
		channels,
		sampleRate,
		blockAlign,
		useExpVlc = (flags & 1) != 0,
		useBitReservoir = (flags & 2) != 0,
		useVariableBlockLen = (flags & 4) != 0,
		frameLenBits = bits,
		frameLen = 1 << bits,
		blockLenBits = bits,
		nextBlockLenBits = bits,
		prevBlockLenBits = bits
	)
	d.blockSizes = 1
	if d.useVariableBlockLen:
		nb = ((flags >> 3) & 3) + 1
		if bitRate / channels >= 32_000: nb += 2
		d.blockSizes = nb.min(bits - blockMinBits) + 1
	bps = f32(bitRate) / f32(channels * sampleRate)
	d.byteOffsetBits = log2Floor(i64(f64(bps) * f64(d.frameLen) / 8.0 + 0.5)) + 2
	if d.byteOffsetBits + 3 > 25: return none
	d.setRates(bps)
	d.setBuffers()
	d

# what the bits per sample decide: noise coding, the high bands, the coefficient tables
fn setRates(mut d Decoder, bps f32):
	bps1 = f32(f64(bps) * 1.6) if d.channels == 2 else bps
	highFreq = d.noiseCodedFreq(bps, bps1)
	for k in 0..d.blockSizes:
		d.setBands(k, highFreq)
	if d.useNoiseCoding:
		d.noiseMult = 0.02 if d.useExpVlc else 0.04
		seed u32 = 1
		norm = f32(1.0 / 2_147_483_648.0 * 3.0.sqrt() * f64(d.noiseMult))
		loop noiseTableSize:
			seed = seed * 314_159 + 1
			d.noiseTable.push(f32(i32.wrap(seed)) * norm)
		d.hgainVlc = newVlc(
			canonicalCodes(hgainLengths),
			hgainLengths,
			hgainSymbols.map(it - 18),
			9
		)
	table = 2
	if d.sampleRate >= 32_000:
		if f64(bps1) < 0.72:
			table = 0
		elif f64(bps1) < 1.16:
			table = 1
	for t in [table * 2, table * 2 + 1]:
		d.coefCodes.push(coefCode(t))
	if d.useExpVlc:
		d.expVlc = newVlc(scalefactorCodes, scalefactorLengths, (0..121).map(it), 8)
	else:
		d.lspCosTable = (0..d.frameLen).map(f32(2.0 * (pi / d.frameLen * it).cos()))

# the frequency above which bands may be noise, and whether there is noise at all, from the
# rate (version 2's rates are normalized) and the bits per sample
fn noiseCodedFreq(mut d Decoder, bps f32, bps1 f32):
	high = d.sampleRate * 0.5
	rate = d.sampleRate
	for r in [44_100, 22_050, 16_000, 11_025, 8_000]:
		if rate >= r:
			rate = r
			break
	b = f64(bps)
	b1 = f64(bps1)
	if rate == 44_100:
		if b1 >= 0.61:
			d.useNoiseCoding = false
		else:
			high *= 0.4
	elif rate == 22_050:
		if b1 >= 1.16:
			d.useNoiseCoding = false
		else:
			high *= 0.7 if b1 >= 0.72 else 0.6
	elif rate == 16_000:
		high *= 0.5 if b > 0.5 else 0.3
	elif rate == 11_025:
		high *= 0.7
	elif rate == 8_000:
		if b <= 0.625:
			high *= 0.5
		elif b > 0.75:
			d.useNoiseCoding = false
		else:
			high *= 0.65
	else:
		high *= 0.75 if b >= 0.8 else 0.6 if b >= 0.6 else 0.5
	f32(high)

# the bands of block size k (frameLen >> k): the exponents' widths, the coded end, the high bands
fn setBands(mut d Decoder, k i64, highFreq f32):
	blockLen = d.frameLen >> k
	bands = d.exponentWidths(k, blockLen)
	d.coefsEnd.push((d.frameLen - d.frameLen * 9 / 100) >> k)
	start = i64(f64(f32(blockLen * 2) * highFreq / f32(d.sampleRate)) + 0.5)
	d.highBandStart.push(start)
	high = []
	pos = 0
	for width in bands:
		first = pos.max(start)
		pos += width
		last = pos.min(d.coefsEnd[k])
		if last > first: high.push(last - first)
	d.exponentBands.push(bands)
	d.highBands.push(high)

# the widths of the exponents' bands of block size k: a table for the three shortest blocks at
# the usual rates, else from the critical frequencies, in steps of four coefficients
fn exponentWidths(d Decoder, k i64, blockLen i64):
	a = d.frameLenBits - blockMinBits - k
	if a < 3:
		rate = d.sampleRate
		if rate >= 44_100: return exponentBands44100[a][1..].copy()
		if rate >= 32_000: return exponentBands32000[a][1..].copy()
		if rate >= 22_050: return exponentBands22050[a][1..].copy()
	widths = []
	last = 0
	for f in criticalFreqs:
		pos = ((blockLen * 2 * f + (d.sampleRate << 1)) / (4 * d.sampleRate) << 2).min(blockLen)
		if pos > last: widths.push(pos - last)
		if pos >= blockLen: break
		last = pos
	widths

# the codes FFmpeg's ff_vlc_init_from_lengths gives lengths listed in code order
fn canonicalCodes(lengths i64[]):
	codes = []
	code = 0
	for n in lengths:
		codes.push(i64(code >> u64(32 - n)))
		code += u64(1) << u64(32 - n)
	codes

# coefficient table t (0 to 5): its codes, and each code's run and level (codes 0 and 1 are the
# escape and the end of the block)
fn coefCode(t i64):
	first = coefStarts[t]
	n = coefStarts[t + 1] - first
	codes = coefCodes[first..first + n]
	lengths = coefLengths[first..first + n].map(i64(it))
	runs = zeros(n)
	levels f32[] = zeros(n)
	i = 2
	level = 1
	for k in levelStarts[t]..levelStarts[t + 1]:
		for run in 0..coefLevels[k]:
			if i >= n: break
			runs[i] = run
			levels[i] = f32(level)
			i += 1
		level += 1
	CoefCode(vlc = newVlc(codes, lengths, (0..n).map(it), 9), runs, levels)

# the windows, the transforms and the buffers of each block size
fn setBuffers(mut d Decoder):
	for k in 0..d.blockSizes:
		n = d.frameLen >> k
		d.windows.push((0..n).map(f32(((it + 0.5) * (pi / (2.0 * n))).sin())))
		d.mdcts.push(mdct.newMdct(mdct.Block(n * 2)))
	d.exponents = zeros(2, d.frameLen)
	d.highBandCoded = fill(2, 16, false)
	d.highBandValues = zeros(2, 16)
	d.coefs1 = zeros(2, d.frameLen)
	d.coefs = zeros(2, d.frameLen)
	d.output = zeros(d.frameLen * 2)
	d.scratch = zeros(d.frameLen)
	d.frameOut = zeros(2, d.frameLen * 2)

# ---------- superframes ----------

# the bits read so far from the reader's bytes
fn bitsRead(br BitReader):
	i64(br.at) * 8 + br.over * 8 - br.count

# Decodes one packet (blockAlign bytes): its frames' samples, interleaved, left in `pcm`; false
# when the packet is damaged (its samples are dropped and the reservoir emptied).
pub fn decodePacket(mut d Decoder, packet u8[]) bool:
	d.pcm.clear()
	if packet.len != d.blockAlign: return false
	ok = d.decodeSuperframe(packet) if d.useBitReservoir else d.decodeSingle(packet)
	if not ok:
		d.pcm.clear()
		d.lastSuperframe.clear()
	ok

fn decodeSingle(mut d Decoder, buf u8[]) bool:
	br = BitReader(d = buf, high = true)
	d.decodeWmaFrame(br, buf.len * 8)

fn decodeSuperframe(mut d Decoder, buf u8[]):
	br = BitReader(d = buf, high = true)
	br.skip(4)
	frames = br.take(4) - (1 if d.lastSuperframe.isEmpty else 0)
	if frames <= 0:
		# a frame longer than the packet: the packet goes whole to the reservoir
		if frames < 0 or buf.len * 8 - 8 <= 8: return false
		d.lastSuperframe.extend(buf[1..])
		return true
	headerBits = 8 + d.byteOffsetBits + 3
	bitOffset = br.take(d.byteOffsetBits + 3)
	if bitOffset > buf.len * 8 - headerBits: return false
	if not d.lastSuperframe.isEmpty:
		# the frame begun in the packets before ends in this one's first bitOffset bits
		joined = d.lastSuperframe.copy()
		left = bitOffset
		while left > 7:
			joined.push(u8(br.take(8)))
			left -= 8
		if left > 0: joined.push(u8(br.take(left) << (8 - left)))
		limit = d.lastSuperframe.len * 8 + bitOffset
		jr = BitReader(d = joined, high = true)
		jr.skip(d.lastBitoffset)
		if not d.decodeWmaFrame(jr, limit): return false
		frames -= 1
	pos = bitOffset + headerBits
	if pos > buf.len * 8: return false
	fr = BitReader(d = buf, high = true)
	left = pos
	while left > 0:
		fr.skip(left.min(32))
		left -= 32
	d.resetBlockLengths = true
	loop frames:
		if not d.decodeWmaFrame(fr, buf.len * 8): return false
	# the frame begun at the end goes to the reservoir
	end = fr.bitsRead()
	d.lastBitoffset = end & 7
	if end >> 3 > buf.len: return false
	d.lastSuperframe = buf[end >> 3..].copy()
	true

# decodes a frame of frameLen samples per channel, appended to pcm
fn decodeWmaFrame(mut d Decoder, mut br BitReader, limit i64):
	d.blockPos = 0
	loop:
		result = d.decodeWmaBlock(br, limit)
		if result < 0: return false
		if result > 0: break
	n = d.frameLen
	for i in 0..n:
		for ch in 0..d.channels:
			d.pcm.push(d.frameOut[ch][i])
	for ch in 0..d.channels:
		out = move d.frameOut[ch]
		for i in 0..n:
			out[i] = out[n + i]
			out[n + i] = 0.0
		d.frameOut[ch] = out
	true

# The samples still held when the packets end (FFmpeg gives them as a last frame), interleaved.
pub fn flushDecoder(d Decoder) f32[]:
	out = []
	for i in 0..d.frameLen:
		for ch in 0..d.channels:
			out.push(d.frameOut[ch][i])
	out

# Back to the state before the first packet.
pub fn resetDecoder(mut d Decoder):
	d.lastSuperframe.clear()
	d.lastBitoffset = 0
	d.resetBlockLengths = true
	d.noiseIndex = 0
	d.exponentsInitialized = [false, false]
	d.maxExponent = [1.0, 1.0]
	for ch in 0..2:
		for i in 0..d.frameOut[ch].len:
			d.frameOut[ch][i] = 0.0
