# Loops over constant bounds are unrolled (each copy's counter a literal, so k * 4 + row folds),
# fixed-array indices proven within the array lose their check, and f32 locals live in
# registers. None of it changes what a program computes: these compare the loops with the same
# work written out, and an index the compiler cannot prove still stops the program.
type Mat4:
	m f32[16]

	fn timesLoop(o Mat4):
		r f32[16]
		for c in 0..4:
			for row in 0..4:
				s = 0.0
				for k in 0..4:
					s += m[k * 4 + row] * o.m[c * 4 + k]
				r[c * 4 + row] = s
		Mat4(m = r)

	fn timesWritten(o Mat4):
		r f32[16]
		r[0] = m[0] * o.m[0] + m[4] * o.m[1] + m[8] * o.m[2] + m[12] * o.m[3]
		r[1] = m[1] * o.m[0] + m[5] * o.m[1] + m[9] * o.m[2] + m[13] * o.m[3]
		r[2] = m[2] * o.m[0] + m[6] * o.m[1] + m[10] * o.m[2] + m[14] * o.m[3]
		r[3] = m[3] * o.m[0] + m[7] * o.m[1] + m[11] * o.m[2] + m[15] * o.m[3]
		r[4] = m[0] * o.m[4] + m[4] * o.m[5] + m[8] * o.m[6] + m[12] * o.m[7]
		r[5] = m[1] * o.m[4] + m[5] * o.m[5] + m[9] * o.m[6] + m[13] * o.m[7]
		r[6] = m[2] * o.m[4] + m[6] * o.m[5] + m[10] * o.m[6] + m[14] * o.m[7]
		r[7] = m[3] * o.m[4] + m[7] * o.m[5] + m[11] * o.m[6] + m[15] * o.m[7]
		r[8] = m[0] * o.m[8] + m[4] * o.m[9] + m[8] * o.m[10] + m[12] * o.m[11]
		r[9] = m[1] * o.m[8] + m[5] * o.m[9] + m[9] * o.m[10] + m[13] * o.m[11]
		r[10] = m[2] * o.m[8] + m[6] * o.m[9] + m[10] * o.m[10] + m[14] * o.m[11]
		r[11] = m[3] * o.m[8] + m[7] * o.m[9] + m[11] * o.m[10] + m[15] * o.m[11]
		r[12] = m[0] * o.m[12] + m[4] * o.m[13] + m[8] * o.m[14] + m[12] * o.m[15]
		r[13] = m[1] * o.m[12] + m[5] * o.m[13] + m[9] * o.m[14] + m[13] * o.m[15]
		r[14] = m[2] * o.m[12] + m[6] * o.m[13] + m[10] * o.m[14] + m[14] * o.m[15]
		r[15] = m[3] * o.m[12] + m[7] * o.m[13] + m[11] * o.m[14] + m[15] * o.m[15]
		Mat4(m = r)

fn sample(seed f32):
	m f32[16]
	for i in 0..16:
		m[i] = seed * (f32(i) + 1.0) / 7.0 - 0.3
	Mat4(m)

# the same products, bit for bit
fn matrices():
	a = sample(1.3)
	b = sample(-0.7)
	x = a.timesLoop(b)
	y = a.timesWritten(b)
	for i in 0..16:
		if x.m[i].toBits() != y.m[i].toBits(): return false
	true

# a triangle (the inner bounds come from the outer counter), a stepped range, the counter
# read whole (passed, printed, compared)
fn shapes():
	t i64[16]
	for i in 0..4:
		for j in i..4:
			t[i * 4 + j] = i * 10 + j
	print(t)
	picked = []
	for i in 1..12 step 3:
		picked.push(i * i)
	print(picked)
	text = ""
	for i in 0..3:
		text += "{i}:{twice(i)} "
		if i == 1:
			text += "one "
	print(text.trimmedEnd())

fn twice(x i64):
	x * 2

# a counter over constant bounds too long to unroll still proves its indices; f32 sums kept in
# registers round as they would in memory
fn sums():
	table i64[100]
	for i in 0..100:
		table[i] = i * i
	total = 0
	for i in 0..table.len:
		total += table[i]
	print(total)
	half i64[50]
	for i in 0..50:
		half[i] = table[i * 2 + 1] - table[i * 2]
	print(half[49])
	acc f32 = 0.0
	acc64 = 0.0
	loop 1000:
		acc += 0.1
		acc64 += 0.1
	print(acc)
	print(acc64)
	print(f64(acc) == acc64)

# u8 elements computed from a counter keep their wrap
fn wraps():
	bytes u8[4]
	for i in 0..4:
		bytes[i] = u8.wrap(i * 100)
	print(bytes)

test "unrolled loops give the written-out results":
	print(matrices())
	shapes()
	sums()
	wraps()
	prints """
	    true
	    [0, 1, 2, 3, 0, 11, 12, 13, 0, 0, 22, 23, 0, 0, 0, 33]
	    [1, 16, 49, 100]
	    0:0 1:2 one 2:4
	    328350
	    197
	    99.99905
	    99.9999999999986
	    false
	    [0, 100, 200, 44]
	    """

test "a folded index past the array still stops the program" stops IndexOutOfBounds:
	a i64[4]
	for k in 0..3:
		a[k * 2] = k
	print(a)

test "a counter past the array still stops the program" stops IndexOutOfBounds:
	a i64[100]
	s = 0
	for i in 0..101:
		s += a[i]
	print(s)

test "an index the loop does not bound is still checked" stops IndexOutOfBounds:
	a i64[4]
	j = 0
	for i in 0..4:
		j += i
		a[j] = i
	print(a)
