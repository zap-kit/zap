# The kernels of attention.zap.

pub type RopeParams:
	x f32[]
	out f32[]
	pairs i32
	width i32
	headWidth i32
	first i32
	theta f32
	stride i32

# an invocation per pair of numbers
pub fn ropeKernel(mut p RopeParams):
	k = globalId.y * p.stride + globalId.x
	if k < p.pairs:
		at = 2 * k
		t = at / p.width
		i = at % p.width % p.headWidth / 2
		a, b = turned(p.x[at], p.x[at + 1], p.first + t, i, p.headWidth, p.theta)
		p.out[at] = a
		p.out[at + 1] = b

pub type AttendParams:
	q f32[]
	keys f32[]
	values f32[]
	out f32[]
	first i32   # the position of q's first row
	width i32   # q's row
	headWidth i32
	kvWidth i32
	group i32   # the heads of q that share one of the keys'

# each position's score of the head
mut scores f32[4096]

# a group per head (x) and row of q (y): its scores over the positions up to its own, their softmax,
# the values weighed
pub fn attendKernel(mut p AttendParams):
	h = groupId.x
	r = groupId.y
	count = p.first + r + 1
	d = p.headWidth
	kh = h / p.group
	qa = r * p.width + h * d
	scale = 1.0 / f32(d).sqrt()
	most = -3.0e38
	t = localIndex
	while t < count:
		s = 0.0
		for i in 0..d:
			s += p.q[qa + i] * p.keys[t * p.kvWidth + kh * d + i]
		scores[t] = s * scale
		most = most.max(s * scale)
		t += 64
	most = groupMax(most)
	total = 0.0
	t = localIndex
	while t < count:
		e = (scores[t] - most).exp()
		scores[t] = e
		total += e
		t += 64
	total = groupTotal(total)
	i = localIndex
	while i < d:
		sum = 0.0
		for u in 0..count:
			sum += scores[u] * p.values[u * p.kvWidth + kh * d + i]
		p.out[qa + i] = sum / total
		i += 64
