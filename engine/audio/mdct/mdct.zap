# The inverse MDCT, after stb_vorbis (public domain, Sean Barrett, github.com/nothings/stb), shared
# by the decoders that end in one (Vorbis, WMA). For a block of n samples it turns n/2
# coefficients X into y[i] = the sum over k of X[k] cos(2 pi / n (i + 1/2 + n/4) (k + 1/2)), for n
# of 256 or more (the steps give other values at 64 and 128).
# Each loop is written over the number of its turns, the offsets computed from the turn, and every
# turn checks once that the offsets it uses lie inside the lists (they do, for a block size the
# table was made for; a turn that finds otherwise ends the transform).

# a count or an offset kept inside 0..=2^30, so that a sum or a product of two never overflows
type Count = i64 in 0..=1_073_741_824

fn count(x i64) Count:
	x.clamp(0, 1_073_741_824)

# a number that may be negative, kept inside -2^30..=2^30 for the same reason
type Signed = i64 in -1_073_741_824..=1_073_741_824

fn signed(x i64) Signed:
	x.clamp(-1_073_741_824, 1_073_741_824)

# a block size: 2^6 to 2^13
pub type Block = i64 in 64..=8192

# The twiddle factors and the bit reversal of one block size.
pub type Mdct:
	n Block
	log2 i64 in 6..=13   # of n
	a f32[]
	b f32[]
	c f32[]
	rev i64[]

# The tables of the inverse MDCT of blocks of n samples (a power of two, 64 to 8192).
pub fn newMdct(n Block) Mdct:
	use noStops
	n4 = n >> 2
	n8 = n >> 3
	a = []
	b = []
	c = []
	for k in 0..n4:
		k2 = 2 * k
		a.push(f32((4.0 * k * pi / n).cos()))
		a.push(f32(-(4.0 * k * pi / n).sin()))
		b.push(f32(((k2 + 1) * pi / n / 2.0).cos()) * 0.5)
		b.push(f32(((k2 + 1) * pi / n / 2.0).sin()) * 0.5)
	for k in 0..n8:
		k2 = 2 * k
		c.push(f32((2.0 * (k2 + 1) * pi / n).cos()))
		c.push(f32(-(2.0 * (k2 + 1) * pi / n).sin()))
	log2 i64 in 6..=13 = 6
	for k in 6..14:
		if n >> k == 1: log2 = k
	# the indices of n/8 reversed in log2 - 3 bits, times 4
	rev = []
	for i in 0..n8:
		r = 0
		x = i
		loop log2 - 3:
			r = r << 1 | x & 1
			x >>= 1
		rev.push(r << 2)
	Mdct(n, log2, a, b, c, rev)

fn step3Iter0(mut e f32[], n Count, iOff Count, kOff Signed, a f32[]):
	use noStops
	for t in 0..n >> 2:
		for s in 0..4:
			p = iOff - 8 * t - 2 * s
			q = p + kOff
			ai = 32 * t + 8 * s
			if p < 1 or q < 1 or p >= e.len or q >= e.len or ai + 1 >= a.len: return
			k00 = e[p] - e[q]
			k01 = e[p - 1] - e[q - 1]
			e[p] += e[q]
			e[p - 1] += e[q - 1]
			e[q] = k00 * a[ai] - k01 * a[ai + 1]
			e[q - 1] = k01 * a[ai] + k00 * a[ai + 1]

fn step3InnerR(mut e f32[], lim Count, d0 Count, kOff Signed, a f32[], k1 Count):
	use noStops
	for t in 0..lim >> 2:
		for s in 0..4:
			p = d0 - 8 * t - 2 * s
			q = p + kOff
			ai = (4 * t + s) * k1
			if p < 1 or q < 1 or p >= e.len or q >= e.len or ai + 1 >= a.len: return
			k00 = e[p] - e[q]
			k01 = e[p - 1] - e[q - 1]
			e[p] += e[q]
			e[p - 1] += e[q - 1]
			e[q] = k00 * a[ai] - k01 * a[ai + 1]
			e[q - 1] = k01 * a[ai] + k00 * a[ai + 1]

fn step3InnerS(
	mut e f32[],
	n Count,
	iOff Count,
	kOff Signed,
	a f32[],
	a0 Count,
	aOff Count,
	k0 Count
):
	use noStops
	i1 = a0 + aOff
	i2 = a0 + aOff * 2
	i3 = a0 + aOff * 3
	if a0 + 1 >= a.len or i1 + 1 >= a.len or i2 + 1 >= a.len or i3 + 1 >= a.len: return
	w0 = a[a0]
	w1 = a[a0 + 1]
	w2 = a[i1]
	w3 = a[i1 + 1]
	w4 = a[i2]
	w5 = a[i2 + 1]
	w6 = a[i3]
	w7 = a[i3 + 1]
	for t in 0..n:
		ee0 = iOff - k0 * t
		ee2 = ee0 + kOff
		if ee0 < 7 or ee2 < 7 or ee0 >= e.len or ee2 >= e.len: return
		k00 = e[ee0] - e[ee2]
		k11 = e[ee0 - 1] - e[ee2 - 1]
		e[ee0] += e[ee2]
		e[ee0 - 1] += e[ee2 - 1]
		e[ee2] = k00 * w0 - k11 * w1
		e[ee2 - 1] = k11 * w0 + k00 * w1
		k00 = e[ee0 - 2] - e[ee2 - 2]
		k11 = e[ee0 - 3] - e[ee2 - 3]
		e[ee0 - 2] += e[ee2 - 2]
		e[ee0 - 3] += e[ee2 - 3]
		e[ee2 - 2] = k00 * w2 - k11 * w3
		e[ee2 - 3] = k11 * w2 + k00 * w3
		k00 = e[ee0 - 4] - e[ee2 - 4]
		k11 = e[ee0 - 5] - e[ee2 - 5]
		e[ee0 - 4] += e[ee2 - 4]
		e[ee0 - 5] += e[ee2 - 5]
		e[ee2 - 4] = k00 * w4 - k11 * w5
		e[ee2 - 5] = k11 * w4 + k00 * w5
		k00 = e[ee0 - 6] - e[ee2 - 6]
		k11 = e[ee0 - 7] - e[ee2 - 7]
		e[ee0 - 6] += e[ee2 - 6]
		e[ee0 - 7] += e[ee2 - 7]
		e[ee2 - 6] = k00 * w6 - k11 * w7
		e[ee2 - 7] = k11 * w6 + k00 * w7

fn iter54(mut z f32[], at Count):
	use noStops
	if at < 7 or at >= z.len: return
	k00 = z[at] - z[at - 4]
	y0 = z[at] + z[at - 4]
	y2 = z[at - 2] + z[at - 6]
	k22 = z[at - 2] - z[at - 6]
	z[at] = y0 + y2
	z[at - 2] = y0 - y2
	k33 = z[at - 3] - z[at - 7]
	z[at - 4] = k00 + k33
	z[at - 6] = k00 - k33
	k11 = z[at - 1] - z[at - 5]
	y1 = z[at - 1] + z[at - 5]
	y3 = z[at - 3] + z[at - 7]
	z[at - 1] = y1 + y3
	z[at - 3] = y1 - y3
	z[at - 5] = k11 - k22
	z[at - 7] = k11 + k22

fn step3Ld654(mut e f32[], n Count, iOff Count, a f32[], baseN Count):
	use noStops
	ai = baseN >> 3
	if ai >= a.len: return
	a2 = a[ai]
	for t in 0..n:
		z = iOff - 16 * t
		if z < 15 or z >= e.len: return
		k00 = e[z] - e[z - 8]
		k11 = e[z - 1] - e[z - 9]
		l00 = e[z - 2] - e[z - 10]
		l11 = e[z - 3] - e[z - 11]
		e[z] += e[z - 8]
		e[z - 1] += e[z - 9]
		e[z - 2] += e[z - 10]
		e[z - 3] += e[z - 11]
		e[z - 8] = k00
		e[z - 9] = k11
		e[z - 10] = (l00 + l11) * a2
		e[z - 11] = (l11 - l00) * a2
		k00 = e[z - 4] - e[z - 12]
		k11 = e[z - 5] - e[z - 13]
		l00 = e[z - 6] - e[z - 14]
		l11 = e[z - 7] - e[z - 15]
		e[z - 4] += e[z - 12]
		e[z - 5] += e[z - 13]
		e[z - 6] += e[z - 14]
		e[z - 7] += e[z - 15]
		e[z - 12] = k11
		e[z - 13] = -k00
		e[z - 14] = (l11 - l00) * a2
		e[z - 15] = (l00 + l11) * -a2
		iter54(e, count(z))
		iter54(e, count(z - 8))

# The spectrum's first n/2 values in `u` become the block's n samples; `v` is scratch of n/2.
pub fn inverseMdct(m Mdct, mut u f32[], mut v f32[]):
	use noStops
	n = m.n
	n2 = n >> 1
	n4 = n >> 2
	n8 = n >> 3
	inverseMdctReflect(u, v, n2, n4, m.a)
	inverseMdctButterflies(u, n, m.log2, n2, n4, n8, m.a)
	inverseMdctBitReverse(u, v, n2, n4, m.rev)
	inverseMdctStep7(v, m.c, n2)
	inverseMdctOutput(u, v, m.b, n, n2)

fn inverseMdctReflect(mut u f32[], mut v f32[], n2 Count, n4 Count, a f32[]):
	use noStops
	# copy and reflect the spectrum, step 0
	quarter = n2 >> 2
	half = n2 >> 1
	for t in 0..quarter:
		d = n2 - 2 - 2 * t
		aa = 2 * t
		e = 4 * t
		if d < 0 or d + 1 >= v.len or e + 2 >= u.len or aa + 1 >= a.len: return
		v[d + 1] = u[e] * a[aa] - u[e + 2] * a[aa + 1]
		v[d] = u[e] * a[aa + 1] + u[e + 2] * a[aa]
	for t in 0..quarter:
		d = half - 2 - 2 * t
		aa = half + 2 * t
		e = n2 - 3 - 4 * t
		if d < 0 or d + 1 >= v.len or e < 0 or e + 2 >= u.len or aa + 1 >= a.len: return
		v[d + 1] = -u[e + 2] * a[aa] - -u[e] * a[aa + 1]
		v[d] = -u[e + 2] * a[aa + 1] + -u[e] * a[aa]
	# step 2
	for t in 0..n2 >> 3:
		ab = n2 - 8 - 8 * t
		e0 = n4 + 4 * t
		e1 = 4 * t
		if ab < 0 or ab + 5 >= a.len or e0 + 3 >= v.len or e1 + 3 >= v.len: return
		if e0 + 3 >= u.len or e1 + 3 >= u.len: return
		v41 = v[e0 + 1] - v[e1 + 1]
		v40 = v[e0] - v[e1]
		u[e0 + 1] = v[e0 + 1] + v[e1 + 1]
		u[e0] = v[e0] + v[e1]
		u[e1 + 1] = v41 * a[ab + 4] - v40 * a[ab + 5]
		u[e1] = v40 * a[ab + 4] + v41 * a[ab + 5]
		v41 = v[e0 + 3] - v[e1 + 3]
		v40 = v[e0 + 2] - v[e1 + 2]
		u[e0 + 3] = v[e0 + 3] + v[e1 + 3]
		u[e0 + 2] = v[e0 + 2] + v[e1 + 2]
		u[e1 + 3] = v41 * a[ab] - v40 * a[ab + 1]
		u[e1 + 2] = v40 * a[ab] + v41 * a[ab + 1]

fn inverseMdctButterflies(
	mut u f32[],
	n Block,
	ld i64 in 6..=13,
	n2 Count,
	n4 Count,
	n8 Count,
	a f32[]
):
	use noStops
	# step 3
	step3Iter0(u, n >> 4, count(n2 - 1), signed(-(n >> 3)), a)
	step3Iter0(u, n >> 4, count(n2 - 1 - n4), signed(-(n >> 3)), a)
	for k in 0..4:
		step3InnerR(u, n >> 5, count(n2 - 1 - n8 * k), signed(-(n >> 4)), a, 16)
	first = ((ld - 3) >> 1).clamp(2, 12)
	for l in 2..first:
		k0 = n >> (l + 2)
		for i in 0..1 << (l + 1):
			step3InnerR(
				u,
				n >> (l + 4),
				count(n2 - 1 - k0 * i),
				signed(-(k0 >> 1)),
				a,
				1 << (l + 3)
			)
	for l in first..(ld - 6).clamp(first, 12):
		k0 = n >> (l + 2)
		k1 = 1 << (l + 3)
		for t in 0..n >> (l + 6):
			step3InnerS(
				u,
				1 << (l + 1),
				count(n2 - 1 - 8 * t),
				signed(-(k0 >> 1)),
				a,
				k1 * 4 * t,
				k1,
				k0
			)
	step3Ld654(u, n >> 5, count(n2 - 1), a, count(n))

fn inverseMdctBitReverse(u f32[], mut v f32[], n2 Count, n4 Count, rev i64[]):
	use noStops
	# steps 4, 5 and 6: bit-reversed order into v
	for t in 0..n4 >> 2:
		q0 = n4 - 4 - 4 * t
		q1 = n2 - 4 - 4 * t
		br = 2 * t
		if q0 < 0 or q1 < 0 or q0 + 3 >= v.len or q1 + 3 >= v.len or br + 1 >= rev.len: return
		k4 = count(rev[br])
		k5 = count(rev[br + 1])
		if k4 + 3 >= u.len or k5 + 3 >= u.len: return
		v[q1 + 3] = u[k4]
		v[q1 + 2] = u[k4 + 1]
		v[q0 + 3] = u[k4 + 2]
		v[q0 + 2] = u[k4 + 3]
		v[q1 + 1] = u[k5]
		v[q1] = u[k5 + 1]
		v[q0 + 1] = u[k5 + 2]
		v[q0] = u[k5 + 3]

fn inverseMdctStep7(mut v f32[], c f32[], n2 Count):
	use noStops
	# step 7, in place in v
	for t in 0..n2 >> 3:
		ci = 4 * t
		dd = 4 * t
		ee = n2 - 4 - 4 * t
		if dd >= ee: return
		if ci + 3 >= c.len or ee < 0 or ee + 3 >= v.len or dd + 3 >= v.len: return
		a02 = v[dd] - v[ee + 2]
		a11 = v[dd + 1] + v[ee + 3]
		b0 = c[ci + 1] * a02 + c[ci] * a11
		b1 = c[ci + 1] * a11 - c[ci] * a02
		b2 = v[dd] + v[ee + 2]
		b3 = v[dd + 1] - v[ee + 3]
		v[dd] = b2 + b0
		v[dd + 1] = b3 + b1
		v[ee + 2] = b2 - b0
		v[ee + 3] = b1 - b3
		a02 = v[dd + 2] - v[ee]
		a11 = v[dd + 3] + v[ee + 1]
		b0 = c[ci + 3] * a02 + c[ci + 2] * a11
		b1 = c[ci + 3] * a11 - c[ci + 2] * a02
		b2 = v[dd + 2] + v[ee]
		b3 = v[dd + 3] - v[ee + 1]
		v[dd + 2] = b2 + b0
		v[dd + 3] = b3 + b1
		v[ee] = b2 - b0
		v[ee + 1] = b1 - b3

fn inverseMdctOutput(mut u f32[], v f32[], b f32[], n Count, n2 Count):
	use noStops
	# step 8 and the decode kernel, into u
	for t in 0..n2 >> 3:
		bi = n2 - 8 - 8 * t
		o0 = 4 * t
		o1 = n2 - 4 - 4 * t
		o2 = n2 + 4 * t
		o3 = n - 4 - 4 * t
		if bi < 0 or bi + 7 >= b.len or bi + 7 >= v.len or o1 < 0 or o3 < 0: return
		if o0 + 3 >= u.len or o1 + 3 >= u.len or o2 + 3 >= u.len or o3 + 3 >= u.len: return
		p3 = v[bi + 6] * b[bi + 7] - v[bi + 7] * b[bi + 6]
		p2 = -v[bi + 6] * b[bi + 6] - v[bi + 7] * b[bi + 7]
		u[o0] = p3
		u[o1 + 3] = -p3
		u[o2] = p2
		u[o3 + 3] = p2
		p1 = v[bi + 4] * b[bi + 5] - v[bi + 5] * b[bi + 4]
		p0 = -v[bi + 4] * b[bi + 4] - v[bi + 5] * b[bi + 5]
		u[o0 + 1] = p1
		u[o1 + 2] = -p1
		u[o2 + 1] = p0
		u[o3 + 2] = p0
		p3 = v[bi + 2] * b[bi + 3] - v[bi + 3] * b[bi + 2]
		p2 = -v[bi + 2] * b[bi + 2] - v[bi + 3] * b[bi + 3]
		u[o0 + 2] = p3
		u[o1 + 1] = -p3
		u[o2 + 2] = p2
		u[o3 + 1] = p2
		p1 = v[bi] * b[bi + 1] - v[bi + 1] * b[bi]
		p0 = -v[bi] * b[bi] - v[bi + 1] * b[bi + 1]
		u[o0 + 3] = p1
		u[o1] = -p1
		u[o2 + 3] = p0
		u[o3] = p0

test "the inverse MDCT is the sum it stands for, at every block size from 256 to 8192":
	for log2 in 8..14:
		n = 1 << log2
		t = newMdct(Block(n))
		x f32[] = zeros(n)
		for k in 0..n / 2:
			x[k] = f32((k * 7919) % 101 - 50) / 50.0
		u = x.copy()
		v f32[] = zeros(n / 2)
		t.inverseMdct(u, v)
		for i in [0, 1, n / 3, n / 2, n - 1]:
			sum = 0.0
			for k in 0..n / 2:
				sum += f64(x[k]) * (2.0 * pi / n * (i + 0.5 + n / 4.0) * (k + 0.5)).cos()
			expect (f64(u[i]) - sum).abs() < 1e-3
