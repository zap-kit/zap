# The integer arithmetic and its flags (Intel SDM vol. 2 for each instruction, vol. 1 3.4.3 for
# the flags): add and subtract with and without carry, the logic, multiplication and division at
# every width, shifts and rotations. A flag the manual leaves undefined keeps its value.

pub fn maskOf(size i64) u64:
	if size == 8: return ~u64(0)
	(u64(1) << u64(8 * size)) - 1

pub fn isNegative(v u64, size i64) bool:
	(v >> u64(8 * size - 1)) & 1 == 1

# v of `size` bytes sign-extended to 64 bits
pub fn widen(v u64, size i64) u64:
	if size == 8: return v
	shift = u64(64 - 8 * size)
	u64(i64(v << shift) >> i64(shift))

fn parity(v u64):
	(v & 0xFF).bitCount() % 2 == 0

# SF, ZF and PF of a result
pub fn setResultFlags(mut m Machine, r u64, size i64):
	v = r & maskOf(size)
	m.zf = v == 0
	m.sf = isNegative(v, size)
	m.pf = parity(v)

pub fn logicFlags(mut m Machine, r u64, size i64):
	m.cf = false
	m.of = false
	m.setResultFlags(r, size)

# a + b + carry at `size` bytes, the flags set
pub fn addWithFlags(mut m Machine, a u64, b u64, carry u64, size i64) u64:
	mask = maskOf(size)
	r = (a + b + carry) & mask
	m.cf = r < a or (carry == 1 and r == a) if size == 8 else (a + b + carry) > mask
	m.of = isNegative((a ^ r) & (b ^ r), size)
	m.af = (a ^ b ^ r) & 0x10 != 0
	m.setResultFlags(r, size)
	r

# a - b - borrow at `size` bytes, the flags set
pub fn subWithFlags(mut m Machine, a u64, b u64, borrow u64, size i64) u64:
	r = (a - b - borrow) & maskOf(size)
	m.cf = a < b or (borrow == 1 and a == b)
	m.of = isNegative((a ^ b) & (a ^ r), size)
	m.af = (a ^ b ^ r) & 0x10 != 0
	m.setResultFlags(r, size)
	r

# operation k of the eight in ALU order (add or adc sbb and sub xor cmp) of a and b; cmp gives a
pub fn alu(mut m Machine, k i64, a u64, b u64, size i64) u64:
	carry u64 = 1 if m.cf else 0
	match k:
		0: m.addWithFlags(a, b, 0, size)
		1:
			m.logicFlags(a | b, size)
			a | b
		2: m.addWithFlags(a, b, carry, size)
		3: m.subWithFlags(a, b, carry, size)
		4:
			m.logicFlags(a & b, size)
			a & b
		5: m.subWithFlags(a, b, 0, size)
		6:
			m.logicFlags(a ^ b, size)
			a ^ b
		_:
			m.subWithFlags(a, b, 0, size)
			a

# the 128-bit product of two 64-bit numbers, (high, low)
pub fn mulWide(a u64, b u64) (u64, u64):
	al = a & 0xFFFF_FFFF
	ah = a >> 32
	bl = b & 0xFFFF_FFFF
	bh = b >> 32
	ll = al * bl
	lh = al * bh
	hl = ah * bl
	hh = ah * bh
	mid = (ll >> 32) + (lh & 0xFFFF_FFFF) + (hl & 0xFFFF_FFFF)
	(hh + (lh >> 32) + (hl >> 32) + (mid >> 32), (mid << 32) | (ll & 0xFFFF_FFFF))

# the signed 128-bit product, (high, low)
pub fn mulWideSigned(a u64, b u64) (u64, u64):
	hi, lo = mulWide(a, b)
	if i64(a) < 0: hi -= b
	if i64(b) < 0: hi -= a
	(hi, lo)

# a and b of `size` bytes multiplied signed: the product cut to the size, and whether it lost bits
pub fn imulTruncated(a u64, b u64, size i64) (u64, bool):
	wa = widen(a & maskOf(size), size)
	wb = widen(b & maskOf(size), size)
	hi, lo = mulWideSigned(wa, wb)
	r = lo & maskOf(size)
	if size == 8: return (r, hi != (~u64(0) if i64(lo) < 0 else 0))
	(r, widen(r, size) != lo or hi != (~u64(0) if i64(lo) < 0 else 0))

# (high:low) / d unsigned: the quotient and the remainder, none when the quotient does not fit
pub fn divWide(high u64, low u64, d u64) (u64, u64)?:
	if d == 0 or high >= d: return none
	if high == 0: return (low / d, low % d)
	q u64 = 0
	r = high
	for k in 0..64:
		top = r >> 63
		r = (r << 1) | ((low >> u64(63 - k)) & 1)
		q <<= 1
		if top == 1 or r >= d:
			r -= d
			q |= 1
	(q, r)

# (high:low) / d signed, at `size` bytes: none when d is 0 or the quotient leaves the size
pub fn idivWide(high u64, low u64, d u64, size i64) (u64, u64)?:
	negative = i64(high) < 0
	nh = high
	nl = low
	if negative:
		nl = ~low + 1
		nh = ~high + (1 if nl == 0 else 0)
	sd = widen(d & maskOf(size), size)
	ad = sd if i64(sd) >= 0 else ~sd + 1
	q, r = try divWide(nh, nl, ad)
	negQ = negative != (i64(sd) < 0)
	limit = u64(1) << u64(8 * size - 1)
	if (negQ and q > limit) or (not negQ and q >= limit): return none
	((~q + 1) if negQ else q, (~r + 1) if negative else r)

# shift or rotation k (rol ror rcl rcr shl shr sal sar) of v by count, the flags set
pub fn shift(mut m Machine, k i64, v u64, countIn u64, size i64) u64:
	bits = 8 * size
	count = i64(countIn & (0x3F if size == 8 else 0x1F))
	if count == 0: return v
	mask = maskOf(size)
	a = v & mask
	match k:
		0, 1:
			n = u64(count % bits)
			r = a if n == 0
				else (
					((a << n) | (a >> u64(bits) - n)) if k == 0
					else ((a >> n) | (a << u64(bits) - n))
				) & mask
			if k == 0:
				m.cf = r & 1 == 1
				m.of = isNegative(r, size) != m.cf
			else:
				m.cf = isNegative(r, size)
				m.of = isNegative(r, size) != isNegative(r << 1, size)
			r
		2, 3: m.rotateCarry(k == 2, a, count, size)
		4, 6:
			r = (a << u64(count)) & mask if count < bits else 0
			m.cf = count <= bits and (a >> u64(bits - count)) & 1 == 1
			m.of = isNegative(r, size) != m.cf
			m.setResultFlags(r, size)
			r
		5:
			r = a >> u64(count) if count < bits else 0
			m.cf = count <= bits and (a >> u64(count - 1)) & 1 == 1
			m.of = isNegative(a, size)
			m.setResultFlags(r, size)
			r
		_:
			s = i64(widen(a, size))
			r = u64(s >> (count.min(63))) & mask
			m.cf = (s >> ((count - 1).min(63))) & 1 == 1
			m.of = false
			m.setResultFlags(r, size)
			r

# rcl (left) or rcr through the carry, a bit at a time
fn rotateCarry(mut m Machine, left bool, a u64, count i64, size i64):
	r = a
	n = count % (8 * size + 1)
	loop n:
		c = m.cf
		if left:
			m.cf = isNegative(r, size)
			r = ((r << 1) | (1 if c else 0)) & maskOf(size)
		else:
			m.cf = r & 1 == 1
			r = (r >> 1) | (u64(1) << u64(8 * size - 1) if c else 0)
	if left: m.of = isNegative(r, size) != m.cf
	else: m.of = isNegative(r, size) != isNegative(r << 1, size)
	r
