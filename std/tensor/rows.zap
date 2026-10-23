# Operations along the last dimension, a row at a time: softmax (causal over square blocks:
# attention's mask), the normalisations, cross-entropy; sums and means of every number; a table's
# rows picked by ids (an embedding).

import gpu

rowsLimit = 65_535

# the groups a kernel of a group per row runs in, as x by y (row groupId.y * 65535 + groupId.x)
fn rowGroups(rows i64):
	if rows <= rowsLimit: return (rows.max(1), 1)
	(rowsLimit, (rows + rowsLimit - 1) / rowsLimit)

fn rowsOf(t Tensor):
	t.count() / t.dim(-1)

# the numbers of row r of a CPU tensor of rows of `cols`
fn rowAt(t Tensor, r i64, cols i64) ref f32[]:
	t.values[r * cols..(r + 1) * cols]

# The exponentials of each row's numbers over their sum. Causal, a row's numbers past its place in
# its square block (row i of a [.., t, t] tensor: columns after i) count as -infinity: each
# position sees itself and those before it.
pub fn softmax(x Tensor, causal bool = false) Tensor:
	x.f32Only("a softmax")
	cols = x.dim(-1)
	rows = x.rowsOf()
	if not x.isOnGpu():
		out f32[] = []
		out.reserve(x.count())
		for r in 0..rows:
			row = x.rowAt(r, cols)
			limit = r % cols + 1 if causal else cols
			most = row[0]
			for c in 0..limit:
				most = most.max(row[c])
			s = 0.0
			for c in 0..limit:
				s += (row[c] - most).exp()
			for c in 0..cols:
				out.push((row[c] - most).exp() / s if c < limit else 0.0)
		return Tensor(shape = x.shape.copy(), values = out)
	out = gpuOut(x.shape)
	gx, gy = rowGroups(rows)
	params = RowsParams(
		x = [],
		y = [],
		out = [],
		rows = i32(rows),
		cols = i32(cols),
		causal = 1 if causal else 0
	)
	gpu.run(compute(softmaxKernel, 64), params, [x.handle(), x.handle(), out.handle()], gx, gy)
	out

pub fn softmaxGrad(x Tensor, causal bool, dy Tensor) Tensor:
	y = x.softmax(causal)
	cols = x.dim(-1)
	rows = x.rowsOf()
	if not x.isOnGpu():
		out f32[] = []
		out.reserve(x.count())
		for r in 0..rows:
			dot = 0.0
			for c in 0..cols:
				dot += y.values[r * cols + c] * dy.values[r * cols + c]
			for c in 0..cols:
				out.push(y.values[r * cols + c] * (dy.values[r * cols + c] - dot))
		return Tensor(shape = x.shape.copy(), values = out)
	out = gpuOut(x.shape)
	gx, gy = rowGroups(rows)
	params = RowsParams(x = [], y = [], out = [], rows = i32(rows), cols = i32(cols))
	gpu.run(compute(softmaxGradKernel, 64), params, [y.handle(), dy.handle(), out.handle()], gx, gy)
	out

# The mean over the rows of logits [rows, classes] of cross-entropy against each row's class
# (labels [rows], the classes' numbers): -ln(softmax(row)[label]). A tensor of one number.
pub fn crossEntropy(logits Tensor, labels Tensor) Tensor:
	logits.sameSide(labels, "a cross-entropy")
	cols = logits.dim(-1)
	rows = logits.rowsOf()
	if labels.count() != rows:
		fail("tensor: {labels.count()} labels for {rows} rows of logits")
	if not logits.isOnGpu():
		total = 0.0
		for r in 0..rows:
			row = logits.rowAt(r, cols)
			most = row[0]
			for v in row:
				most = most.max(v)
			s = 0.0
			for v in row:
				s += (v - most).exp()
			total += f64(s.ln() + most - row[i64(labels.values[r])])
		return scalar(f32(total / rows))
	losses = gpuOut([rows])
	gx, gy = rowGroups(rows)
	params = RowsParams(x = [], y = [], out = [], rows = i32(rows), cols = i32(cols))
	gpu.run(
		compute(crossEntropyKernel, 64),
		params,
		[logits.handle(), labels.handle(), losses.handle()],
		gx,
		gy
	)
	losses.mean()

pub fn crossEntropyGrad(logits Tensor, labels Tensor, dy Tensor) Tensor:
	cols = logits.dim(-1)
	rows = logits.rowsOf()
	if not logits.isOnGpu():
		p = logits.softmax()
		k = dy.values[0] / f32(rows)
		values = (0..logits.count()).map(
			(p.values[it] - (1.0 if i64(labels.values[it / cols]) == it % cols else 0.0)) * k
		)
		return Tensor(shape = logits.shape.copy(), values)
	out = gpuOut(logits.shape)
	gx, gy = rowGroups(rows)
	params = LossGradParams(
		logits = [],
		labels = [],
		dy = [],
		out = [],
		rows = i32(rows),
		cols = i32(cols)
	)
	gpu.run(
		compute(crossEntropyGradKernel, 64),
		params,
		[logits.handle(), labels.handle(), dy.handle(), out.handle()],
		gx,
		gy
	)
	out

# ---------- normalisations ----------

# Each row less its mean, over its deviation (the square root of its variance plus eps), times
# gain and plus bias ([cols] each): PyTorch's LayerNorm.
pub fn layerNorm(x Tensor, gain Tensor, bias Tensor, eps f32 = 0.00001) Tensor:
	x.normed(gain, bias, eps, true)

# each row over the square root of its numbers' mean square plus eps, times gain: RMSNorm (Llama's)
pub fn rmsNorm(x Tensor, gain Tensor, eps f32 = 0.000001) Tensor:
	x.normed(gain, gain, eps, false)

pub fn layerNormGrad(
	x Tensor,
	gain Tensor,
	bias Tensor,
	eps f32,
	dy Tensor
) (Tensor, Tensor, Tensor):
	dx, dgain = x.normedGrad(gain, eps, true, dy)
	(dx, dgain, dy.sumTo(bias.shape))

pub fn rmsNormGrad(x Tensor, gain Tensor, eps f32, dy Tensor) (Tensor, Tensor):
	x.normedGrad(gain, eps, false, dy)

# a row's mean (0 unless centered) and the inverse of its deviation
fn rowMoments(row f32[], eps f32, centered bool):
	n = f32(row.len)
	mean = 0.0
	if centered:
		for v in row:
			mean += v
		mean /= n
	s = 0.0
	for v in row:
		s += (v - mean) * (v - mean)
	(mean, 1.0 / (s / n + eps).sqrt())

fn normed(x Tensor, gain Tensor, bias Tensor, eps f32, centered bool):
	x.sameSide(gain, "a normalisation")
	cols = x.dim(-1)
	rows = x.rowsOf()
	if gain.count() != cols:
		fail("tensor: a gain of {gain.count()} for rows of {cols}")
	if not x.isOnGpu():
		out f32[] = []
		out.reserve(x.count())
		for r in 0..rows:
			row = x.rowAt(r, cols)
			mean, inverse = rowMoments(row, eps, centered)
			for c in 0..cols:
				out.push(
					(row[c] - mean) * inverse * gain.values[c] +
						(bias.values[c] if centered else 0.0)
				)
		return Tensor(shape = x.shape.copy(), values = out)
	out = gpuOut(x.shape)
	gx, gy = rowGroups(rows)
	params = NormParams(
		x = [],
		gain = [],
		bias = [],
		dy = [],
		out = [],
		products = [],
		rows = i32(rows),
		cols = i32(cols),
		eps,
		centered = 1 if centered else 0
	)
	gpu.run(
		compute(normKernel, 64),
		params,
		[x.handle(), gain.handle(), bias.handle(), x.handle(), out.handle(), out.handle()],
		gx,
		gy
	)
	out

# the derivatives of a normalisation: dx, and dgain (the sums over the rows of dy times the
# normalised numbers)
fn normedGrad(x Tensor, gain Tensor, eps f32, centered bool, dy Tensor):
	cols = x.dim(-1)
	rows = x.rowsOf()
	if not x.isOnGpu():
		dx = []
		scaled = []
		for r in 0..rows:
			row = x.rowAt(r, cols)
			mean, inverse = rowMoments(row, eps, centered)
			sumG = 0.0
			sumGX = 0.0
			for c in 0..cols:
				g = dy.values[r * cols + c] * gain.values[c]
				sumG += g
				sumGX += g * (row[c] - mean) * inverse
			n = f32(cols)
			for c in 0..cols:
				xhat = (row[c] - mean) * inverse
				g = dy.values[r * cols + c] * gain.values[c]
				dx.push(inverse * (g - (sumG / n if centered else 0.0) - xhat * sumGX / n))
				scaled.push(dy.values[r * cols + c] * xhat)
		products = Tensor(shape = x.shape.copy(), values = scaled)
		return (Tensor(shape = x.shape.copy(), values = dx), products.sumTo(gain.shape))
	dx = gpuOut(x.shape)
	products = gpuOut(x.shape)
	gx, gy = rowGroups(rows)
	params = NormParams(
		x = [],
		gain = [],
		bias = [],
		dy = [],
		out = [],
		products = [],
		rows = i32(rows),
		cols = i32(cols),
		eps,
		centered = 1 if centered else 0
	)
	gpu.run(
		compute(normGradKernel, 64),
		params,
		[x.handle(), gain.handle(), gain.handle(), dy.handle(), dx.handle(), products.handle()],
		gx,
		gy
	)
	(dx, products.sumTo(gain.shape))

# ---------- sums ----------

# the sum of every number: a tensor of one number
pub fn sum(x Tensor) Tensor:
	x.f32Only("a sum")
	if not x.isOnGpu():
		s = 0.0
		for v in x.values:
			s += f64(v)
		return scalar(f32(s))
	out = gpuOut([])
	gpu.run(
		compute(sumKernel, 64),
		SumParams(values = [], out = [], count = i32(x.count())),
		[x.handle(), out.handle()],
		1
	)
	out

pub fn sumGrad(x Tensor, dy Tensor) Tensor:
	x.zerosLike() + dy

# the mean of every number: a tensor of one number
pub fn mean(x Tensor) Tensor:
	x.sum().scaled(1.0 / f32(x.count()))

pub fn meanGrad(x Tensor, dy Tensor) Tensor:
	x.zerosLike() + dy.scaled(1.0 / f32(x.count()))

# ---------- a table's rows ----------

# The rows of table [n, d] that ids name (a tensor of the rows' numbers, of any shape): a tensor
# of ids' shape and d.
pub fn embedding(table Tensor, ids Tensor) Tensor:
	table.sameSide(ids, "an embedding")
	d = table.dim(-1)
	shape = ids.shape.copy()
	shape.push(d)
	n = ids.count()
	if not table.isOnGpu():
		out f32[] = []
		out.reserve(n * d)
		for t in 0..n:
			out.extend(table.rowAt(i64(ids.values[t]), d))
		return Tensor(shape, values = out)
	out = gpuOut(shape)
	x, y = spread(n * d)
	params = PickParams(
		table = [],
		ids = [],
		out = [],
		count = i32(n),
		cols = i32(d),
		rows = i32(table.dim(0)),
		stride = i32(x * 64)
	)
	gpu.run(
		compute(embeddingKernel, 64),
		params,
		[table.handle(), ids.handle(), out.handle()],
		x,
		y
	)
	out

# the table's gradient: each row the sum of the gradients of the places that picked it
pub fn embeddingGrad(table Tensor, ids Tensor, dy Tensor) Tensor:
	d = table.dim(-1)
	n = ids.count()
	if not table.isOnGpu():
		out = fill(table.count(), f32(0))
		for t in 0..n:
			row = i64(ids.values[t])
			for c in 0..d:
				out[row * d + c] += dy.values[t * d + c]
		return Tensor(shape = table.shape.copy(), values = out)
	out = gpuOut(table.shape)
	x, y = spread(table.count())
	params = PickParams(
		table = [],
		ids = [],
		out = [],
		count = i32(n),
		cols = i32(d),
		rows = i32(table.dim(0)),
		stride = i32(x * 64)
	)
	gpu.run(
		compute(embeddingGradKernel, 64),
		params,
		[dy.handle(), ids.handle(), out.handle()],
		x,
		y
	)
	out
