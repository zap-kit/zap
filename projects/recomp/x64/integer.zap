# The general-purpose instructions run: the one-byte map and the integer part of 0F (moves,
# arithmetic, branches, the stack, string stores), each as Intel SDM vol. 2 has it. An instruction
# the table decodes but no line here runs is an error naming it.

fn notRun(d Instr):
	"0x{d.at:x}: {d.textOf()} is not emulated"

# the operand size of a byte form (its opcode's low bit clear) or of the instruction
fn sizeOf(d Instr):
	1 if d.opcode & 1 == 0 else d.opsize

pub fn execInteger(mut m Machine, d Instr) ? str:
	if d.map == 0:
		match d.opcode:
			0x00..=0x3F: m.execAluForm(d)
			0x50..=0x57: m.push(m.reg((d.opcode & 7) | (d.rex & 1) << 3, 8, d.rex))
			0x58..=0x5F: m.setReg((d.opcode & 7) | (d.rex & 1) << 3, 8, d.rex, m.pop())
			0x63: m.writeG(d, d.opsize, widen(m.readE(d, 4), 4) & maskOf(d.opsize))
			0x68, 0x6A: m.push(u64.wrap(d.imm))
			0x69, 0x6B: m.imulInto(d, m.readE(d, d.opsize), u64.wrap(d.imm))
			0x70..=0x7F: if m.holds(d.opcode & 15): m.jump(d.at + u64(d.len) + u64.wrap(d.imm))
			0x80..=0x83:
				size = 1 if d.opcode == 0x80 else d.opsize
				r = m.alu(d.reg & 7, m.readE(d, size), u64.wrap(d.imm) & maskOf(size), size)
				if d.reg & 7 != 7: m.writeE(d, size, r)
			0x84, 0x85: m.logicFlags(m.readE(d, d.sizeOf()) & m.readG(d, d.sizeOf()), d.sizeOf())
			0x86, 0x87:
				a = m.readE(d, d.sizeOf())
				m.writeE(d, d.sizeOf(), m.readG(d, d.sizeOf()))
				m.writeG(d, d.sizeOf(), a)
			0x88, 0x89: m.writeE(d, d.sizeOf(), m.readG(d, d.sizeOf()))
			0x8A, 0x8B: m.writeG(d, d.sizeOf(), m.readE(d, d.sizeOf()))
			0x8D: m.writeG(d, d.opsize, m.ea(d) & maskOf(d.opsize))
			0x8F: m.writeE(d, 8, m.pop())
			0x90: pass
			0x91..=0x97:
				r = (d.opcode & 7) | (d.rex & 1) << 3
				a = m.reg(r, d.opsize, d.rex)
				m.setReg(r, d.opsize, d.rex, m.reg(0, d.opsize, d.rex))
				m.setReg(0, d.opsize, d.rex, a)
			0x98: m.setReg(
				0,
				d.opsize,
				d.rex,
				widen(m.reg(0, d.opsize / 2, d.rex), d.opsize / 2) & maskOf(d.opsize)
			)
			0x99: m.setReg(
				2,
				d.opsize,
				d.rex,
				maskOf(d.opsize) if isNegative(m.reg(0, d.opsize, d.rex), d.opsize) else 0
			)
			0xA4, 0xA5, 0xAA, 0xAB: return m.execString(d)
			0xA8, 0xA9: m.logicFlags(m.reg(0, d.sizeOf(), d.rex) & u64.wrap(d.imm), d.sizeOf())
			0xB0..=0xB7: m.setReg((d.opcode & 7) | (d.rex & 1) << 3, 1, d.rex, u64.wrap(d.imm))
			0xB8..=0xBF: m.setReg(
				(d.opcode & 7) | (d.rex & 1) << 3,
				d.opsize,
				d.rex,
				u64.wrap(d.imm) & maskOf(d.opsize)
			)
			0xC0, 0xC1, 0xD0..=0xD3: m.execShift(d)
			0xC2, 0xC3:
				m.jump(m.pop())
				m.regs[4] += u64.wrap(d.imm) if d.opcode == 0xC2 else 0
			0xC6, 0xC7: m.writeE(d, d.sizeOf(), u64.wrap(d.imm) & maskOf(d.sizeOf()))
			0xC9:
				m.regs[4] = m.regs[5]
				m.regs[5] = m.pop()
			0xE8:
				m.push(d.at + u64(d.len))
				m.jump(d.at + u64(d.len) + u64.wrap(d.imm))
			0xE9, 0xEB: m.jump(d.at + u64(d.len) + u64.wrap(d.imm))
			0xF6, 0xF7: return m.execUnary(d)
			0xFC: m.df = false
			0xFE, 0xFF: return m.execGroup5(d)
			_: return d.notRun()
		return
	match d.opcode:
		0x0B: return "0x{d.at:x}: ud2"
		0x18, 0x1F: pass
		0x40..=0x4F:
			v = m.readE(d, d.opsize)
			m.writeG(d, d.opsize, v if m.holds(d.opcode & 15) else m.readG(d, d.opsize))
		0x80..=0x8F: if m.holds(d.opcode & 15): m.jump(d.at + u64(d.len) + u64.wrap(d.imm))
		0x90..=0x9F: m.writeE(d, 1, 1 if m.holds(d.opcode & 15) else 0)
		0xA3, 0xAB, 0xB3, 0xBA, 0xBB: m.execBitTest(d)
		0xA4, 0xA5, 0xAC, 0xAD: m.execDoubleShift(d)
		0xAE: return m.execMxcsr(d)
		0xAF: m.imulInto(d, m.readG(d, d.opsize), m.readE(d, d.opsize))
		0xB0, 0xB1: m.execCmpxchg(d)
		0xB6, 0xB7, 0xBE, 0xBF:
			from = 1 if d.opcode & 1 == 0 else 2
			v = m.readE(d, from)
			m.writeG(d, d.opsize, (widen(v, from) if d.opcode >= 0xBE else v) & maskOf(d.opsize))
		0xB8, 0xBC, 0xBD: m.execBitScan(d)
		0xC0, 0xC1:
			a = m.readE(d, d.sizeOf())
			b = m.readG(d, d.sizeOf())
			m.writeG(d, d.sizeOf(), a)
			m.writeE(d, d.sizeOf(), m.addWithFlags(a, b, 0, d.sizeOf()))
		0xC8..=0xCF:
			r = (d.opcode & 7) | (d.rex & 1) << 3
			v = m.reg(r, d.opsize, d.rex)
			m.setReg(r, d.opsize, d.rex, v.byteSwap() >> 32 if d.opsize == 4 else v.byteSwap())
		_: return d.notRun()

# the forms 00..3F: operation (opcode >> 3) between E and G either way, or AL/rAX and an immediate
fn execAluForm(mut m Machine, d Instr) ? str:
	k = d.opcode >> 3
	size = d.sizeOf()
	match d.opcode & 7:
		0, 1:
			r = m.alu(k, m.readE(d, size), m.readG(d, size), size)
			if k != 7: m.writeE(d, size, r)
		2, 3:
			r = m.alu(k, m.readG(d, size), m.readE(d, size), size)
			if k != 7: m.writeG(d, size, r)
		4, 5:
			s = 1 if d.opcode & 7 == 4 else d.opsize
			r = m.alu(k, m.reg(0, s, d.rex), u64.wrap(d.imm) & maskOf(s), s)
			if k != 7: m.setReg(0, s, d.rex, r)
		_: return d.notRun()

# imul G by a and b, the product cut to the operand size
fn imulInto(mut m Machine, d Instr, a u64, b u64):
	r, lost = imulTruncated(a, b, d.opsize)
	m.cf = lost
	m.of = lost
	m.writeG(d, d.opsize, r)

fn execShift(mut m Machine, d Instr):
	size = d.sizeOf()
	count = match d.opcode:
		0xC0, 0xC1: u64.wrap(d.imm)
		0xD0, 0xD1: u64(1)
		_: m.regs[1] & 0xFF
	m.writeE(d, size, m.shift(d.reg & 7, m.readE(d, size), count, size))

# F6, F7: test, not, neg, mul, imul, div, idiv of E
fn execUnary(mut m Machine, d Instr) ? str:
	size = d.sizeOf()
	v = m.readE(d, size)
	match d.reg & 7:
		0, 1: m.logicFlags(v & u64.wrap(d.imm), size)
		2: m.writeE(d, size, ~v & maskOf(size))
		3:
			r = m.subWithFlags(0, v, 0, size)
			m.writeE(d, size, r)
		4, 5:
			a = m.reg(0, size, d.rex)
			signed = d.reg & 7 == 5
			hi, lo = mulWideSigned(widen(a, size), widen(v, size)) if signed else mulWide(a, v)
			lost = hi != (~u64(0) if i64(lo) < 0 else 0) if signed else hi != 0
			if size < 8:
				lost = widen(lo & maskOf(size), size) != lo if signed else lo >> u64(8 * size) != 0
				hi = (lo >> u64(8 * size)) & maskOf(size)
				lo &= maskOf(size)
			m.writeWide(size, hi, lo)
			m.cf = lost
			m.of = lost
		6:
			high, low = m.readWide(size, false)
			q, r = divWide(high, low, v) ?? return "0x{d.at:x}: divide error"
			if q > maskOf(size): return "0x{d.at:x}: divide error"
			m.writeWide(size, r, q)
		_:
			high, low = m.readWide(size, true)
			q, r = idivWide(high, low, v, size) ?? return "0x{d.at:x}: divide error"
			m.writeWide(size, r & maskOf(size), q & maskOf(size))

# the dividend: ax, dx:ax, edx:eax or rdx:rax as a 128-bit (high, low) value, signed or not
fn readWide(mut m Machine, size i64, signed bool):
	if size == 8: return (m.regs[2], m.regs[0])
	whole = m.regs[0] & 0xFFFF if size == 1
		else (m.reg(2, size, 1) << u64(8 * size)) | m.reg(0, size, 1)
	if not signed: return (0, whole)
	wide = widen(whole, 2 * size)
	(u64(0) if i64(wide) >= 0 else ~u64(0), wide)

fn writeWide(mut m Machine, size i64, hi u64, lo u64):
	if size == 1:
		m.regs[0] = (m.regs[0] & ~u64(0xFFFF)) | (hi & 0xFF) << 8 | (lo & 0xFF)
		return
	m.setReg(0, size, 1, lo)
	m.setReg(2, size, 1, hi)

# FE, FF: inc, dec, call, jmp, push
fn execGroup5(mut m Machine, d Instr) ? str:
	size = d.sizeOf()
	match d.reg & 7:
		0, 1:
			carry = m.cf
			v = m.readE(d, size)
			r = m.addWithFlags(v, 1, 0, size) if d.reg & 7 == 0 else m.subWithFlags(v, 1, 0, size)
			m.cf = carry
			m.writeE(d, size, r)
		2:
			to = m.readE(d, 8)
			m.push(d.at + u64(d.len))
			m.jump(to)
		4: m.jump(m.readE(d, 8))
		6: m.push(m.readE(d, 8))
		_: return d.notRun()
