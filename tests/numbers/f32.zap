# f32 locals in arithmetic: both operands are loaded from their slots (the right one into
# rcx through xmm0), converted, combined and narrowed back.
#
# f32 values through calls: an argument that needs code (a conversion, a call) is computed
# before the others, and its slot holds the f32 like every other; trigonometry and logarithms.
#
# f32 comparisons as conditions (ucomiss and a jump; a NaN is never equal, less or greater),
# the square root of an f32 (sqrtss), and f32 results of inlined methods used as
# f32 again without a round trip through f64.

mut a f32 = f32(1.5)
mut b f32 = f32(2.25)
loop 2:
	a += b
	b = b * a - a
print(a)
print(b)
print(a < b)

test "f32 locals are loaded, combined and narrowed back":
	main()
	prints """
	    8.4375
	    31.113281
	    true
	    """

type Acc:
	vs f32[]

fn add2(mut a Acc, x f32, y f32):
	a.vs.push(x)
	a.vs.push(y)

test "an f32 argument computed before the others keeps its value":
	a = Acc(vs = [])
	for i in 0..2:
		a.add2(f32(i), 20.0)
	expect a.vs == [0, 20, 1, 20]

test "trigonometry, exp and ln":
	print(1.0.sin())
	print(0.5.cos())
	print((-1.0).atan2(-1.0))
	print(0.7.atan())
	print(10.0.ln())
	x f32 = 0.5
	print(x.sin())
	print(2.0.exp().ln())
	prints """
		0.8414709848078965
		0.8775825618903728
		-2.356194490192345
		0.6107259643892086
		2.302585092994046
		0.47942555
		2
		"""

type P:
	x f32
	y f32

	fn len2():
		x * x + y * y

	fn len():
		len2().sqrt()

fn classify(a f32, b f32):
	s = ""
	if a < b:
		s += "<"
	if a <= b:
		s += "l"
	if a > b:
		s += ">"
	if a >= b:
		s += "g"
	if a == b:
		s += "="
	if a != b:
		s += "!"
	if not (a < b):
		s += "n"
	s

test "f32 comparisons hold for ordered values and fail for nan":
	nan = f32(0.0) / f32(0.0)
	expect classify(1.0, 2.0) == "<l!"
	expect classify(2.0, 1.0) == ">g!n"
	expect classify(1.5, 1.5) == "lg=n"
	expect classify(nan, 1.0) == "!n"
	expect classify(1.0, nan) == "!n"
	ps = [P(x = 3.0, y = 4.0), P(x = 1.0, y = 1.0)]
	far = 0
	for p in ps:
		if p.len2() > 10.0:
			far += 1
	expect far == 1

test "f32 square roots":
	expect P(x = 3.0, y = 4.0).len == 5.0
	x f32 = 2.0
	r = x.sqrt()
	expect r == 1.4142135
	expect r * r != 2.0
	s = 0.0
	for i in 0..100:
		s += f32(i).sqrt()
	expect s == 661.463
