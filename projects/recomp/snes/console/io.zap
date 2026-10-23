# The CPU's own registers (4200-421F): the interrupts allowed (NMITIMEN), the H/V timer, the
# multiplier and divider, the vertical blank's flags, the joypads read automatically at its start
# and through the old serial port (4016-4017), the ROM's speed (MEMSEL).

pub mut nmitimen u8 = 0
pub mut fastRom = false
pub mut nmiFlag = false     # 4210 bit 7: the vertical blank began, until read
pub mut irqFlag = false     # 4211 bit 7: the H/V timer fired, until read
mut irqLineAt i64 = 0       # from when the CPU sees it
mut autoReadFrom i64 = 0    # when the joypads' automatic read begins
irqLineDelay = 4
mut ioPort u8 = 0xFF        # 4201
pub mut hTime = 0x1FF       # 4207-4208
pub mut vTime = 0x1FF       # 4209-420A

# The buttons held on joypad 1, a bit each as 4218-4219 read them: B Y Select Start Up Down Left
# Right from bit 15, then A X L R. Set by the screen's keys or a route.
pub mut buttons u16 = 0
pub buttonB u16 = 0x8000
pub buttonY u16 = 0x4000
pub buttonSelect u16 = 0x2000
pub buttonStart u16 = 0x1000
pub buttonUp u16 = 0x0800
pub buttonDown u16 = 0x0400
pub buttonLeft u16 = 0x0200
pub buttonRight u16 = 0x0100
pub buttonA u16 = 0x0080
pub buttonX u16 = 0x0040
pub buttonL u16 = 0x0020
pub buttonR u16 = 0x0010

mut padData u16[4] = [0, 0, 0, 0]   # 4218-421F: what the last automatic read took
mut serialBits u16 = 0              # what 4016 shifts out, its high bit next
mut serialStrobed = false

fn ioFields(mut f StateFile):
	nmitimen = f.byte(nmitimen)
	fastRom = f.isSet(fastRom)
	nmiFlag = f.isSet(nmiFlag)
	irqFlag = f.isSet(irqFlag)
	irqLineAt = f.int(irqLineAt)
	autoReadFrom = f.int(autoReadFrom)
	ioPort = f.byte(ioPort)
	hTime = f.int(hTime)
	vTime = f.int(vTime)
	buttons = f.word(buttons)
	for k in 0..4:
		padData[k] = f.word(padData[k])
	serialBits = f.word(serialBits)
	serialStrobed = f.isSet(serialStrobed)

fn cpuRegisterRead(addr u32, off u32):
	advance()
	bus = openBus()
	match off:
		0x4210:
			v u8 = (0x80 if nmiFlag else 0) | 0x02 | (bus & 0x70)
			nmiFlag = false
			v
		0x4211:
			v u8 = (0x80 if irqFlag else 0) | (bus & 0x7F)
			irqFlag = false
			updateDue()
			v
		0x4212: hvbjoy() | (bus & 0x3E)
		0x4213: ioPort
		0x4214..0x4218: aluRead(off)
		0x4218..0x4220:
			noteJoypadRead()
			pad = padData[i64(off - 0x4218) / 2]
			u8(pad >> 8) if off & 1 == 1 else u8(pad & 0xFF)
		_: bus

fn cpuRegisterSet(off u32, v u8):
	advance()
	match off:
		0x4200:
			if v & 0x80 != 0 and nmitimen & 0x80 == 0 and nmiFlag: raiseNmi(cycles, 2)
			nmitimen = v
			if v & 0x30 == 0: irqFlag = false
			scheduleIrq()
			updateDue()
		0x4201: ioPort = v
		0x4202..0x4207: aluWrite(off, v)
		0x4207: setTimer(true, (hTime & 0x100) | i64(v))
		0x4208: setTimer(true, (hTime & 0xFF) | (i64(v & 1) << 8))
		0x4209: setTimer(false, (vTime & 0x100) | i64(v))
		0x420A: setTimer(false, (vTime & 0xFF) | (i64(v & 1) << 8))
		0x420B: askDma(v)
		0x420C: hdmaChannels = v
		0x420D: fastRom = v & 1 == 1
		_: pass

# the H/V timer fired: its flag up, the CPU's IRQ line a tick later unless it is up already
fn raiseIrq():
	if not irqFlag: irqLineAt = clock + irqLineDelay
	irqFlag = true
	updateDue()

fn setTimer(horizontal bool, v i64):
	if horizontal:
		hTime = v
	else:
		vTime = v
	scheduleIrq()
	updateDue()

# The vertical blank's start: the joypads read when 4200 asks (padData then, as the 16 serial
# reads would leave it, the old port's bits all shifted out), the NMI flag up, the NMI line 6
# master cycles later when allowed.
fn vblankRegisters():
	nmiFlag = true
	autoReadFrom = (lineStart + 130 + 255) & ~255
	if nmitimen & 0x80 != 0: raiseNmi(lineStart + nmiDelay, 1)
	if nmitimen & 1 == 1:
		padData[0] = buttons
		serialBits = 0xFFFF

# 4212: in the vertical blank, in the horizontal blank, the automatic read still running (its
# 4,224 master cycles from the first multiple of 256 since power-on 130 or more into the vertical
# blank, as Mesen 2 times it)
fn hvbjoy():
	h = clock - lineStart   # in master cycles: the blank ends at 4 and starts after 1096
	sinceRead = clock - autoReadFrom
	reading = nmitimen & 1 == 1 and line >= vblankLine and sinceRead >= 0 and sinceRead < 4224
	vblank u8 = 0x80 if line >= vblankLine else 0
	hblank u8 = 0 if h >= 4 and h <= 1096 else 0x40
	vblank | hblank | (1 if reading else 0)

fn serialStrobe(v u8):
	if serialStrobed and v & 1 == 0: serialBits = buttons
	serialStrobed = v & 1 == 1

# 4016's bit 0: joypad 1's buttons one at a time, B first, ones once all 16 are out; 4017 none
fn serialRead(second bool) u8:
	if second: return 0x1C
	if serialStrobed: return buttons >> 15
	bit = serialBits >> 15
	serialBits = (serialBits << 1) | 1
	u8(bit)
