# The game's sounds (resources 10000 + n of the sound DATs, as SDLPoP's load_sounds and
# load_opt_sounds find them): a PC speaker tune (IBM_SND), a digitized sound (DIGISND) or a MIDI
# tune (MIDISND), the last DAT opened first, so music plays as MIDI and effects digitized.

pub soundCount = 58

pub soundSpeaker = 0
pub soundDigi = 1
pub soundMidi = 2

pub type SoundBank:
	sounds u8[]?[]   # by sound id: the resource, its first byte the kind
	instruments Instrument[]   # the MIDI tunes' instruments (PRINCE.DAT's resource 1)

	pub fn exists(id i64) bool:
		id >= 0 and id < sounds.len and sounds[id] != none

	pub fn kind(id i64) i64:
		if sounds[id] is b: return i64(b[0]) & 7
		-1

	# how many ticks of 60 a second the sound plays
	pub fn ticks(id i64) i64:
		if sounds[id] is b:
			k = i64(b[0]) & 7
			if k == soundDigi:
				rate = i64(b.u16le(1))
				count = i64(b.u16le(4))
				return (count * 60 + rate - 1) / rate.max(1)
			if k == soundSpeaker: return speakerTicks(b)
			if k == soundMidi: return midiTicks(b)
		0

	# a MIDI tune started on the synthesizer, none for the other kinds
	pub fn midiStream(id i64) MidiStream?:
		if sounds[id] is b:
			if (i64(b[0]) & 7) == soundMidi:
				return startMidi(b[1..].copy(), instruments, outputRate, tempoModifier(id))
		none

	# the sound as samples at outputRate, mono; a MIDI tune's come from midiStream
	pub fn samplesOf(id i64) f32[]:
		if sounds[id] is b:
			k = i64(b[0]) & 7
			if k == soundDigi: return digiSamples(b)
			if k == soundSpeaker: return speakerSamples(b)
		[]

# the sounds of the install: 0..43 from the first DATs, 44..56 from the second ones
pub fn loadSounds(dir str) SoundBank:
	first = DatChain(
		[
			loadDat(dir, "MIDISND1.DAT"),
			loadDat(dir, "DIGISND3.DAT"),
			loadDat(dir, "DIGISND1.DAT"),
			loadDat(dir, "IBM_SND1.DAT")
		]
	)
	second = DatChain(
		[loadDat(dir, "MIDISND2.DAT"), loadDat(dir, "DIGISND2.DAT"), loadDat(dir, "IBM_SND2.DAT")]
	)
	sounds u8[]?[] = []
	for id in 0..soundCount:
		chain = first if id < 44 else second
		if chain.resource(10_000 + id) is b:
			sounds.push(b.copy())
		else:
			sounds.push(none)
	prince = loadDat(dir, "PRINCE.DAT")
	SoundBank(sounds, instruments = instrumentsOf(prince.need(1)))

# a speaker tune: its tempo, then notes of (frequency, length) until frequency 0x12
fn speakerTicks(b u8[]):
	tempo = i64(b.u16le(1))
	total = 0
	at = 3
	while at + 2 < b.len and i64(b.u16le(at)) != 0x12:
		total += b[at + 2]
		at += 3
	total * 60 / tempo.max(1)

# a tempo meta event: from tick on, a beat lasts microsPerBeat
type TempoChange:
	tick i64
	microsPerBeat i64

# a MIDI tune's length: the longest track's ticks at the tempos any track sets
fn midiTicks(b u8[]) i64:
	if b.len < 15: return 0
	tracks, division = parseMidi(b[1..].copy())
	tempos = []
	ends = []
	for t in tracks:
		tick = 0
		for e in t.events:
			tick += e.delta
			if e.kind == 0xFF and e.meta == 0x51 and e.data.len >= 3:
				tempos.push(
					TempoChange(
						tick,
						microsPerBeat = i64(e.data[0]) << 16 | i64(e.data[1]) << 8 | e.data[2]
					)
				)
		ends.push(tick)
	# in the order of their ticks, those at one tick as found (an insertion sort)
	for i in 1..tempos.len:
		c = tempos[i]
		j = i - 1
		while j >= 0 and tempos[j].tick > c.tick:
			tempos[j + 1] = tempos[j]
			j -= 1
		tempos[j + 1] = c
	longest = 0.0
	for last in ends:
		micros = 0.0
		from = 0
		tempo = 500_000
		for t in tempos:
			if t.tick >= last: break
			if t.tick > from:
				micros += f64(t.tick - from) * f64(tempo) / division.max(1)
				from = t.tick
			tempo = t.microsPerBeat
		micros += f64(last - from) * f64(tempo) / division.max(1)
		longest = longest.max(micros)
	i64(longest / 1000000.0 * 60.0)

pub outputRate = 44_100

# the tempos SDLPoP adjusts: the PV scene's music lines up with its flashes, the title's with
# its pictures
fn tempoModifier(id i64):
	if id == 53: return -0.03
	if id == 54: return 0.03
	0.0

# 8-bit unsigned samples at their own rate, resampled by linear interpolation
fn digiSamples(b u8[]):
	if b.len < 9: return []
	rate = i64(b.u16le(1)).max(1)
	count = i64(b.u16le(4)).min(b.len - 9)
	frames = count * outputRate / rate
	out = []
	ratio = f64(rate) / f64(outputRate)
	for i in 0..frames:
		src = i * ratio
		s0 = i64(src)
		a = (b[9 + s0] - 128.0) / 128.0
		if s0 + 1 < count:
			c = (b[9 + s0 + 1] - 128.0) / 128.0
			alpha = src - s0
			a = (1.0 - alpha) * a + alpha * c
		out.push(f32(a))
	out

# the PC speaker's square waves: a note's length in 1/tempo seconds, frequencies 0 and 1 rests
fn speakerSamples(b u8[]):
	if b.len < 3: return []
	tempo = i64(b.u16le(1)).max(1)
	out f32[] = []
	level = f32(0.12)
	sinceFlip = 0.0
	at = 3
	while at + 2 < b.len and i64(b.u16le(at)) != 0x12:
		freq = i64(b.u16le(at))
		n = i64(b[at + 2]) * outputRate / tempo
		if freq <= 1:
			loop n:
				out.push(0.0)
		else:
			half = f64(outputRate) / f64(freq) * 0.5
			loop n:
				if sinceFlip > half:
					level = -level
					sinceFlip -= half
				out.push(level)
				sinceFlip += 1.0
		at += 3
	out
