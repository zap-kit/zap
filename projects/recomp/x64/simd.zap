# The integer SIMD instructions of SSE2 and SSE4.1 on the XMM registers (66 0F, 0F 38, 0F 3A):
# lane-wise arithmetic, compares, logic and shifts, unpacks and packs, shuffles, inserts and
# extracts, the moves between XMM and general registers; and SSE4.1's blends, insertps and rounding.

# whether 66 0F opcode is one of the integer instructions (the rest of 66 0F is double floats)
pub fn isIntegerSimd(opcode i64) bool:
	match opcode:
		0x60..=0x7F, 0xC4, 0xC5, 0xD1..=0xE5, 0xE7..=0xFE: true
		_: false

# the lane operations
laneAdd = 0
laneSub = 1
laneEq = 2
laneGt = 3   # signed
laneMulLow = 4
laneMinU = 5
laneMaxU = 6
laneMinS = 7
laneMaxS = 8

fn laneOf(op i64, a u64, b u64, bytes i64):
	sa = i64(widen(a, bytes))
	sb = i64(widen(b, bytes))
	all = maskOf(bytes)
	match op:
		0: a + b
		1: a - b
		2: all if a == b else 0
		3: all if sa > sb else 0
		4: a * b
		5: a.min(b)
		6: a.max(b)
		7: u64.wrap(sa.min(sb))
		_: u64.wrap(sa.max(sb))

# op of each lane pair of `bytes` bytes of two 64-bit halves
fn lanes(op i64, x u64, y u64, bytes i64):
	mask = maskOf(bytes)
	r u64 = 0
	for k in 0..8 / bytes:
		s = u64(8 * bytes * k)
		r |= (laneOf(op, (x >> s) & mask, (y >> s) & mask, bytes) & mask) << s
	r

# lane k of `bytes` bytes of a 128-bit value
fn laneAt(lo u64, hi u64, k i64, bytes i64):
	n = 8 / bytes
	half = lo if k < n else hi
	(half >> u64(8 * bytes * (k % n))) & maskOf(bytes)

# (lo, hi) with lane k set to v
fn withLane(lo u64, hi u64, k i64, bytes i64, v u64):
	n = 8 / bytes
	s = u64(8 * bytes * (k % n))
	mask = maskOf(bytes) << s
	if k < n: return ((lo & ~mask) | ((v << s) & mask), hi)
	(lo, (hi & ~mask) | ((v << s) & mask))

# the lanes of a's and b's halves interleaved: a0 b0 a1 b1 ...
fn interleave(a u64, b u64, bytes i64):
	lo = 0
	hi = 0
	n = 8 / bytes
	for k in 0..n:
		for (j, v) in [(2 * k, laneAt(a, 0, k, bytes)), (2 * k + 1, laneAt(b, 0, k, bytes))]:
			lo, hi = withLane(lo, hi, j, bytes, v)
	(lo, hi)

# a lane of `bytes` bytes narrowed to half as many with signed or unsigned saturation
fn saturate(v u64, bytes i64, unsigned bool):
	x = i64(widen(v, bytes))
	bits = 4 * bytes
	low = 0 if unsigned else -(1 << (bits - 1))
	high = (1 << bits) - 1 if unsigned else (1 << (bits - 1)) - 1
	u64.wrap(x.clamp(low, high)) & maskOf(bytes / 2)

# packsswb, packssdw, packuswb: a's lanes then b's, each narrowed
fn pack(alo u64, ahi u64, blo u64, bhi u64, bytes i64, unsigned bool):
	lo = 0
	hi = 0
	n = 16 / bytes
	for k in 0..2 * n:
		v = laneAt(alo, ahi, k, bytes) if k < n else laneAt(blo, bhi, k - n, bytes)
		lo, hi = withLane(lo, hi, k, bytes / 2, saturate(v, bytes, unsigned))
	(lo, hi)

# a lane shift: left, logical right or arithmetic right by count
fn shiftLanes(x u64, bytes i64, kind i64, count u64):
	bits = u64(8 * bytes)
	mask = maskOf(bytes)
	r u64 = 0
	for k in 0..8 / bytes:
		s = u64(8 * bytes * k)
		v = (x >> s) & mask
		out = match kind:
			0: (v << count) & mask if count < bits else 0
			1: v >> count if count < bits else 0
			_: u64.wrap(i64(widen(v, bytes)) >> i64(count.min(bits - 1))) & mask
		r |= out << s
	r

fn simdError(d Instr):
	"0x{d.at:x}: {d.textOf()} is not emulated"

pub fn execSimd(mut m Machine, d Instr) ? str:
	if d.map == 2: return m.execSse41(d)
	if d.map == 3: return m.execSse41Imm(d)
	r = d.reg
	alo = m.lo(r)
	ahi = m.hi(r)
	match (d.opcode, d.pfx):
		(0x6F, _):
			lo, hi = m.readW(d, 16)
			m.setXmm(r, lo, hi)
		(0x7F, _):
			if d.mem:
				m.mem.write(m.ea(d), 8, alo)
				m.mem.write(m.ea(d) + 8, 8, ahi)
			else: m.setXmm(d.rm, alo, ahi)
		(0x6E, _): m.setXmm(r, m.readE(d, 8 if d.rexW() else 4), 0)
		(0x7E, 1): m.writeE(d, 8 if d.rexW() else 4, alo & maskOf(8 if d.rexW() else 4))
		(0x7E, 2):
			lo, _ = m.readW(d, 8)
			m.setXmm(r, lo, 0)
		(0xD6, _):
			if d.mem: m.mem.write(m.ea(d), 8, alo)
			else: m.setXmm(d.rm, alo, 0)
		(0x70, _):
			lo, hi = m.readW(d, 16)
			m.shuffleWords(d, lo, hi)
		(0x71, _), (0x72, _), (0x73, _): m.shiftImmediate(d)
		(0xC4, _):
			v = m.readE(d, 2)
			lo, hi = withLane(alo, ahi, d.imm & 7, 2, v)
			m.setXmm(r, lo, hi)
		(0xC5, _): m.writeG(d, 4, laneAt(m.lo(d.rm), m.hi(d.rm), d.imm & 7, 2))
		(0xD7, _):
			bits = 0
			for k in 0..16:
				bits |= (laneAt(m.lo(d.rm), m.hi(d.rm), k, 1) >> 7) << u64(k)
			m.writeG(d, 4, bits)
		_:
			blo, bhi = m.readW(d, 16)
			return m.simdBinary(d, alo, ahi, blo, bhi)

# pshufd, pshufhw, pshuflw
fn shuffleWords(mut m Machine, d Instr, lo u64, hi u64):
	s = d.imm
	match d.pfx:
		1:
			out = [0, 1, 2, 3].map(laneAt(lo, hi, (s >> (2 * it)) & 3, 4))
			m.setXmm(d.reg, out[0] | out[1] << 32, out[2] | out[3] << 32)
		2:
			out = [0, 1, 2, 3].map(laneAt(hi, 0, (s >> (2 * it)) & 3, 2))
			m.setXmm(d.reg, lo, out[0] | out[1] << 16 | out[2] << 32 | out[3] << 48)
		_:
			out = [0, 1, 2, 3].map(laneAt(lo, 0, (s >> (2 * it)) & 3, 2))
			m.setXmm(d.reg, out[0] | out[1] << 16 | out[2] << 32 | out[3] << 48, hi)

# 66 0F 71..73: psrlw psraw psllw, psrld psrad pslld, psrlq psrldq psllq pslldq by the immediate
fn shiftImmediate(mut m Machine, d Instr):
	r = d.rm
	lo = m.lo(r)
	hi = m.hi(r)
	n = u64.wrap(d.imm) & 0xFF
	bytes = match d.opcode:
		0x71: 2
		0x72: 4
		_: 8
	kind = match d.reg & 7:
		2: 1
		4: 2
		6: 0
		_: 3
	if kind < 3:
		m.setXmm(r, shiftLanes(lo, bytes, kind, n), shiftLanes(hi, bytes, kind, n))
		return
	# psrldq (3), pslldq (7): whole bytes
	k = i64(n.min(16))
	out = [u64(0), u64(0)]
	for j in 0..16:
		from = j + k if d.reg & 7 == 3 else j - k
		if from < 0 or from > 15: continue
		v = laneAt(lo, hi, from, 1)
		out[j / 8] |= v << u64(8 * (j % 8))
	m.setXmm(r, out[0], out[1])

# the two-operand lane instructions of 66 0F
fn simdBinary(mut m Machine, d Instr, alo u64, ahi u64, blo u64, bhi u64) ? str:
	r = d.reg
	both = (op i64, bytes i64): m.setXmm(r, lanes(op, alo, blo, bytes), lanes(op, ahi, bhi, bytes))
	match d.opcode:
		0x60..=0x62, 0x6C:
			bytes = 8 if d.opcode == 0x6C else 1 << (d.opcode - 0x60)
			lo, hi = interleave(alo, blo, bytes)
			m.setXmm(r, lo, hi)
		0x68..=0x6A, 0x6D:
			bytes = 8 if d.opcode == 0x6D else 1 << (d.opcode - 0x68)
			lo, hi = interleave(ahi, bhi, bytes)
			m.setXmm(r, lo, hi)
		0x63, 0x67, 0x6B:
			bytes = 4 if d.opcode == 0x6B else 2
			lo, hi = pack(alo, ahi, blo, bhi, bytes, d.opcode == 0x67)
			m.setXmm(r, lo, hi)
		0x64..=0x66: both(laneGt, 1 << (d.opcode - 0x64))
		0x74..=0x76: both(laneEq, 1 << (d.opcode - 0x74))
		0xD1..=0xD3, 0xE1, 0xE2, 0xF1..=0xF3:
			bytes = 1 << (d.opcode & 3)
			kind = 1 if d.opcode < 0xE0 else 2 if d.opcode < 0xF0 else 0
			m.setXmm(r, shiftLanes(alo, bytes, kind, blo), shiftLanes(ahi, bytes, kind, blo))
		0xD4: both(laneAdd, 8)
		0xD5: both(laneMulLow, 2)
		0xDA: both(laneMinU, 1)
		0xDE: both(laneMaxU, 1)
		0xEA: both(laneMinS, 2)
		0xEE: both(laneMaxS, 2)
		0xDB: m.setXmm(r, alo & blo, ahi & bhi)
		0xDF: m.setXmm(r, ~alo & blo, ~ahi & bhi)
		0xEB: m.setXmm(r, alo | blo, ahi | bhi)
		0xEF: m.setXmm(r, alo ^ blo, ahi ^ bhi)
		0xF4: m.setXmm(
			r,
			(alo & 0xFFFF_FFFF) * (blo & 0xFFFF_FFFF),
			(ahi & 0xFFFF_FFFF) * (bhi & 0xFFFF_FFFF)
		)
		0xF8..=0xFB: both(laneSub, 1 << (d.opcode - 0xF8))
		0xFC..=0xFE: both(laneAdd, 1 << (d.opcode - 0xFC))
		_: return d.simdError()

# 66 0F 38: pshufb, blendvps, ptest, the 64-bit compares, min and max of 8 and 32 bits, pmulld
fn execSse41(mut m Machine, d Instr) ? str:
	r = d.reg
	alo = m.lo(r)
	ahi = m.hi(r)
	blo, bhi = m.readW(d, 16)
	both = (op i64, bytes i64): m.setXmm(r, lanes(op, alo, blo, bytes), lanes(op, ahi, bhi, bytes))
	match d.opcode:
		0x00:
			lo = 0
			hi = 0
			for k in 0..16:
				sel = laneAt(blo, bhi, k, 1)
				v = u64(0) if sel & 0x80 != 0 else laneAt(alo, ahi, sel & 15, 1)
				lo, hi = withLane(lo, hi, k, 1, v)
			m.setXmm(r, lo, hi)
		0x14:
			lo = alo
			hi = ahi
			for k in 0..4:
				if laneAt(m.lo(0), m.hi(0), k, 4) >> 31 == 1:
					lo, hi = withLane(lo, hi, k, 4, laneAt(blo, bhi, k, 4))
			m.setXmm(r, lo, hi)
		0x17:
			m.logicFlags(0, 8)
			m.zf = (alo & blo) == 0 and (ahi & bhi) == 0
			m.cf = (~alo & blo) == 0 and (~ahi & bhi) == 0
		0x29: both(laneEq, 8)
		0x37: both(laneGt, 8)
		0x38: both(laneMinS, 1)
		0x39: both(laneMinS, 4)
		0x3B: both(laneMinU, 4)
		0x3D: both(laneMaxS, 4)
		0x3F: both(laneMaxU, 4)
		0x40: both(laneMulLow, 4)
		_: return d.simdError()

# 66 0F 3A: rounding, blendps, pextrd, extractps, insertps, pinsrd
fn execSse41Imm(mut m Machine, d Instr) ? str:
	r = d.reg
	match d.opcode:
		0x08..=0x0B: m.roundFloat(d)
		0x0C:
			blo, bhi = m.readW(d, 16)
			lo = m.lo(r)
			hi = m.hi(r)
			for k in 0..4:
				if (d.imm >> k) & 1 == 1: lo, hi = withLane(lo, hi, k, 4, laneAt(blo, bhi, k, 4))
			m.setXmm(r, lo, hi)
		0x16, 0x17:
			bytes = 8 if d.rexW() and d.opcode == 0x16 else 4
			k = d.imm & (1 if bytes == 8 else 3)
			m.writeE(d, bytes, laneAt(m.lo(r), m.hi(r), k, bytes))
		0x21:
			source = m.mem.read(m.ea(d), 4) if d.mem
				else laneAt(m.lo(d.rm), m.hi(d.rm), (d.imm >> 6) & 3, 4)
			lo, hi = withLane(m.lo(r), m.hi(r), (d.imm >> 4) & 3, 4, source)
			for k in 0..4:
				if (d.imm >> k) & 1 == 1: lo, hi = withLane(lo, hi, k, 4, 0)
			m.setXmm(r, lo, hi)
		0x22:
			bytes = 8 if d.rexW() else 4
			lo, hi = withLane(
				m.lo(r),
				m.hi(r),
				d.imm & (1 if bytes == 8 else 3),
				bytes,
				m.readE(d, bytes)
			)
			m.setXmm(r, lo, hi)
		_: return d.simdError()
