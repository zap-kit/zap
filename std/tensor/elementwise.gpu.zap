# The kernels of elementwise.zap: an invocation a number, at globalId.y * stride + globalId.x.

pub type BinaryParams:
	a f32[]
	b f32[]
	out f32[]
	count i32
	aCount i32   # a repeats every aCount numbers (its shape a suffix of the result's)
	bCount i32
	op i32
	stride i32

pub fn binaryKernel(mut p BinaryParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		p.out[i] = combine(p.a[i % p.aCount], p.b[i % p.bCount], p.op)

pub type ColumnsParams:
	values f32[]
	out f32[]
	rows i32
	cols i32
	stride i32

# a column's sum, its rows in order
pub fn columnSumsKernel(mut p ColumnsParams):
	c = globalId.y * p.stride + globalId.x
	if c < p.cols:
		s = 0.0
		for r in 0..p.rows:
			s += p.values[r * p.cols + c]
		p.out[c] = s

pub type ByNumberParams:
	values f32[]
	out f32[]
	count i32
	k f32
	how i32
	stride i32

pub fn byNumberKernel(mut p ByNumberParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		p.out[i] = withNumber(p.values[i], p.k, p.how)

pub type UnaryParams:
	values f32[]
	out f32[]
	count i32
	op i32
	stride i32

pub fn unaryKernel(mut p UnaryParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		p.out[i] = activation(p.values[i], p.op)

pub type UnaryGradParams:
	values f32[]
	dy f32[]
	out f32[]
	count i32
	op i32
	stride i32

pub fn unaryGradKernel(mut p UnaryGradParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		p.out[i] = p.dy[i] * slope(p.values[i], p.op)
