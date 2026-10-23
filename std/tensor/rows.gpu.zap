# The kernels of rows.zap: a group of 64 invocations per row (row groupId.y * 65535 +
# groupId.x), each reading the row's numbers 64 apart.

pub type RowsParams:
	x f32[]
	y f32[]   # a second input: softmax's derivative's dy, cross-entropy's labels
	out f32[]
	rows i32
	cols i32
	causal i32 = 0

fn rowIndex() i32:
	groupId.y * 65535 + groupId.x

# the columns of row r a causal softmax reads (all of them otherwise)
fn seen(r i32, cols i32, causal i32) i32:
	r % cols + 1 if causal == 1 else cols

pub fn softmaxKernel(mut p RowsParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		limit = seen(r, p.cols, p.causal)
		most = -3.0e38
		c = localIndex
		while c < limit:
			most = most.max(p.x[base + c])
			c += 64
		most = groupMax(most)
		s = 0.0
		c = localIndex
		while c < limit:
			s += (p.x[base + c] - most).exp()
			c += 64
		s = groupTotal(s)
		c = localIndex
		while c < p.cols:
			p.out[base + c] = (p.x[base + c] - most).exp() / s if c < limit else 0.0
			c += 64

# x holds the softmax's numbers, y the gradient of its result
pub fn softmaxGradKernel(mut p RowsParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		dot = 0.0
		c = localIndex
		while c < p.cols:
			dot += p.x[base + c] * p.y[base + c]
			c += 64
		dot = groupTotal(dot)
		c = localIndex
		while c < p.cols:
			p.out[base + c] = p.x[base + c] * (p.y[base + c] - dot)
			c += 64

# each row's loss: x the logits, y the labels
pub fn crossEntropyKernel(mut p RowsParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		most = -3.0e38
		c = localIndex
		while c < p.cols:
			most = most.max(p.x[base + c])
			c += 64
		most = groupMax(most)
		s = 0.0
		c = localIndex
		while c < p.cols:
			s += (p.x[base + c] - most).exp()
			c += 64
		s = groupTotal(s)
		if localIndex == 0:
			p.out[r] = s.ln() + most - p.x[base + i32(p.y[r])]

pub type LossGradParams:
	logits f32[]
	labels f32[]
	dy f32[]
	out f32[]
	rows i32
	cols i32

pub fn crossEntropyGradKernel(mut p LossGradParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		most = -3.0e38
		c = localIndex
		while c < p.cols:
			most = most.max(p.logits[base + c])
			c += 64
		most = groupMax(most)
		s = 0.0
		c = localIndex
		while c < p.cols:
			s += (p.logits[base + c] - most).exp()
			c += 64
		s = groupTotal(s)
		k = p.dy[0] / f32(p.rows)
		label = i32(p.labels[r])
		c = localIndex
		while c < p.cols:
			hit = 1.0 if c == label else 0.0
			p.out[base + c] = ((p.logits[base + c] - most).exp() / s - hit) * k
			c += 64

pub type NormParams:
	x f32[]
	gain f32[]
	bias f32[]
	dy f32[]
	out f32[]   # the result, or the derivative of x
	products f32[]   # dy times the normalised number, summed over the rows for the gain's gradient
	rows i32
	cols i32
	eps f32
	centered i32   # 1 a layer norm (less the mean, plus the bias), 0 an RMS norm

# row r's mean (0 unless centered) and the inverse of its deviation, every invocation given them
fn moments(p NormParams, base i32) (f32, f32):
	mean = 0.0
	if p.centered == 1:
		s = 0.0
		c = localIndex
		while c < p.cols:
			s += p.x[base + c]
			c += 64
		mean = groupTotal(s) / f32(p.cols)
	v = 0.0
	c = localIndex
	while c < p.cols:
		d = p.x[base + c] - mean
		v += d * d
		c += 64
	(mean, 1.0 / (groupTotal(v) / f32(p.cols) + p.eps).sqrt())

pub fn normKernel(mut p NormParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		mean, inverse = moments(p, base)
		c = localIndex
		while c < p.cols:
			shift = p.bias[c] if p.centered == 1 else 0.0
			p.out[base + c] = (p.x[base + c] - mean) * inverse * p.gain[c] + shift
			c += 64

pub fn normGradKernel(mut p NormParams):
	r = rowIndex()
	if r < p.rows:
		base = r * p.cols
		mean, inverse = moments(p, base)
		sumG = 0.0
		sumGX = 0.0
		c = localIndex
		while c < p.cols:
			g = p.dy[base + c] * p.gain[c]
			sumG += g
			sumGX += g * (p.x[base + c] - mean) * inverse
			c += 64
		n = f32(p.cols)
		sumG = groupTotal(sumG) / n
		sumGX = groupTotal(sumGX) / n
		c = localIndex
		while c < p.cols:
			xhat = (p.x[base + c] - mean) * inverse
			g = p.dy[base + c] * p.gain[c]
			p.out[base + c] = inverse * (g - (sumG if p.centered == 1 else 0.0) - xhat * sumGX)
			p.products[base + c] = p.dy[base + c] * xhat
			c += 64

pub type SumParams:
	values f32[]
	out f32[]
	count i32

# one group adds every number
pub fn sumKernel(mut p SumParams):
	s = 0.0
	i = localIndex
	while i < p.count:
		s += p.values[i]
		i += 64
	total = groupTotal(s)
	if localIndex == 0:
		p.out[0] = total

pub type PickParams:
	table f32[]
	ids f32[]
	out f32[]
	count i32   # the ids
	cols i32
	rows i32   # the table's
	stride i32

pub fn embeddingKernel(mut p PickParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count * p.cols:
		t = i / p.cols
		p.out[i] = p.table[i32(p.ids[t]) * p.cols + i % p.cols]

# table holds dy; out the table's gradient, an invocation per number
pub fn embeddingGradKernel(mut p PickParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.rows * p.cols:
		row = f32(i / p.cols)
		c = i % p.cols
		s = 0.0
		for t in 0..p.count:
			if p.ids[t] == row:
				s += p.table[t * p.cols + c]
		p.out[i] = s
