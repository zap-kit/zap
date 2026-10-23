# Operations number by number: two tensors (the second's shape a suffix of the first's, or the
# other way round, repeats), a tensor and a number, and the functions of one number (activations).

import gpu

opAdd = 0
opSub = 1
opMul = 2
opDiv = 3

# x op y, the operation's code one of opAdd..opDiv (the CPU's and the GPU's)
pub fn combine(x f32, y f32, op i32) f32:
	match op:
		0: x + y
		1: x - y
		2: x * y
		_: x / y

# the shape of a op b: the longer one when the shorter is its suffix
fn broadcastShape(a i64[], b i64[], what str):
	long = a if a.len >= b.len else b
	short = b if a.len >= b.len else a
	if long[len - short.len..] != short:
		fail("tensor: {what} of a {shapeText(a)} tensor and a {shapeText(b)} one")
	long.copy()

fn binary(a Tensor, b Tensor, op i32, what str):
	a.sameSide(b, what)
	a.f32Only(what)
	b.f32Only(what)
	shape = broadcastShape(a.shape, b.shape, what)
	n = shapeCount(shape)
	if not a.isOnGpu():
		an = a.values.len
		bn = b.values.len
		values = (0..n).map(combine(a.values[it % an], b.values[it % bn], op))
		return Tensor(shape, values)
	out = gpuOut(shape)
	x, y = spread(n)
	gpu.run(
		compute(binaryKernel, 64),
		BinaryParams(a = [], b = [], out = [], count = i32(n), aCount = i32(a.count()), bCount = i32(b.count()), op, stride = i32(x * 64)),
		[a.handle(), b.handle(), out.handle()],
		x,
		y
	)
	out

pub fn add(a Tensor, b Tensor) Tensor:
	a.binary(b, opAdd, "a sum")

pub fn sub(a Tensor, b Tensor) Tensor:
	a.binary(b, opSub, "a difference")

pub fn mul(a Tensor, b Tensor) Tensor:
	a.binary(b, opMul, "a product")

pub fn div(a Tensor, b Tensor) Tensor:
	a.binary(b, opDiv, "a quotient")

pub fn addGrad(a Tensor, b Tensor, dy Tensor) (Tensor, Tensor):
	(dy.sumTo(a.shape), dy.sumTo(b.shape))

pub fn subGrad(a Tensor, b Tensor, dy Tensor) (Tensor, Tensor):
	(dy.sumTo(a.shape), dy.scaled(-1.0).sumTo(b.shape))

pub fn mulGrad(a Tensor, b Tensor, dy Tensor) (Tensor, Tensor):
	(dy.mul(b).sumTo(a.shape), dy.mul(a).sumTo(b.shape))

pub fn divGrad(a Tensor, b Tensor, dy Tensor) (Tensor, Tensor):
	da = dy.div(b)
	db = da.mul(a.div(b)).scaled(-1.0)
	(da.sumTo(a.shape), db.sumTo(b.shape))

# The tensor summed down to `shape`, a suffix of its own: the sums over the leading dimensions
# it repeats over (a bias's gradient over a batch).
pub fn sumTo(tensor Tensor, to i64[]) Tensor:
	if tensor.shape == to: return tensor.copy()
	cols = shapeCount(to)
	rows = tensor.count() / cols.max(1)
	if not tensor.isOnGpu():
		totals = fill(cols, f32(0))
		for r in 0..rows:
			for c in 0..cols:
				totals[c] += tensor.values[r * cols + c]
		return Tensor(shape = to.copy(), values = totals)
	out = gpuOut(to)
	x, y = spread(cols)
	gpu.run(
		compute(columnSumsKernel, 64),
		ColumnsParams(values = [], out = [], rows = i32(rows), cols = i32(cols), stride = i32(x * 64)),
		[tensor.handle(), out.handle()],
		x,
		y
	)
	out

# ---------- a tensor and a number ----------

scaleTimes = 0
scalePlus = 1
scaleFrom = 2   # k - x
scaleOver = 3   # x / k
scaleInto = 4   # k / x
scaleMinus = 5   # x - k

# x combined with k by `how` (scaleTimes..scaleInto)
pub fn withNumber(x f32, k f32, how i32) f32:
	match how:
		0: x * k
		1: x + k
		2: k - x
		3: x / k
		4: k / x
		_: x - k

fn byNumber(a Tensor, k f32, how i32):
	a.f32Only("an operation with a number")
	if not a.isOnGpu():
		return Tensor(shape = a.shape.copy(), values = a.values.map(withNumber(it, k, how)))
	out = gpuOut(a.shape)
	n = a.count()
	x, y = spread(n)
	gpu.run(
		compute(byNumberKernel, 64),
		ByNumberParams(values = [], out = [], count = i32(n), k, how, stride = i32(x * 64)),
		[a.handle(), out.handle()],
		x,
		y
	)
	out

# every number times k (a * k, k * a, -a)
pub fn scaled(a Tensor, k f32) Tensor:
	a.byNumber(k, scaleTimes)

# every number plus k (a + k, a - k)
pub fn shifted(a Tensor, k f32) Tensor:
	a.byNumber(k, scalePlus)

# every number less k (a - k)
pub fn subtracted(a Tensor, k f32) Tensor:
	a.byNumber(k, scaleMinus)

pub fn subtractedGrad(a Tensor, k f32, dy Tensor) Tensor:
	dy.copy()

# k less every number (k - a)
pub fn subtractedFrom(a Tensor, k f32) Tensor:
	a.byNumber(k, scaleFrom)

# every number over k (a / k)
pub fn divided(a Tensor, k f32) Tensor:
	a.byNumber(k, scaleOver)

# k over every number (k / a)
pub fn dividing(a Tensor, k f32) Tensor:
	a.byNumber(k, scaleInto)

# -a
pub fn neg(a Tensor) Tensor:
	a.byNumber(-1.0, scaleTimes)

pub fn scaledGrad(a Tensor, k f32, dy Tensor) Tensor:
	dy.scaled(k)

pub fn shiftedGrad(a Tensor, k f32, dy Tensor) Tensor:
	dy.copy()

pub fn subtractedFromGrad(a Tensor, k f32, dy Tensor) Tensor:
	dy.scaled(-1.0)

pub fn dividedGrad(a Tensor, k f32, dy Tensor) Tensor:
	dy.divided(k)

pub fn dividingGrad(a Tensor, k f32, dy Tensor) Tensor:
	# d(k / a) = -k / a^2
	inverse = a.dividing(1.0)
	dy.mul(inverse.mul(inverse).scaled(-k))

pub fn negGrad(a Tensor, dy Tensor) Tensor:
	dy.scaled(-1.0)

# a tensor of the same shape and place, every number 1
pub fn onesLike(tensor Tensor) Tensor:
	tensor.zerosLike().shifted(1.0)

# ---------- functions of one number ----------

opRelu = 0
opGelu = 1
opSilu = 2
opSigmoid = 3
opTanh = 4
opExp = 5
opLn = 6
opSqrt = 7
opSquare = 8

# the function `op` of one number: an activation or another (opRelu..opSquare), the CPU's and the
# GPU's; its derivative is grad's (unaryGrad)
pub fn activation(x f32, op i32) f32:
	match op:
		0: x.max(0.0)
		1: 0.5 * x * (1.0 + (0.7978846 * (x + 0.044715 * x * x * x)).tanh())   # GELU, tanh's form
		2: x / (1.0 + (-x).exp())
		3: 1.0 / (1.0 + (-x).exp())
		4: x.tanh()
		5: x.exp()
		6: x.ln()
		7: x.sqrt()
		_: x * x

fn unary(a Tensor, op i32):
	a.f32Only("an activation")
	if not a.isOnGpu():
		return Tensor(shape = a.shape.copy(), values = a.values.map(activation(it, op)))
	out = gpuOut(a.shape)
	n = a.count()
	x, y = spread(n)
	gpu.run(
		compute(unaryKernel, 64),
		UnaryParams(values = [], out = [], count = i32(n), op, stride = i32(x * 64)),
		[a.handle(), out.handle()],
		x,
		y
	)
	out

# dy times the derivative of the function `op` at each number of a
fn unaryGrad(a Tensor, dy Tensor, op i32):
	a.sameSide(dy, "a derivative")
	if not a.isOnGpu():
		values = (0..a.count()).map(dy.values[it] * slope(a.values[it], op))
		return Tensor(shape = a.shape.copy(), values)
	out = gpuOut(a.shape)
	n = a.count()
	x, y = spread(n)
	gpu.run(
		compute(unaryGradKernel, 64),
		UnaryGradParams(values = [], dy = [], out = [], count = i32(n), op, stride = i32(x * 64)),
		[a.handle(), dy.handle(), out.handle()],
		x,
		y
	)
	out

# the derivative of activation(x, op) at x, as grad writes it
pub fn slope(x f32, op i32) f32:
	_, d = grad(activation)(x, op)
	d

pub fn relu(a Tensor) Tensor:
	a.unary(opRelu)

# GELU in tanh's form (PyTorch's gelu(approximate = "tanh"))
pub fn gelu(a Tensor) Tensor:
	a.unary(opGelu)

pub fn silu(a Tensor) Tensor:
	a.unary(opSilu)

pub fn sigmoid(a Tensor) Tensor:
	a.unary(opSigmoid)

pub fn tanh(a Tensor) Tensor:
	a.unary(opTanh)

pub fn exp(a Tensor) Tensor:
	a.unary(opExp)

pub fn ln(a Tensor) Tensor:
	a.unary(opLn)

pub fn sqrt(a Tensor) Tensor:
	a.unary(opSqrt)

pub fn square(a Tensor) Tensor:
	a.unary(opSquare)

pub fn reluGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opRelu)

pub fn geluGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opGelu)

pub fn siluGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opSilu)

pub fn sigmoidGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opSigmoid)

pub fn tanhGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opTanh)

pub fn expGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opExp)

pub fn lnGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opLn)

pub fn sqrtGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opSqrt)

pub fn squareGrad(a Tensor, dy Tensor) Tensor:
	a.unaryGrad(dy, opSquare)
