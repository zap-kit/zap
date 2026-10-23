# Products of matrices (a @ b, a layer's x times its weights) and tensors with two dimensions
# swapped.

import gpu

# the strides of a matrix in memory: element (i, j) at offset + i * row + j * col
type Strided:
	rows i64
	cols i64
	row i64
	col i64

# a [m, k] matrix stored row-major, read as it is or as its transpose
fn strided(rows i64, cols i64, transposed bool):
	if transposed: return Strided(rows = cols, cols = rows, row = 1, col = cols)
	Strided(rows, cols, row = cols, col = 1)

# A product of matrices: a [m, k] @ b [k, n] gives [m, n]; a of more dimensions is a stack of rows
# ([..., m, k] @ [k, n] gives [..., m, n]); of three dimensions both are batches of matrices
# ([batch, m, k] @ [batch, k, n]). Each number is its row's and column's sum in the order of k.
pub fn matmul(a Tensor, b Tensor) Tensor:
	a.productOf(false, b, false)

pub fn matmulGrad(a Tensor, b Tensor, dy Tensor) (Tensor, Tensor):
	if a.rank() == 3 and b.rank() == 3:
		return (dy.productOf(false, b, true), a.productOf(true, dy, false))
	# a's leading dimensions are rows: its transpose is that of the [rows, k] matrix
	k = a.dim(-1)
	flat = a.reshape([-1, k])
	dyFlat = dy.reshape([-1, b.dim(-1)])
	(dy.productOf(false, b, true), flat.productOf(true, dyFlat, false))

# x [..., k] times the transpose of w [n, k] (a layer whose weights are a row per output, as GGUF
# and PyTorch store them): [..., n]. w on the GPU may be stored in any format.
pub fn linear(x Tensor, w Tensor) Tensor:
	if w.format == .F32: return x.productOf(false, w, true)
	x.packedProduct(w)

pub fn linearGrad(x Tensor, w Tensor, dy Tensor) (Tensor, Tensor):
	w.f32Only("a layer's derivative")
	n = w.dim(0)
	flat = x.reshape([-1, x.dim(-1)])
	(dy.productOf(false, w, false), dy.reshape([-1, n]).productOf(true, flat, false))

# a (transposed when ta) times b (transposed when tb), as matmul reads their shapes
fn productOf(a Tensor, ta bool, b Tensor, tb bool):
	a.sameSide(b, "a product")
	a.f32Only("a product")
	b.f32Only("a product")
	batched = a.rank() == 3 and b.rank() == 3
	if b.rank() != 2 and not batched or a.rank() < 2 and not batched:
		fail("tensor: a product of a {shapeText(a.shape)} tensor and a {shapeText(b.shape)} one")
	batch = a.dim(0) if batched else 1
	aRows = a.dim(-2) if batched else a.count() / a.dim(-1)
	sa = strided(aRows, a.dim(-1), ta)
	sb = strided(b.dim(-2), b.dim(-1), tb)
	if sa.cols != sb.rows or batched and b.dim(0) != batch:
		fail("tensor: a product of a {shapeText(a.shape)}{" transposed" if ta else ""} tensor and a {shapeText(b.shape)}{" transposed" if tb else ""} one")
	shape = [batch, sa.rows, sb.cols] if batched else a.shape[..a.rank() - 1].copy()
	if not batched:
		if ta:
			shape = [sa.rows]
		shape.push(sb.cols)
	m = sa.rows
	n = sb.cols
	k = sa.cols
	aBatch = aRows * a.dim(-1)
	bBatch = b.dim(-2) * b.dim(-1)
	if not a.isOnGpu():
		out = fill(batch * m * n, f32(0))
		for z in 0..batch:
			for i in 0..m:
				for q in 0..k:
					x = a.values[z * aBatch + i * sa.row + q * sa.col]
					for j in 0..n:
						out[z * m * n + i * n + j] += x *
							b.values[z * bBatch + q * sb.row + j * sb.col]
		return Tensor(shape, values = out)
	out = gpuOut(shape)
	params = ProductParams(
		a = [],
		b = [],
		c = [],
		m = i32(m),
		n = i32(n),
		k = i32(k),
		aRow = i32(sa.row),
		aCol = i32(sa.col),
		bRow = i32(sb.row),
		bCol = i32(sb.col),
		aBatch = i32(aBatch),
		bBatch = i32(bBatch)
	)
	gpu.run(
		compute(productKernel, 16, 16),
		params,
		[a.handle(), b.handle(), out.handle()],
		(n + 63) / 64,
		(m + 63) / 64,
		batch
	)
	out

# x times the transpose of a weight stored as halves or blocks
fn packedProduct(x Tensor, w Tensor):
	x.sameSide(w, "a layer")
	k = w.dim(1)
	n = w.dim(0)
	if x.dim(-1) != k:
		fail("tensor: a layer of {shapeText(w.shape)} weights over a {shapeText(x.shape)} tensor")
	rows = x.count() / k
	shape = x.shape[..x.rank() - 1].copy()
	shape.push(n)
	out = gpuOut(shape)
	blocked = w.format == .Q8 or w.format == .Q4
	# blocks multiply the inputs quantized as llama.cpp's blocks of Q8_0 (integer products)
	xq = gpuOut(x.shape) if blocked else x.copy()
	xScales = gpuOut([x.count() / 32]) if blocked else x.copy()
	if blocked:
		bx, by = spread(x.count() / 32)
		quantize = QuantizeParams(
			x = [],
			q = [],
			scales = [],
			blocks = i32(x.count() / 32),
			stride = i32(bx * 64)
		)
		gpu.run(
			compute(quantizeKernel, 64),
			quantize,
			[x.handle(), xq.handle(), xScales.handle()],
			bx,
			by
		)
	params = PackedParams(
		x = [],
		words = [],
		scales = [],
		xScales = [],
		out = [],
		n = i32(n),
		k = i32(k),
		bfloat = 1 if w.format == .BF16 else 0
	)
	buffers = [xq.handle(), w.handle()]
	if w.scales is s:
		buffers.push(s.handle)
	else:
		buffers.push(w.handle())
	buffers.push(xScales.handle())
	buffers.push(out.handle())
	if w.format == .Q8:
		gpu.run(compute(q8ProductKernel, 64), params, buffers, n, rows)
	elif w.format == .Q4:
		gpu.run(compute(q4ProductKernel, 64), params, buffers, n, rows)
	else:
		gpu.run(compute(halvesProductKernel, 64), params, buffers, n, rows)
	out

# The tensor with dimensions d0 and d1 swapped (from the end when negative), its numbers moved:
# a.swapped(0, 1) of [t, heads, d] is [heads, t, d]. Up to four dimensions.
pub fn swapped(a Tensor, d0 i64, d1 i64) Tensor:
	a.f32Only("a swap")
	r = a.rank()
	if r > 4 or r < 2:
		fail("tensor: a swap of a {shapeText(a.shape)} tensor")
	i = d0 if d0 >= 0 else r + d0
	j = d1 if d1 >= 0 else r + d1
	inStrides = fill(r, 0)
	s = 1
	q = r - 1
	while q >= 0:
		inStrides[q] = s
		s *= a.shape[q]
		q -= 1
	shape = a.shape.copy()
	shape[i] = a.shape[j]
	shape[j] = a.shape[i]
	strides = inStrides.copy()
	strides[i] = inStrides[j]
	strides[j] = inStrides[i]
	# padded in front to four dimensions
	dims = fill(4 - r, 1)
	dims.extend(shape)
	steps = fill(4 - r, 0)
	steps.extend(strides)
	n = a.count()
	if not a.isOnGpu():
		out f32[] = []
		out.reserve(n)
		for i0 in 0..dims[0]:
			for i1 in 0..dims[1]:
				for i2 in 0..dims[2]:
					for i3 in 0..dims[3]:
						out.push(
							a.values[i0 * steps[0] + i1 * steps[1] + i2 * steps[2] + i3 * steps[3]]
						)
		return Tensor(shape, values = out)
	out = gpuOut(shape)
	x, y = spread(n)
	params = SwapParams(
		values = [],
		out = [],
		count = i32(n),
		n1 = i32(dims[1]),
		n2 = i32(dims[2]),
		n3 = i32(dims[3]),
		s0 = i32(steps[0]),
		s1 = i32(steps[1]),
		s2 = i32(steps[2]),
		s3 = i32(steps[3]),
		stride = i32(x * 64)
	)
	gpu.run(compute(swapKernel, 64), params, [a.handle(), out.handle()], x, y)
	out

pub fn swappedGrad(a Tensor, d0 i64, d1 i64, dy Tensor) Tensor:
	dy.swapped(d0, d1)

# the transpose of the last two dimensions
pub fn transposed(a Tensor) Tensor:
	a.swapped(-2, -1)

pub fn transposedGrad(a Tensor, dy Tensor) Tensor:
	dy.transposed()
