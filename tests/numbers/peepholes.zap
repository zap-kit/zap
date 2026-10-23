# Shapes the backend shortens: `x & mask == 0` as one test, a literal on the left of a
# commutative operator, `x * 3`, `x * 5` and `x * 9` as one lea, f32 sums whose operands wait in
# a register.
fn collatzSteps(n i64):
	x = n
	steps = 0
	while x != 1:
		if x & 1 == 0:
			x >>= 1
		else:
			x = 3 * x + 1
		steps += 1
	steps

fn masks(xs i64[]):
	s = 0
	for x in xs:
		if x & 6 == 0:
			s += 1
		if x & -8 != 0:
			s += 10
		if not (x & 1 == 0):
			s += 100
	s

fn scaled(n i64):
	s = 0
	for i in -n..n:
		s += i * 3 + i * 5 - i * 9 + 7 * i + (2 & i) + (1 | i) + (5 ^ i)
	s

fn sums(a f32[], b f32[]):
	s = 0.0
	for i in 0..a.len:
		s += (a[i] * b[i] + a[i]) * (b[i] - a[i]) + (b[i] + a[i] * 2.0)
	s

test "tests, literals on the left, lea":
	expect collatzSteps(27) == 111
	expect collatzSteps(97) == 118
	expect masks([0, 1, 2, 7, 8, 9, -1, -8]) == 445
	expect scaled(50) == -250
	expect sums([1.0, 2.0, 0.5], [3.0, -1.0, 4.0]) == 29.75
