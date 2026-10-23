# SSE's float arithmetic on the bits of single (u32) and double (u64) values, as Intel SDM vol. 1
# 4.8.3 and 11.5.2 give it under the default MXCSR: an operation with a NaN operand gives the first
# source's NaN if it is one, else the second's, made quiet; an invalid operation (inf - inf, 0 x inf,
# 0 / 0, the root of a negative) gives the default NaN (negative, quiet); min and max give the second
# operand when either is a NaN or both are zero; a conversion to an integer out of range or of a
# NaN gives the integer indefinite (only the sign bit set). The rest is IEEE 754 rounded to nearest,
# which Zap's operators on f32 and f64 are.

pub defaultNaN32 u32 = 0xFFC0_0000
pub defaultNaN64 u64 = 0xFFF8_0000_0000_0000

pub fn isNaN32(a u32) bool:
	a & 0x7F80_0000 == 0x7F80_0000 and a & 0x7F_FFFF != 0

pub fn isNaN64(a u64) bool:
	a & 0x7FF0_0000_0000_0000 == 0x7FF0_0000_0000_0000 and a & 0xF_FFFF_FFFF_FFFF != 0

# the operations by number: add, sub, mul, div, min, max, sqrt (of b)
pub opAdd = 0
pub opSub = 1
pub opMul = 2
pub opDiv = 3
pub opMin = 4
pub opMax = 5
pub opSqrt = 6

pub fn arith32(op i64, a u32, b u32) u32:
	x = f32.fromBits(a)
	y = f32.fromBits(b)
	if op == opMin: return a if x < y else b
	if op == opMax: return a if x > y else b
	if op == opSqrt:
		if isNaN32(b): return b | 0x40_0000
		r = y.sqrt().toBits()
		return defaultNaN32 if isNaN32(r) else r
	if isNaN32(a): return a | 0x40_0000
	if isNaN32(b): return b | 0x40_0000
	r = match op:
		0: x + y
		1: x - y
		2: x * y
		_: x / y
	bits = r.toBits()
	defaultNaN32 if isNaN32(bits) else bits

pub fn arith64(op i64, a u64, b u64) u64:
	x = f64.fromBits(a)
	y = f64.fromBits(b)
	if op == opMin: return a if x < y else b
	if op == opMax: return a if x > y else b
	if op == opSqrt:
		if isNaN64(b): return b | 0x8_0000_0000_0000
		r = y.sqrt().toBits()
		return defaultNaN64 if isNaN64(r) else r
	if isNaN64(a): return a | 0x8_0000_0000_0000
	if isNaN64(b): return b | 0x8_0000_0000_0000
	r = match op:
		0: x + y
		1: x - y
		2: x * y
		_: x / y
	bits = r.toBits()
	defaultNaN64 if isNaN64(bits) else bits

# single to double, a NaN's payload kept and made quiet
pub fn widen32(a u32) u64:
	if isNaN32(a): return (u64(a >> 31) << 63) | 0x7FF8_0000_0000_0000 | (u64(a & 0x3F_FFFF) << 29)
	f64(f32.fromBits(a)).toBits()

# double to single rounded to nearest, a NaN's payload's top bits kept and made quiet
pub fn narrow64(a u64) u32:
	if isNaN64(a): return u32(a >> 63) << 31 | 0x7FC0_0000 | u32((a >> 29) & 0x3F_FFFF)
	f32(f64.fromBits(a)).toBits()

# an integer (of 64 bits, signed) to single, rounded once
pub fn intToSingle(v i64) u32:
	if v > -(1 << 53) and v < (1 << 53): return f32(f64(v)).toBits()
	negative = v < 0
	s = u64(v) if not negative else ~u64(v) + 1
	# the bits below the 53 an f64 holds, folded into one that keeps the rounding's direction
	t = (s >> 11) | (1 if s & 0x7FF != 0 else 0)
	r = f32(t * 2048.0)
	(-r if negative else r).toBits()

pub fn intToDouble(v i64) u64:
	f64(v).toBits()

# x rounded to an integral value: mode 0 nearest (ties to even), 1 down, 2 up, 3 toward zero; the
# sign of a zero kept
pub fn roundTo(x f64, mode i64) f64:
	if x != x or x.abs() >= 4_503_599_627_370_496.0: return x
	r = match mode & 3:
		0:
			down = x.floor()
			gap = x - down
			up = gap > 0.5 or (gap == 0.5 and (down * 0.5).floor() * 2.0 != down)
			down + 1.0 if up else down
		1: x.floor()
		2: x.ceil()
		_: x.trunc()
	if r == 0.0: return -0.0 if x < 0.0 or (x == 0.0 and x.toBits() >> 63 == 1) else 0.0
	r

# x to an integer of `bytes` (4 or 8) truncated or rounded to nearest; the indefinite when it
# does not fit or is a NaN
pub fn toInteger(x f64, bytes i64, truncate bool) u64:
	indefinite = u64(1) << u64(8 * bytes - 1)
	if x != x: return indefinite
	r = x.trunc() if truncate else roundTo(x, 0)
	limit = 2_147_483_648.0 if bytes == 4 else 9_223_372_036_854_775_808.0
	if r >= limit or r < -limit: return indefinite
	u64.wrap(i64(r)) & maskOf(bytes)

# comparison of two singles: -2 unordered, -1 less, 0 equal, 1 greater
pub fn order32(a u32, b u32) i64:
	if isNaN32(a) or isNaN32(b): return -2
	x = f32.fromBits(a)
	y = f32.fromBits(b)
	-1 if x < y else 1 if x > y else 0

pub fn order64(a u64, b u64) i64:
	if isNaN64(a) or isNaN64(b): return -2
	x = f64.fromBits(a)
	y = f64.fromBits(b)
	-1 if x < y else 1 if x > y else 0

# cmpss's predicate p (0 eq, 1 lt, 2 le, 3 unord, 4 neq, 5 nlt, 6 nle, 7 ord) of an order
pub fn predicateHolds(p i64, order i64) bool:
	match p & 7:
		0: order == 0
		1: order == -1
		2: order == -1 or order == 0
		3: order == -2
		4: order != 0
		5: order != -1
		6: order == 1 or order == -2
		_: order != -2
