# The SSE, SSE2 and SSE4.1 float instructions run on the XMM registers' halves: moves, scalar and
# packed arithmetic (floats.zap gives each lane's result), comparisons, conversions, shuffles and
# rounding. The integer SIMD instructions are in simd.zap. rcpss and rsqrtss are refused: their
# approximations are the processor's own, no manual gives their bits.

fn low32(v u64) u32:
	u32.wrap(v)

fn high32(v u64) u32:
	u32.wrap(v >> 32)

fn join32(lo u32, hi u32):
	lo | u64(hi) << 32

# the low lane of v replaced by x
fn withLow32(v u64, x u32):
	(v & 0xFFFF_FFFF_0000_0000) | u64(x)

# lane k (0..3) of a 128-bit value
fn lane32(lo u64, hi u64, k i64):
	match k & 3:
		0: low32(lo)
		1: high32(lo)
		2: low32(hi)
		_: high32(hi)

fn pair32(op i64, a u64, b u64):
	join32(arith32(op, low32(a), low32(b)), arith32(op, high32(a), high32(b)))

fn floatOp(opcode i64):
	match opcode:
		0x51: opSqrt
		0x58: opAdd
		0x59: opMul
		0x5C: opSub
		0x5D: opMin
		0x5E: opDiv
		_: opMax

fn sseError(d Instr, why str):
	"0x{d.at:x}: {d.textOf()}: {why}"

pub fn execSse(mut m Machine, d Instr) ? str:
	if d.map == 2 or d.map == 3 or (d.map == 1 and d.pfx == 1 and isIntegerSimd(d.opcode)):
		return m.execSimd(d)
	if d.map == 1 and d.pfx == 2 and (d.opcode in [0x6F, 0x7E, 0x7F, 0x70]): return m.execSimd(d)
	if d.map == 1 and d.pfx == 3 and d.opcode == 0x70: return m.execSimd(d)
	match d.opcode:
		0x51, 0x58, 0x59, 0x5C, 0x5D, 0x5E, 0x5F: m.floatArith(d)
		0x10..=0x17, 0x28, 0x29: return m.floatMove(d)
		0x2A..=0x2F, 0x5A, 0x5B, 0xE6: return m.floatConvert(d)
		0x50:
			a = m.lo(d.rm)
			b = m.hi(d.rm)
			bits = (a >> 63) | (b >> 63) << 1
			if d.pfx == 0:
				bits = (a >> 31 & 1) | (a >> 63) << 1 | (b >> 31 & 1) << 2 | (b >> 63) << 3
			m.writeG(d, 4, bits)
		0x52, 0x53: return d.sseError("the processor's own approximation, not emulated")
		0x54..=0x57:
			blo, bhi = m.readW(d, 16)
			alo = m.lo(d.reg)
			ahi = m.hi(d.reg)
			match d.opcode:
				0x54: m.setXmm(d.reg, alo & blo, ahi & bhi)
				0x55: m.setXmm(d.reg, ~alo & blo, ~ahi & bhi)
				0x56: m.setXmm(d.reg, alo | blo, ahi | bhi)
				_: m.setXmm(d.reg, alo ^ blo, ahi ^ bhi)
		0xC2: m.floatCompare(d)
		0xC6:
			blo, bhi = m.readW(d, 16)
			alo = m.lo(d.reg)
			ahi = m.hi(d.reg)
			s = d.imm
			if d.pfx == 1:
				m.setXmm(d.reg, ahi if s & 1 == 1 else alo, bhi if s & 2 == 2 else blo)
			else:
				m.setXmm(d.reg, join32(lane32(alo, ahi, s), lane32(alo, ahi, s >> 2)),
					join32(lane32(blo, bhi, s >> 4), lane32(blo, bhi, s >> 6)))
		_: return d.sseError("not emulated")

# sqrt, add, mul, sub, min, div, max in their four forms
fn floatArith(mut m Machine, d Instr):
	op = floatOp(d.opcode)
	r = d.reg
	match d.pfx:
		0:
			blo, bhi = m.readW(d, 16)
			if op == opSqrt: m.setXmm(r, pair32(op, blo, blo), pair32(op, bhi, bhi))
			else: m.setXmm(r, pair32(op, m.lo(r), blo), pair32(op, m.hi(r), bhi))
		1:
			blo, bhi = m.readW(d, 16)
			m.setXmm(r, arith64(op, m.lo(r), blo), arith64(op, m.hi(r), bhi))
		2:
			blo, _ = m.readW(d, 4)
			m.setXmm(r, withLow32(m.lo(r), arith32(op, low32(m.lo(r)), low32(blo))), m.hi(r))
		_:
			blo, _ = m.readW(d, 8)
			m.setXmm(r, arith64(op, m.lo(r), blo), m.hi(r))

fn floatMove(mut m Machine, d Instr) ? str:
	r = d.reg
	match (d.opcode, d.pfx):
		(0x10, 0), (0x10, 1), (0x28, _):
			lo, hi = m.readW(d, 16)
			m.setXmm(r, lo, hi)
		(0x11, 0), (0x11, 1), (0x29, _): m.storeW(d, 16, m.lo(r), m.hi(r))
		(0x10, 2):
			lo, _ = m.readW(d, 4)
			if d.mem: m.setXmm(r, lo, 0)
			else: m.setXmm(r, withLow32(m.lo(r), low32(lo)), m.hi(r))
		(0x10, 3):
			lo, _ = m.readW(d, 8)
			m.setXmm(r, lo, 0 if d.mem else m.hi(r))
		(0x11, 2):
			if d.mem: m.mem.write(m.ea(d), 4, m.lo(r) & 0xFFFF_FFFF)
			else: m.setXmm(d.rm, withLow32(m.lo(d.rm), low32(m.lo(r))), m.hi(d.rm))
		(0x11, 3): m.storeW(d, 8, m.lo(r), 0)
		(0x12, 0), (0x12, 1):
			if d.mem: m.setXmm(r, m.mem.read(m.ea(d), 8), m.hi(r))
			else: m.setXmm(r, m.hi(d.rm), m.hi(r))
		(0x12, 3):
			lo, _ = m.readW(d, 8)
			m.setXmm(r, lo, lo)
		(0x13, _): m.mem.write(m.ea(d), 8, m.lo(r))
		(0x14, 0), (0x15, 0):
			blo, bhi = m.readW(d, 16)
			a = m.lo(r) if d.opcode == 0x14 else m.hi(r)
			b = blo if d.opcode == 0x14 else bhi
			m.setXmm(r, join32(low32(a), low32(b)), join32(high32(a), high32(b)))
		(0x14, 1), (0x15, 1):
			blo, bhi = m.readW(d, 16)
			if d.opcode == 0x14: m.setXmm(r, m.lo(r), blo)
			else: m.setXmm(r, m.hi(r), bhi)
		(0x16, 0), (0x16, 1):
			if d.mem: m.setXmm(r, m.lo(r), m.mem.read(m.ea(d), 8))
			else: m.setXmm(r, m.lo(r), m.lo(d.rm))
		(0x17, _): m.mem.write(m.ea(d), 8, m.hi(r))
		_: return d.sseError("not emulated")

# the 128 bits, or the low 8, written to the XMM-or-memory operand
fn storeW(mut m Machine, d Instr, bytes i64, lo u64, hi u64):
	if not d.mem:
		m.setXmm(d.rm, lo, hi if bytes == 16 else m.hi(d.rm))
		return
	at = m.ea(d)
	m.mem.write(at, 8, lo)
	if bytes == 16: m.mem.write(at + 8, 8, hi)

# ucomis*, comis* set ZF PF CF as the order is; cmp* write masks
fn floatCompare(mut m Machine, d Instr):
	r = d.reg
	p = d.imm
	all32 u32 = 0xFFFF_FFFF
	match d.pfx:
		0:
			blo, bhi = m.readW(d, 16)
			alo = m.lo(r)
			ahi = m.hi(r)
			lanes = [0, 1, 2, 3].map(
				all32 if predicateHolds(p, order32(lane32(alo, ahi, it), lane32(blo, bhi, it)))
				else u32(0)
			)
			m.setXmm(r, join32(lanes[0], lanes[1]), join32(lanes[2], lanes[3]))
		1:
			blo, bhi = m.readW(d, 16)
			m.setXmm(r, ~u64(0) if predicateHolds(p, order64(m.lo(r), blo)) else 0,
				~u64(0) if predicateHolds(p, order64(m.hi(r), bhi)) else 0)
		2:
			blo, _ = m.readW(d, 4)
			mask = all32 if predicateHolds(p, order32(low32(m.lo(r)), low32(blo))) else u32(0)
			m.setXmm(r, withLow32(m.lo(r), mask), m.hi(r))
		_:
			blo, _ = m.readW(d, 8)
			m.setXmm(r, ~u64(0) if predicateHolds(p, order64(m.lo(r), blo)) else 0, m.hi(r))

pub fn setOrderFlags(mut m Machine, order i64):
	m.zf = order == 0 or order == -2
	m.pf = order == -2
	m.cf = order == -1 or order == -2
	m.of = false
	m.sf = false
	m.af = false

fn floatConvert(mut m Machine, d Instr) ? str:
	r = d.reg
	match (d.opcode, d.pfx):
		(0x2A, 2), (0x2A, 3):
			bytes = 8 if d.rexW() else 4
			v = i64(widen(m.readE(d, bytes), bytes))
			if d.pfx == 2: m.setXmm(r, withLow32(m.lo(r), intToSingle(v)), m.hi(r))
			else: m.setXmm(r, intToDouble(v), m.hi(r))
		(0x2C, 2), (0x2D, 2), (0x2C, 3), (0x2D, 3):
			bytes = 8 if d.rexW() else 4
			lo, _ = m.readW(d, 4 if d.pfx == 2 else 8)
			x = f64(f32.fromBits(low32(lo))) if d.pfx == 2 else f64.fromBits(lo)
			m.writeG(d, bytes, toInteger(x, bytes, d.opcode == 0x2C))
		(0x2E, 0), (0x2F, 0):
			lo, _ = m.readW(d, 4)
			m.setOrderFlags(order32(low32(m.lo(r)), low32(lo)))
		(0x2E, 1), (0x2F, 1):
			lo, _ = m.readW(d, 8)
			m.setOrderFlags(order64(m.lo(r), lo))
		(0x5A, 0):
			lo, _ = m.readW(d, 8)
			m.setXmm(r, widen32(low32(lo)), widen32(high32(lo)))
		(0x5A, 1):
			lo, hi = m.readW(d, 16)
			m.setXmm(r, join32(narrow64(lo), narrow64(hi)), 0)
		(0x5A, 2):
			lo, _ = m.readW(d, 4)
			m.setXmm(r, widen32(low32(lo)), m.hi(r))
		(0x5A, 3):
			lo, _ = m.readW(d, 8)
			m.setXmm(r, withLow32(m.lo(r), narrow64(lo)), m.hi(r))
		(0x5B, _), (0xE6, 1), (0xE6, 3), (0xE6, 2): m.packedConvert(d)
		_: return d.sseError("not emulated")

# cvtdq2ps, cvtps2dq, cvttps2dq; cvttpd2dq, cvtpd2dq, cvtdq2pd
fn packedConvert(mut m Machine, d Instr):
	r = d.reg
	lo, hi = m.readW(d, 8 if d.opcode == 0xE6 and d.pfx == 2 else 16)
	if d.opcode == 0x5B:
		lanes = [0, 1, 2, 3].map(convertLane(lane32(lo, hi, it), d.pfx))
		m.setXmm(r, join32(lanes[0], lanes[1]), join32(lanes[2], lanes[3]))
		return
	if d.pfx == 2:
		m.setXmm(r, intToDouble(i64(widen(low32(lo), 4))), intToDouble(i64(widen(high32(lo), 4))))
		return
	truncate = d.pfx == 1
	m.setXmm(
		r,
		join32(u32.wrap(toInteger(f64.fromBits(lo), 4, truncate)), u32.wrap(toInteger(f64.fromBits(hi), 4, truncate))),
		0
	)

# a lane of cvtdq2ps (prefix 0), cvtps2dq (66) or cvttps2dq (F3)
fn convertLane(x u32, pfx i64) u32:
	if pfx == 0: return intToSingle(i64(widen(x, 4)))
	u32.wrap(toInteger(f64(f32.fromBits(x)), 4, pfx == 2))

# roundss, roundsd, roundps, roundpd (66 0F 3A 08..0B): the immediate's mode, bit 2 the MXCSR's
pub fn roundFloat(mut m Machine, d Instr):
	mode = 0 if d.imm & 4 != 0 else d.imm & 3
	r = d.reg
	match d.opcode:
		0x08:
			lo, hi = m.readW(d, 16)
			m.setXmm(r, join32(roundSingle(low32(lo), mode), roundSingle(high32(lo), mode)),
				join32(roundSingle(low32(hi), mode), roundSingle(high32(hi), mode)))
		0x09:
			lo, hi = m.readW(d, 16)
			m.setXmm(r, roundDouble(lo, mode), roundDouble(hi, mode))
		0x0A:
			lo, _ = m.readW(d, 4)
			m.setXmm(r, withLow32(m.lo(r), roundSingle(low32(lo), mode)), m.hi(r))
		_:
			lo, _ = m.readW(d, 8)
			m.setXmm(r, roundDouble(lo, mode), m.hi(r))

fn roundSingle(x u32, mode i64):
	if isNaN32(x): return x | 0x40_0000
	f32(roundTo(f64(f32.fromBits(x)), mode)).toBits()

fn roundDouble(x u64, mode i64):
	if isNaN64(x): return x | 0x8_0000_0000_0000
	roundTo(f64.fromBits(x), mode).toBits()
