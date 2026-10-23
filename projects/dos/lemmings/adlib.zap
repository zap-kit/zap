# adlib.dat: the game's AdLib driver ("AdLib Music by Sound Images (c) 1991"), one .DAT section
# of x86 code with its songs and effects in it, run here as Zap. The game calls it as an
# interrupt: AH 2 resets the chip, AH 3 asks for a song (AL 1..21, 22 and up stop the music), AH 4
# for an effect (AL 1..18), AH 5 sets the song playing, and AH 0 is the tick its timer calls
# 1193182 / 16384 times a second. This port reads the driver's own bytes as its memory, at the
# offsets its code uses, and follows that code step by step (disassembled; the offsets of the
# routines are named in the comments).
#
# Its data: a song (the table at 0x0B6C, a word a song) is a header (a word, the instrument bank
# 0x0B6E + word, the tempo in ticks, the count of channels) and a pattern list a channel (offsets
# from 0x0B6E, 0 then the offset to loop to). A pattern is bytes: below 0x80 a note; 0x80 the next
# pattern, 0x81 a rest, 0x82 a tie, 0x83 the end of the music, 0x84 a transposition, 0x85 the
# channel's end, 0x86 and 0x87 a slide up or down by a semitone a tick; 0xB0 a volume (the next
# byte), 0xC0 + n instrument n, 0xE0 + n a duration of n + 1. An instrument is 16 bytes of
# operator registers. An effect (the table at 0x55E3) is a pattern on one of channels 5 to 8.

channelRecords = 0x05AC   # nine records of 20 bytes, the channels' state
recordBytes = 0x14
songRequest = 0x00ED
songPlaying = 0x00EE
songStarting = 0x00EF
effectRequest = 0x00F0
instrumentBank = 0x0B68
tempo = 0x0B6A
tempoCount = 0x0B6B
channelCount = 0x0B6C
songTable = 0x0B6C
dataBase = 0x0B6E
effectBank = 0x54E3
effectTable = 0x55E3
levels = 0x08A7   # volume to total level, 128 entries
octaves = 0x0AA7
semitones = 0x0B07
fNumbers = 0x0927
resetPairs = 0x006D
jumpTable = 0x03EA

# a channel record's fields
note = 0x00
duration = 0x01
instrument = 0x02   # word: the instrument's 16 bytes
operators = 0x05   # the modulator's register offset, the carrier's next
number = 0x07
keyOff = 0x08   # word: register 0xB0 + n and its value without the key bit
patternList = 0x0A   # word
pattern = 0x0C   # word
modLevel = 0x0E
carrierLevel = 0x0F
state = 0x10   # 0 silent, 1 music, 2 an effect
length = 0x11
transpose = 0x12
slide = 0x13

pub ticksPerSecond = 1_193_182.0 / 16_384.0

pub type AdlibDriver:
	mem u8[]
	dx i64 = 0   # the register its instrument command sets and its volume command reads
	chip Opl2
	untilTick f64 = 0.0   # the chip's samples left before the timer's next tick

# the driver of an adlib.dat, the chip reset as the game resets it
pub fn newAdlibDriver(packed u8[]) AdlibDriver:
	sections = sectionsOf(packed)
	if sections.len != 1: fail("adlib.dat has {sections.len} sections, not 1")
	d = AdlibDriver(mem = sections[0].bytes, chip = newOpl2())
	d.reset()
	d

fn memWord(d AdlibDriver, at i64):
	d.mem[at] | i64(d.mem[at + 1]) << 8

fn setMemWord(mut d AdlibDriver, at i64, v i64):
	d.mem[at] = v & 0xff
	d.mem[at + 1] = v >> 8 & 0xff

# a register write as the routine at 0x0559 makes it: AL the register, AH the value
fn out(mut d AdlibDriver, ax i64):
	d.chip.writeRegister(ax & 0xff, ax >> 8 & 0xff)

# AH 2 (0x003A): the music stopped, the chip's operators silenced, every channel free
pub fn reset(mut d AdlibDriver):
	d.stopMusic()
	for i in 0..0x1b:
		d.out(d.memWord(resetPairs + i * 2))
	for c in 0..9:
		d.mem[channelRecords + c * recordBytes + state] = 0

# AH 3: a song asked for (it starts at the next tick)
pub fn requestSong(mut d AdlibDriver, song i64):
	d.mem[songRequest] = u8(song)

# AH 4: an effect asked for
pub fn requestEffect(mut d AdlibDriver, effect i64):
	d.mem[effectRequest] = u8(effect)

# AH 5: the song taken as playing (0: none, so the next request starts)
pub fn setPlaying(mut d AdlibDriver, song i64):
	d.mem[songPlaying] = u8(song)

# the chip's next n samples (-1..1), the driver ticked between them as the game's timer does
pub fn render(mut d AdlibDriver, n i64) f32[]:
	out f32[] = []
	out.reserve(n)
	loop n:
		if d.untilTick <= 0.0:
			d.tick()
			d.untilTick += oplRate / ticksPerSecond
		d.untilTick -= 1.0
		out.push(f32(d.chip.generate()) / 32768.0)
	out

# AH 0 (0x0115): one tick
pub fn tick(mut d AdlibDriver):
	d.startSong()
	d.startEffect()
	d.mem[tempoCount] -= 1
	for c in 0..9:
		d.updateChannel(channelRecords + c * recordBytes)
	if d.mem[tempoCount] == 0:
		d.mem[tempoCount] = d.mem[tempo]

# 0x03AA: the music's channels keyed off and freed
fn stopMusic(mut d AdlibDriver):
	for c in 0..d.memWord(channelCount):
		di = channelRecords + c * recordBytes
		d.out(d.memWord(di + keyOff))
		d.mem[di + state] = 0
	d.setMemWord(songRequest, 0)

# 0x0457: a song asked for starts
fn startSong(mut d AdlibDriver):
	if d.mem[songPlaying] == 0:
		d.mem[songStarting] = d.mem[songRequest]
	song = i64(d.mem[songStarting])
	if song == 0: return
	d.mem[songRequest] = 0
	d.mem[songStarting] = 0
	if song >= 0x16:
		d.stopMusic()
		return
	d.mem[songPlaying] = song
	si = d.memWord(songTable + song * 2)
	for c in 0..9:
		d.mem[channelRecords + c * recordBytes + state] = 0
	d.setMemWord(0x05A8, d.memWord(si))
	d.setMemWord(instrumentBank, d.memWord(si + 2) + dataBase)
	d.mem[tempo] = d.mem[si + 4]
	count = i64(d.mem[si + 5])
	d.setMemWord(channelCount, count)
	for c in 0..count:
		di = channelRecords + c * recordBytes
		bx = d.memWord(si + 6 + c * 2) + dataBase
		d.setMemWord(di + patternList, bx + 2)
		d.setMemWord(di + pattern, d.memWord(bx) + dataBase)
		d.mem[di + duration] = 1
		d.mem[di + state] = 1
	for c in 0..9:
		d.out(d.memWord(channelRecords + c * recordBytes + keyOff))
	for ax in [0x2001, 0xc0bd, 0x0008, 0x2104]:
		d.out(ax)
	d.mem[tempoCount] = 1

# 0x051C: an effect asked for takes the first free channel of 8, 7, 6 and 5, or waits for one
fn startEffect(mut d AdlibDriver):
	effect = i64(d.mem[effectRequest])
	if effect == 0 or effect >= 0x13: return
	for c in [8, 7, 6, 5]:
		di = channelRecords + c * recordBytes
		if d.mem[di + state] != 0: continue
		d.mem[effectRequest] = 0
		d.mem[di + state] = 2
		d.mem[di + slide] = 0
		d.readEvents(di, d.memWord(effectTable + effect * 2))
		return

# 0x0177: a channel's tick: music moves on when the tempo's count runs out, an effect every tick
fn updateChannel(mut d AdlibDriver, di i64):
	if d.mem[di + state] == 0: return
	bx = d.memWord(di + pattern)
	if d.mem[di + state] != 2 and d.mem[tempoCount] != 0: return
	d.mem[di + duration] -= 1
	if d.mem[di + duration] == 0:
		d.readEvents(di, bx)
		return
	d.slideNote(di)
	# 0x03CA: the note keyed off once its duration falls to the instrument's release point,
	# unless a tie follows
	if d.mem[bx] == 0x82: return
	if d.mem[d.memWord(di + instrument) + 0x0e] == d.mem[di + duration]:
		d.out(d.memWord(di + keyOff))
		d.mem[di + slide] = 0

# 0x019E: a pattern's bytes read up to the next note, rest or tie
fn readEvents(mut d AdlibDriver, di i64, from i64):
	bx = from
	while true:
		al = i64(d.mem[bx])
		bx += 1
		if al < 0x80:
			d.mem[di + note] = al
			d.out(d.memWord(di + keyOff))
			d.noteOn(di)
			d.holdNote(di, bx)
			return
		if al >= 0xe0:
			d.mem[di + length] = al - 0xdf
		elif al >= 0xc0:
			d.setInstrument(di, al - 0xc0)
		elif al >= 0xb0:
			d.setVolume(di, d.mem[bx])
			bx += 1
		else:
			match d.memWord(jumpTable + (al * 2 & 0xff)):
				0x0415:
					bx = d.nextPattern(di)
				0x01c0:
					d.out(d.memWord(di + keyOff))
					d.mem[di + slide] = 0
					d.holdNote(di, bx)
					return
				0x01b3:
					d.holdNote(di, bx)
					return
				0x03aa:
					d.stopMusic()
					return
				0x0430:
					d.mem[di + transpose] = d.mem[bx]
					bx += 1
				0x043a:
					d.out(d.memWord(di + keyOff))
					d.mem[di + state] = 0
					return
				0x0447:
					d.mem[di + slide] = 1
				_:
					d.mem[di + slide] = 0xff

# 0x01B3: where the pattern goes on, the duration started again
fn holdNote(mut d AdlibDriver, di i64, bx i64):
	d.setMemWord(di + pattern, bx)
	d.mem[di + duration] = d.mem[di + length]

# 0x0415: the pattern list's next pattern; at its end (a 0) the list goes on at its loop offset
fn nextPattern(mut d AdlibDriver, di i64):
	bx = d.memWord(di + patternList)
	cx = d.memWord(bx)
	bx += 2
	if cx == 0:
		bx = d.memWord(bx) + dataBase
		cx = d.memWord(bx)
		bx += 2
	d.setMemWord(di + patternList, bx)
	d.setMemWord(di + pattern, cx + dataBase)
	cx + dataBase

# 0x0339: a slide moves the note by a semitone a tick
fn slideNote(mut d AdlibDriver, di i64):
	step = d.mem[di + slide]
	if step == 0: return
	d.mem[di + note] += step
	d.noteOn(di)

# 0x0349: the channel's note keyed on: its octave and frequency from the tables
fn noteOn(mut d AdlibDriver, di i64):
	si = (i64(d.mem[di + note]) + i64(d.mem[di + transpose]) + 4) & 0xff
	bl = i64(d.mem[octaves + si]) - 1
	ax = d.memWord(fNumbers + ((i64(d.mem[semitones + si]) * 16) & 0xff) * 2)
	if ax & 0x8000 == 0 and bl < 0:
		bl += 1
		ax >>= 1
	elif ax & 0x8000 != 0:
		bl += 1
		if bl < 0:
			bl += 1
			ax = (ax >> 1) | 0x8000
	ch = i64(d.mem[di + number])
	d.out(((ax & 0xff) << 8) | (0xa0 + ch))
	value = ((ax >> 8) & 3) | (((bl & 0xff) << 2) & 0xff)
	d.setMemWord(di + keyOff, (value << 8) | (0xb0 + ch))
	d.out(((value | 0x20) << 8) | (0xb0 + ch))

# 0x0248: instrument n's registers written to the channel's two operators
fn setInstrument(mut d AdlibDriver, di i64, n i64):
	d.mem[di + 4] = u8(n)
	base = d.memWord(instrumentBank) if di < channelRecords + 4 * recordBytes else effectBank
	si = base + ((((n - 1) & 0xff) * 8) & 0xff) * 2
	d.setMemWord(di + instrument, si)
	d.dx = d.memWord(di + operators)
	dl = d.dx & 0xff
	dh = d.dx >> 8
	for group in [(0x60, 0), (0x80, 2), (0xe0, 6)]:
		r, field = group
		d.out((i64(d.mem[si + field]) << 8) | ((dl + r) & 0xff))
		d.out((i64(d.mem[si + field + 1]) << 8) | ((dh + r) & 0xff))
	d.out((i64(d.mem[si + 9]) << 8) | (i64(d.mem[di + number]) + 0xc0))
	d.out((i64(d.mem[si + 4]) << 8) | ((dl + 0x20) & 0xff))
	d.out((i64(d.mem[si + 5]) << 8) | ((dh + 0x20) & 0xff))
	d.mem[di + transpose] = d.mem[si + 8]
	d.mem[di + modLevel] = d.mem[si + 0x0a]
	d.mem[di + carrierLevel] = d.mem[si + 0x0b]
	d.writeLevels(di, si, d.mem[si + 0x0a])
	d.mem[di + transpose] = d.mem[si + 8]

# 0x01F4: the volume command: a new modulator level (the carrier's is the instrument's still)
fn setVolume(mut d AdlibDriver, di i64, v i64):
	d.mem[di + modLevel] = u8(v)
	d.writeLevels(di, d.memWord(di + instrument), v)

# the operators' total levels: the modulator's from `level`, the carrier's from the record's
# offset and the instrument's level; the scaling bits of byte 0x0C
fn writeLevels(mut d AdlibDriver, di i64, si i64, level i64):
	dl = d.dx & 0xff
	dh = d.dx >> 8
	ksl = i64(d.mem[si + 0x0c])
	modTl = i64(d.mem[levels + (level & 0x7f)]) | ((ksl << 2) & 0xc0)
	d.out((modTl << 8) | ((dl + 0x40) & 0xff))
	carrier = (i64(d.mem[di + carrierLevel]) + i64(d.mem[si + 0x0a])) & 0x7f
	carTl = i64(d.mem[levels + carrier]) | ((ksl << 6) & 0xc0)
	d.out((carTl << 8) | ((dh + 0x40) & 0xff))
