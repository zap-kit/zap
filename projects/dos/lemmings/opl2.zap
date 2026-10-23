# The OPL2 (Yamaha YM3812), the FM chip of the AdLib and the Sound Blaster: nine channels of two
# operators, a sample of 16 bits each 49716th of a second, written by its registers. A port of
# Nuked OPL3 1.8 (Nuke.YKT, github.com/nukeykt/Nuked-OPL3, LGPL 2.1) in its OPL2 mode: the
# second register bank, four-operator channels and the stereo outputs left out; the waveform
# select enable of register 1 is the OPL2's, which Nuked's OPL3 has always on.

pub oplRate = 49_716

# long: the chip's ROM tables, as Nuked OPL3 has them
logsinrom = [
	0x859, 0x6c3, 0x607, 0x58b, 0x52e, 0x4e4, 0x4a6, 0x471, 0x443, 0x41a, 0x3f5, 0x3d3, 0x3b5,
	0x398, 0x37e, 0x365, 0x34e, 0x339, 0x324, 0x311, 0x2ff, 0x2ed, 0x2dc, 0x2cd, 0x2bd, 0x2af,
	0x2a0, 0x293, 0x286, 0x279, 0x26d, 0x261, 0x256, 0x24b, 0x240, 0x236, 0x22c, 0x222, 0x218,
	0x20f, 0x206, 0x1fd, 0x1f5, 0x1ec, 0x1e4, 0x1dc, 0x1d4, 0x1cd, 0x1c5, 0x1be, 0x1b7, 0x1b0,
	0x1a9, 0x1a2, 0x19b, 0x195, 0x18f, 0x188, 0x182, 0x17c, 0x177, 0x171, 0x16b, 0x166, 0x160,
	0x15b, 0x155, 0x150, 0x14b, 0x146, 0x141, 0x13c, 0x137, 0x133, 0x12e, 0x129, 0x125, 0x121,
	0x11c, 0x118, 0x114, 0x10f, 0x10b, 0x107, 0x103, 0x0ff, 0x0fb, 0x0f8, 0x0f4, 0x0f0, 0x0ec,
	0x0e9, 0x0e5, 0x0e2, 0x0de, 0x0db, 0x0d7, 0x0d4, 0x0d1, 0x0cd, 0x0ca, 0x0c7, 0x0c4, 0x0c1,
	0x0be, 0x0bb, 0x0b8, 0x0b5, 0x0b2, 0x0af, 0x0ac, 0x0a9, 0x0a7, 0x0a4, 0x0a1, 0x09f, 0x09c,
	0x099, 0x097, 0x094, 0x092, 0x08f, 0x08d, 0x08a, 0x088, 0x086, 0x083, 0x081, 0x07f, 0x07d,
	0x07a, 0x078, 0x076, 0x074, 0x072, 0x070, 0x06e, 0x06c, 0x06a, 0x068, 0x066, 0x064, 0x062,
	0x060, 0x05e, 0x05c, 0x05b, 0x059, 0x057, 0x055, 0x053, 0x052, 0x050, 0x04e, 0x04d, 0x04b,
	0x04a, 0x048, 0x046, 0x045, 0x043, 0x042, 0x040, 0x03f, 0x03e, 0x03c, 0x03b, 0x039, 0x038,
	0x037, 0x035, 0x034, 0x033, 0x031, 0x030, 0x02f, 0x02e, 0x02d, 0x02b, 0x02a, 0x029, 0x028,
	0x027, 0x026, 0x025, 0x024, 0x023, 0x022, 0x021, 0x020, 0x01f, 0x01e, 0x01d, 0x01c, 0x01b,
	0x01a, 0x019, 0x018, 0x017, 0x017, 0x016, 0x015, 0x014, 0x014, 0x013, 0x012, 0x011, 0x011,
	0x010, 0x00f, 0x00f, 0x00e, 0x00d, 0x00d, 0x00c, 0x00c, 0x00b, 0x00a, 0x00a, 0x009, 0x009,
	0x008, 0x008, 0x007, 0x007, 0x007, 0x006, 0x006, 0x005, 0x005, 0x005, 0x004, 0x004, 0x004,
	0x003, 0x003, 0x003, 0x002, 0x002, 0x002, 0x002, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001,
	0x001, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000
]

exprom = [
	0x7fa, 0x7f5, 0x7ef, 0x7ea, 0x7e4, 0x7df, 0x7da, 0x7d4, 0x7cf, 0x7c9, 0x7c4, 0x7bf, 0x7b9,
	0x7b4, 0x7ae, 0x7a9, 0x7a4, 0x79f, 0x799, 0x794, 0x78f, 0x78a, 0x784, 0x77f, 0x77a, 0x775,
	0x770, 0x76a, 0x765, 0x760, 0x75b, 0x756, 0x751, 0x74c, 0x747, 0x742, 0x73d, 0x738, 0x733,
	0x72e, 0x729, 0x724, 0x71f, 0x71a, 0x715, 0x710, 0x70b, 0x706, 0x702, 0x6fd, 0x6f8, 0x6f3,
	0x6ee, 0x6e9, 0x6e5, 0x6e0, 0x6db, 0x6d6, 0x6d2, 0x6cd, 0x6c8, 0x6c4, 0x6bf, 0x6ba, 0x6b5,
	0x6b1, 0x6ac, 0x6a8, 0x6a3, 0x69e, 0x69a, 0x695, 0x691, 0x68c, 0x688, 0x683, 0x67f, 0x67a,
	0x676, 0x671, 0x66d, 0x668, 0x664, 0x65f, 0x65b, 0x657, 0x652, 0x64e, 0x649, 0x645, 0x641,
	0x63c, 0x638, 0x634, 0x630, 0x62b, 0x627, 0x623, 0x61e, 0x61a, 0x616, 0x612, 0x60e, 0x609,
	0x605, 0x601, 0x5fd, 0x5f9, 0x5f5, 0x5f0, 0x5ec, 0x5e8, 0x5e4, 0x5e0, 0x5dc, 0x5d8, 0x5d4,
	0x5d0, 0x5cc, 0x5c8, 0x5c4, 0x5c0, 0x5bc, 0x5b8, 0x5b4, 0x5b0, 0x5ac, 0x5a8, 0x5a4, 0x5a0,
	0x59c, 0x599, 0x595, 0x591, 0x58d, 0x589, 0x585, 0x581, 0x57e, 0x57a, 0x576, 0x572, 0x56f,
	0x56b, 0x567, 0x563, 0x560, 0x55c, 0x558, 0x554, 0x551, 0x54d, 0x549, 0x546, 0x542, 0x53e,
	0x53b, 0x537, 0x534, 0x530, 0x52c, 0x529, 0x525, 0x522, 0x51e, 0x51b, 0x517, 0x514, 0x510,
	0x50c, 0x509, 0x506, 0x502, 0x4ff, 0x4fb, 0x4f8, 0x4f4, 0x4f1, 0x4ed, 0x4ea, 0x4e7, 0x4e3,
	0x4e0, 0x4dc, 0x4d9, 0x4d6, 0x4d2, 0x4cf, 0x4cc, 0x4c8, 0x4c5, 0x4c2, 0x4be, 0x4bb, 0x4b8,
	0x4b5, 0x4b1, 0x4ae, 0x4ab, 0x4a8, 0x4a4, 0x4a1, 0x49e, 0x49b, 0x498, 0x494, 0x491, 0x48e,
	0x48b, 0x488, 0x485, 0x482, 0x47e, 0x47b, 0x478, 0x475, 0x472, 0x46f, 0x46c, 0x469, 0x466,
	0x463, 0x460, 0x45d, 0x45a, 0x457, 0x454, 0x451, 0x44e, 0x44b, 0x448, 0x445, 0x442, 0x43f,
	0x43c, 0x439, 0x436, 0x433, 0x430, 0x42d, 0x42a, 0x428, 0x425, 0x422, 0x41f, 0x41c, 0x419,
	0x416, 0x414, 0x411, 0x40e, 0x40b, 0x408, 0x406, 0x403, 0x400
]

multipliers = [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30]   # twice the multiple
kslrom = [0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64]
kslshift = [8, 1, 2, 0]
egIncStep = [[0, 0, 0, 0], [1, 0, 0, 0], [1, 0, 1, 0], [1, 1, 1, 0]]

# a register's low five bits: its operator, -1 for none
slotOfRegister = [
	0, 1, 2, 3, 4, 5, -1, -1, 6, 7, 8, 9, 10, 11, -1, -1, 12, 13, 14, 15, 16, 17, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1
]
firstSlotOfChannel = [0, 1, 2, 6, 7, 8, 12, 13, 14]

attack = 0
decay = 1
sustain = 2
release = 3
keyNormal = 1
keyDrum = 2
silent = -1   # a modulation or an output of nothing
ownFeedback = -2   # the operator's own feedback as its modulation

type Operator:
	channel i64
	out i64 = 0
	fbmod i64 = 0
	mod i64 = silent   # the operator whose output modulates this one, or silent or ownFeedback
	prout i64 = 0
	egRout i64 = 0x1ff
	egOut i64 = 0x1ff
	egGen i64 = release
	egKsl i64 = 0
	tremolo bool = false
	vib bool = false
	sustaining bool = false   # reg_type: holds at the sustain level while keyed
	ksr i64 = 0
	mult i64 = 0
	ksl i64 = 0
	tl i64 = 0
	ar i64 = 0
	dr i64 = 0
	sl i64 = 0
	rr i64 = 0
	wf i64 = 0
	key i64 = 0
	pgReset bool = false
	pgPhase i64 = 0
	pgPhaseOut i64 = 0
	num i64

type Channel:
	a i64   # its operators
	b i64
	outs i64[4] = [silent, silent, silent, silent]   # the operators summed into the mix
	drum bool = false
	fNum i64 = 0
	block i64 = 0
	fb i64 = 0
	con i64 = 0
	ksv i64 = 0
	num i64

pub type Opl2:
	ops Operator[] = []
	channels Channel[] = []
	timer i64 = 0
	egTimer i64 = 0
	egTimerRem i64 = 0
	egState i64 = 0
	egAdd i64 = 0
	egTimerLo i64 = 0
	nts i64 = 0
	rhy i64 = 0
	vibpos i64 = 0
	vibshift i64 = 1
	tremolo i64 = 0
	tremolopos i64 = 0
	tremoloshift i64 = 4
	noise i64 = 1
	waveforms bool = false   # register 1's bit 5: the operators may choose a waveform
	hhBit2 i64 = 0
	hhBit3 i64 = 0
	hhBit7 i64 = 0
	hhBit8 i64 = 0
	tcBit3 i64 = 0
	tcBit5 i64 = 0

# a chip as it is after a reset
pub fn newOpl2() Opl2:
	chip = Opl2()
	for i in 0..18:
		chip.ops.push(Operator(channel = 0, num = i))
	for c in 0..9:
		first = firstSlotOfChannel[c]
		chip.ops[first].channel = c
		chip.ops[first + 3].channel = c
		chip.channels.push(Channel(a = first, b = first + 3, num = c))
		chip.setupAlgorithm(c)
	chip

# ---------- the envelope ----------

fn calcExp(level i64):
	l = level.min(0x1fff)
	(exprom[l & 0xff] << 1) >> (l >> 8)

# the operator's output for a phase and an attenuation, by waveform (OPL2 has the first four)
fn sinOut(wf i64, phase0 i64, envelope i64):
	phase = phase0 & 0x3ff
	env = envelope << 3
	match wf:
		0:
			out = logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0
				else logsinrom[phase & 0xff]
			v = calcExp(out + env)
			-v - 1 if phase & 0x200 != 0 else v
		1:
			out = 0x1000 if phase & 0x200 != 0
				else logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0
				else logsinrom[phase & 0xff]
			calcExp(out + env)
		2:
			out = logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0
				else logsinrom[phase & 0xff]
			calcExp(out + env)
		_:
			out = 0x1000 if phase & 0x100 != 0 else logsinrom[phase & 0xff]
			calcExp(out + env)

fn updateKsl(mut chip Opl2, slot i64):
	ch = chip.channels[chip.ops[slot].channel]
	ksl = (kslrom[ch.fNum >> 6] << 2) - ((8 - ch.block) << 5)
	chip.ops[slot].egKsl = ksl.max(0)

# the rate's shift of the envelope this sample
fn envelopeShift(chip Opl2, rateHi i64, rateLo i64, nonzero bool):
	if not nonzero: return 0
	if rateHi < 12:
		if chip.egState == 0: return 0
		match rateHi + chip.egAdd:
			12: return 1
			13: return (rateLo >> 1) & 1
			14: return rateLo & 1
			_: return 0
	shift = (rateHi & 3) + egIncStep[rateLo][chip.egTimerLo]
	if shift & 4 != 0:
		shift = 3
	if shift == 0:
		shift = chip.egState
	shift

fn envelopeCalc(mut chip Opl2, s i64):
	op = chip.ops[s]
	trem = chip.tremolo if op.tremolo else 0
	op.egOut = op.egRout + (op.tl << 2) + (op.egKsl >> kslshift[op.ksl]) + trem
	reset = false
	regRate = 0
	if op.key != 0 and op.egGen == release:
		reset = true
		regRate = op.ar
	else:
		regRate = match op.egGen:
			0: op.ar
			1: op.dr
			2: 0 if op.sustaining else op.rr
			_: op.rr
	op.pgReset = reset
	ks = chip.channels[op.channel].ksv >> ((op.ksr ^ 1) << 1)
	rate = ks + (regRate << 2)
	rateHi = rate >> 2
	rateLo = rate & 3
	if rateHi & 0x10 != 0:
		rateHi = 0x0f
	shift = chip.envelopeShift(rateHi, rateLo, regRate != 0)
	egRout = op.egRout
	egInc = 0
	if reset and rateHi == 0x0f:
		egRout = 0
	off = op.egRout & 0x1f8 == 0x1f8
	if op.egGen != attack and not reset and off:
		egRout = 0x1ff
	if op.egGen == attack:
		if op.egRout == 0:
			op.egGen = decay
		elif op.key != 0 and shift > 0 and rateHi != 0x0f:
			egInc = (~op.egRout) >> (4 - shift)
	elif op.egGen == decay:
		if op.egRout >> 4 == op.sl:
			op.egGen = sustain
		elif not off and not reset and shift > 0:
			egInc = 1 << (shift - 1)
	elif not off and not reset and shift > 0:
		egInc = 1 << (shift - 1)
	op.egRout = (egRout + egInc) & 0x1ff
	if reset:
		op.egGen = attack
	if op.key == 0:
		op.egGen = release
	chip.ops[s] = op

# ---------- the phase ----------

fn phaseGenerate(mut chip Opl2, s i64):
	op = chip.ops[s]
	ch = chip.channels[op.channel]
	fNum = ch.fNum
	if op.vib:
		range = (fNum >> 7) & 7
		if chip.vibpos & 3 == 0:
			range = 0
		elif chip.vibpos & 1 != 0:
			range >>= 1
		range >>= chip.vibshift
		if chip.vibpos & 4 != 0:
			range = -range
		fNum = (fNum + range) & 0xffff
	basefreq = (fNum << ch.block) >> 1
	phase = (op.pgPhase >> 9) & 0xffff
	if op.pgReset:
		op.pgPhase = 0
	op.pgPhase = (op.pgPhase + ((basefreq * multipliers[op.mult]) >> 1)) & 0xffff_ffff
	op.pgPhaseOut = phase
	if s == 13:   # the hi-hat
		chip.hhBit2 = (phase >> 2) & 1
		chip.hhBit3 = (phase >> 3) & 1
		chip.hhBit7 = (phase >> 7) & 1
		chip.hhBit8 = (phase >> 8) & 1
	if s == 17 and chip.rhy & 0x20 != 0:   # the top cymbal
		chip.tcBit3 = (phase >> 3) & 1
		chip.tcBit5 = (phase >> 5) & 1
	if chip.rhy & 0x20 != 0:
		rmXor = (chip.hhBit2 ^ chip.hhBit7) | (chip.hhBit3 ^ chip.tcBit5) | (
			chip.tcBit3 ^ chip.tcBit5
		)
		if s == 13:
			op.pgPhaseOut = rmXor << 9 | (0xd0 if (rmXor ^ (chip.noise & 1)) != 0 else 0x34)
		elif s == 16:
			op.pgPhaseOut = chip.hhBit8 << 9 | (chip.hhBit8 ^ (chip.noise & 1)) << 8
		elif s == 17:
			op.pgPhaseOut = rmXor << 9 | 0x80
	chip.ops[s] = op
	chip.clockNoise()

fn clockNoise(mut chip Opl2):
	bit = ((chip.noise >> 14) ^ chip.noise) & 1
	chip.noise = (chip.noise >> 1) | (bit << 22)

# ---------- an operator's sample ----------

fn modulation(chip Opl2, op Operator):
	if op.mod == silent: return 0
	if op.mod == ownFeedback: return op.fbmod
	chip.ops[op.mod].out

fn processSlot(mut chip Opl2, s i64):
	fb = chip.channels[chip.ops[s].channel].fb
	op = chip.ops[s]
	op.fbmod = (op.prout + op.out) >> (9 - fb) if fb != 0 else 0
	op.prout = op.out
	chip.ops[s] = op
	chip.envelopeCalc(s)
	chip.phaseGenerate(s)
	o = chip.ops[s]
	wf = o.wf if chip.waveforms else 0
	chip.ops[s].out = sinOut(wf, o.pgPhaseOut + chip.modulation(o), o.egOut)

fn channelSum(chip Opl2, c i64):
	accm = 0
	for o in chip.channels[c].outs:
		if o != silent:
			accm += chip.ops[o].out
	# the chip adds in 16 bits
	(accm & 0xffff ^ 0x8000) - 0x8000

# the next sample, -32768..32767
pub fn generate(mut chip Opl2) i64:
	# the quirk Nuked keeps: the last three operators come after the left channel's mix
	for s in 0..15:
		chip.processSlot(s)
	mix = 0
	for c in 0..9:
		mix += chip.channelSum(c)
	for s in 15..18:
		chip.processSlot(s)
	# the second bank's operators clock the noise too
	loop 18:
		chip.clockNoise()
	chip.advanceTimers()
	mix.clamp(-32_768, 32_767)

fn advanceTimers(mut chip Opl2):
	if chip.timer & 0x3f == 0x3f:
		chip.tremolopos = (chip.tremolopos + 1) % 210
	chip.tremolo = (
		chip.tremolopos if chip.tremolopos < 105 else 210 - chip.tremolopos
	) >> chip.tremoloshift
	if chip.timer & 0x3ff == 0x3ff:
		chip.vibpos = (chip.vibpos + 1) & 7
	chip.timer = (chip.timer + 1) & 0xffff
	if chip.egState != 0:
		shift = 0
		while shift < 13 and (chip.egTimer >> shift) & 1 == 0:
			shift += 1
		chip.egAdd = 0 if shift > 12 else shift + 1
		chip.egTimerLo = chip.egTimer & 3
	if chip.egTimerRem != 0 or chip.egState != 0:
		if chip.egTimer == 0xf_ffff_ffff:
			chip.egTimer = 0
			chip.egTimerRem = 1
		else:
			chip.egTimer += 1
			chip.egTimerRem = 0
	chip.egState ^= 1

# ---------- the registers ----------

fn setupAlgorithm(mut chip Opl2, c i64):
	ch = chip.channels[c]
	a = ch.a
	b = ch.b
	if ch.drum:
		if c == 7 or c == 8:
			chip.ops[a].mod = silent
			chip.ops[b].mod = silent
			return
		chip.ops[a].mod = ownFeedback
		chip.ops[b].mod = a if ch.con == 0 else silent
		return
	chip.ops[a].mod = ownFeedback
	if ch.con == 0:
		chip.ops[b].mod = a
		chip.channels[c].outs = [b, silent, silent, silent]
	else:
		chip.ops[b].mod = silent
		chip.channels[c].outs = [a, b, silent, silent]

fn updateRhythm(mut chip Opl2, v i64):
	chip.rhy = v & 0x3f
	if chip.rhy & 0x20 != 0:
		c6 = chip.channels[6]
		c7 = chip.channels[7]
		c8 = chip.channels[8]
		chip.channels[6].outs = [c6.b, c6.b, silent, silent]
		chip.channels[7].outs = [c7.a, c7.a, c7.b, c7.b]
		chip.channels[8].outs = [c8.a, c8.a, c8.b, c8.b]
		for c in 6..9:
			chip.channels[c].drum = true
			chip.setupAlgorithm(c)
		chip.drumKey(c7.a, chip.rhy & 0x01)   # hi-hat
		chip.drumKey(c8.b, chip.rhy & 0x02)   # top cymbal
		chip.drumKey(c8.a, chip.rhy & 0x04)   # tom
		chip.drumKey(c7.b, chip.rhy & 0x08)   # snare
		chip.drumKey(c6.a, chip.rhy & 0x10)   # bass drum
		chip.drumKey(c6.b, chip.rhy & 0x10)
	else:
		for c in 6..9:
			chip.channels[c].drum = false
			chip.setupAlgorithm(c)
			chip.ops[chip.channels[c].a].key &= ~keyDrum
			chip.ops[chip.channels[c].b].key &= ~keyDrum

fn drumKey(mut chip Opl2, s i64, on i64):
	if on != 0:
		chip.ops[s].key |= keyDrum
	else:
		chip.ops[s].key &= ~keyDrum

fn updateFrequency(mut chip Opl2, c i64):
	ch = chip.channels[c]
	chip.channels[c].ksv = ch.block << 1 | (ch.fNum >> (9 - chip.nts)) & 1
	chip.updateKsl(ch.a)
	chip.updateKsl(ch.b)

fn writeOperator(mut chip Opl2, group i64, s i64, v i64):
	op = chip.ops[s]
	match group:
		0x20:
			op.tremolo = (v >> 7) & 1 != 0
			op.vib = (v >> 6) & 1 != 0
			op.sustaining = (v >> 5) & 1 != 0
			op.ksr = (v >> 4) & 1
			op.mult = v & 0x0f
		0x40:
			op.ksl = (v >> 6) & 3
			op.tl = v & 0x3f
		0x60:
			op.ar = (v >> 4) & 0x0f
			op.dr = v & 0x0f
		0x80:
			op.sl = (v >> 4) & 0x0f
			if op.sl == 0x0f:
				op.sl = 0x1f
			op.rr = v & 0x0f
		_:
			op.wf = v & 3
	chip.ops[s] = op
	if group == 0x40:
		chip.updateKsl(s)

# a write to register `reg` (0..0xff) of the value v
pub fn writeRegister(mut chip Opl2, reg i64, v i64):
	group = reg & 0xf0
	low = reg & 0x0f
	if reg == 0x01:
		chip.waveforms = v & 0x20 != 0
	elif reg == 0x08:
		chip.nts = (v >> 6) & 1
	elif group in [0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xe0, 0xf0]:
		s = slotOfRegister[reg & 0x1f]
		if s >= 0:
			chip.writeOperator(group & 0xe0, s, v)
	elif group == 0xa0 and low < 9:
		chip.channels[low].fNum = chip.channels[low].fNum & 0x300 | v
		chip.updateFrequency(low)
	elif reg == 0xbd:
		chip.tremoloshift = (((v >> 7) ^ 1) << 1) + 2
		chip.vibshift = ((v >> 6) & 1) ^ 1
		chip.updateRhythm(v)
	elif group == 0xb0 and low < 9:
		chip.channels[low].fNum = chip.channels[low].fNum & 0xff | (v & 3) << 8
		chip.channels[low].block = (v >> 2) & 7
		chip.updateFrequency(low)
		ch = chip.channels[low]
		for s in [ch.a, ch.b]:
			if v & 0x20 != 0:
				chip.ops[s].key |= keyNormal
			else:
				chip.ops[s].key &= ~keyNormal
	elif group == 0xc0 and low < 9:
		chip.channels[low].fb = (v & 0x0e) >> 1
		chip.channels[low].con = v & 1
		chip.setupAlgorithm(low)

test "a keyed sine sounds and a released one falls silent":
	chip = newOpl2()
	chip.writeRegister(0x20, 0x21)   # the modulator and the carrier held, at the base frequency
	chip.writeRegister(0x23, 0x21)
	chip.writeRegister(0x40, 0x3f)   # the modulator silent: a pure sine
	chip.writeRegister(0x43, 0x00)
	chip.writeRegister(0x60, 0xf0)
	chip.writeRegister(0x63, 0xf0)
	chip.writeRegister(0x80, 0x0f)
	chip.writeRegister(0x83, 0x0f)
	chip.writeRegister(0xa0, 0x41)   # 440 Hz: f-number 0x241, block 4
	chip.writeRegister(0xb0, 0x32)
	peak = 0
	crossings = 0
	last = 0
	loop oplRate / 10:
		v = chip.generate()
		peak = peak.max(v.abs())
		if last < 0 and v >= 0:
			crossings += 1
		last = v
	expect peak > 3000
	expect crossings >= 43 and crossings <= 45
	chip.writeRegister(0xb0, 0x12)
	loop oplRate:
		chip.generate()
	expect chip.generate().abs() < 16
