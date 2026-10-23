# The operations too long to lower step by step, written once and called by number from the
# common form (a Helper step): the shifts and rotations by a count, the divisions, the decimal
# arithmetic and the bound checks. Each reads and sets the machine's flags itself; helperFlagsRead
# and helperFlagsWritten say which, so the flags around them are kept or left out rightly.

pub helperAsl = 0
pub helperAsr = 1
pub helperLsl = 2
pub helperLsr = 3
pub helperRol = 4
pub helperRor = 5
pub helperRoxl = 6
pub helperRoxr = 7
pub helperDivu = 8
pub helperDivs = 9
pub helperAbcd = 10
pub helperSbcd = 11
pub helperChk = 12
pub helperTrapv = 13

nzvc = 1 << flagN | 1 << flagZ | 1 << flagV | 1 << flagC

pub fn helperFlagsRead(h i64) i64:
	match h:
		6, 7: 1 << flagX
		10, 11: 1 << flagX | 1 << flagZ
		13: 1 << flagV
		_: 0

pub fn helperFlagsWritten(h i64) i64:
	match h:
		4, 5, 8, 9: nzvc
		10, 11: 1 << flagX | 1 << flagZ | 1 << flagC
		12: 1 << flagN
		13: 0
		_: allFlags

# the helper's result: a shift's value, a division's register, a decimal sum
pub fn helper(h i64, a u32, b u32, size i64) u32:
	match h:
		0, 1, 2, 3, 4, 5, 6, 7: shifted(h, a, b & 63, size)
		8: divu(a, b)
		9: divs(a, b)
		10: abcd(a, b)
		11: sbcd(a, b)
		12: chk(a, b)
		_:
			if cv: stop("TRAPV with the overflow flag set")
			0

pub fn sizeMask(size i64) u32:
	match size:
		1: 0xFF
		2: 0xFFFF
		_: 0xFFFF_FFFF

fn top(v u32, size i64):
	v >> (size * 8 - 1) & 1 != 0

fn setNz(r u32, size i64):
	cn = top(r, size)
	cz = r & sizeMask(size) == 0

# a shift or rotation of v (its low `size` bytes) by count (0-63), the flags as the 68000 sets them
fn shifted(h i64, v0 u32, count i64, size i64):
	bits = size * 8
	v = v0 & sizeMask(size)
	r = v
	cv = false
	if count == 0:
		cc = cx if h >= helperRoxl else false
		setNz(r, size)
		return r
	match h:
		0, 2:
			if count <= bits:
				cc = v >> (bits - count) & 1 != 0
				r = v << count & sizeMask(size) if count < 32 else 0
			else:
				cc = false
				r = 0
			cx = cc
			if h == helperAsl:
				if count >= bits:
					cv = v != 0
				else:
					t = v >> (bits - count - 1)
					cv = t != 0 and t != (u32(1) << (count + 1)) - 1
		1:
			sv = i64(v) - (1 << bits) if top(v, size) else v
			n = count.min(bits)
			cc = sv >> (n - 1) & 1 != 0
			r = u32.wrap(sv >> n) & sizeMask(size)
			cx = cc
		3:
			if count <= bits:
				cc = v >> (count - 1) & 1 != 0
				r = v >> count if count < 32 else 0
			else:
				cc = false
				r = 0
			cx = cc
		4:
			n = count % bits
			r = (v << n | v >> (bits - n)) & sizeMask(size) if n != 0 else v
			cc = r & 1 != 0
		5:
			n = count % bits
			r = (v >> n | v << (bits - n)) & sizeMask(size) if n != 0 else v
			cc = top(r, size)
		_:
			loop count % (bits + 1):
				if h == helperRoxl:
					out = top(r, size)
					r = (r << 1 | (1 if cx else 0)) & sizeMask(size)
					cx = out
				else:
					out = r & 1 != 0
					r = r >> 1 | (u32(1) << (bits - 1) if cx else 0)
					cx = out
			cc = cx
	setNz(r, size)
	r

# DIVU: the 32 bits of a by b's low word; the remainder and the quotient, or a unchanged on
# overflow
fn divu(a u32, b u32):
	divisor = b & 0xFFFF
	if divisor == 0: return a   # the lowering raised exception 5 before
	q = a / divisor
	cc = false
	if q > 0xFFFF:
		cv = true
		return a
	cv = false
	cn = q & 0x8000 != 0
	cz = q == 0
	(a % divisor) << 16 | q

fn divs(a u32, b u32):
	divisor = i64(i16.wrap(i64(b & 0xFFFF)))
	if divisor == 0: return a
	dividend = i64(i32.wrap(i64(a)))
	q = dividend / divisor
	cc = false
	if q < -32_768 or q > 32_767:
		cv = true
		return a
	cv = false
	cn = q < 0
	cz = q == 0
	u32(u16.wrap(dividend % divisor)) << 16 | u16.wrap(q)

# ABCD and SBCD: two packed decimal bytes, X in; Z kept clear by a non-zero result
fn abcd(d u32, s u32):
	r = (s & 15) + (d & 15) + (1 if cx else 0)
	if r > 9: r += 6
	r += (s & 0xF0) + (d & 0xF0)
	cc = r > 0x99
	if cc: r -= 0xA0
	cx = cc
	r &= 0xFF
	if r != 0: cz = false
	r

fn sbcd(d u32, s u32):
	r = (d & 15) - (s & 15) - (1 if cx else 0)
	if r > 9: r -= 6
	r += (d & 0xF0) - (s & 0xF0)
	cc = r > 0x99
	if cc: r += 0xA0
	cx = cc
	r &= 0xFF
	if r != 0: cz = false
	r

# CHK: a register's word against 0 and a bound
fn chk(v u32, bound u32) u32:
	x = i64(i16.wrap(i64(v & 0xFFFF)))
	if x < 0:
		cn = true
		stop("CHK out of bounds (the 68000's exception 6)")
	if x > i16.wrap(i64(bound & 0xFFFF)):
		cn = false
		stop("CHK out of bounds (the 68000's exception 6)")
	0
