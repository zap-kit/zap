# WAV files, read and written: RIFF chunks, the format (PCM of 8 bits unsigned, 16, 24 and 32
# bits signed, IEEE floats of 32 and 64 bits, WAVE_FORMAT_EXTENSIBLE around those, IMA ADPCM and
# Microsoft ADPCM), and the samples as floats in -1..1, as ffmpeg gives them (an integer sample
# over 2^(bits - 1), ADPCM decoded to 16 bits first). A Stream decodes block by block, so a
# long file plays without its samples all in memory; encodeWav writes 16-bit PCM or float files.

wavPcm = 1
wavMsAdpcm = 2
wavFloat = 3
wavImaAdpcm = 0x11
wavExtensible = 0xFFFE

# The layout of a WAV file's samples, from its "fmt " chunk, and where its "data" chunk is.
pub type Format:
	format i64   # wavPcm, wavFloat, wavMsAdpcm or wavImaAdpcm (extensible resolved)
	channels i64
	sampleRate i64
	bits i64   # per sample (4 for ADPCM)
	blockAlign i64   # bytes per frame (PCM) or per block (ADPCM)
	samplesPerBlock i64   # ADPCM: frames per block
	coefs i64[]   # MS ADPCM: the predictor pairs, 256 for 1.0
	dataStart i64
	dataBytes i64

# Interleaved float samples: `channels` per frame, `sampleRate` frames a second.
pub type Pcm:
	samples f32[]
	channels i64
	sampleRate i64

	# samples per channel
	fn frames():
		samples.len / channels if channels > 0 else 0

# whether the bytes begin as a WAV file
pub fn isWav(b ref u8[]) bool:
	b.startsWith("RIFF") and b.matchesAt(8, "WAVE")

# The format and data chunk of a WAV file; none when it is not one or its format is not read.
pub fn readWavFormat(b ref u8[]) Format?:
	if not isWav(b): return none
	f = Format(
		format = 0,
		channels = 0,
		sampleRate = 0,
		bits = 0,
		blockAlign = 0,
		samplesPerBlock = 0,
		coefs = [],
		dataStart = 0,
		dataBytes = 0
	)
	haveFormat = false
	at = 12
	while at + 8 <= b.len:
		size = i64(b.u32le(at + 4))
		body = at + 8
		if b.matchesAt(at, "fmt ") and size >= 16 and body + size <= b.len:
			f.format = b.u16le(body)
			f.channels = b.u16le(body + 2)
			f.sampleRate = b.u32le(body + 4)
			f.blockAlign = b.u16le(body + 12)
			f.bits = b.u16le(body + 14)
			extra = b.u16le(body + 16) if size >= 18 else 0
			if f.format == wavExtensible and size >= 40:
				f.format = b.u16le(body + 24)   # the sub-format GUID's first word: 1 PCM, 3 float
			if (f.format == wavImaAdpcm or f.format == wavMsAdpcm) and extra >= 2:
				f.samplesPerBlock = b.u16le(body + 18)
			if f.format == wavMsAdpcm and extra >= 4:
				n = i64(b.u16le(body + 20))
				for k in 0..n:
					if body + 22 + k * 4 + 4 <= body + size:
						f.coefs.push(b.i16le(body + 22 + k * 4))
						f.coefs.push(b.i16le(body + 22 + k * 4 + 2))
			haveFormat = true
		elif b.matchesAt(at, "data") and haveFormat:
			f.dataStart = body
			f.dataBytes = size.min(b.len - body)   # a truncated file plays what it has
			return checkedFormat(move f)
		at = body + size + (size & 1)
	none

fn checkedFormat(move f Format) Format?:
	if f.channels < 1 or f.channels > 8 or f.sampleRate < 1 or f.blockAlign < 1: return none
	g = f
	if g.format == wavPcm and (g.bits in [8, 16, 24, 32]) or
		g.format == wavFloat and (g.bits == 32 or g.bits == 64):
		g.blockAlign = g.channels * g.bits / 8   # what the samples take, whatever the header says
		return g
	# an ADPCM block's frames: what its bytes hold at most (a header claiming more is not believed)
	if g.format == wavImaAdpcm and g.bits == 4:
		most = (g.blockAlign - 4 * g.channels) * 2 / g.channels + 1
		if g.samplesPerBlock <= 0 or g.samplesPerBlock > most:
			g.samplesPerBlock = most
		return g if g.blockAlign > 4 * g.channels else none
	if g.format == wavMsAdpcm and g.bits == 4 and g.channels <= 2:
		most = (g.blockAlign - 7 * g.channels) * 2 / g.channels + 2
		if g.samplesPerBlock <= 0 or g.samplesPerBlock > most:
			g.samplesPerBlock = most
		if g.coefs.len < 14:
			g.coefs = [256, 0, 512, -256, 0, 0, 192, 64, 240, 0, 460, -208, 392, -232]
		return g if g.blockAlign > 7 * g.channels else none
	none

# ---------- streaming ----------

# A WAV file decoded block by block (a block: 1024 frames of PCM, one ADPCM block).
pub type Stream:
	bytes u8[]
	format Format
	at i64 = 0   # bytes of the data chunk read

pub fn openWav(move bytes u8[]) Stream?:
	f = try readWavFormat(bytes)
	Stream(bytes, format = f)

pub fn rewindWav(mut s Stream):
	s.at = 0

# Appends the next block's frames to `out` (interleaved, the file's channels); how many, 0 at
# the end.
pub fn readWavBlock(mut s Stream, mut out f32[]) i64:
	f = s.format
	left = f.dataBytes - s.at
	if f.format == wavImaAdpcm or f.format == wavMsAdpcm:
		if left < f.blockAlign: return 0
		start = f.dataStart + s.at
		s.at += f.blockAlign
		if f.format == wavImaAdpcm: return decodeImaBlock(s.bytes, start, f, out)
		return decodeMsBlock(s.bytes, start, f, out)
	frames = (left / f.blockAlign).min(1024)
	if frames <= 0: return 0
	start = f.dataStart + s.at
	s.at += frames * f.blockAlign
	decodePcmFrames(s.bytes, start, frames, f, out)
	frames

fn decodePcmFrames(b ref u8[], start i64, frames i64, f Format, mut out f32[]):
	n = frames * f.channels
	bytesPer = f.bits / 8
	p = start
	if f.format == wavFloat and f.bits == 32:
		loop n:
			out.push(b.f32le(p))
			p += 4
	elif f.format == wavFloat:
		loop n:
			out.push(f32(b.f64le(p)))
			p += 8
	elif bytesPer == 1:
		loop n:
			out.push(f32(i64(b[p]) - 128) * (1.0 / 128.0))
			p += 1
	elif bytesPer == 2:
		loop n:
			out.push(f32(b.i16le(p)) * (1.0 / 32768.0))
			p += 2
	elif bytesPer == 3:
		loop n:
			v = b[p] | i64(b[p + 1]) << 8 | i64(b[p + 2]) << 16
			if v >= 8_388_608:
				v -= 16_777_216
			out.push(f32(v) * (1.0 / 8388608.0))
			p += 3
	else:
		loop n:
			out.push(f32(b.i32le(p)) * (1.0 / 2147483648.0))
			p += 4
	# a 16-bit sample over 32768 is exact in f32; 32-bit ones round like ffmpeg's (int to float, then the scale)

# ---------- IMA ADPCM ----------

imaIndexTable i32[] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]

imaStepTable i32[] = [
	7,
	8,
	9,
	10,
	11,
	12,
	13,
	14,
	16,
	17,
	19,
	21,
	23,
	25,
	28,
	31,
	34,
	37,
	41,
	45,
	50,
	55,
	60,
	66,
	73,
	80,
	88,
	97,
	107,
	118,
	130,
	143,
	157,
	173,
	190,
	209,
	230,
	253,
	279,
	307,
	337,
	371,
	408,
	449,
	494,
	544,
	598,
	658,
	724,
	796,
	876,
	963,
	1060,
	1166,
	1282,
	1411,
	1552,
	1707,
	1878,
	2066,
	2272,
	2499,
	2749,
	3024,
	3327,
	3660,
	4026,
	4428,
	4871,
	5358,
	5894,
	6484,
	7132,
	7845,
	8630,
	9493,
	10_442,
	11_487,
	12_635,
	13_899,
	15_289,
	16_818,
	18_500,
	20_350,
	22_385,
	24_623,
	27_086,
	29_794,
	32_767
]

# a channel's predictor and step while decoding
type AdpcmChannel:
	predictor i64
	stepIndex i64
	sample1 i64
	sample2 i64
	coef1 i64
	coef2 i64
	delta i64

fn imaNibble(mut c AdpcmChannel, nibble i64):
	step = i64(imaStepTable[c.stepIndex])
	diff = step >> 3
	if (nibble & 4) != 0:
		diff += step
	if (nibble & 2) != 0:
		diff += step >> 1
	if (nibble & 1) != 0:
		diff += step >> 2
	p = c.predictor - diff if (nibble & 8) != 0 else c.predictor + diff
	c.predictor = p.clamp(-32_768, 32_767)
	c.stepIndex = (c.stepIndex + imaIndexTable[nibble]).clamp(0, 88)
	c.predictor

fn emptyChannel():
	AdpcmChannel(
		predictor = 0,
		stepIndex = 0,
		sample1 = 0,
		sample2 = 0,
		coef1 = 0,
		coef2 = 0,
		delta = 0
	)

# one IMA block: per channel a header (first sample, step index), then groups of 8 samples a
# channel, two to a byte, the low nibble first
fn decodeImaBlock(b ref u8[], start i64, f Format, mut out f32[]):
	ch = f.channels
	state = []
	frames = Grid<i64>(ch, f.samplesPerBlock)   # a sample frame a row
	for c in 0..ch:
		s = emptyChannel()
		s.predictor = b.i16le(start + 4 * c)
		s.stepIndex = i64(b[start + 4 * c + 2]).clamp(0, 88)
		frames[c, 0] = s.predictor
		state.push(s)
	p = start + 4 * ch
	groups = (f.samplesPerBlock - 1) / 8
	for g in 0..groups:
		for c in 0..ch:
			for m in 0..4:
				v = i64(b[p])
				p += 1
				at = 1 + g * 8 + m * 2
				frames[c, at] = state[c].imaNibble(v & 15)
				frames[c, at + 1] = state[c].imaNibble(v >> 4)
	n = 1 + groups * 8
	for y in 0..n:
		for c in 0..ch:
			out.push(f32(frames[c, y]) * (1.0 / 32768.0))
	n

# ---------- Microsoft ADPCM ----------

msAdaptation i32[] = [
	230,
	230,
	230,
	230,
	307,
	409,
	512,
	614,
	768,
	614,
	512,
	409,
	307,
	230,
	230,
	230
]

fn msNibble(mut c AdpcmChannel, nibble i64):
	predictor = (c.sample1 * c.coef1 + c.sample2 * c.coef2) / 256
	predictor += (nibble - 16 if (nibble & 8) != 0 else nibble) * c.delta
	c.sample2 = c.sample1
	c.sample1 = predictor.clamp(-32_768, 32_767)
	c.delta = (msAdaptation[nibble] * c.delta) >> 8
	c.delta = c.delta.clamp(16, 2_147_483_647 / 768)
	c.sample1

# one MS ADPCM block: per channel a predictor index, a delta and two samples (the older first),
# then nibbles, the high one first, alternating channels in stereo
fn decodeMsBlock(b ref u8[], start i64, f Format, mut out f32[]):
	ch = f.channels
	state = []
	for c in 0..ch:
		s = emptyChannel()
		k = i64(b[start + c]).clamp(0, f.coefs.len / 2 - 1)
		s.coef1 = f.coefs[2 * k]
		s.coef2 = f.coefs[2 * k + 1]
		s.delta = b.i16le(start + ch + 2 * c)
		s.sample1 = b.i16le(start + 3 * ch + 2 * c)
		s.sample2 = b.i16le(start + 5 * ch + 2 * c)
		state.push(s)
	for c in 0..ch:
		out.push(f32(state[c].sample2) * (1.0 / 32768.0))
	for c in 0..ch:
		out.push(f32(state[c].sample1) * (1.0 / 32768.0))
	p = start + 7 * ch
	nibbles = (f.samplesPerBlock - 2) * ch
	k = 0
	while k + 1 < nibbles + 1 and p < start + f.blockAlign:
		v = i64(b[p])
		p += 1
		out.push(f32(state[0].msNibble(v >> 4)) * (1.0 / 32768.0))
		out.push(f32(state[ch - 1].msNibble(v & 15)) * (1.0 / 32768.0))
		k += 2
	2 + k / ch

# ---------- whole files ----------

# A WAV file's samples, all of them.
pub fn decodeWav(move bytes u8[]) Pcm?:
	s = try openWav(move bytes)
	out f32[] = []
	out.reserve(s.format.dataBytes * 8 / s.format.bits.max(1))
	while s.readWavBlock(out) > 0:
		pass
	Pcm(samples = out, channels = s.format.channels, sampleRate = s.format.sampleRate)

# A WAV file of the samples: 16-bit PCM (`bits` 16) or 32-bit floats (`bits` 32).
pub fn encodeWav(samples ref f32[], channels i64, sampleRate i64, bits i64 = 16) u8[]:
	isFloat = bits == 32
	bytesPer = 4 if isFloat else 2
	dataBytes = samples.len * bytesPer
	b u8[] = []
	b.reserve(44 + dataBytes)
	b.extend("RIFF".bytes())
	b.pushU32le(36 + dataBytes)
	b.extend("WAVEfmt ".bytes())
	b.pushU32le(16)
	b.pushU16le(wavFloat if isFloat else wavPcm)
	b.pushU16le(channels)
	b.pushU32le(sampleRate)
	b.pushU32le(sampleRate * channels * bytesPer)
	b.pushU16le(channels * bytesPer)
	b.pushU16le(bytesPer * 8)
	b.extend("data".bytes())
	b.pushU32le(dataBytes)
	for x in samples:
		if isFloat:
			b.pushF32le(x)
		else:
			b.pushU16le(i64((x * 32768.0).round()).clamp(-32_768, 32_767))
	b
