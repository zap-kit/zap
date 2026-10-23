# Optimisers: a model's tensors changed by their gradients. A model is a Tensor or any struct
# holding tensors (in fields, lists, nested structs): the compiler writes `Learnable`'s functions
# for each (spec 5.4), and the model's gradient, of the same struct, is walked alongside.
#
#   mut adam = tensor.Optimiser(method = .Adam, rate = 0.001)
#   loss, g = grad(lossOf)(model, batch)
#   adam.step(model, g)

import gpu

# what an optimiser walks: the tensors a value holds, numbered from 0
pub bound Learnable:
	fn tensorCount(self Learnable) i64
	fn tensorAt(self Learnable, k i64) ref Tensor
	fn tensorAtMut(mut self Learnable, k i64) mut ref Tensor

# a tensor is a model of one tensor
pub fn tensorCount(t Tensor) i64:
	1

pub fn tensorAt(t Tensor, k i64) ref Tensor:
	if k != 0: fail("tensor: a tensor holds tensor 0 alone, not {k}")
	t

pub fn tensorAtMut(mut t Tensor, k i64) mut ref Tensor:
	if k != 0: fail("tensor: a tensor holds tensor 0 alone, not {k}")
	mut ref t

# how an optimiser changes a tensor by its gradient
pub type Method:
	Sgd   # stochastic gradient descent, PyTorch's SGD: less rate times the gradient (or the velocity, with momentum)
	Adam   # Adam (Kingma and Ba), PyTorch's; with weightDecay, AdamW's

# An optimiser and what it keeps of each tensor between steps: SGD's velocity (with momentum: its
# last plus the gradient), Adam's running means of the gradient and of its square (m and v,
# corrected for their start at zero: the tensor less rate * m / (sqrt(v) + eps), decayed first by
# rate * weightDecay).
pub type Optimiser:
	method Method
	rate f32
	momentum f32 = 0.0
	beta1 f32 = 0.9
	beta2 f32 = 0.999
	eps f32 = 0.00000001
	weightDecay f32 = 0.0
	steps i64 = 0
	first Tensor[] = []   # SGD's velocity, Adam's m
	second Tensor[] = []   # Adam's v

	# one step: each tensor of the model changed in place by the same one of grads
	pub mut fn step<M Learnable>(mut model M, grads M):
		n = model.tensorCount()
		if first.isEmpty:
			for k in 0..n:
				first.push(grads.tensorAt(k).zerosLike())
				second.push(grads.tensorAt(k).zerosLike())
		steps += 1
		kind = stepAdam if method == .Adam else stepMomentum if momentum != 0.0 else stepSgd
		how = OptimiserStep(
			rate,
			beta1 = momentum if method == .Sgd else beta1,
			beta2 = beta2,
			eps = eps,
			decay = weightDecay,
			firstCorrection = 1.0 - beta1.pow(f32(steps)),
			secondCorrection = 1.0 - beta2.pow(f32(steps)),
			kind = i32(kind)
		)
		for k in 0..n:
			p = model.tensorAtMut(k)
			p.updated(grads.tensorAt(k), first[k], second[k], how)

stepSgd = 0
stepMomentum = 1
stepAdam = 2

# one number p of a tensor, its gradient g and its state a, b: (p, a, b) after the step
pub fn stepped(s OptimiserStep, p f32, g f32, a f32, b f32) (f32, f32, f32):
	if s.kind == 0: return (p - s.rate * g, a, b)
	if s.kind == 1:
		v = s.beta1 * a + g
		return (p - s.rate * v, v, b)
	m = s.beta1 * a + (1.0 - s.beta1) * g
	v = s.beta2 * b + (1.0 - s.beta2) * g * g
	decayed = p - s.rate * s.decay * p
	(decayed - s.rate * (m / s.firstCorrection) / ((v / s.secondCorrection).sqrt() + s.eps), m, v)

# the tensor, and the state tensors a and b, changed in place by a step
fn updated(mut p Tensor, g Tensor, mut a Tensor, mut b Tensor, s OptimiserStep):
	p.sameSide(g, "an optimiser's step")
	n = p.count()
	if g.count() != n:
		fail("tensor: a step of a {shapeText(p.shape)} tensor by a {shapeText(g.shape)} gradient")
	if not p.isOnGpu():
		for i in 0..n:
			x, y, z = s.stepped(p.values[i], g.values[i], a.values[i], b.values[i])
			p.values[i] = x
			if s.kind >= 1:
				a.values[i] = y
			if s.kind == 2:
				b.values[i] = z
		return
	x, y = spread(n)
	params = StepParams(
		p = [],
		g = [],
		a = [],
		b = [],
		count = i32(n),
		stride = i32(x * 64),
		how = s
	)
	gpu.run(compute(stepKernel, 64), params, [p.handle(), g.handle(), a.handle(), b.handle()], x, y)
