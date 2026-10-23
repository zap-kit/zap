# The machine the code runs on: the 68000's registers and flags, and its memory, big-endian, its
# addresses 24 bits wide as the Mac Plus's were (a handle's master pointer keeps flags in its top
# byte). An address past the memory reads from the hook the Mac gives (its ROM, its devices).

pub mut d0 u32 = 0
pub mut d1 u32 = 0
pub mut d2 u32 = 0
pub mut d3 u32 = 0
pub mut d4 u32 = 0
pub mut d5 u32 = 0
pub mut d6 u32 = 0
pub mut d7 u32 = 0
pub mut a0 u32 = 0
pub mut a1 u32 = 0
pub mut a2 u32 = 0
pub mut a3 u32 = 0
pub mut a4 u32 = 0
pub mut a5 u32 = 0
pub mut a6 u32 = 0
pub mut a7 u32 = 0
pub mut usp u32 = 0
pub mut cc = false
pub mut cv = false
pub mut cz = false
pub mut cn = false
pub mut cx = false
pub mut systemByte u32 = 0x27   # the status register's high byte: supervisor, interrupts masked

pub memSize = 0x40_0000   # 4 MB, a Mac Plus's most
pub mut mem u8[] = zeros(memSize)

# what the machine does when it stops for good (the driver tells and keeps the reason), before
# the program stops
pub mut onStop fn(str) = (_): pass

pub fn stop(reason str):
	told = onStop
	told(reason)
	fail(reason)

# what a read or a write past the memory does (the Mac's ROM and devices): set by the Mac
pub mut readPast fn(i64, i64) u32 = (_, _): 0
pub mut writePast fn(i64, i64, u32) = (_, _, _): pass

# the 256-byte pages of memory that hold decoded code, and what a write to one does (the
# interpreter forgets what it decoded there: code that writes code)
pub mut codePages = fill(memSize >> 8, false)
pub mut onCodeWrite fn(i64) = (_): pass

fn noteCodeWrite(i i64):
	codePages[i >> 8] = false
	written = onCodeWrite
	written(i)

# register r: 0-7 d0-d7, 8-15 a0-a7, 16 the user stack pointer
pub fn register(r i64) u32:
	match r:
		0: d0
		1: d1
		2: d2
		3: d3
		4: d4
		5: d5
		6: d6
		7: d7
		8: a0
		9: a1
		10: a2
		11: a3
		12: a4
		13: a5
		14: a6
		15: a7
		_: usp

pub fn setRegister(r i64, v u32):
	match r:
		0: d0 = v
		1: d1 = v
		2: d2 = v
		3: d3 = v
		4: d4 = v
		5: d5 = v
		6: d6 = v
		7: d7 = v
		8: a0 = v
		9: a1 = v
		10: a2 = v
		11: a3 = v
		12: a4 = v
		13: a5 = v
		14: a6 = v
		15: a7 = v
		_: usp = v

# the low `size` bytes of v merged into the old value's upper bytes
pub fn merged(old u32, v u32, size i64) u32:
	match size:
		1: old & 0xFFFF_FF00 | v & 0xFF
		2: old & 0xFFFF_0000 | v & 0xFFFF
		_: v

pub fn read8(a u32) u32:
	i = i64(a & 0xFF_FFFF)
	if i < memSize: return mem[i]
	past = readPast
	past(i, 1)

pub fn read16(a u32) u32:
	i = i64(a & 0xFF_FFFF)
	if i + 1 < memSize: return mem.u16be(i)
	past = readPast
	past(i, 2)

pub fn read32(a u32) u32:
	i = i64(a & 0xFF_FFFF)
	if i + 3 < memSize: return mem.u32be(i)
	past = readPast
	past(i, 4)

pub fn write8(a u32, v u32):
	i = i64(a & 0xFF_FFFF)
	if i < memSize:
		if codePages[i >> 8]: noteCodeWrite(i)
		mem[i] = v & 0xFF
		return
	past = writePast
	past(i, 1, v)

pub fn write16(a u32, v u32):
	i = i64(a & 0xFF_FFFF)
	if i + 1 < memSize:
		if codePages[i >> 8]: noteCodeWrite(i)
		mem.setU16be(i, v & 0xFFFF)
		return
	past = writePast
	past(i, 2, v)

pub fn write32(a u32, v u32):
	i = i64(a & 0xFF_FFFF)
	if i + 3 < memSize:
		if codePages[i >> 8]: noteCodeWrite(i)
		mem.setU32be(i, v)
		return
	past = writePast
	past(i, 4, v)

pub fn read(a u32, size i64) u32:
	match size:
		1: read8(a)
		2: read16(a)
		_: read32(a)

pub fn write(a u32, v u32, size i64):
	match size:
		1: write8(a, v)
		2: write16(a, v)
		_: write32(a, v)

# the condition code register: X N Z V C in bits 4-0
pub fn ccr() u32:
	r u32 = 0
	if cc: r |= 1
	if cv: r |= 2
	if cz: r |= 4
	if cn: r |= 8
	if cx: r |= 16
	r

pub fn setCcr(v u32):
	cc = v & 1 != 0
	cv = v & 2 != 0
	cz = v & 4 != 0
	cn = v & 8 != 0
	cx = v & 16 != 0

pub fn sr() u32:
	systemByte << 8 | ccr()

pub fn setSr(v u32):
	systemByte = v >> 8 & 0xFF
	setCcr(v)

pub fn push16(v u32):
	a7 -= 2
	write16(a7, v)

pub fn push32(v u32):
	a7 -= 4
	write32(a7, v)

pub fn pop16() u32:
	v = read16(a7)
	a7 += 2
	v

pub fn pop32() u32:
	v = read32(a7)
	a7 += 4
	v
