# f32 arithmetic runs in single precision: each + - * / gives what the f64 operation rounded to
# f32 gives, wherever the operands come from (fields, elements, literals, parameters, calls).

type P:
	x f32
	y f32
	z f32

tenth f32 = 0.1
nearOne f32 = 0.7

fn r(v f64):
	f32(v)

fn third(v f32):
	v / 3.0

fn tree(p P, xs f32[], k f32):
	((p.x * xs[0] + p.y / k) - (xs[1] * 0.1 - p.z)) *
		((k + xs[2]) / (p.x - 0.7) + third(p.y) * (xs[0] - k))

# the same tree with every operation done in f64 and rounded to f32
fn treeRounded(p P, xs f32[], k f32):
	a = r(f64(r(f64(p.x) * f64(xs[0]))) + f64(r(f64(p.y) / f64(k))))
	b = r(f64(r(f64(xs[1]) * f64(tenth))) - f64(p.z))
	c = r(f64(r(f64(k) + f64(xs[2]))) / f64(r(f64(p.x) - f64(nearOne))))
	d = r(f64(r(f64(p.y) / 3.0)) * f64(r(f64(xs[0]) - f64(k))))
	r(f64(r(f64(a) - f64(b))) * f64(r(f64(c) + f64(d))))

test "f32 trees give the f64 operations rounded at each step":
	same = 0
	for i in 0..200:
		v = f32(i)
		p = P(x = v * 0.37 + 1.0, y = 3.1 - v * 0.013, z = v / 7.0)
		xs = [v * 1.7, 0.33 - v, v * v * 0.001]
		k = 1.0 + v * 0.29
		if p.tree(xs, k) == p.treeRounded(xs, k):
			same += 1
	print("{same} of 200 the same")
	prints "200 of 200 the same"

test "a deep f32 tree keeps every partial result":
	a f32 = 1.0
	xs f32[] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
	expect xs[0] + (xs[1] + (xs[2] + (xs[3] + (xs[4] + (xs[5] + (xs[6] + (xs[7] * a))))))) == 36
