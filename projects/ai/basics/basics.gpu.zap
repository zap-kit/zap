# Kernels the tests of std/gpu run: each invocation one element.

pub type Scaled:
	values f32[]
	out f32[]
	factor f32
	count i32

pub fn scale(mut p Scaled):
	i = globalId.x
	if i < p.count:
		p.out[i] = p.values[i] * p.factor
