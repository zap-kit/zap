# The Yamaha OPL3 FM synthesizer of the Sound Blaster and AdLib cards, as Nuked OPL3 1.7.4
# (Alexey Khokholov, GPL-2) emulates it, for the paths two-operator music takes: 18 channels of
# 2 operators, the waveforms, envelopes, vibrato and tremolo, resampled from the chip's 49716 Hz.
# Not here: the 4-operator modes and the rhythm section, which no tune of these games turns on.

logsinrom = [
	0x859,
	0x6c3,
	0x607,
	0x58b,
	0x52e,
	0x4e4,
	0x4a6,
	0x471,
	0x443,
	0x41a,
	0x3f5,
	0x3d3,
	0x3b5,
	0x398,
	0x37e,
	0x365,
	0x34e,
	0x339,
	0x324,
	0x311,
	0x2ff,
	0x2ed,
	0x2dc,
	0x2cd,
	0x2bd,
	0x2af,
	0x2a0,
	0x293,
	0x286,
	0x279,
	0x26d,
	0x261,
	0x256,
	0x24b,
	0x240,
	0x236,
	0x22c,
	0x222,
	0x218,
	0x20f,
	0x206,
	0x1fd,
	0x1f5,
	0x1ec,
	0x1e4,
	0x1dc,
	0x1d4,
	0x1cd,
	0x1c5,
	0x1be,
	0x1b7,
	0x1b0,
	0x1a9,
	0x1a2,
	0x19b,
	0x195,
	0x18f,
	0x188,
	0x182,
	0x17c,
	0x177,
	0x171,
	0x16b,
	0x166,
	0x160,
	0x15b,
	0x155,
	0x150,
	0x14b,
	0x146,
	0x141,
	0x13c,
	0x137,
	0x133,
	0x12e,
	0x129,
	0x125,
	0x121,
	0x11c,
	0x118,
	0x114,
	0x10f,
	0x10b,
	0x107,
	0x103,
	0x0ff,
	0x0fb,
	0x0f8,
	0x0f4,
	0x0f0,
	0x0ec,
	0x0e9,
	0x0e5,
	0x0e2,
	0x0de,
	0x0db,
	0x0d7,
	0x0d4,
	0x0d1,
	0x0cd,
	0x0ca,
	0x0c7,
	0x0c4,
	0x0c1,
	0x0be,
	0x0bb,
	0x0b8,
	0x0b5,
	0x0b2,
	0x0af,
	0x0ac,
	0x0a9,
	0x0a7,
	0x0a4,
	0x0a1,
	0x09f,
	0x09c,
	0x099,
	0x097,
	0x094,
	0x092,
	0x08f,
	0x08d,
	0x08a,
	0x088,
	0x086,
	0x083,
	0x081,
	0x07f,
	0x07d,
	0x07a,
	0x078,
	0x076,
	0x074,
	0x072,
	0x070,
	0x06e,
	0x06c,
	0x06a,
	0x068,
	0x066,
	0x064,
	0x062,
	0x060,
	0x05e,
	0x05c,
	0x05b,
	0x059,
	0x057,
	0x055,
	0x053,
	0x052,
	0x050,
	0x04e,
	0x04d,
	0x04b,
	0x04a,
	0x048,
	0x046,
	0x045,
	0x043,
	0x042,
	0x040,
	0x03f,
	0x03e,
	0x03c,
	0x03b,
	0x039,
	0x038,
	0x037,
	0x035,
	0x034,
	0x033,
	0x031,
	0x030,
	0x02f,
	0x02e,
	0x02d,
	0x02b,
	0x02a,
	0x029,
	0x028,
	0x027,
	0x026,
	0x025,
	0x024,
	0x023,
	0x022,
	0x021,
	0x020,
	0x01f,
	0x01e,
	0x01d,
	0x01c,
	0x01b,
	0x01a,
	0x019,
	0x018,
	0x017,
	0x017,
	0x016,
	0x015,
	0x014,
	0x014,
	0x013,
	0x012,
	0x011,
	0x011,
	0x010,
	0x00f,
	0x00f,
	0x00e,
	0x00d,
	0x00d,
	0x00c,
	0x00c,
	0x00b,
	0x00a,
	0x00a,
	0x009,
	0x009,
	0x008,
	0x008,
	0x007,
	0x007,
	0x007,
	0x006,
	0x006,
	0x005,
	0x005,
	0x005,
	0x004,
	0x004,
	0x004,
	0x003,
	0x003,
	0x003,
	0x002,
	0x002,
	0x002,
	0x002,
	0x001,
	0x001,
	0x001,
	0x001,
	0x001,
	0x001,
	0x001,
	0x000,
	0x000,
	0x000,
	0x000,
	0x000,
	0x000,
	0x000,
	0x000
]

exprom = [
	0x000,
	0x003,
	0x006,
	0x008,
	0x00b,
	0x00e,
	0x011,
	0x014,
	0x016,
	0x019,
	0x01c,
	0x01f,
	0x022,
	0x025,
	0x028,
	0x02a,
	0x02d,
	0x030,
	0x033,
	0x036,
	0x039,
	0x03c,
	0x03f,
	0x042,
	0x045,
	0x048,
	0x04b,
	0x04e,
	0x051,
	0x054,
	0x057,
	0x05a,
	0x05d,
	0x060,
	0x063,
	0x066,
	0x069,
	0x06c,
	0x06f,
	0x072,
	0x075,
	0x078,
	0x07b,
	0x07e,
	0x082,
	0x085,
	0x088,
	0x08b,
	0x08e,
	0x091,
	0x094,
	0x098,
	0x09b,
	0x09e,
	0x0a1,
	0x0a4,
	0x0a8,
	0x0ab,
	0x0ae,
	0x0b1,
	0x0b5,
	0x0b8,
	0x0bb,
	0x0be,
	0x0c2,
	0x0c5,
	0x0c8,
	0x0cc,
	0x0cf,
	0x0d2,
	0x0d6,
	0x0d9,
	0x0dc,
	0x0e0,
	0x0e3,
	0x0e7,
	0x0ea,
	0x0ed,
	0x0f1,
	0x0f4,
	0x0f8,
	0x0fb,
	0x0ff,
	0x102,
	0x106,
	0x109,
	0x10c,
	0x110,
	0x114,
	0x117,
	0x11b,
	0x11e,
	0x122,
	0x125,
	0x129,
	0x12c,
	0x130,
	0x134,
	0x137,
	0x13b,
	0x13e,
	0x142,
	0x146,
	0x149,
	0x14d,
	0x151,
	0x154,
	0x158,
	0x15c,
	0x160,
	0x163,
	0x167,
	0x16b,
	0x16f,
	0x172,
	0x176,
	0x17a,
	0x17e,
	0x181,
	0x185,
	0x189,
	0x18d,
	0x191,
	0x195,
	0x199,
	0x19c,
	0x1a0,
	0x1a4,
	0x1a8,
	0x1ac,
	0x1b0,
	0x1b4,
	0x1b8,
	0x1bc,
	0x1c0,
	0x1c4,
	0x1c8,
	0x1cc,
	0x1d0,
	0x1d4,
	0x1d8,
	0x1dc,
	0x1e0,
	0x1e4,
	0x1e8,
	0x1ec,
	0x1f0,
	0x1f5,
	0x1f9,
	0x1fd,
	0x201,
	0x205,
	0x209,
	0x20e,
	0x212,
	0x216,
	0x21a,
	0x21e,
	0x223,
	0x227,
	0x22b,
	0x230,
	0x234,
	0x238,
	0x23c,
	0x241,
	0x245,
	0x249,
	0x24e,
	0x252,
	0x257,
	0x25b,
	0x25f,
	0x264,
	0x268,
	0x26d,
	0x271,
	0x276,
	0x27a,
	0x27f,
	0x283,
	0x288,
	0x28c,
	0x291,
	0x295,
	0x29a,
	0x29e,
	0x2a3,
	0x2a8,
	0x2ac,
	0x2b1,
	0x2b5,
	0x2ba,
	0x2bf,
	0x2c4,
	0x2c8,
	0x2cd,
	0x2d2,
	0x2d6,
	0x2db,
	0x2e0,
	0x2e5,
	0x2e9,
	0x2ee,
	0x2f3,
	0x2f8,
	0x2fd,
	0x302,
	0x306,
	0x30b,
	0x310,
	0x315,
	0x31a,
	0x31f,
	0x324,
	0x329,
	0x32e,
	0x333,
	0x338,
	0x33d,
	0x342,
	0x347,
	0x34c,
	0x351,
	0x356,
	0x35b,
	0x360,
	0x365,
	0x36a,
	0x370,
	0x375,
	0x37a,
	0x37f,
	0x384,
	0x38a,
	0x38f,
	0x394,
	0x399,
	0x39f,
	0x3a4,
	0x3a9,
	0x3ae,
	0x3b4,
	0x3b9,
	0x3bf,
	0x3c4,
	0x3c9,
	0x3cf,
	0x3d4,
	0x3da,
	0x3df,
	0x3e4,
	0x3ea,
	0x3ef,
	0x3f5,
	0x3fa
]

# the frequency multipliers, doubled
mt = [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30]
kslrom = [0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64]
kslshift = [8, 1, 2, 0]

# the envelope's steps: [kind][rate's low bits][timer's 3 bits], flattened
egIncstep = [
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1
]
egIncdesc = [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2]
egIncsh = [0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 0, -1, -2]

# a register's operator by its low 5 bits, -1 for none
adSlot = [
	0,
	1,
	2,
	3,
	4,
	5,
	-1,
	-1,
	6,
	7,
	8,
	9,
	10,
	11,
	-1,
	-1,
	12,
	13,
	14,
	15,
	16,
	17,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1,
	-1
]
chSlot = [0, 1, 2, 6, 7, 8, 12, 13, 14, 18, 19, 20, 24, 25, 26, 30, 31, 32]

egOff = 0
egAttack = 1
egDecay = 2
egSustain = 3
egRelease = 4

# where an operator's modulation and a channel's outputs come from: nothing, an operator's
# output, or an operator's feedback
zeroSource = -1
fbSource = 1000

type OplSlot:
	channel i64 = 0
	out i64 = 0
	fbmod i64 = 0
	mod i64 = zeroSource
	prout i64 = 0
	egRout i64 = 0x1ff
	egOut i64 = 0x1ff
	egInc i64 = 0
	egGen i64 = egOff
	egRate i64 = 0
	egKsl i64 = 0
	trem bool = false
	regVib i64 = 0
	regType i64 = 0
	regKsr i64 = 0
	regMult i64 = 0
	regKsl i64 = 0
	regTl i64 = 0
	regAr i64 = 0
	regDr i64 = 0
	regSl i64 = 0
	regRr i64 = 0
	regWf i64 = 0
	key i64 = 0
	pgPhase i64 = 0

type OplChannel:
	slot0 i64
	slot1 i64
	out i64[] = [zeroSource, zeroSource, zeroSource, zeroSource]
	fNum i64 = 0
	block i64 = 0
	fb i64 = 0
	con i64 = 0
	alg i64 = 0
	ksv i64 = 0
	cha bool = true
	chb bool = true

pub type Opl3:
	slots OplSlot[]
	channels OplChannel[]
	timer i64 = 0
	newm i64 = 0
	nts i64 = 0
	vibpos i64 = 0
	vibshift i64 = 1
	tremolo i64 = 0
	tremolopos i64 = 0
	tremoloshift i64 = 4
	mixbuff i64[] = [0, 0]
	rateratio i64
	samplecnt i64 = 0
	oldsamples i64[] = [0, 0]
	samples i64[] = [0, 0]

	fn slotValue(source i64):
		if source == zeroSource: return 0
		if source >= fbSource: return slots[source - fbSource].fbmod
		slots[source].out

	fn calcRate(s i64, regRate i64):
		if regRate == 0: return 0
		ksv = channels[slots[s].channel].ksv
		rate = (regRate << 2) + (ksv if slots[s].regKsr != 0 else ksv >> 2)
		rate.min(0x3c)

	fn updateKsl(s i64):
		ch = channels[slots[s].channel]
		ksl = (kslrom[ch.fNum >> 6] << 2) - ((8 - ch.block) << 5)
		slots[s].egKsl = ksl.max(0)

	fn updateRate(s i64):
		g = slots[s].egGen
		if g == egOff or g == egAttack:
			slots[s].egRate = self.calcRate(s, slots[s].regAr)
		elif g == egDecay:
			slots[s].egRate = self.calcRate(s, slots[s].regDr)
		else:
			slots[s].egRate = self.calcRate(s, slots[s].regRr)

	fn envelopeGen(s i64):
		g = slots[s].egGen
		if g == egOff:
			slots[s].egRout = 0x1ff
		elif g == egAttack:
			if slots[s].egRout == 0:
				slots[s].egGen = egDecay
				self.updateRate(s)
				return
			slots[s].egRout = short16(slots[s].egRout + ((~slots[s].egRout * slots[s].egInc) >> 3))
			if slots[s].egRout < 0: slots[s].egRout = 0
		elif g == egDecay:
			if slots[s].egRout >= slots[s].regSl << 4:
				slots[s].egGen = egSustain
				self.updateRate(s)
				return
			slots[s].egRout = short16(slots[s].egRout + slots[s].egInc)
		elif g == egSustain:
			if slots[s].regType == 0: self.envelopeRelease(s)
		else:
			self.envelopeRelease(s)

	fn envelopeRelease(s i64):
		if slots[s].egRout >= 0x1ff:
			slots[s].egGen = egOff
			slots[s].egRout = 0x1ff
			self.updateRate(s)
			return
		slots[s].egRout = short16(slots[s].egRout + slots[s].egInc)

	fn envelopeCalc(s i64):
		rateH = slots[s].egRate >> 2
		rateL = slots[s].egRate & 3
		inc = 0
		sh = egIncsh[rateH]
		row = egIncdesc[rateH] * 32 + rateL * 8
		if sh > 0:
			if (timer & ((1 << sh) - 1)) == 0:
				inc = egIncstep[row + ((timer >> sh) & 7)]
		else:
			inc = egIncstep[row + (timer & 7)] << -sh
		slots[s].egInc = inc
		trem = tremolo if slots[s].trem else 0
		slots[s].egOut = short16(
			slots[s].egRout + (slots[s].regTl << 2) +
				(slots[s].egKsl >> kslshift[slots[s].regKsl]) +
				trem
		)
		self.envelopeGen(s)

	fn keyOn(s i64):
		if slots[s].key == 0:
			slots[s].egGen = egAttack
			self.updateRate(s)
			if (slots[s].egRate >> 2) == 0x0f:
				slots[s].egGen = egDecay
				self.updateRate(s)
				slots[s].egRout = 0
			slots[s].pgPhase = 0
		slots[s].key |= 1

	fn keyOff(s i64):
		if slots[s].key != 0:
			slots[s].key &= ~1
			if slots[s].key == 0:
				slots[s].egGen = egRelease
				self.updateRate(s)

	fn phaseGenerate(s i64):
		ch = channels[slots[s].channel]
		fNum = ch.fNum
		if slots[s].regVib != 0:
			range = (fNum >> 7) & 7
			if vibpos & 3 == 0:
				range = 0
			elif vibpos & 1 != 0:
				range >>= 1
			range >>= vibshift
			if vibpos & 4 != 0: range = -range
			fNum = (fNum + range) & 0xFFFF
		basefreq = (fNum << ch.block) >> 1
		slots[s].pgPhase = (
			slots[s].pgPhase + ((basefreq * mt[slots[s].regMult]) >> 1)
		) & 0xFFFF_FFFF

	fn slotGenerate(s i64):
		phase = (slots[s].pgPhase >> 9) + self.slotValue(slots[s].mod)
		slots[s].out = short16(calcSin(slots[s].regWf, phase, slots[s].egOut))

	fn slotCalcFb(s i64):
		fb = channels[slots[s].channel].fb
		if fb != 0:
			slots[s].fbmod = short16((slots[s].prout + slots[s].out) >> (9 - fb))
		else:
			slots[s].fbmod = 0
		slots[s].prout = slots[s].out

	fn setupAlg(c i64):
		s0 = channels[c].slot0
		s1 = channels[c].slot1
		slots[s0].mod = fbSource + s0
		if channels[c].alg & 1 == 0:
			slots[s1].mod = s0
			channels[c].out = [s1, zeroSource, zeroSource, zeroSource]
		else:
			slots[s1].mod = zeroSource
			channels[c].out = [s0, s1, zeroSource, zeroSource]

	mut fn slotStep(s i64, generate bool):
		self.slotCalcFb(s)
		self.phaseGenerate(s)
		self.envelopeCalc(s)
		if generate: self.slotGenerate(s)

	fn mix(right bool):
		mixed = 0
		for ch in channels:
			accm = short16(
				self.slotValue(ch.out[0]) + self.slotValue(ch.out[1]) + self.slotValue(ch.out[2]) +
					self.slotValue(ch.out[3])
			)
			if (ch.chb if right else ch.cha): mixed += accm
		mixed

	# OPL3_Generate: a sample of the chip's own rate, both sides
	fn generate():
		samples[1] = clip(mixbuff[1])
		for s in 0..15:
			self.slotStep(s, true)
		mixbuff[0] = self.mix(false)
		for s in 15..18:
			self.slotStep(s, true)
		samples[0] = clip(mixbuff[0])
		for s in 18..33:
			self.slotStep(s, true)
		mixbuff[1] = self.mix(true)
		for s in 33..36:
			self.slotStep(s, true)
		if (timer & 0x3f) == 0x3f:
			tremolopos = (tremolopos + 1) % 210
		tremolo = (tremolopos if tremolopos < 105 else 210 - tremolopos) >> tremoloshift
		if (timer & 0x3ff) == 0x3ff:
			vibpos = (vibpos + 1) & 7
		timer = (timer + 1) & 0xFFFF

	# OPL3_GenerateResampled: a sample at the output rate, left and right
	pub mut fn nextSample() (i64, i64):
		while samplecnt >= rateratio:
			oldsamples[0] = samples[0]
			oldsamples[1] = samples[1]
			self.generate()
			samplecnt -= rateratio
		left = (oldsamples[0] * (rateratio - samplecnt) + samples[0] * samplecnt) / rateratio
		right = (oldsamples[1] * (rateratio - samplecnt) + samples[1] * samplecnt) / rateratio
		samplecnt += 1 << 10
		(short16(left), short16(right))

	# OPL3_WriteReg
	pub mut fn writeReg(reg i64, v i64):
		high = (reg >> 8) & 1
		regm = reg & 0xff
		kind = regm & 0xf0
		if kind == 0x00:
			if high != 0 and (regm & 0x0f) == 0x05:
				newm = v & 1
			elif high == 0 and (regm & 0x0f) == 0x08:
				nts = (v >> 6) & 1
		elif kind == 0x20 or kind == 0x30:
			s = slotOf(high, regm)
			if s >= 0:
				slots[s].trem = (v >> 7) & 1 != 0
				slots[s].regVib = (v >> 6) & 1
				slots[s].regType = (v >> 5) & 1
				slots[s].regKsr = (v >> 4) & 1
				slots[s].regMult = v & 0x0f
				self.updateRate(s)
		elif kind == 0x40 or kind == 0x50:
			s = slotOf(high, regm)
			if s >= 0:
				slots[s].regKsl = (v >> 6) & 3
				slots[s].regTl = v & 0x3f
				self.updateKsl(s)
		elif kind == 0x60 or kind == 0x70:
			s = slotOf(high, regm)
			if s >= 0:
				slots[s].regAr = (v >> 4) & 0x0f
				slots[s].regDr = v & 0x0f
				self.updateRate(s)
		elif kind == 0x80 or kind == 0x90:
			s = slotOf(high, regm)
			if s >= 0:
				sl = (v >> 4) & 0x0f
				slots[s].regSl = 0x1f if sl == 0x0f else sl
				slots[s].regRr = v & 0x0f
				self.updateRate(s)
		elif kind == 0xe0 or kind == 0xf0:
			s = slotOf(high, regm)
			if s >= 0:
				slots[s].regWf = v & 7 if newm != 0 else v & 3
		elif kind == 0xa0:
			if (regm & 0x0f) < 9:
				c = 9 * high + (regm & 0x0f)
				channels[c].fNum = (channels[c].fNum & 0x300) | v
				self.channelFreqChanged(c)
		elif kind == 0xb0:
			if (regm & 0x0f) < 9 and not (regm == 0xbd and high == 0):
				c = 9 * high + (regm & 0x0f)
				channels[c].fNum = (channels[c].fNum & 0xff) | ((v & 3) << 8)
				channels[c].block = (v >> 2) & 7
				self.channelFreqChanged(c)
				if v & 0x20 != 0:
					self.keyOn(channels[c].slot0)
					self.keyOn(channels[c].slot1)
				else:
					self.keyOff(channels[c].slot0)
					self.keyOff(channels[c].slot1)
		elif kind == 0xc0:
			if (regm & 0x0f) < 9:
				c = 9 * high + (regm & 0x0f)
				channels[c].fb = (v & 0x0e) >> 1
				channels[c].con = v & 1
				channels[c].alg = channels[c].con
				self.setupAlg(c)
				channels[c].cha = newm == 0 or (v >> 4) & 1 != 0
				channels[c].chb = newm == 0 or (v >> 5) & 1 != 0

	fn channelFreqChanged(c i64):
		channels[c].ksv = (channels[c].block << 1) | ((channels[c].fNum >> (9 - nts)) & 1)
		self.updateKsl(channels[c].slot0)
		self.updateKsl(channels[c].slot1)
		self.updateRate(channels[c].slot0)
		self.updateRate(channels[c].slot1)

fn short16(v i64):
	((v + 0x8000) & 0xFFFF) - 0x8000

# OPL3_Reset: a chip whose output is resampled to `sampleRate`
pub fn newOpl3(sampleRate i64) Opl3:
	slots OplSlot[] = fill(36, OplSlot())
	channels = (0..18).map(OplChannel(slot0 = chSlot[it], slot1 = chSlot[it] + 3))
	for c in 0..18:
		slots[chSlot[c]].channel = c
		slots[chSlot[c] + 3].channel = c
	chip = Opl3(slots, channels, rateratio = (sampleRate << 10) / 49_716)
	for c in 0..18:
		chip.setupAlg(c)
	chip

fn calcExp(level i64):
	l = level.min(0x1fff)
	((exprom[(l & 0xff) ^ 0xff] | 0x400) << 1) >> (l >> 8)

# the eight waveforms, a phase of 10 bits and an attenuation
fn calcSin(wf i64, phaseIn i64, envelope i64):
	phase = phaseIn & 0x3ff
	e = envelope << 3
	if wf == 0:
		out = logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0 else logsinrom[phase & 0xff]
		v = calcExp(out + e)
		return ~v if phase & 0x200 != 0 else v
	if wf == 1:
		out = 0x1000
		if phase & 0x200 == 0:
			out = logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0
				else logsinrom[phase & 0xff]
		return calcExp(out + e)
	if wf == 2:
		out = logsinrom[(phase & 0xff) ^ 0xff] if phase & 0x100 != 0 else logsinrom[phase & 0xff]
		return calcExp(out + e)
	if wf == 3:
		out = 0x1000 if phase & 0x100 != 0 else logsinrom[phase & 0xff]
		return calcExp(out + e)
	if wf == 4 or wf == 5:
		out = 0x1000
		if phase & 0x200 == 0:
			out = logsinrom[((phase ^ 0xff) << 1) & 0xff] if phase & 0x80 != 0
				else logsinrom[(phase << 1) & 0xff]
		v = calcExp(out + e)
		return ~v if wf == 4 and (phase & 0x300) == 0x100 else v
	if wf == 6:
		v = calcExp(e)
		return ~v if phase & 0x200 != 0 else v
	p = phase
	neg = false
	if p & 0x200 != 0:
		neg = true
		p = (p & 0x1ff) ^ 0x1ff
	v = calcExp((p << 3) + e)
	~v if neg else v

fn clip(v i64):
	v.clamp(-32_768, 32_767)

fn slotOf(high i64, regm i64):
	a = adSlot[regm & 0x1f]
	if a < 0: return -1
	18 * high + a
