# Simd<4, f64>.rsqrtEstimate is the hardware's 12-bit 1/sqrt on every target (spec vectors): its
# relative error within x64's bound, 1.5 * 2^-12, over a spread of inputs
fn worst():
	e = 0.0
	x = 0.001
	while x < 1000.0:
		s = Simd<4>(x, x * 1.1, x * 1.2, x * 1.3)
		est = s.rsqrtEstimate()
		for i in 0..4:
			exact = 1.0 / s.lane(i).sqrt()
			e = e.max(((est.lane(i) - exact) / exact).abs())
		x *= 1.37
	e

test "rsqrtEstimate":
	print("{worst() <= 1.5 / 4096.0}")
	prints "true"
