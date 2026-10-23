# Convolutions of images: x [n, channels, height, width] by w [outputs, channels, kh, kw], each
# output channel the sum over the input channels of the kernel slid `stride` apart over the image
# padded with `padding` zeros: [n, outputs, oh, ow] (PyTorch's conv2d without a bias).

import gpu

# the sizes a convolution reads and gives
type ConvShape:
	n i64
	c i64
	h i64
	w i64
	o i64
	kh i64
	kw i64
	oh i64
	ow i64
	stride i64
	padding i64

fn convShape(x Tensor, w Tensor, stride i64, padding i64):
	if x.rank() != 4 or w.rank() != 4 or x.dim(1) != w.dim(1):
		fail(
			"tensor: a convolution of a {shapeText(x.shape)} image by {shapeText(w.shape)} kernels"
		)
	h = x.dim(2)
	wd = x.dim(3)
	kh = w.dim(2)
	kw = w.dim(3)
	ConvShape(
		n = x.dim(0),
		c = x.dim(1),
		h,
		w = wd,
		o = w.dim(0),
		kh,
		kw,
		oh = (h + 2 * padding - kh) / stride + 1,
		ow = (wd + 2 * padding - kw) / stride + 1,
		stride,
		padding
	)

fn convParams(s ConvShape, count i64, stride i64):
	ConvParams(
		x = [],
		w = [],
		out = [],
		n = i32(s.n),
		c = i32(s.c),
		h = i32(s.h),
		wd = i32(s.w),
		o = i32(s.o),
		kh = i32(s.kh),
		kw = i32(s.kw),
		oh = i32(s.oh),
		ow = i32(s.ow),
		step = i32(s.stride),
		padding = i32(s.padding),
		count = i32(count),
		stride = i32(stride)
	)

pub fn conv2d(x Tensor, w Tensor, stride i64 = 1, padding i64 = 0) Tensor:
	x.sameSide(w, "a convolution")
	s = x.convShape(w, stride, padding)
	shape = [s.n, s.o, s.oh, s.ow]
	if not x.isOnGpu():
		out = fill(shapeCount(shape), f32(0))
		for i in 0..out.len:
			out[i] = convAt(x.values, w.values, s, i)
		return Tensor(shape, values = out)
	out = gpuOut(shape)
	n = shapeCount(shape)
	gx, gy = spread(n)
	gpu.run(
		compute(convKernel, 64),
		s.convParams(n, gx * 64),
		[x.handle(), w.handle(), out.handle()],
		gx,
		gy
	)
	out

pub fn conv2dGrad(x Tensor, w Tensor, stride i64, padding i64, dy Tensor) (Tensor, Tensor):
	s = x.convShape(w, stride, padding)
	if not x.isOnGpu():
		dx = fill(x.count(), f32(0))
		for i in 0..dx.len:
			dx[i] = convInputGradAt(dy.values, w.values, s, i)
		dw = fill(w.count(), f32(0))
		for i in 0..dw.len:
			dw[i] = convWeightGradAt(x.values, dy.values, s, i)
		return (
			Tensor(shape = x.shape.copy(), values = dx),
			Tensor(shape = w.shape.copy(), values = dw)
		)
	dx = gpuOut(x.shape)
	gx, gy = spread(x.count())
	gpu.run(
		compute(convInputGradKernel, 64),
		s.convParams(x.count(), gx * 64),
		[dy.handle(), w.handle(), dx.handle()],
		gx,
		gy
	)
	dw = gpuOut(w.shape)
	wx, wy = spread(w.count())
	gpu.run(
		compute(convWeightGradKernel, 64),
		s.convParams(w.count(), wx * 64),
		[x.handle(), dy.handle(), dw.handle()],
		wx,
		wy
	)
	(dx, dw)

# output i ((n, o, oy, ox) row-major): the kernel's sum over the image
fn convAt(x f32[], w f32[], s ConvShape, i i64):
	ox = i % s.ow
	oy = i / s.ow % s.oh
	o = i / (s.ow * s.oh) % s.o
	n = i / (s.ow * s.oh * s.o)
	sum = 0.0
	for c in 0..s.c:
		for ky in 0..s.kh:
			iy = oy * s.stride - s.padding + ky
			if iy < 0 or iy >= s.h: continue
			for kx in 0..s.kw:
				ix = ox * s.stride - s.padding + kx
				if ix < 0 or ix >= s.w: continue
				sum += x[((n * s.c + c) * s.h + iy) * s.w + ix] *
					w[((o * s.c + c) * s.kh + ky) * s.kw + kx]
	sum

# the gradient of input i ((n, c, iy, ix)): each output it was read for, times the kernel's number
fn convInputGradAt(dy f32[], w f32[], s ConvShape, i i64):
	ix = i % s.w
	iy = i / s.w % s.h
	c = i / (s.w * s.h) % s.c
	n = i / (s.w * s.h * s.c)
	sum = 0.0
	for o in 0..s.o:
		for ky in 0..s.kh:
			ty = iy + s.padding - ky
			if ty < 0 or ty % s.stride != 0 or ty / s.stride >= s.oh: continue
			for kx in 0..s.kw:
				tx = ix + s.padding - kx
				if tx < 0 or tx % s.stride != 0 or tx / s.stride >= s.ow: continue
				sum += dy[((n * s.o + o) * s.oh + ty / s.stride) * s.ow + tx / s.stride] *
					w[((o * s.c + c) * s.kh + ky) * s.kw + kx]
	sum

# the gradient of kernel number i ((o, c, ky, kx)): over every output, its input times dy
fn convWeightGradAt(x f32[], dy f32[], s ConvShape, i i64):
	kx = i % s.kw
	ky = i / s.kw % s.kh
	c = i / (s.kw * s.kh) % s.c
	o = i / (s.kw * s.kh * s.c)
	sum = 0.0
	for n in 0..s.n:
		for oy in 0..s.oh:
			iy = oy * s.stride - s.padding + ky
			if iy < 0 or iy >= s.h: continue
			for ox in 0..s.ow:
				ix = ox * s.stride - s.padding + kx
				if ix < 0 or ix >= s.w: continue
				sum += x[((n * s.c + c) * s.h + iy) * s.w + ix] *
					dy[((n * s.o + o) * s.oh + oy) * s.ow + ox]
	sum
