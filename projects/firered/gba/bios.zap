# long: the BIOS's calls, one arm each
# The BIOS's calls (swi), done here as mGBA does them without a BIOS: the arguments in r0 to r3,
# the results back in them.

import cpu

pub fn swi(n i64):
	match n:
		0x01: registerRamReset(cpu.r0)
		0x02: halt()
		0x04: intrWait(cpu.r0 != 0, cpu.r1)
		0x05: intrWait(true, 1)
		0x06: divide(i32(cpu.r0), i32(cpu.r1))
		0x07: divide(i32(cpu.r1), i32(cpu.r0))
		0x08: cpu.r0 = squareRoot(cpu.r0)
		0x09: cpu.r0 = u32(arcTan(i16.wrap(cpu.r0))) & 0xFFFF
		0x0A: cpu.r0 = arcTan2(i16.wrap(cpu.r0), i16.wrap(cpu.r1)) & 0xFFFF
		0x0B: cpuSet(cpu.r0, cpu.r1, cpu.r2)
		0x0C: cpuFastSet(cpu.r0, cpu.r1, cpu.r2)
		0x0D: cpu.r0 = 0xBAAE_187F
		0x0E: bgAffineSet(cpu.r0, cpu.r1, cpu.r2)
		0x0F: objAffineSet(cpu.r0, cpu.r1, cpu.r2, cpu.r3)
		0x10: bitUnpack(cpu.r0, cpu.r1, cpu.r2)
		0x11, 0x12: lz77(cpu.r0, cpu.r1, n == 0x12)
		0x14, 0x15: runLength(cpu.r0, cpu.r1, n == 0x15)
		0x19: pass
		0x1F: cpu.r0 = midiKeyToFrequency(load32(cpu.r0 + 4), cpu.r1, cpu.r2)
		_: fail("the BIOS call 0x{n:X} is not done")

fn registerRamReset(flags u32):
	if flags & 1 != 0: ewram = zeros(0x4_0000)
	if flags & 2 != 0:
		for i in 0..0x7E00:
			iwram[i] = 0
	if flags & 4 != 0: palette = zeros(0x400)
	if flags & 8 != 0: vram = zeros(0x1_8000)
	if flags & 16 != 0: oam = zeros(0x400)
	if flags & 0x80 != 0:
		for off in 0x000..0x060 step 2:
			if off != 4 and off != 6: io.setU16le(off, 0)
		io.setU16le(regDispcnt, 0x80)   # the screen blanked, as the BIOS leaves it

# waits for one of the interrupts of the mask (the bits the game's handler sets at 0x03007FF8),
# throwing away those already there when asked
fn intrWait(discard bool, mask u32):
	if discard: store16(0x0300_7FF8, load16(0x0300_7FF8) & ~mask)
	io.setU16le(regIme, 1)
	while load16(0x0300_7FF8) & mask == 0:
		halt()
	store16(0x0300_7FF8, load16(0x0300_7FF8) & ~mask)

fn divide(n i32, d i32):
	if d == 0:
		cpu.r0 = 1 if n < 0 else u32(0xFFFF_FFFF) if n > 0 else 0
		cpu.r1 = u32(n)
		cpu.r3 = 1
		return
	q = i64(n) / i64(d)
	cpu.r0 = u32.wrap(q)
	cpu.r1 = u32.wrap(i64(n) % i64(d))
	cpu.r3 = u32.wrap(q.abs())

fn squareRoot(v u32):
	r = u32(f64(v).sqrt())
	while u64(r) * u64(r) > v:
		r -= 1
	while u64(r + 1) * u64(r + 1) <= u64(v):
		r += 1
	r

fn arcTan(i i64):
	a = -((i * i) >> 14)
	b = ((0xA9 * a) >> 14) + 0x390
	for c in [0x91C, 0xFB6, 0x16AA, 0x2081, 0x3651, 0xA2F9]:
		b = ((b * a) >> 14) + c
	(i * b) >> 16

fn arcTan2(x i64, y i64):
	if y == 0: return 0 if x >= 0 else 0x8000
	if x == 0: return 0x4000 if y >= 0 else 0xC000
	if y >= 0:
		if x >= 0:
			if x >= y: return arcTan((y << 14) / x)
		elif -x >= y:
			return arcTan((y << 14) / x) + 0x8000
		return 0x4000 - arcTan((x << 14) / y)
	if x <= 0:
		if -x > -y: return arcTan((y << 14) / x) + 0x8000
	elif x >= -y:
		return arcTan((y << 14) / x) + 0x1_0000
	0xC000 - arcTan((x << 14) / y)

# copies (or fills with the first unit, bit 24) count halfwords or words (bit 26)
fn cpuSet(src u32, dst u32, control u32):
	count = control & 0x1F_FFFF
	fill = control & 0x100_0000 != 0
	words = control & 0x400_0000 != 0
	size u32 = 4 if words else 2
	s = src & ~(size - 1)
	d = dst & ~(size - 1)
	value = load32(s) if words else load16(s)
	loop count:
		if words:
			store32(d, value if fill else load32(s))
		else:
			store16(d, value if fill else load16(s))
		d += size
		if not fill: s += size

# words in blocks of eight
fn cpuFastSet(src u32, dst u32, control u32):
	count = ((control & 0x1F_FFFF) + 7) & ~u32(7)
	fill = control & 0x100_0000 != 0
	s = src & ~u32(3)
	d = dst & ~u32(3)
	value = load32(s)
	loop count:
		store32(d, value if fill else load32(s))
		d += 4
		if not fill: s += 4

fn fixed(v f32) u32:
	u32.wrap(i64(v * 256.0))

fn bgAffineSet(src u32, dst u32, count i64):
	s = src
	d = dst
	loop count:
		ox = f32(i32(load32(s))) / 256.0
		oy = f32(i32(load32(s + 4))) / 256.0
		cx = f32(i16.wrap(load16(s + 8)))
		cy = f32(i16.wrap(load16(s + 10)))
		sx = f32(i16.wrap(load16(s + 12))) / 256.0
		sy = f32(i16.wrap(load16(s + 14))) / 256.0
		theta = f32(load16(s + 16) >> 8) / 128.0 * f32(pi)
		a = theta.cos() * sx
		b = -theta.sin() * sx
		c = theta.sin() * sy
		dd = theta.cos() * sy
		store16(d, fixed(a))
		store16(d + 2, fixed(b))
		store16(d + 4, fixed(c))
		store16(d + 6, fixed(dd))
		store32(d + 8, fixed(ox - (a * cx + b * cy)))
		store32(d + 12, fixed(oy - (c * cx + dd * cy)))
		s += 20
		d += 16

fn objAffineSet(src u32, dst u32, count i64, stride u32):
	s = src
	d = dst
	loop count:
		sx = f32(i16.wrap(load16(s))) / 256.0
		sy = f32(i16.wrap(load16(s + 2))) / 256.0
		theta = f32(load16(s + 4) >> 8) / 128.0 * f32(pi)
		store16(d, fixed(theta.cos() * sx))
		store16(d + stride, fixed(-theta.sin() * sx))
		store16(d + stride * 2, fixed(theta.sin() * sy))
		store16(d + stride * 3, fixed(theta.cos() * sy))
		s += 8
		d += stride * 4

# units of a few bits widened to more, an offset added to those not 0 (or to all, bit 31)
fn bitUnpack(src u32, dst u32, info u32):
	length = load16(info)
	from = load8(info + 2)
	to = load8(info + 3)
	offset = load32(info + 4)
	s = src
	d = dst
	out = 0
	outBits u32 = 0
	loop i64(length):
		b = load8(s)
		s += 1
		bit u32 = 0
		while bit < 8:
			unit = (b >> bit) & ((u32(1) << from) - 1)
			if unit != 0 or offset >> 31 == 1: unit += offset & 0x7FFF_FFFF
			out |= unit << outBits
			outBits += to
			if outBits == 32:
				store32(d, out)
				d += 4
				out = 0
				outBits = 0
			bit += from

# The LZ77 data at src unpacked to dst: a header of the size, then flags each for eight units, a
# literal byte or a copy of 3 to 18 bytes from before. Into video RAM by halfwords.
fn lz77(src u32, dst u32, halfwords bool):
	size = load32(src) >> 8
	s = src + 4
	out = []
	while u32(out.len) < size:
		flags = load8(s)
		s += 1
		for k in 0..8:
			if u32(out.len) >= size: break
			if (flags >> u32(7 - k)) & 1 == 0:
				out.push(u8(load8(s)))
				s += 1
				continue
			b1 = load8(s)
			b2 = load8(s + 1)
			s += 2
			length = i64(b1 >> 4) + 3
			back = i64(((b1 & 15) << 8) | b2) + 1
			loop length:
				out.push(out[len - back])
	writeOut(dst, out, halfwords, size)

fn writeOut(dst u32, out u8[], halfwords bool, size i64):
	if not halfwords:
		for i in 0..size:
			store8(dst + u32(i), out[i])
		return
	i = 0
	while i + 1 < size:
		store16(dst + u32(i), out.u16le(i))
		i += 2

fn runLength(src u32, dst u32, halfwords bool):
	size = i64(load32(src) >> 8)
	s = src + 4
	out = []
	while out.len < size:
		flag = load8(s)
		s += 1
		if flag & 0x80 != 0:
			b = u8(load8(s))
			s += 1
			loop i64(flag & 0x7F) + 3:
				out.push(b)
		else:
			loop i64(flag) + 1:
				out.push(u8(load8(s)))
				s += 1
	writeOut(dst, out, halfwords, size)

fn midiKeyToFrequency(key i64, mk i64, fp i64) u32:
	u32(f32(key) / f32(2.0).pow((180.0 - f32(mk) - f32(fp) / 256.0) / 12.0))
