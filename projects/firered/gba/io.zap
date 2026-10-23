# The I/O registers at 0x04000000: most only hold what was written (io), the others are read
# from the hardware's state (the line, the timers, the keys, the interrupts asked for) or act
# when written (DMA, timers, the interrupts acknowledged, halting).

pub regDispcnt = 0x000
pub regDispstat = 0x004
pub regVcount = 0x006
pub regKeyinput = 0x130
pub regIe = 0x200
pub regIf = 0x202
pub regIme = 0x208

pub fn ioHalf(off i64) u32:
	io.u16le(off)

fn setIoHalf(off i64, v u16):
	io.setU16le(off, v)

# the keys held, as KEYINPUT reads them: a bit a key, 0 while it is held
pub mut keysUp u32 = 0x3FF

pub fn ioRead16(a u32) u32:
	off = i64(a & 0x3FE)
	match off:
		0x004: dispstat()
		0x006: u32(line)
		0x100, 0x104, 0x108, 0x10C: timerCounter((off - 0x100) / 4)
		0x130: keysUp
		_: ioHalf(off) if off < 0x400 else 0

mut ioLog = args.hasFlag("--io")

pub fn ioWrite16(o i64, v u16):
	if ioLog: print("io {o:03X} = {v:04X} at line {line} frame {frameCount}")
	match o:
		0x004: setIoHalf(o, (v & 0xFFF8) | (io.u16le(o) & 7))
		0x006: pass
		0x0A0, 0x0A2: fifoPush(0, o - 0x0A0, v)
		0x0A4, 0x0A6: fifoPush(1, o - 0x0A4, v)
		0x0BA, 0x0C6, 0x0D2, 0x0DE:
			before = io.u16le(o)
			setIoHalf(o, v)
			dmaControl((o - 0x0BA) / 12, before, v)
		0x100, 0x104, 0x108, 0x10C: timerReload((o - 0x100) / 4, v)
		0x102, 0x106, 0x10A, 0x10E: timerControl((o - 0x102) / 4, v)
		0x130: pass
		0x202: setIoHalf(o, io.u16le(o) & ~v)
		0x208:
			setIoHalf(o, v & 1)
			interruptsChanged()
		0x200:
			setIoHalf(o, v)
			interruptsChanged()
		0x300:
			setIoHalf(o, v)
			if v >> 15 == 0 and v & 0xFF00 != 0: halt()
		_:
			setIoHalf(o, v)
			if o >= 0x28 and o < 0x40 and o & 0xF >= 8: affineWritten(o & ~3)
			if o >= 0x60 and o < 0xA0: soundWritten(o, v)

# a byte written: into its halfword, as if the halfword were written (an acknowledgment takes
# only the byte's bits)
pub fn ioWrite8(off u32, b u8):
	half = off & 0x3FE
	shift = 8 * (off & 1)
	if half == 0x202:
		setIoHalf(0x202, io.u16le(0x202) & ~u16(u32(b) << shift))
		return
	if off == 0x301:
		halt()
		return
	old = u32(io.u16le(half))
	ioWrite16(half, u16.wrap((old & ~(u32(0xFF) << shift)) | (u32(b) << shift)))

# an interrupt asked for: its bit of IF set
pub fn raise(bit u32):
	setIoHalf(regIf, io.u16le(regIf) | u16.wrap(bit))
	interruptsChanged()
