# The game's MIDI tunes played on the OPL3 as the DOS game drives an AdLib or Sound Blaster
# (SDLPoP's midi.c, from PRINCE.EXE's seg009:6C3C on): 9 voices, the instruments of PRINCE.DAT's
# resource 1, notes an octave below MIDI's, rendered whole into samples.

import dos

# an operator's registers in the instrument bank
type Operator:
	mul i64
	kslTl i64
	aD i64
	sR i64
	waveform i64

pub type Instrument:
	fbConn i64
	operators Operator[]

type MidiEvent:
	delta i64
	kind i64   # the status's high nibble for a channel's event, else 0xF0, 0xF7 or 0xFF
	channel i64
	p1 i64
	p2 i64
	meta i64
	data u8[]

type MidiTrack:
	events MidiEvent[]
	index i64 = 0
	nextPauseTick i64 = 0

numVoices = 9
sbproOp = [0, 1, 2, 6, 7, 8, 12, 13, 14, 18, 19, 20, 24, 25, 26, 30, 31, 32]
regPairOffsets = [
	0x000,
	0x001,
	0x002,
	0x003,
	0x004,
	0x005,
	0x008,
	0x009,
	0x00A,
	0x00B,
	0x00C,
	0x00D,
	0x010,
	0x011,
	0x012,
	0x013,
	0x014,
	0x015,
	0x100,
	0x101,
	0x102,
	0x103,
	0x104,
	0x105,
	0x108,
	0x109,
	0x10A,
	0x10B,
	0x10C,
	0x10D,
	0x110,
	0x111,
	0x112,
	0x113,
	0x114,
	0x115
]
regSingleOffsets = [
	0,
	1,
	2,
	3,
	4,
	5,
	6,
	7,
	8,
	0x100,
	0x101,
	0x102,
	0x103,
	0x104,
	0x105,
	0x106,
	0x107,
	0x108
]

# the bank of PRINCE.DAT's resource 1: a count, then 16 bytes an instrument
pub fn instrumentsOf(b u8[]) Instrument[]:
	n = i64(b[0])
	(0..n).map(instrumentAt(b, 1 + it * 16))

fn instrumentAt(b u8[], at i64):
	Instrument(fbConn = b[at + 2], operators = [operatorAt(b, at + 3), operatorAt(b, at + 8)])

fn operatorAt(b u8[], at i64):
	Operator(
		mul = b[at],
		kslTl = b[at + 1],
		aD = b[at + 2],
		sR = b[at + 3],
		waveform = b[at + 4]
	)

fn readVarLength(m u8[], mut at i64[]):
	v = 0
	loop 4:
		c = i64(m[at[0]])
		at[0] += 1
		v = v << 7 | (c & 0x7F)
		if c & 0x80 == 0: break
	v

# parse_midi: the tracks' events (running status kept across tracks, as SDLPoP does)
fn parseMidi(m u8[]):
	division = i64(m[12]) << 8 | m[13]
	tracks = []
	at = [14]
	last = 0
	while at[0] + 8 <= m.len:
		length = i64(m[at[0] + 4]) << 24 | i64(m[at[0] + 5]) << 16 | i64(m[at[0] + 6]) << 8 | i64(
			m[at[0] + 7]
		)
		next = at[0] + 8 + length
		at[0] += 8
		events = []
		while at[0] < next:
			delta = readVarLength(m, at)
			status = i64(m[at[0]])
			if status & 0x80 != 0:
				if status < 0xF8: last = status
				at[0] += 1
			else:
				status = last
			hi = status & 0xF0
			e = MidiEvent(delta, kind = status, channel = 0, p1 = 0, p2 = 0, meta = 0, data = [])
			if hi >= 0x80 and hi <= 0xE0:
				e.kind = hi
				e.channel = status & 0x0F
				e.p1 = m[at[0]]
				at[0] += 1
				if hi != 0xC0 and hi != 0xD0:
					e.p2 = m[at[0]]
					at[0] += 1
			elif status == 0xF0 or status == 0xF7:
				size = readVarLength(m, at)
				e.data = m[at[0]..at[0] + size].copy()
				at[0] += size
			elif status == 0xFF:
				e.meta = m[at[0]]
				at[0] += 1
				size = readVarLength(m, at)
				e.data = m[at[0]..at[0] + size].copy()
				at[0] += size
			else:
				break   # an unknown event: the track ends here
			endOfTrack = status == 0xFF and e.meta == 0x2F
			events.push(e)
			if endOfTrack: break
		tracks.push(MidiTrack(events))
		at[0] = next
	(tracks, division)

type MidiPlayer:
	chip dos.Opl3
	instruments Instrument[]
	cached i64[] = zeros(512)
	voiceNote i64[] = zeros(18)
	voiceInstrument i64[] = zeros(18)
	voiceChannel i64[] = zeros(18)
	channelInstrument i64[] = (0..16).map(it)
	lastUsedVoice i64 = 0
	semitonesHigher i64 = 0
	usPerBeat i64 = 500_000
	tempoModifier f64 = 0.0

	fn writeReg(reg i64, v i64):
		chip.writeReg(reg, v)
		cached[reg] = v

	mut fn writeRegMasked(reg i64, v i64, mask i64):
		self.writeReg(reg, (cached[reg] & ~mask) | (v & mask))

	mut fn writeInstrument(instrument Instrument, voice i64):
		self.writeReg(0xC0 + regSingleOffsets[voice], instrument.fbConn | 0x30)   # both speakers
		for op in 0..2:
			o = instrument.operators[op]
			r = regPairOffset(voice, op)
			self.writeReg(0x20 + r, o.mul)
			self.writeReg(0x40 + r, o.kslTl)
			self.writeReg(0x60 + r, o.aD)
			self.writeReg(0x80 + r, o.sR)
			self.writeReg(0xE0 + r, o.waveform)

	fn instrument(id i64):
		instruments[id] if id >= 0 and id < instruments.len else instruments[0]

	fn noteOff(e MidiEvent):
		for voice in 0..numVoices:
			if voiceChannel[voice] == e.channel and voiceNote[voice] == e.p1:
				self.writeRegMasked(0xB0 + regSingleOffsets[voice], 0, 0x20)   # the key released
				voiceNote[voice] = 0
				break

	fn noteOn(e MidiEvent):
		if e.p2 == 0:
			self.noteOff(e)
			return
		id = channelInstrument[e.channel]
		ins = self.instrument(id)
		# a free voice, not the one just used: its note may still be dying away
		voice = -1
		test = lastUsedVoice
		loop numVoices:
			test = (test + 1) % numVoices
			if voiceNote[test] == 0:
				voice = test
				break
		lastUsedVoice = voice
		if voice < 0: return
		if voiceInstrument[voice] != id:
			self.writeInstrument(ins, voice)
			voiceInstrument[voice] = id
		voiceNote[voice] = e.p1
		voiceChannel[voice] = e.channel
		# note 69 is A4 at 440 Hz, the game's notes an octave lower unless a SysEx raises them
		octaves = f32(e.p1 - 69 - 12 + semitonesHigher) / f32(12.0)
		frequency = f32(2.0).pow(octaves) * f32(440.0)
		fNumber = frequency * f32(1 << 20) / f32(49716.0)
		block = i64(fNumber.log2() - f32(9.0)) & 7
		f = (i64(fNumber) >> block) & 1023
		r = regSingleOffsets[voice]
		self.writeReg(0xA0 + r, f & 0xFF)
		self.writeReg(0xB0 + r, 0x20 | (block << 2) | (f >> 8))
		self.writeRegMasked(0x40 + regPairOffset(voice, 0), ins.operators[0].kslTl, 0x3F)
		# the carrier's level from its own and the note's velocity
		carrier = (((ins.operators[1].kslTl & 0x3F) + 64) * 225 / (e.p2 + 161)).clamp(64, 127) - 64
		self.writeRegMasked(0x40 + regPairOffset(voice, 1), carrier, 0x3F)

	fn processEvent(e MidiEvent):
		if e.kind == 0x80:
			self.noteOff(e)
		elif e.kind == 0x90:
			self.noteOn(e)
		elif e.kind == 0xC0:
			channelInstrument[e.channel] = e.p1
		elif e.kind == 0xF0:
			if e.data.len == 7 and e.data[2] == 0x34 and (e.data[3] == 0 or e.data[3] == 1) and
				e.data[4] == 0:
				semitonesHigher = i8.wrap(e.data[5])
		elif e.kind == 0xFF and e.meta == 0x51 and e.data.len >= 3:
			tempo = i64(e.data[0]) << 16 | i64(e.data[1]) << 8 | e.data[2]
			usPerBeat = i64(f64(f32(tempo) * f32(1.0 + tempoModifier)))

fn regPairOffset(voice i64, op i64):
	regPairOffsets[sbproOp[voice]] + (3 if op == 1 else 0)

# a tune playing: midi_callback's state between two calls
pub type MidiStream:
	player MidiPlayer
	tracks MidiTrack[]
	ticksPerBeat i64
	rate i64
	pos i64 = 0
	fract f32 = 0.0
	ticksToNextPause i64 = 0
	done bool = false

	# midi_callback: `frames` samples, mono, silence once every track ended
	pub mut fn render(frames i64) f32[]:
		out f32[] = []
		while out.len < frames:
			if done:
				out.push(0.0)
				continue
			if ticksToNextPause > 0:
				self.advance(frames - out.len, out)
			else:
				self.processEvents()
		out

	# the chip run until the next event, or as far as the buffer goes
	fn advance(framesNeeded i64, mut out f32[]):
		usToNextPause = ticksToNextPause * player.usPerBeat / ticksPerBeat
		usNeeded = framesNeeded * 1_000_000 / rate
		advanceUs = usToNextPause.min(usNeeded)
		available = (advanceUs * rate + 999_999) / 1_000_000
		frames = available.min(framesNeeded)
		advanceUs = frames * 1_000_000 / rate
		loop frames:
			left, right = player.chip.nextSample()
			out.push(f32(left + right) / f32(65536.0))
		elapsedF = f32(advanceUs) * f32(ticksPerBeat) / f32(player.usPerBeat)
		elapsed = i64(elapsedF)
		fract += elapsedF - f32(elapsed)
		if fract > f32(1.0):
			fract -= f32(1.0)
			elapsed += 1
		pos += elapsed
		ticksToNextPause -= elapsed

	# the events due on every track, then the pause to the next one
	fn processEvents():
		finished = 0
		for mut t in tracks:
			while pos >= t.nextPauseTick:
				left = t.events.len - t.index
				if left <= 0:
					finished += 1
					break
				player.processEvent(t.events[t.index])
				t.index += 1
				if left > 1 and t.events[t.index].delta != 0:
					t.nextPauseTick += t.events[t.index].delta
		if finished >= tracks.len:
			done = true
			return
		first = -1
		for t in tracks:
			if t.index < t.events.len and pos < t.nextPauseTick:
				if first < 0 or t.nextPauseTick < first: first = t.nextPauseTick
		if first < 0:
			done = true
			return
		ticksToNextPause = first - pos

# play_midi_sound: the chip reset, every voice the first instrument, every channel its own
pub fn startMidi(m u8[], instruments Instrument[], rate i64, tempoModifier f64) MidiStream:
	tracks, division = parseMidi(m)
	player = MidiPlayer(chip = dos.newOpl3(rate), instruments = instruments.copy(), tempoModifier)
	player.writeReg(0x105, 0x01)   # OPL3 on
	for voice in 0..numVoices:
		player.writeInstrument(player.instruments[0], voice)
	MidiStream(player, tracks, ticksPerBeat = division.max(1), rate)
