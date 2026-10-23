# Loop-invariant indexing: L[v] inside `for v in a..b` is located once per iteration, but only
# when the body cannot resize or replace L and the first statement reaches L[v] unconditionally.
# Each case below would go wrong (or miss a bounds error) if the rule were looser.
#
# Element addresses located once per step past the first statement: lets that read fields of
# several lists' elements at the loop's index (each list's element found once), and the order
# of the checks kept when a later list is too short.

type Cell:
	v i64
	tag str
fn grows(mut xs i64[]):
	xs.push(99)
# the body pushes: the buffer may move, so no hoisting
mut xs = [1, 2, 3]
for i in 0..3:
	xs[i] *= 10
	xs.push(xs[i])
print(xs)
# a bare list argument may be a mut parameter: no hoisting
mut ys = [1, 2, 3]
for i in 0..3:
	ys[i] += 1
	grows(ys)
print(ys)
# the list is replaced inside the body: no hoisting
mut zs = [5, 6, 7]
for i in 0..3:
	zs[i] -= 1
	zs = [zs[i], 0, 0]
print(zs)
# the index only runs under a condition: no early bounds check
short = [1, 2]
mut hits = 0
for i in 0..5:
	if i < short.len:
		hits += short[i]
print(hits)
# short-circuit: the right side may not run
mut seen = 0
for i in 0..4:
	ok = i < short.len and short[i] > 0
	if ok:
		seen += 1
print(seen)
# hoisted: structs with strings, fields read and written, nested loops over two indices
mut cells = []
for i in 0..4:
	cells.push(Cell(v = i, tag = "c{i}"))
for i in 0..4:
	cells[i].v *= 2
	for j in 0..4:
		cells[i].v += cells[j].v
print(cells)
# the loop variable shadowed inside the body: the inner i is another variable
mut sum = 0
for i in 0..3:
	sum += cells[i].v
	i2 = i + 1
	if i2 < 4:
		sum += cells[i2].v
print(sum)

test "an element is located once per turn only when the body cannot resize or replace its list":
	main()
	prints """
		[10, 20, 30, 10, 20, 30]
		[2, 3, 4, 99, 99, 99]
		[-1, 0, 0]
		3
		2
		[Cell(v = 6, tag = "c0"), Cell(v = 21, tag = "c1"), Cell(v = 65, tag = "c2"), Cell(v = 196, tag = "c3")]
		374
		"""

test "an address at an index the loop does not count is kept only while the body leaves the index alone":
	# An element address L[k] is hoisted per loop; when the index is not the loop's counter the
	# address may be kept for the whole loop only if the body never changes the index (a running
	# pair index k stepped inside the inner loop once read stale addresses).
	ws = [0.5, 0.25, 0.2, 0.1, 0.05, 0.025]
	e = 0.0
	k = 0
	for i in 1..4:
		for j in 0..i:
			e += ws[k] * (j + 1)
			k += 1
	print(e)
	names = []
	at = 0
	words = ["a", "b", "c", "d"]
	loop 2:
		loop 2:
			names.push(move words[at])
			at += 1
	print(names)
	prints """
	    1.425
	    ["a", "b", "c", "d"]
	    """

fn mixed(a i64[], b i64[], mut c i64[]):
	for i in 0..a.len:
		c[i] = a[i] * 3 + b[i]

fn guarded(a i64[], b i64[]):
	s = 0
	for i in 0..a.len:
		if i < b.len:
			s += b[i]
		s += a[i]
	s

test "lists read at the loop's index each step are checked once before the loop":
	c = [0, 0, 0]
	mixed([1, 2, 3], [0, 0, 0], c)
	expect c == [3, 6, 9]
	expect guarded([1, 2, 3], [10]) == 16

test "a list shorter than the loop stops the program before it" stops IndexOutOfBounds:
	c = [0, 0, 0]
	a i64[] = [1, 2, 3]
	b i64[] = [1]
	for i in 0..a.len:
		c[i] = a[i] + b[i]
	print(c)

# an index rising with the counter (i * n + j, 2 * j + 1) is checked for the first and the last
# step before the loop; one under a condition is checked where it runs
fn rows(n i64):
	m = (0..n * n).map(it)
	sum = 0
	for i in 0..n:
		for j in 0..n:
			sum += m[i * n + j] * (2 * j + 1)
	sum

fn sparse(xs i64[]):
	sum = 0
	for j in 0..xs.len:
		if j + 1 < xs.len:
			sum += xs[j + 1]
	sum

test "indexes rising with the counter":
	expect rows(3) == 120
	expect sparse([2, 3, 6]) == 9

test "an index rising past the end stops before the loop" stops IndexOutOfBounds:
	xs = [0, 0, 0, 0]
	for j in 0..3:
		xs[2 * j + 1] = j
	print(xs)

# a stepped loop's last step is lo plus a whole number of steps: j >> 2 at j = 19 is 4
fn marks(n i64):
	xs = zeros(n)
	for j in 1..20 step 3:
		xs[j >> 2] += 1 << (j & 63)
	xs

test "an index of a stepped loop, through a shift":
	expect marks(5) == [2, 144, 1024, 8192, 589_824]

test "a stepped loop's index past the end stops before the loop" stops IndexOutOfBounds:
	xs = [0, 0, 0, 0]
	for j in 1..20 step 3:
		xs[j >> 2] = j
	print(xs)

type V3:
	x f32
	y f32
	z f32

fn crossDot(a V3[], b V3[], c V3[]):
	s = 0.0
	for i in 0..a.len:
		ax = a[i].x
		ay = a[i].y
		az = a[i].z
		bx = b[i].x
		by = b[i].y
		bz = b[i].z
		s += (ay * bz - az * by) * c[i].x + (az * bx - ax * bz) * c[i].y +
			(ax * by - ay * bx) * c[i].z
	s

fn sums(a i64[], b i64[], k i64):
	s = 0
	for i in 0..a.len:
		x = a[i] * 2
		y = x + b[i] / 2
		s += y % k + b[i]
	s

test "lets over several lists":
	a = [V3(x = 1.0, y = 2.0, z = 3.0), V3(x = 0.0, y = 1.0, z = 0.0)]
	b = [V3(x = 4.0, y = 5.0, z = 6.0), V3(x = 1.0, y = 0.0, z = 0.0)]
	c = [V3(x = 1.0, y = 0.0, z = 2.0), V3(x = 0.0, y = 0.0, z = 1.0)]
	expect crossDot(a, b, c) == -10.0
	expect sums([1, 2, 3], [10, 20, 30], 7) == 60

test "a later list too short stops the program at its element" stops IndexOutOfBounds:
	a i64[] = [1, 2, 3]
	b i64[] = [1]
	s = 0
	for i in 0..a.len:
		x = a[i] * 2
		print(x)
		s += x + b[i]
	print(s)
