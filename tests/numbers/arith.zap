# Floating point and integer arithmetic classics: accumulation error, Newton's sqrt, Leibniz pi,
# statistics, Mandelbrot in ASCII, compound interest, integer edge cases.
#
# Integer literals: decimal, hexadecimal and binary, with `_` between digits.

import fs

fn newtonSqrt(x f64):
	g = x / 2.0
	loop 30:
		g = (g + x / g) / 2.0
	g

fn leibnizPi(terms i64):
	s = 0.0
	sign = 1.0
	for k in 0..terms:
		s += sign / (2.0 * k + 1.0)
		sign = -sign
	4.0 * s

fn mandelbrotRow(y f64):
	line = ""
	x = -2.0
	while x < 0.5:
		zr = 0.0
		zi = 0.0
		i = 0
		while i < 50 and zr * zr + zi * zi < 4.0:
			t = zr * zr - zi * zi + x
			zi = 2.0 * zr * zi + y
			zr = t
			i += 1
		if i == 50:
			line += "#"
		elif i > 10:
			line += "+"
		elif i > 4:
			line += "."
		else:
			line += " "
		x += 0.0625
	line

mut acc = 0.0
loop 10:
	acc += 0.1
print("0.1 * 10 = {acc}, equals 1.0: {acc == 1.0}")
print("1/3 = {1.0 / 3.0}, 2/3 = {2.0 / 3.0}, 1e21 = {1.0e21}, 1e-7 = {1.0e-7}")
print("sqrt(2) newton = {newtonSqrt(2.0)}, builtin = {(2.0).sqrt()}")
print("pi (100000 terms) = {leibnizPi(100000):.5}")
data = [2.5, 3.5, 7.25, 1.0, 9.75, 4.0, 6.5, 8.0]
mean = data.sum() / data.len
mut var = 0.0
for v in data:
	var += (v - mean) * (v - mean)
sd = (var / data.len).sqrt()
print("mean {mean:.3} sd {sd:.3} min {data.min() ?? 0.0} max {data.max() ?? 0.0}")
mut y = -1.0
while y <= 1.0:
	print(mandelbrotRow(y))
	y += 0.25
mut balance = 1000.0
for year in 1..6:
	balance *= 1.05
	print("year {year}: {balance:.2}")
print("floor/ceil/round: {(2.5).floor()} {(2.5).ceil()} {(2.5).round()} {(-2.5).round()} {i32(3.7)} {i32(-3.7)}")
big i64 = 9_223_372_036_854_775_807
print("i64 max {big}, max - 1 = {big - 1}, i32 max {2147483647}")
print("7 / 2 = {7 / 2}, -7 / 2 = {-7 / 2}, 7 % 3 = {7 % 3}, -7 % 3 = {-7 % 3}, 2 ** 10 = {2 ** 10}, 3 ** 4 = {3 ** 4}")
print("bits: {5 & 3} {5 | 3} {5 ^ 3} {1 << 10} {1024 >> 3} {~0}")
mut h i64 = 5381
for ch in "hello world".chars():
	h = (h * 33 + ch.charCode()) % 4_294_967_296
print("djb2 hash: {h}")
print("parsed: {i32.parse("42") ?? -1} {i32.parse("x") ?? -1} {f64.parse("3.25") ?? 0.0} {f64.parse("1e3") ?? 0.0}")

test "floating point and integer classics print their known values":
	main()
	prints fs.readFile("tests/numbers/arith.expected") ?? ""

test "decimals of a format carry into a new integer digit":
	print("{99.97:.1} {9.96:.1} {0.999:.2} {999.5:.0}")
	prints "100.0 10.0 1.00 1000"

test "pow, clamp and lerp on f32, f64 and integers":
	x f32 = 0.5
	y = 0.5
	n = 15
	m = -7
	expect x.pow(2.0) == 0.25
	expect y.pow(2.0) == 0.25
	expect x.clamp(0.0, 0.3) == 0.3
	expect n.clamp(0, 10) == 10
	expect m.clamp(-2, 2) == -2
	expect x.lerp(2.0, 0.5) == 1.25
	expect y.lerp(2.0, 0.5) == 1.25

test "a float ** a fraction is exp and ln's (fdlibm), an integer power repeated squaring":
	print("{1.1 ** 10.0} {2.5 ** -3.0} {0.5 ** 1023.0}")
	print("{2.5 ** 1.3} {2.5 ** 1.3 == (1.3 * 2.5.ln()).exp()}")
	inf = 1.0 / 0.0
	print("{inf ** 0.3} {inf.ln()} {0.0 ** 0.3}")
	prints """
		2.593742460100002 0.064 1.1125369292536007e-308
		3.2909555108355937 true
		Infinity Infinity 0
		"""

test "digit sums by / 10 and % 10":
	s = 0
	for i in 0..100000:
		x = i
		while x > 0:
			s += x % 10
			x /= 10
	expect s == 2_250_000

test "a remainder by a constant past 32 bits, which no immediate holds, takes a division":
	out = []
	for i in 0..8:
		out.push(i * 2_654_435_761 % 4_294_967_291)
	expect out ==
		[
			0,
			2_654_435_761,
			1_013_904_231,
			3_668_339_992,
			2_027_808_462,
			387_276_932,
			3_041_712_693,
			1_401_181_163
		]

test "a _ needs digits on both sides" refuses InvalidNumber:
	print(1000_)
