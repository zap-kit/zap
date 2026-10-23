# The kernels of conv.zap, an invocation per number they give, in the CPU's order of terms.

pub type ConvParams:
	x f32[]   # the image (the input's gradient: dy)
	w f32[]   # the kernels (the weights' gradient: dy)
	out f32[]
	n i32
	c i32
	h i32
	wd i32
	o i32
	kh i32
	kw i32
	oh i32
	ow i32
	step i32
	padding i32
	count i32
	stride i32

pub fn convKernel(mut p ConvParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		ox = i % p.ow
		oy = i / p.ow % p.oh
		o = i / (p.ow * p.oh) % p.o
		n = i / (p.ow * p.oh * p.o)
		sum = 0.0
		for c in 0..p.c:
			for ky in 0..p.kh:
				iy = oy * p.step - p.padding + ky
				if iy >= 0 and iy < p.h:
					for kx in 0..p.kw:
						ix = ox * p.step - p.padding + kx
						if ix >= 0 and ix < p.wd:
							sum += p.x[((n * p.c + c) * p.h + iy) * p.wd + ix] *
								p.w[((o * p.c + c) * p.kh + ky) * p.kw + kx]
		p.out[i] = sum

pub fn convInputGradKernel(mut p ConvParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		ix = i % p.wd
		iy = i / p.wd % p.h
		c = i / (p.wd * p.h) % p.c
		n = i / (p.wd * p.h * p.c)
		sum = 0.0
		for o in 0..p.o:
			for ky in 0..p.kh:
				ty = iy + p.padding - ky
				if ty >= 0 and ty % p.step == 0 and ty / p.step < p.oh:
					for kx in 0..p.kw:
						tx = ix + p.padding - kx
						if tx >= 0 and tx % p.step == 0 and tx / p.step < p.ow:
							sum += p.x[((n * p.o + o) * p.oh + ty / p.step) * p.ow + tx / p.step] *
								p.w[((o * p.c + c) * p.kh + ky) * p.kw + kx]
		p.out[i] = sum

pub fn convWeightGradKernel(mut p ConvParams):
	i = globalId.y * p.stride + globalId.x
	if i < p.count:
		kx = i % p.kw
		ky = i / p.kw % p.kh
		c = i / (p.kw * p.kh) % p.c
		o = i / (p.kw * p.kh * p.c)
		sum = 0.0
		for n in 0..p.n:
			for oy in 0..p.oh:
				iy = oy * p.step - p.padding + ky
				if iy >= 0 and iy < p.h:
					for ox in 0..p.ow:
						ix = ox * p.step - p.padding + kx
						if ix >= 0 and ix < p.wd:
							sum += p.x[((n * p.c + c) * p.h + iy) * p.wd + ix] *
								p.w[((n * p.o + o) * p.oh + oy) * p.ow + ox]
		p.out[i] = sum
