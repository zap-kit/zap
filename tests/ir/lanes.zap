# A vector's lane by a computed index, read and written, and a map whose key is a struct of many
# numbers (reached by its address), both through the intermediate form.
type Key:
	a i64
	b i64
	c i64
	d i64
	e i64
	f i64
	g bool

fn snapped(v Vec3, step f32):
	c = v
	for i in 0..3:
		c[i] = (c[i] / step).round() * step
	c

fn sum(v Vec4, n i64):
	t = f32(0.0)
	for i in 0..n:
		t += v[i]
	t

test "lanes by a computed index":
	print(snapped(Vec3(1.2, 2.6, -2.9), 0.5))
	expect sum(Vec4(1, 2, 3, 4), 3) == 6
	prints """
		Vec3(x = 1, y = 2.5, z = -3)
		"""

test "a lane past the end stops the program" stops IndexOutOfBounds:
	v = Vec3(1, 2, 3)
	print(v[args.len + 3])

test "a map keyed by a struct of many numbers":
	k1 = Key(a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = true)
	k2 = Key(a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = false)
	m = {k1: 7, k2: 8}
	expect m.len == 2
	expect (m.get(k1) ?? 0) == 7
	expect (m.get(Key(a = 0, b = 2, c = 3, d = 4, e = 5, f = 6, g = true)) ?? 0) == 0
