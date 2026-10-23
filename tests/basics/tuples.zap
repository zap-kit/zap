# Tuples beside other features (spec/tuples.zap states them): for i, x in xs walks a list with
# each element's index; generic structs written without type arguments take them from their fields.
type Pair<A, B>:
	left A
	right B

test "parallel results as tuples":
	parts = (0..10).parallel().map(k: (k, k * k))
	total = 0
	top = 0
	for (k, square) in parts:
		total += k
		top = top.max(square)
	expect total == 45
	expect top == 81

test "generic structs infer their type arguments":
	print(Pair(left = 1, right = "r"))
	p = Pair(left = "l", right = true)
	print(p)
	prints """
		Pair<i64, str>(left = 1, right = "r")
		Pair<str, bool>(left = "l", right = true)
		"""

test "for with an index over a list made there":
	for i, x in [1, 2].reversed():
		print(i + x)
	for i, w in ["a", "b"]:
		print("{i} {w}")
	prints """
		2
		2
		0 a
		1 b
		"""

test "for with an index over an element" refuses ForIndexNeedsPlace:
	rows = [[1], [2]]
	for i, x in rows[0]:
		print(i + x)

type Vec3f:
	x f32
	y f32
	z f32

fn shaded() (Vec3f, f32):
	(Vec3f(x = 0.5, y = 0.25, z = 0.125), 2.0)

test "taking a tuple apart leaves the field after an odd-sized struct whole":
	c, k = shaded()
	expect c.z == 0.125
	expect k == 2
