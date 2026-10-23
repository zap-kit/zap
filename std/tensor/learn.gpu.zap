# The kernel of learn.zap: an invocation per number of the tensor, changed in place with its state.

# what one step of an optimiser does to a number (the CPU's and the GPU's)
pub type OptimiserStep:
	rate f32
	beta1 f32 = 0.0
	beta2 f32 = 0.0
	eps f32 = 0.0
	decay f32 = 0.0
	firstCorrection f32 = 1.0
	secondCorrection f32 = 1.0
	kind i32

pub type StepParams:
	p f32[]
	g f32[]
	a f32[]
	b f32[]
	count i32
	stride i32
	how OptimiserStep

pub fn stepKernel(mut p StepParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		x, y, z = p.how.stepped(p.p[i], p.g[i], p.a[i], p.b[i])
		p.p[i] = x
		if p.how.kind >= 1:
			p.a[i] = y
		if p.how.kind == 2:
			p.b[i] = z
