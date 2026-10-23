# What a transformer's inference adds: rotary positions (RoPE), a cache's rows written in place,
# and one position's attention over the cache.

import gpu

# Each head's pairs of numbers (2i, 2i + 1) of row t turned by the angle (first + t) * theta^(-2i
# / d), d the head's width: rotary positions, as llama.cpp's for Llama (x [t, heads * d]).
pub fn rope(x Tensor, heads i64, first i64, theta f32 = 10000.0) Tensor:
	x.f32Only("a rotation")
	width = x.dim(-1)
	d = width / heads
	rows = x.count() / width
	if not x.isOnGpu():
		out = x.values.copy()
		for t in 0..rows:
			for h in 0..heads:
				for i in 0..d / 2:
					at = t * width + h * d + 2 * i
					a, b = turned(out[at], out[at + 1], first + t, i, d, theta)
					out[at] = a
					out[at + 1] = b
		return Tensor(shape = x.shape.copy(), values = out)
	out = gpuOut(x.shape)
	n = rows * width / 2
	gx, gy = spread(n)
	params = RopeParams(
		x = [],
		out = [],
		pairs = i32(n),
		width = i32(width),
		headWidth = i32(d),
		first = i32(first),
		theta,
		stride = i32(gx * 64)
	)
	gpu.run(compute(ropeKernel, 64), params, [x.handle(), out.handle()], gx, gy)
	out

# the pair (a, b) of number 2i of a head of width d at a position, turned (the CPU's and the GPU's)
fn turned(a f32, b f32, position i64, i i64, d i64, theta f32):
	angle = f32(position) * theta.pow(-2.0 * f32(i) / f32(d))
	c = angle.cos()
	s = angle.sin()
	(a * c - b * s, a * s + b * c)

# rows' numbers written into this tensor from row `first` on, in place (a cache of keys)
pub fn writeRows(mut t Tensor, first i64, from Tensor):
	per = t.count() / t.shape[0].max(1)
	if first < 0 or from.count() % per.max(1) != 0 or first * per + from.count() > t.count():
		fail("tensor: a {shapeText(from.shape)} tensor written from row {first} of a {shapeText(t.shape)} one")
	if not t.isOnGpu():
		for i in 0..from.count():
			t.values[first * per + i] = from.values[i]
		return
	from.storage().copyBytes(0, t.storage(), first * per * 4, from.count() * 4)

# The attention of positions first.. (q [rows, heads * d], a row a position) over the rows of keys
# and values [cache rows, kvHeads * d] up to each one's own (causal; each key's head shared by
# heads / kvHeads of q's): each head's softmax of its scores (q . k / sqrt(d)) weighing the values,
# [rows, heads * d]. A prompt's positions at once, or one position's.
pub fn attend(q Tensor, keys Tensor, values Tensor, first i64, heads i64, kvHeads i64) Tensor:
	width = q.dim(-1)
	d = width / heads
	kvWidth = keys.dim(-1)
	rows = q.count() / width
	if first + rows > keys.dim(0):
		fail("tensor: attention of positions {first}..{first + rows} over {keys.dim(0)} rows")
	if not q.isOnGpu():
		out = fill(rows * width, f32(0))
		for r in 0..rows:
			count = first + r + 1
			for h in 0..heads:
				kh = h / (heads / kvHeads)
				logits = []
				for t in 0..count:
					s = 0.0
					for i in 0..d:
						s += q.values[r * width + h * d + i] * keys.values[t * kvWidth + kh * d + i]
					logits.push(s / f32(d).sqrt())
				most = logits.max() ?? 0.0
				weights = logits.map((it - most).exp())
				total = weights.sum()
				for t in 0..count:
					for i in 0..d:
						out[r * width + h * d + i] += weights[t] / total *
							values.values[t * kvWidth + kh * d + i]
		return Tensor(shape = q.shape.copy(), values = out)
	if first + rows > maxAttended:
		fail("tensor: attention over {first + rows} positions, {maxAttended} at most")
	out = gpuOut(q.shape)
	params = AttendParams(
		q = [],
		keys = [],
		values = [],
		out = [],
		first = i32(first),
		width = i32(width),
		headWidth = i32(d),
		kvWidth = i32(kvWidth),
		group = i32(heads / kvHeads)
	)
	gpu.run(
		compute(attendKernel, 64),
		params,
		[q.handle(), keys.handle(), values.handle(), out.handle()],
		heads,
		rows
	)
	out

# the positions a kernel's attention keeps scores of
pub maxAttended = 4096
