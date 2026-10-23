# Constant arithmetic, one for both compilers: an operator on two integers of `bits` bits (the
# CPU's 64, the GPU's 32), wrapping as the machine does, and on two floats of `bits` bits, each
# result rounded to them. none where the operation is not folded (a division by zero, a shift
# past the width, an operator of another kind). Also the small arithmetic both compilers' layouts
# share.

# the integer `bits` bits hold of v (signed)
pub fn wrapBits(v i64, bits i64) i64:
	if bits >= 64: return v
	shift = 64 - bits
	(v << shift) >> shift

# v rounded to the float of `bits` bits nearest it (an operation on two f32s done in f64 and
# rounded so is the f32 operation's result)
pub fn roundBits(v f64, bits i64) f64:
	f64(f32(v)) if bits == 32 else v

# a + b (k 0), a - b (1) or a * b (2) wrapped to 64 bits
pub fn intWrapped(k i64, a i64, b i64) i64:
	ua = u64(a)
	ub = u64(b)
	i64(ua + ub if k == 0 else ua - ub if k == 1 else ua * ub)

# a + b (k 0), a - b (1) or a * b (2), none when the result leaves 64 bits, signed
pub fn intChecked(k i64, a i64, b i64) i64?:
	v = intWrapped(k, a, b)
	if k == 0 and (a >= 0) == (b >= 0) and (v >= 0) != (a >= 0): return none
	if k == 1 and (a >= 0) != (b >= 0) and (v >= 0) != (a >= 0): return none
	if k == 2 and a != 0 and ((a == -1 and b == minI64) or (b == -1 and a == minI64) or v / a != b):
		return none
	v

# the smallest i64
pub minI64 = -9_223_372_036_854_775_807 - 1

# An operator on two integers folded at `bits` bits: at 64 (the CPU's) none when + - * leave
# them or a division is MIN / -1, as the program would stop; at 32 (the GPU's) wrapped.
pub fn intOp(op str, a i64, b i64, bits i64) i64?:
	v = 0
	if op in ["+", "-", "*"]:
		k = 0 if op == "+" else 1 if op == "-" else 2
		v = (try intChecked(k, a, b)) if bits >= 64 else intWrapped(k, a, b)
	elif op == "/" and b == -1:
		if bits >= 64 and a == minI64: return none
		v = intWrapped(1, 0, a)
	elif op == "%" and b == -1:
		v = 0
	elif (op == "/" or op == "%") and b != 0:
		v = a / b if op == "/" else a % b
	elif op == "&":
		v = a & b
	elif op == "|":
		v = a | b
	elif op == "^":
		v = a ^ b
	elif (op == "<<" or op == ">>") and b >= 0 and b < bits:
		v = a << b if op == "<<" else a >> b
	else:
		return none
	wrapBits(v, bits)

pub fn floatOp(op str, a f64, b f64, bits i64) f64?:
	v = 0.0
	if op == "+":
		v = a + b
	elif op == "-":
		v = a - b
	elif op == "*":
		v = a * b
	elif op == "/":
		v = a / b
	else:
		return none
	roundBits(v, bits)

# a comparison of two integers, none for another operator
pub fn compareOp(op str, a i64, b i64) bool?:
	if op == "==": return a == b
	if op == "!=": return a != b
	if op == "<": return a < b
	if op == ">": return a > b
	if op == "<=": return a <= b
	if op == ">=": return a >= b
	none
