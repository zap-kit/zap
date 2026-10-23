# Affine recurrences run eight turns a step (spec 14.3): the values are the turn-by-turn ones, for
# every count (the turns a step leaves run one by one), in 32 bits and in 64 wrapping, the
# loop's other work (stores, a counter, a check) as written.

# the reference: a call each turn keeps the loop as written
fn lcgStep(x u32):
	x * 1_103_515_245 + 12_345

fn noise(n i64):
	x u32 = 42
	(0..n).map(_:
		x = x * 1_103_515_245 + 12_345
		u8.wrap(x >> 16)
	)

fn noiseByCalls(n i64):
	x = 42
	out = []
	loop n:
		x = lcgStep(x)
		out.push(u8.wrap(x >> 16))
	out

fn mixed64(n i64):
	x u64 = 7
	s u64 = 0
	loop n:
		x = x * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407
		s ^= x >> 3
	s

fn mixed64ByCalls(n i64):
	x = 7
	s u64 = 0
	i = 0
	while i < n:
		x = pcgStep(x)
		s ^= x >> 3
		i += 1
	s

fn pcgStep(x u64):
	x * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407

# a recurrence beside a list read at the counter: its check stops at the same element
fn walk(xs i64[], n i64):
	x u32 = 1
	s = 0
	for i in 0..n:
		x = x * 69_069 + 1
		s += xs[i] + (x & 7)
	s

test "each count gives the turn-by-turn values" for n in [0, 1, 7, 8, 9, 15, 16, 17, 100, 1001]:
	expect noise(n) == noiseByCalls(n)
	expect mixed64(n) == mixed64ByCalls(n)

test "an outer loop around an unrolled one":
	all = []
	for k in 0..5:
		all.extend(noise(k * 3))
	by = []
	for k in 0..5:
		by.extend(noiseByCalls(k * 3))
	expect all == by

fn walkByCalls(xs i64[], n i64):
	x = 1
	s = 0
	for i in 0..n:
		x = mulAdd(x)
		s += xs[i] + (x & 7)
	s

fn mulAdd(x u32):
	x * 69_069 + 1

test "a check inside gives what the loop as written does" for n in [0, 5, 8, 20]:
	xs = (0..20).map(it)
	expect walk(xs, n) == walkByCalls(xs, n)

test "a check inside stops the loop" stops IndexOutOfBounds:
	xs = (0..20).map(it)
	x u32 = 1
	s = 0
	for i in 0..xs.len + args.len + 1:
		x = x * 69_069 + 1
		s += xs[i] + (x & 7)
	print(s)

# a fixed array bound inside the loop is not there to check ahead of it
fn shifted(x f32[9]):
	x

fn rebound(n i64):
	sum = 0.0
	loop n:
		co f32[9]
		co[0] = 1.0
		co = shifted(co)
		sum += co[0]
	sum

test "a fixed array bound inside a loop, indexed at a literal":
	expect rebound(2) == 2.0
