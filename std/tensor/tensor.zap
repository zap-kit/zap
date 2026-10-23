# Tensors: numbers of any rank, row-major, on the CPU or on the GPU. A module of the standard
# library: `import tensor`, then
#
#   x = tensor.fromList([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]).gpu()
#   w = tensor.randomNormal([3, 4], seed = 1, scale = 0.1).gpu()
#   y = tensor.relu(x @ w + b)
#   print(y.toList())
#
# The math operators take tensors as they take grids (spec 7.10): `a + b`, `a - b`, `a * b`,
# `a / b` element by element (the second's shape a suffix of the first's repeats over its leading
# dimensions: a bias over a batch), `a * k`, `k * a`, `a / k`, `a + k`, `a - k`, `-a` with a
# number, and `a @ b` the product of matrices (a batch of them when both have three dimensions).
# Each operation runs where its tensors are: on the CPU in loops, on the GPU in kernels of this
# module's `.gpu.zap` files (std/gpu runs them), the GPU's tensors never read back unless asked
# (`toList`, `item`). Tensors on two sides is an error that stops the program.
#
# On the GPU a tensor's numbers are stored as f32, or for weights read by `linear` as halves (f16
# or bf16) or as 8-bit or 4-bit integers in blocks of 32 sharing a scale (GGUF's Q8_0 and Q4_0):
# `w.gpu(.Q4)`. Every function of a tensor's numbers has its derivative (`fGrad`), which `grad`
# (spec 5.4) composes.

import gpu

# how a GPU tensor stores its numbers
pub type Format:
	F32
	F16   # IEEE halves, two to a word
	BF16   # the high halves of f32s, two to a word
	Q8   # blocks of 32 bytes, each times its block's f32 scale
	Q4   # blocks of 32 nibbles less 8, each times its block's f32 scale

# A tensor: its shape (the length of each dimension, the last varying fastest) and its numbers,
# on the CPU (`values`) or on the GPU (`buffer`, in `format`; scales in `scales` for Q8 and Q4).
pub type Tensor:
	shape i64[]
	values f32[] = []
	buffer gpu.Buffer? = none
	scales gpu.Buffer? = none
	format Format = .F32

	# the count of the tensor's numbers
	pub fn count() i64:
		shapeCount(shape)

	pub fn rank() i64:
		shape.len

	# whether the tensor's numbers are on the GPU
	pub fn isOnGpu() bool:
		buffer != none

	# the length of dimension d (from the end when negative)
	pub fn dim(d i64) i64:
		shape[d if d >= 0 else len + d]

	# a tensor of the same shape and place, every number 0
	pub fn zerosLike() Tensor:
		if isOnGpu(): return Tensor(shape = shape.copy(), buffer = gpu.zeroBuffer(count() * 4))
		zeros(shape)

	fn copy():
		Tensor(
			shape = shape.copy(),
			values = values.copy(),
			buffer = buffer?.copy(),
			scales = scales?.copy(),
			format
		)

	# The tensor on the GPU, its numbers stored in `format` (the CPU's numbers rounded to it: halves to
	# the nearest even, blocks scaled by their largest magnitude). A tensor on the GPU already in that
	# format is given as it is.
	pub fn gpu(to Format = .F32) Tensor:
		if isOnGpu():
			if to == format: return self.copy()
			return toCpu().gpu(to)
		match to:
			F32:
				b = gpu.newBuffer(values.len * 4)
				b.upload(values)
				Tensor(shape = shape.copy(), buffer = b)
			F16: packedHalves(shape, values.map(halfBits(it)), .F16)
			BF16: packedHalves(shape, values.map(bfloatBits(it)), .BF16)
			Q8: quantized(shape, values, .Q8)
			Q4: quantized(shape, values, .Q4)

	# the tensor on the CPU, its numbers as f32 (a GPU's read back, waiting for the work before)
	pub fn toCpu() Tensor:
		if not isOnGpu(): return self.copy()
		Tensor(shape = shape.copy(), values = self.gpuValues())

	# the tensor's numbers in order (read back from the GPU)
	pub fn toList() f32[]:
		if not isOnGpu(): return values.copy()
		self.gpuValues()

	# the one number of a tensor that holds one
	pub fn item() f32:
		if count() != 1:
			fail("tensor: item() of a {shapeText(shape)} tensor")
		toList()[0]

	# the same numbers in another shape of the same count (one dimension -1: what the others leave)
	pub fn reshape(to i64[]) Tensor:
		s = to.copy()
		known = shapeCount(to.filter(it >= 0))
		for i in 0..s.len:
			if s[i] < 0:
				s[i] = count() / known.max(1)
		if shapeCount(s) != count():
			fail("tensor: a {shapeText(shape)} tensor reshaped to {shapeText(to)}")
		Tensor(
			shape = s,
			values = values.copy(),
			buffer = buffer?.copy(),
			scales = scales?.copy(),
			format
		)

	pub fn reshapeGrad(to i64[], dy Tensor) Tensor:
		dy.reshape(shape)

	# n rows of the first dimension from row `first`: a tensor of their own (a batch of a data set)
	pub fn rows(first i64, n i64) Tensor:
		self.f32Only("a part")
		per = count() / shape[0].max(1)
		if first < 0 or n < 0 or first + n > shape[0]:
			fail("tensor: rows {first}..{first + n} of a {shapeText(shape)} tensor")
		to = shape.copy()
		to[0] = n
		if not isOnGpu():
			return Tensor(shape = to, values = values[first * per..(first + n) * per].copy())
		out = gpuOut(to)
		storage().copyBytes(first * per * 4, out.storage(), 0, n * per * 4)
		out

	# the gradient of rows(first, n): dy in those rows, zeros elsewhere
	pub fn rowsGrad(first i64, n i64, dy Tensor) Tensor:
		per = count() / shape[0].max(1)
		if not isOnGpu():
			out = fill(count(), f32(0))
			for i in 0..n * per:
				out[first * per + i] = dy.values[i]
			return Tensor(shape = shape.copy(), values = out)
		out = zerosLike()
		dy.storage().copyBytes(0, out.storage(), first * per * 4, n * per * 4)
		out

# the count of numbers a shape holds
pub fn shapeCount(shape i64[]) i64:
	n = 1
	for d in shape:
		n *= d
	n

# the tensor of this shape and these numbers, row-major
pub fn fromList(shape i64[], values f32[]) Tensor:
	if shapeCount(shape) != values.len:
		fail("tensor: a {shapeText(shape)} tensor holds {shapeCount(shape)} numbers, given {values.len}")
	Tensor(shape = shape.copy(), values = values.copy())

# the tensor of one number, of no dimensions
pub fn scalar(x f32) Tensor:
	Tensor(shape = [], values = [x])

# every number k
pub fn full(shape i64[], k f32) Tensor:
	Tensor(shape = shape.copy(), values = fill(shapeCount(shape), k))

# every number 0
pub fn zeros(shape i64[]) Tensor:
	full(shape, 0.0)

# A tensor of numbers drawn from the normal distribution of mean 0 and deviation `scale`, the
# same numbers for the same seed (Box-Muller over the runtime's Random).
pub fn randomNormal(shape i64[], seed i64, scale f32 = 1.0) Tensor:
	rng = Random(seed)
	n = shapeCount(shape)
	values f32[] = []
	values.reserve(n)
	while values.len < n:
		u = rng.nextFloat(0.0, 1.0).max(1e-12)
		v = rng.nextFloat(0.0, 1.0)
		r = (-2.0 * u.ln()).sqrt()
		values.push(f32(r * (tau * v).cos()) * scale)
		if values.len < n:
			values.push(f32(r * (tau * v).sin()) * scale)
	Tensor(shape = shape.copy(), values)

# A tensor of numbers drawn evenly from -bound..bound, the same for the same seed: a layer's
# weights as PyTorch's Linear starts them (bound = 1 / sqrt(inputs)).
pub fn randomUniform(shape i64[], seed i64, bound f32) Tensor:
	rng = Random(seed)
	values = []
	loop shapeCount(shape):
		values.push(f32(rng.nextFloat(-1.0, 1.0)) * bound)
	Tensor(shape = shape.copy(), values)

pub fn shapeText(shape i64[]) str:
	"[{shape.map(str(it)).join(", ")}]"

# ---------- moving between the CPU and the GPU ----------

fn gpuValues(t Tensor):
	b = t.storage()
	match t.format:
		F32:
			out = fill(t.count(), f32(0))
			b.download(out)
			out
		F16, BF16:
			words = fill((t.count() + 1) / 2, u32(0))
			b.download(words)
			unpackHalves(words, t.count(), t.format)
		Q8, Q4: t.dequantized()

# both on the CPU or both on the GPU, else the program stops
fn sameSide(a Tensor, b Tensor, what str):
	if a.isOnGpu() != b.isOnGpu():
		fail("tensor: {what} of a tensor on the {a.side()} and one on the {b.side()}")

fn side(t Tensor):
	"GPU" if t.isOnGpu() else "CPU"

fn f32Only(t Tensor, what str):
	if t.format != .F32:
		fail("tensor: {what} of a tensor stored as {t.format}: only linear reads it")

# the handle a kernel names a GPU tensor's numbers by
fn handle(t Tensor):
	t.storage().handle

# the buffer of a GPU tensor's numbers
fn storage(t Tensor) ref gpu.Buffer:
	match t.buffer:
		b: b
		none: fail("tensor: not on the GPU")

# the buffer of a GPU tensor's blocks' scales
fn scaleStorage(t Tensor) ref gpu.Buffer:
	match t.scales:
		s: s
		none: fail("tensor: a {t.format} tensor without scales")

# a GPU tensor of this shape, its numbers to be written
fn gpuOut(shape i64[]):
	Tensor(shape = shape.copy(), buffer = gpu.newBuffer(shapeCount(shape) * 4))

# The groups of 64 that cover n invocations, as x by y (a dimension holds 65535 at most); the
# invocation's index is globalId.y * (x * 64) + globalId.x.
fn spread(n i64):
	groups = (n + 63) / 64
	if groups <= 65_535: return (groups.max(1), 1)
	(65_535, (groups + 65_534) / 65_535)
