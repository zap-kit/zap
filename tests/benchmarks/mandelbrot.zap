# mandelbrot: the set on an n by n grid as a binary PBM, 8 pixels per byte. Every 64 rows are a task;
# sixteen pixels (two bytes, four Simd<4, f64> chains that hide each other's latency) are iterated at
# once, the row padded to an even byte count. A pixel is inside when |z|^2 <= 4 after 50
# iterations; every five through the 40th, the pair stops early when all its pixels escaped and
# the pair before it was outside. The real parts are stored with each group of four reversed, so a lane mask reads as
# the pixel bits leftmost first.

import problems

n = arg(0, 200)
bytesPerRow = (n + 7) / 8
pairs = (bytesPerRow + 1) / 2
mut crs f64[] = zeros(pairs * 16)
for x in 0..crs.len:
	crs[x / 4 * 4 + 3 - x % 4] = 2.0 * x / n - 1.5
# a task makes 64 rows into one block (the image in a few big blocks, not one per row)
blocks = (0..(n + 63) / 64).parallel().map(t:
	rows u8[] = []
	rows.reserve(64 * bytesPerRow + 1)   # the last row's padding byte too
	for y in t * 64..(t * 64 + 64).min(n):
		ci = Simd<4>(2.0 * y / n - 1.0)
		four = Simd<4>(4.0)
		leftOut = true
		for p in 0..pairs:
			cr Simd<4, f64>[4]
			for k in 0..4:
				cr[k] = crs.load4(p * 16 + k * 4)
			zr Simd<4, f64>[4]
			zi Simd<4, f64>[4]
			i = 0
			allOut = false
			while i < 50 and not allOut:
				loop 5:
					for k in 0..4:
						s = zr[k] * zr[k] - zi[k] * zi[k] + cr[k]
						zi[k] = (zr[k] + zr[k]) * zi[k] + ci
						zr[k] = s
				i += 5
				if leftOut and i <= 40:
					inside = 0
					for k in 0..4:
						inside |= (zr[k] * zr[k] + zi[k] * zi[k]).leMask(four)
					allOut = inside == 0
			bits i64[4]
			for k in 0..4:
				bits[k] = (zr[k] * zr[k] + zi[k] * zi[k]).leMask(four)
			rows.push(u8((bits[0] << 4) | bits[1]))
			rows.push(u8((bits[2] << 4) | bits[3]))
			leftOut = bits[2] | bits[3] == 0
		rows.truncate((y - t * 64 + 1) * bytesPerRow)   # the row's padding byte goes
	rows
)
out = stdout
out.write("P4\n{n} {n}\n")
for b in blocks:
	out.writeBytes(b)

test "the set's bitmap is the reference's bytes, and the C, Rust and Python programs print the same bytes":
	main()
	prints problems.expectedOf("mandelbrot")
	expect problems.agree("mandelbrot")
