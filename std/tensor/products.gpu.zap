# The kernels of products.zap.

pub type ProductParams:
	a f32[]
	b f32[]
	c f32[]
	m i32
	n i32
	k i32
	aRow i32   # a's element (i, q) at z * aBatch + i * aRow + q * aCol
	aCol i32
	bRow i32
	bCol i32
	aBatch i32
	bBatch i32

# the tiles of a and b a group reads: 16 of k by 64 rows (columns)
mut tileA f32[1024]
mut tileB f32[1024]

# A 64 by 64 block of c per group of 16 by 16 invocations, each summing 4 by 4 of its numbers
# (rows localId.y + 16 * i, columns localId.x + 16 * j) over tiles of 16 of k, in the order of k.
pub fn productKernel(mut p ProductParams):
	tx = localId.x
	ty = localId.y
	t = localIndex
	m0 = groupId.y * 64
	n0 = groupId.x * 64
	z = groupId.z
	aBase = z * p.aBatch
	bBase = z * p.bBatch
	acc f32[16]
	for k0 in (0..p.k step 16):
		for s in 0..4:
			at = t + 256 * s
			r = at / 16
			kk = at % 16
			row = m0 + r
			q = k0 + kk
			tileA[kk * 64 + r] = p.a[aBase + row * p.aRow + q * p.aCol] if row < p.m and q < p.k
				else 0.0
			kb = at / 64
			col = n0 + at % 64
			qb = k0 + kb
			tileB[kb * 64 + at % 64] = p.b[bBase + qb * p.bRow + col * p.bCol] if col < p.n and
				qb < p.k
				else 0.0
		barrier()
		for q in 0..16:
			a0 = tileA[q * 64 + ty]
			a1 = tileA[q * 64 + ty + 16]
			a2 = tileA[q * 64 + ty + 32]
			a3 = tileA[q * 64 + ty + 48]
			for j in 0..4:
				b = tileB[q * 64 + tx + 16 * j]
				acc[j] += a0 * b
				acc[4 + j] += a1 * b
				acc[8 + j] += a2 * b
				acc[12 + j] += a3 * b
		barrier()
	for i in 0..4:
		row = m0 + ty + 16 * i
		for j in 0..4:
			col = n0 + tx + 16 * j
			if row < p.m and col < p.n:
				p.c[z * p.m * p.n + row * p.n + col] = acc[i * 4 + j]

pub type SwapParams:
	values f32[]
	out f32[]
	count i32
	n1 i32   # the output's dimensions past the first (four in all)
	n2 i32
	n3 i32
	s0 i32   # the input's strides of the output's dimensions
	s1 i32
	s2 i32
	s3 i32
	stride i32

pub fn swapKernel(mut p SwapParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		i3 = i % p.n3
		i2 = i / p.n3 % p.n2
		i1 = i / (p.n3 * p.n2) % p.n1
		i0 = i / (p.n3 * p.n2 * p.n1)
		p.out[i] = p.values[i0 * p.s0 + i1 * p.s1 + i2 * p.s2 + i3 * p.s3]
