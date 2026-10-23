# std/tensor: the same operations on the CPU and on the GPU (the GPU's skipped where there is none).

import tensor
import gpu

# whether two lists of numbers agree within tol, relative to their size
fn near(a f32[], b f32[], tol f32 = 0.0001):
	if a.len != b.len: return false
	for i in 0..a.len:
		if (a[i] - b[i]).abs() > tol * (1.0 + a[i].abs()): return false
	true

test "numbers combined element by element, a bias over a batch, a tensor and a number":
	a = tensor.fromList([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
	b = tensor.fromList([3], [10.0, 20.0, 30.0])
	print(a.add(b).toList())
	print(a.mul(a).toList())
	print(a.scaled(0.5).toList())
	print(a.shifted(-3.0).relu().toList())
	print(a.sumTo([3]).toList())
	if gpu.available():
		ga = a.gpu()
		gb = b.gpu()
		expect near(ga.add(gb).toList(), a.add(b).toList())
		expect near(ga.div(gb).toList(), a.div(b).toList())
		expect near(ga.gelu().toList(), a.gelu().toList())
		expect near(ga.sumTo([3]).toList(), [5.0, 7.0, 9.0])
		expect near(ga.geluGrad(ga).toList(), a.geluGrad(a).toList())
	prints """
		[11, 22, 33, 14, 25, 36]
		[1, 4, 9, 16, 25, 36]
		[0.5, 1, 1.5, 2, 2.5, 3]
		[0, 0, 0, 1, 2, 3]
		[5, 7, 9]
		"""

test "the math operators on tensors are their methods":
	a = tensor.fromList([2, 2], [1.0, 2.0, 3.0, 4.0])
	b = tensor.fromList([2], [10.0, 20.0])
	print((a + b).toList())
	print((a * 2.0 - 1.0).toList())
	print((1.0 - a / 2.0).toList())
	print((-a + a * a).toList())
	print((2.0 / a).toList())
	prints """
		[11, 22, 13, 24]
		[1, 3, 5, 7]
		[0.5, 0, -0.5, -1]
		[0, 2, 6, 12]
		[2, 1, 0.6666667, 0.5]
		"""

test "products of matrices, of batches, of a layer, and swapped dimensions":
	a = tensor.fromList([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
	b = tensor.fromList([3, 2], [1.0, 0.0, 0.0, 1.0, 2.0, 2.0])
	print((a @ b).toList())
	print(a.transposed().toList())
	print(a.linear(a).toList())
	da, db = a.matmulGrad(b, tensor.full([2, 2], 1.0))
	print("{da.toList()} {db.toList()}")
	print(tensor.fromList([2, 3, 2], (0..12).map(f32(it))).swapped(0, 1).toList())
	if gpu.available():
		m = tensor.randomNormal([70, 45], seed = 1)
		n = tensor.randomNormal([45, 130], seed = 2)
		expect near((m.gpu() @ n.gpu()).toList(), (m @ n).toList(), 0.001)
		p = tensor.randomNormal([3, 20, 33], seed = 3)
		q = tensor.randomNormal([3, 33, 17], seed = 4)
		expect near((p.gpu() @ q.gpu()).toList(), (p @ q).toList(), 0.001)
		expect near(p.gpu().swapped(0, 1).toList(), p.swapped(0, 1).toList())
		expect near(m.gpu().transposed().toList(), m.transposed().toList())
		gda, gdb = m.gpu().matmulGrad(n.gpu(), (m @ n).gpu())
		cda, cdb = m.matmulGrad(n, m @ n)
		expect near(gda.toList(), cda.toList(), 0.001) and near(gdb.toList(), cdb.toList(), 0.001)
	prints """
		[7, 8, 16, 17]
		[1, 4, 2, 5, 3, 6]
		[14, 32, 32, 77]
		[1, 1, 4, 1, 1, 4] [5, 5, 7, 7, 9, 9]
		[0, 1, 6, 7, 2, 3, 8, 9, 4, 5, 10, 11]
		"""

# the largest difference of two lists' numbers
fn farthest(a f32[], b f32[]):
	most f32 = 0.0
	for i in 0..a.len:
		most = most.max((a[i] - b[i]).abs())
	most

fn tolerance(f tensor.Format) f32:
	match f:
		F16: 0.01
		BF16, Q8: 0.05
		_: 0.3

test "a layer whose weights are halves or blocks of 8 or 4 bits":
	if not gpu.available():
		print("skipped: {gpu.unavailableReason()}")
		return
	x = tensor.randomNormal([3, 64], seed = 5)
	w = tensor.randomNormal([40, 64], seed = 6, scale = 0.1)
	exact = x.linear(w).toList()
	gx = x.gpu()
	formats tensor.Format[] = [.F16, .BF16, .Q8, .Q4]
	for format in formats:
		stored = w.gpu(format)
		# the product of the stored numbers, read back, is the kernel's (blocks read the inputs
		# quantized as llama.cpp does)
		read = x.blockQuantized() if format == .Q8 or format == .Q4 else x.copy()
		expect near(gx.linear(stored).toList(), read.linear(stored.toCpu()).toList(), 0.0001)
		print("{format} {farthest(gx.linear(stored).toList(), exact) < format.tolerance()}")
	prints """
		F16 true
		BF16 true
		Q8 true
		Q4 true
		"""

# the same operation on the CPU and on the GPU agrees
fn agree(cpu tensor.Tensor, gpu tensor.Tensor, tol f32 = 0.0001):
	cpu.shape == gpu.shape and near(cpu.toList(), gpu.toList(), tol)

test "softmax, causal over square blocks, cross-entropy, normalisations, sums and an embedding":
	x = tensor.fromList([2, 3], [1.0, 2.0, 3.0, 1.0, 1.0, 1.0])
	print(x.softmax().toList())
	print(
		tensor
			.fromList([3, 3], [1.0, 2.0, 3.0, 1.0, 2.0, 3.0, 1.0, 2.0, 3.0])
			.softmax(causal = true)
			.toList()
	)
	labels = tensor.fromList([2], [2.0, 0.0])
	print(x.crossEntropy(labels).item())
	print(x.layerNorm(tensor.full([3], 1.0), tensor.zeros([3])).toList())
	print(x.sum().item())
	table = tensor.fromList([3, 2], [0.0, 1.0, 10.0, 11.0, 20.0, 21.0])
	print(table.embedding(tensor.fromList([2, 2], [2.0, 0.0, 1.0, 2.0])).toList())
	print(
		table
			.embeddingGrad(tensor.fromList([3], [2.0, 2.0, 0.0]), tensor.full([3, 2], 1.0))
			.toList()
	)
	if gpu.available():
		big = tensor.randomNormal([37, 100], seed = 7)
		dy = tensor.randomNormal([37, 100], seed = 8)
		gain = tensor.randomNormal([100], seed = 9)
		bias = tensor.randomNormal([100], seed = 10)
		classes = tensor.fromList([37], (0..37).map(f32(it * 7 % 100)))
		g = big.gpu()
		gd = dy.gpu()
		expect big.softmax().agree(g.softmax())
		square = tensor.randomNormal([2, 30, 30], seed = 11)
		expect square.softmax(causal = true).agree(square.gpu().softmax(causal = true))
		expect big.softmaxGrad(false, dy).agree(g.softmaxGrad(false, gd))
		expect big.crossEntropy(classes).agree(g.crossEntropy(classes.gpu()))
		dl = tensor.scalar(2.0)
		expect big.crossEntropyGrad(classes, dl).agree(g.crossEntropyGrad(classes.gpu(), dl.gpu()))
		expect big.layerNorm(gain, bias).agree(g.layerNorm(gain.gpu(), bias.gpu()), 0.001)
		expect big.rmsNorm(gain).agree(g.rmsNorm(gain.gpu()), 0.001)
		cdx, cdg, cdb = big.layerNormGrad(gain, bias, 0.00001, dy)
		gdx, gdg, gdb = g.layerNormGrad(gain.gpu(), bias.gpu(), 0.00001, gd)
		expect cdx.agree(gdx, 0.001) and cdg.agree(gdg, 0.001) and cdb.agree(gdb, 0.001)
		rdx, rdg = big.rmsNormGrad(gain, 0.000001, dy)
		qdx, qdg = g.rmsNormGrad(gain.gpu(), 0.000001, gd)
		expect rdx.agree(qdx, 0.001) and rdg.agree(qdg, 0.001)
		expect big.sum().agree(g.sum(), 0.001)
		ids = tensor.fromList([5], [3.0, 0.0, 3.0, 36.0, 1.0])
		expect big.embedding(ids).agree(g.embedding(ids.gpu()))
		dPicked = tensor.randomNormal([5, 100], seed = 12)
		expect big
			.embeddingGrad(ids, dPicked)
			.agree(g.embeddingGrad(ids.gpu(), dPicked.gpu()), 0.001)
	prints """
		[0.09003057, 0.24472848, 0.66524094, 0.33333334, 0.33333334, 0.33333334]
		[1, 0, 0, 0.26894143, 0.7310586, 0, 0.09003057, 0.24472848, 0.66524094]
		0.7531091
		[-1.2247356, 0, 1.2247356, 0, 0, 0]
		9
		[20, 21, 0, 1, 10, 11, 20, 21]
		[1, 1, 0, 0, 2, 2]
		"""

test "a convolution and its derivatives, strided and padded":
	x = tensor.fromList([1, 1, 3, 3], (1..10).map(f32(it)))
	w = tensor.fromList([1, 1, 2, 2], [1.0, 0.0, 0.0, 1.0])
	print(x.conv2d(w).toList())
	print(x.conv2d(w, padding = 1, stride = 2).toList())
	dx, dw = x.conv2dGrad(w, 1, 0, tensor.full([1, 1, 2, 2], 1.0))
	print("{dx.toList()} {dw.toList()}")
	if gpu.available():
		img = tensor.randomNormal([2, 3, 9, 8], seed = 13)
		k = tensor.randomNormal([4, 3, 3, 3], seed = 14)
		for (stride, padding) in [(1, 0), (2, 1), (1, 2)]:
			y = img.conv2d(k, stride, padding)
			expect y.agree(img.gpu().conv2d(k.gpu(), stride, padding), 0.001)
			dy = tensor.randomNormal(y.shape, seed = 15)
			cx, cw = img.conv2dGrad(k, stride, padding, dy)
			gxx, gw = img.gpu().conv2dGrad(k.gpu(), stride, padding, dy.gpu())
			expect cx.agree(gxx, 0.001) and cw.agree(gw, 0.001)
	prints """
		[6, 8, 12, 14]
		[1, 3, 7, 14]
		[1, 1, 0, 1, 2, 1, 0, 1, 1] [12, 16, 24, 28]
		"""
