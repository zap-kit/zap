# Every vector method and operator on every Simd type, each lane against the scalar code's (run
# with --target linux-arm64 too: a vector instruction a backend does not lower stops the program)
use fusedMultiplyAdd

# the vector's lanes against the scalar code's, printed when they differ
fn same(name str, got str, want str):
	if got != want:
		print("{name}: {got}, scalar {want}")

# bit i set where flags[i] holds: a mask method's scalar
fn bits(flags bool[]):
	m = 0
	for i, f in flags:
		if f:
			m |= 1 << i
	m

test "Simd<4, f64>":
	xs = [4.0, -2.5, 9.0, 0.1]
	ys = [1.5, 3.0, -9.0, 10.0]
	zs = [-0.4, 1.0, 2.0, -1.0]
	a = xs.load4(0)
	b = ys.load4(0)
	c = zs.load4(0)
	same("add", "{a + b}", "{(0..4).map(xs[it] + ys[it])}")
	same("sub", "{a - b}", "{(0..4).map(xs[it] - ys[it])}")
	same("mul", "{a * b}", "{(0..4).map(xs[it] * ys[it])}")
	same("div", "{a / b}", "{(0..4).map(xs[it] / ys[it])}")
	same("min", "{a.min(b)}", "{(0..4).map(xs[it].min(ys[it]))}")
	same("max", "{a.max(b)}", "{(0..4).map(xs[it].max(ys[it]))}")
	same("ltMask", "{a.ltMask(b)}", "{bits((0..4).map(xs[it] < ys[it]))}")
	same("leMask", "{a.leMask(b)}", "{bits((0..4).map(xs[it] <= ys[it]))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..4).map(xs[it] > ys[it]))}")
	same("geMask", "{a.geMask(b)}", "{bits((0..4).map(xs[it] >= ys[it]))}")
	same("sum", "{a.sum()}", "{(xs[0] + xs[1]) + (xs[2] + xs[3])}")
	same("lane", "{a.lane(2)} {a.lane(args.len + 2)}", "{xs[2]} {xs[2]}")
	same("splat", "{Simd<4>(xs[3])}", "{fill(4, xs[3])}")
	same("literal", "{Simd<4>(4.0, -2.5, 9.0, 0.1)} {Simd<4>(xs[0], xs[1], xs[2], xs[3])}",
		"{xs} {xs}")
	same("sqrt", "{(a * a).sqrt()}", "{(0..4).map((xs[it] * xs[it]).sqrt())}")
	same("spread", "{a.spread(1)} {a.spread(args.len + 3)}", "{fill(4, xs[1])} {fill(4, xs[3])}")
	same("sums4", "{a.sums4(b, c, a + b)}", "{[a.sum(), b.sum(), c.sum(), (a + b).sum()]}")
	same("mulAdd", "{a * b + c}", "{(0..4).map(xs[it] * ys[it] + zs[it])}")
	same("mulSub", "{a * b - c}", "{(0..4).map(xs[it] * ys[it] - zs[it])}")
	same("subMul", "{c - a * b}", "{(0..4).map(zs[it] - xs[it] * ys[it])}")
	same("rounded once", "{xs[3] * ys[3] + zs[3] != 0.0}", "true")   # 0.1 * 10 - 1 is 0 rounded twice
	est = (a * a).rsqrtEstimate()
	worst = (0..4).map(((est.lane(it) - 1.0 / xs[it].abs()) * xs[it].abs()).abs()).max() ?? 1.0
	same("rsqrtEstimate", "{worst <= 1.5 / 4096.0}", "true")
	out f64[] = zeros(6)
	out.store4(1, a)
	same("store4", "{out}", "{[0.0, xs[0], xs[1], xs[2], xs[3], 0.0]}")
	print("Simd<4, f64> done")
	prints "Simd<4, f64> done"

test "Simd<8, f32>":
	fs f32[] = [1.5, -2.0, 3.25, 0.1, -0.5, 7.0, 8.0, 1.0e-3]
	gs f32[] = [0.5, -2.0, 4.0, 0.3, 0.25, -7.0, 1.0, 3.0]
	a = fs.load8(0)
	b = gs.load8(0)
	same("add", "{a + b}", "{(0..8).map(fs[it] + gs[it])}")
	same("sub", "{a - b}", "{(0..8).map(fs[it] - gs[it])}")
	same("mul", "{a * b}", "{(0..8).map(fs[it] * gs[it])}")
	same("div", "{a / b}", "{(0..8).map(fs[it] / gs[it])}")
	same("min", "{a.min(b)}", "{(0..8).map(fs[it].min(gs[it]))}")
	same("max", "{a.max(b)}", "{(0..8).map(fs[it].max(gs[it]))}")
	same("eqMask", "{a.eqMask(b)}", "{bits((0..8).map(fs[it] == gs[it]))}")
	same("ltMask", "{a.ltMask(b)}", "{bits((0..8).map(fs[it] < gs[it]))}")
	same("leMask", "{a.leMask(b)}", "{bits((0..8).map(fs[it] <= gs[it]))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..8).map(fs[it] > gs[it]))}")
	same("geMask", "{a.geMask(b)}", "{bits((0..8).map(fs[it] >= gs[it]))}")
	total = 0.0
	for f in fs:
		total += f
	same("sum", "{a.sum()}", "{total}")
	same("lane", "{a.lane(5)} {a.lane(args.len + 7)}", "{fs[5]} {fs[7]}")
	same("splat", "{Simd<8>(fs[2])}", "{fill(8, fs[2])}")
	out = fill(10, f32(0.0))
	out.store8(2, a)
	same("store8", "{out[2..]}", "{fs}")
	print("Simd<8, f32> done")
	prints "Simd<8, f32> done"

test "Simd<8, i32>":
	ns i32[] = [1, -2, 300, -4, 5, 65_536, 7, -8]
	ms i32[] = [1, 3, -300, -4, 6, 255, -7, 9]
	a = ns.load8(0)
	b = ms.load8(0)
	same("add", "{a + b}", "{(0..8).map(ns[it] + ms[it])}")
	same("sub", "{a - b}", "{(0..8).map(ns[it] - ms[it])}")
	same("mul", "{a * b}", "{(0..8).map(ns[it] * ms[it])}")
	same("and", "{a & b}", "{(0..8).map(ns[it] & ms[it])}")
	same("or", "{a | b}", "{(0..8).map(ns[it] | ms[it])}")
	same("xor", "{a ^ b}", "{(0..8).map(ns[it] ^ ms[it])}")
	same("min", "{a.min(b)}", "{(0..8).map(ns[it].min(ms[it]))}")
	same("max", "{a.max(b)}", "{(0..8).map(ns[it].max(ms[it]))}")
	same("eqMask", "{a.eqMask(b)}", "{bits((0..8).map(ns[it] == ms[it]))}")
	same("ltMask", "{a.ltMask(b)}", "{bits((0..8).map(ns[it] < ms[it]))}")
	same("leMask", "{a.leMask(b)}", "{bits((0..8).map(ns[it] <= ms[it]))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..8).map(ns[it] > ms[it]))}")
	same("geMask", "{a.geMask(b)}", "{bits((0..8).map(ns[it] >= ms[it]))}")
	same("sum", "{a.sum()}", "{ns.sum()}")
	same("lane", "{a.lane(5)} {a.lane(args.len + 7)}", "{ns[5]} {ns[7]}")
	same("splat", "{Simd<8>(ns[2])}", "{fill(8, ns[2])}")
	out = fill(10, ns[0] - ns[0])
	out.store8(2, a)
	same("store8", "{out[2..]}", "{ns}")
	print("Simd<8, i32> done")
	prints "Simd<8, i32> done"

test "Simd<4, i64>":
	ls = [10_000_000_000, -5, 7, -3]
	ks = [-10_000_000_000, -5, 9, 4]
	a = ls.load4(0)
	b = ks.load4(0)
	same("add", "{a + b}", "{(0..4).map(ls[it] + ks[it])}")
	same("sub", "{a - b}", "{(0..4).map(ls[it] - ks[it])}")
	same("and", "{a & b}", "{(0..4).map(ls[it] & ks[it])}")
	same("or", "{a | b}", "{(0..4).map(ls[it] | ks[it])}")
	same("xor", "{a ^ b}", "{(0..4).map(ls[it] ^ ks[it])}")
	same("min", "{a.min(b)}", "{(0..4).map(ls[it].min(ks[it]))}")
	same("max", "{a.max(b)}", "{(0..4).map(ls[it].max(ks[it]))}")
	same("eqMask", "{a.eqMask(b)}", "{bits((0..4).map(ls[it] == ks[it]))}")
	same("ltMask", "{a.ltMask(b)}", "{bits((0..4).map(ls[it] < ks[it]))}")
	same("leMask", "{a.leMask(b)}", "{bits((0..4).map(ls[it] <= ks[it]))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..4).map(ls[it] > ks[it]))}")
	same("geMask", "{a.geMask(b)}", "{bits((0..4).map(ls[it] >= ks[it]))}")
	same("sum", "{a.sum()}", "{ls.sum()}")
	same("lane", "{a.lane(1)} {a.lane(args.len + 3)}", "{ls[1]} {ls[3]}")
	same("splat", "{Simd<4>(ls[0])}", "{fill(4, ls[0])}")
	out = zeros(6)
	out.store4(2, a)
	same("store4", "{out[2..]}", "{ls}")
	print("Simd<4, i64> done")
	prints "Simd<4, i64> done"

# the bytes i * 7 and i * 13 + 100, wrapping
fn ramp(n i64, k i64, at i64):
	bytes = []
	for i in 0..n:
		bytes.push(u8.wrap(i * k + at))
	bytes

# u8 lanes compare signed in the masks
fn signedGt(x u8, y u8):
	(i64(x) ^ 128) > (i64(y) ^ 128)

test "Simd<32, u8>":
	us = ramp(32, 7, 0)
	vs = ramp(32, 13, 100)
	vs[5] = us[5]
	a = us.load32(0)
	b = vs.load32(0)
	same("add", "{a + b}", "{(0..32).map(u8.wrap(i64(us[it]) + i64(vs[it])))}")
	same("sub", "{a - b}", "{(0..32).map(u8.wrap(i64(us[it]) - i64(vs[it])))}")
	same("and", "{a & b}", "{(0..32).map(us[it] & vs[it])}")
	same("or", "{a | b}", "{(0..32).map(us[it] | vs[it])}")
	same("xor", "{a ^ b}", "{(0..32).map(us[it] ^ vs[it])}")
	same("min", "{a.min(b)}", "{(0..32).map(us[it].min(vs[it]))}")
	same("max", "{a.max(b)}", "{(0..32).map(us[it].max(vs[it]))}")
	same("eqMask", "{a.eqMask(b)}", "{bits((0..32).map(us[it] == vs[it]))}")
	same("ltMask", "{a.ltMask(b)}", "{bits((0..32).map(signedGt(vs[it], us[it])))}")
	same("leMask", "{a.leMask(b)}", "{bits((0..32).map(not signedGt(us[it], vs[it])))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..32).map(signedGt(us[it], vs[it])))}")
	same("geMask", "{a.geMask(b)}", "{bits((0..32).map(not signedGt(vs[it], us[it])))}")
	same("sum", "{a.sum()}", "{u8.wrap(us.map(i64(it)).sum())}")
	same("lane", "{a.lane(9)} {a.lane(args.len + 31)}", "{us[9]} {us[31]}")
	same("splat", "{Simd<32>(us[3])}", "{fill(32, us[3])}")
	out = ramp(34, 0, 0)
	out.store32(2, a)
	same("store32", "{out[2..]}", "{us}")
	print("Simd<32, u8> done")
	prints "Simd<32, u8> done"

test "Simd<16, u8>":
	us = ramp(16, 7, 0)
	vs = ramp(16, 13, 100)
	vs[5] = us[5]
	idx u8[] = [15, 0, 3, 128, 7, 255, 16, 33, 1, 2, 4, 8, 143, 9, 10, 11]
	a = us.load16(0)
	b = vs.load16(0)
	m = idx.load16(0)
	same("add", "{a + b}", "{(0..16).map(u8.wrap(i64(us[it]) + i64(vs[it])))}")
	same("sub", "{a - b}", "{(0..16).map(u8.wrap(i64(us[it]) - i64(vs[it])))}")
	same("and", "{a & b}", "{(0..16).map(us[it] & vs[it])}")
	same("or", "{a | b}", "{(0..16).map(us[it] | vs[it])}")
	same("xor", "{a ^ b}", "{(0..16).map(us[it] ^ vs[it])}")
	same("eqMask", "{a.eqMask(b)}", "{bits((0..16).map(us[it] == vs[it]))}")
	same("gtMask", "{a.gtMask(b)}", "{bits((0..16).map(signedGt(us[it], vs[it])))}")
	same("eqBytes", "{a.eqBytes(b)}", "{(0..16).map(u8(255) if us[it] == vs[it] else u8(0))}")
	same(
		"shuffle",
		"{a.shuffle(m)}",
		"{(0..16).map(u8(0) if idx[it] >= 128 else us[idx[it] & 15])}"
	)
	same("blend", "{a.blend(b, m)}", "{(0..16).map(vs[it] if idx[it] >= 128 else us[it])}")
	same("lane", "{a.lane(9)} {a.lane(args.len + 15)}", "{us[9]} {us[15]}")
	same("splat", "{Simd<16>(us[3])}", "{fill(16, us[3])}")
	out = ramp(18, 0, 0)
	out.store16(2, a)
	same("store16", "{out[2..]}", "{us}")
	print("Simd<16, u8> done")
	prints "Simd<16, u8> done"
