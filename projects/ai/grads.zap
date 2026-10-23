# grad: derivatives the compiler writes, checked against finite differences on the CPU and run on
# the GPU (skipped where there is none).

import tensor
import gpu

type Mlp:
	w1 tensor.Tensor
	b1 tensor.Tensor
	w2 tensor.Tensor
	b2 tensor.Tensor
	width i64

fn layer(w tensor.Tensor, b tensor.Tensor, x tensor.Tensor):
	(x @ w + b).gelu()

fn mlpLoss(m Mlp, x tensor.Tensor, labels tensor.Tensor):
	h = m.w1.layer(m.b1, x)
	logits = h @ m.w2 + m.b2
	logits.crossEntropy(labels) * 0.5 + (m.w2 * m.w2).mean() * 0.01

fn newMlp(seed i64):
	Mlp(
		w1 = tensor.randomNormal([4, 6], seed, scale = 0.5),
		b1 = tensor.randomNormal([6], seed + 1, scale = 0.1),
		w2 = tensor.randomNormal([6, 3], seed + 2, scale = 0.5),
		b2 = tensor.zeros([3]),
		width = 6
	)

fn onGpu(m Mlp):
	Mlp(w1 = m.w1.gpu(), b1 = m.b1.gpu(), w2 = m.w2.gpu(), b2 = m.b2.gpu(), width = m.width)

# the derivative of the loss by w1's number k, by central differences
fn numeric(m Mlp, x tensor.Tensor, labels tensor.Tensor, k i64):
	h f32 = 0.01
	up = m.w1.toList()
	up[k] += h
	down = m.w1.toList()
	down[k] -= h
	plus = mlpLoss(
		Mlp(w1 = tensor.fromList([4, 6], up), b1 = m.b1.copy(), w2 = m.w2.copy(), b2 = m.b2.copy(), width = 6),
		x,
		labels
	).item()
	minus = mlpLoss(
		Mlp(w1 = tensor.fromList([4, 6], down), b1 = m.b1.copy(), w2 = m.w2.copy(), b2 = m.b2.copy(), width = 6),
		x,
		labels
	).item()
	(plus - minus) / (2.0 * h)

test "the gradient of a network's loss, by a struct of its weights, as finite differences give it":
	m = newMlp(3)
	x = tensor.randomNormal([5, 4], seed = 9)
	labels = tensor.fromList([5], [0.0, 2.0, 1.0, 1.0, 0.0])
	loss, g = grad(mlpLoss)(m, x, labels)
	print("{loss.item() == m.mlpLoss(x, labels).item()} {g.width} {g.w1.shape} {g.b2.shape}")
	worst f32 = 0.0
	for k in [0, 5, 11, 17, 23]:
		worst = worst.max((m.numeric(x, labels, k) - g.w1.toList()[k]).abs())
	print(worst < 0.002)
	if gpu.available():
		gl, gg = grad(mlpLoss)(m.onGpu(), x.gpu(), labels.gpu())
		expect (gl.item() - loss.item()).abs() < 0.0001
		expect near(gg.w1.toList(), g.w1.toList()) and near(gg.b1.toList(), g.b1.toList())
		expect near(gg.w2.toList(), g.w2.toList()) and near(gg.b2.toList(), g.b2.toList())
	prints """
		true 6 [4, 6] [3]
		true
		"""

fn near(a f32[], b f32[]):
	a.len == b.len and (0..a.len).all((a[it] - b[it]).abs() <= 0.0001 * (1.0 + b[it].abs()))

type Stack:
	layers tensor.Tensor[]
	scale tensor.Tensor

fn deep(s Stack, x tensor.Tensor):
	h = x.copy()
	for w in s.layers:
		h = (h @ w).tanh() * s.scale
	h.sum()

test "a loop over a list of layers, each step computed again backward":
	s = Stack(
		layers = [tensor.randomNormal([3, 3], seed = 1), tensor.randomNormal([3, 3], seed = 2), tensor.randomNormal([3, 3], seed = 3)],
		scale = tensor.scalar(1.5)
	)
	x = tensor.randomNormal([2, 3], seed = 4)
	value, g = grad(deep)(s, x)
	# the scale's gradient by finite differences
	e f32 = 0.001
	up = deep(Stack(layers = s.layers.map(.copy()), scale = tensor.scalar(1.5 + e)), x).item()
	down = deep(Stack(layers = s.layers.map(.copy()), scale = tensor.scalar(1.5 - e)), x).item()
	expect g.layers.len == 3
	expect ((up - down) / (2.0 * e) - g.scale.item()).abs() < 0.01
	expect value.item() == s.deep(x).item()

type Line:
	w tensor.Tensor
	b tensor.Tensor

fn lineLoss(m Line, x tensor.Tensor, y tensor.Tensor):
	d = x @ m.w + m.b - y
	(d * d).mean()

# a line fitted by an optimiser for 400 steps, on the CPU or the GPU
fn fitted(method tensor.Method, onGpu bool):
	m = Line(w = tensor.zeros([1, 1]), b = tensor.zeros([1]))
	x = tensor.fromList([4, 1], [1.0, 2.0, 3.0, 4.0])
	y = tensor.fromList([4, 1], [3.0, 5.0, 7.0, 9.0])
	if onGpu:
		m = Line(w = m.w.gpu(), b = m.b.gpu())
		x = x.gpu()
		y = y.gpu()
	opt = tensor.Optimiser(
		method,
		rate = 0.05 if method == .Sgd else 0.1,
		momentum = 0.5 if method == .Sgd else 0.0
	)
	loop 400:
		_, g = grad(lineLoss)(m, x, y)
		opt.step(m, g)
	[m.w.item(), m.b.item()]

methods = [tensor.Method.Sgd, tensor.Method.Adam]

test "SGD with momentum and Adam fit a line, the same on the CPU and the GPU" for method in methods:
	cpu = method.fitted(false)
	expect (cpu[0] - 2.0).abs() < 0.05 and (cpu[1] - 1.0).abs() < 0.1
	if gpu.available():
		expect near(method.fitted(true), cpu)
