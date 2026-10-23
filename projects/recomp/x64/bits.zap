# The rest of the integer instructions: bit tests and scans, double shifts, compare-exchange, the
# string moves and stores (rep movs, rep stos, as inlined memcpy and memset write them) and MXCSR's
# load and store, which only the default rounding may pass.

pub defaultMxcsr u64 = 0x1F80

# bt, bts, btr, btc: the bit of E that G (or the immediate) names
pub fn execBitTest(mut m Machine, d Instr):
	size = d.opsize
	bits = u64(8 * size)
	which = match d.opcode:
		0xBA: d.reg & 7
		0xA3: 4
		0xAB: 5
		0xB3: 6
		_: 7
	n = u64.wrap(d.imm) % bits if d.opcode == 0xBA else m.readG(d, size)
	d2 = d
	if d.mem and d.opcode != 0xBA:
		# a register offset reaches beyond the operand: the address moves by whole operands
		offset = i64(widen(n & maskOf(size), size)) >> bits.trailingZeros()
		d2.disp += offset * size
	bit = n % bits
	v = m.readE(d2, size)
	m.cf = (v >> bit) & 1 == 1
	match which:
		5: m.writeE(d2, size, v | u64(1) << bit)
		6: m.writeE(d2, size, v & ~(u64(1) << bit))
		7: m.writeE(d2, size, v ^ u64(1) << bit)
		_: pass

# popcnt, tzcnt, bsf, lzcnt, bsr
pub fn execBitScan(mut m Machine, d Instr):
	size = d.opsize
	v = m.readE(d, size)
	bits = 8 * size
	if d.opcode == 0xB8:
		m.logicFlags(0, size)
		m.zf = v == 0
		m.writeG(d, size, u64(v.bitCount()))
		return
	zeros = v.trailingZeros() if d.opcode == 0xBC else v.leadingZeros() - (64 - bits)
	if d.pfx == 2:
		m.cf = v == 0
		count = bits if v == 0 else zeros
		m.zf = count == 0
		m.writeG(d, size, u64(count))
		return
	m.zf = v == 0
	if v == 0: return
	m.writeG(d, size, u64(zeros if d.opcode == 0xBC else bits - 1 - zeros))

# shld, shrd: E shifted with G's bits coming in
pub fn execDoubleShift(mut m Machine, d Instr):
	size = d.opsize
	bits = 8 * size
	count = i64(
		(u64.wrap(d.imm) if d.opcode & 1 == 0 else m.regs[1]) & (0x3F if size == 8 else 0x1F)
	)
	if count == 0 or count > bits: return
	a = m.readE(d, size)
	b = m.readG(d, size)
	mask = maskOf(size)
	left = d.opcode < 0xA8
	r = a
	if count == bits: r = b
	elif left: r = ((a << u64(count)) | (b >> u64(bits - count))) & mask
	else: r = ((a >> u64(count)) | (b << u64(bits - count))) & mask
	m.cf = (a >> u64(bits - count)) & 1 == 1 if left else (a >> u64(count - 1)) & 1 == 1
	m.of = isNegative(r, size) != isNegative(a, size)
	m.setResultFlags(r, size)
	m.writeE(d, size, r)

# cmpxchg: E is G's when it equals the accumulator, else the accumulator takes E
pub fn execCmpxchg(mut m Machine, d Instr):
	size = 1 if d.opcode == 0xB0 else d.opsize
	v = m.readE(d, size)
	acc = m.reg(0, size, d.rex)
	m.subWithFlags(acc, v, 0, size)
	if m.zf: m.writeE(d, size, m.readG(d, size))
	else: m.setReg(0, size, d.rex, v)

# stmxcsr gives the default; ldmxcsr of any other value is refused, as the ops round to nearest
pub fn execMxcsr(mut m Machine, d Instr) ? str:
	match d.reg & 7:
		2:
			v = m.readE(d, 4)
			if v & 0xFFC0 != defaultMxcsr & 0xFFC0:
				return "0x{d.at:x}: ldmxcsr 0x{v:x}, not the default rounding"
		3: m.writeE(d, 4, defaultMxcsr)
		_: pass

# movs and stos, once or rep (rcx times), forward (the direction flag clear)
pub fn execString(mut m Machine, d Instr) ? str:
	if m.df: return "0x{d.at:x}: a string instruction with the direction flag set"
	size = d.sizeOf()
	count = m.regs[1] if d.rep == 0xF3 else 1
	step = u64(size)
	loop i64(count):
		if d.opcode <= 0xA5:
			m.mem.write(m.regs[7], size, m.mem.read(m.regs[6], size))
			m.regs[6] += step
		else:
			m.mem.write(m.regs[7], size, m.reg(0, size, d.rex))
		m.regs[7] += step
	if d.rep == 0xF3: m.regs[1] = 0
