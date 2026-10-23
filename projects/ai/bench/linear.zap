# The speed of a Q8 linear layer on the GPU at the shapes of TinyLlama's (one row times a matrix:
# the bandwidth it reaches) and of an rmsNorm, for the inference's profile.
#   zap run projects/ai/bench/linear.zap   (from the repository's root)

import tensor
import gpu
for (n, k) in [(2048, 2048), (5632, 2048), (2048, 5632), (32_000, 2048)]:
	w = tensor.randomNormal([n, k], seed = 1, scale = 0.02).gpu(.Q8)
	x = tensor.randomNormal([1, k], seed = 2).gpu()
	x.linear(w).toList()
	a = clockSeconds()
	loop 200:
		x.linear(w)
	gpu.finish()
	s = clockSeconds() - a
	bytes = (n * k) * 34.0 / 32.0
	print("{n}x{k}: {s * 5.0:.3} ms, {bytes * 200.0 / s / 1e9:.1} GB/s")
x = tensor.randomNormal([1, 2048], seed = 2).gpu()
g = tensor.full([2048], 1.0).gpu()
a = clockSeconds()
loop 1000:
	x.rmsNorm(g)
gpu.finish()
print("rmsNorm {(clockSeconds() - a):.3} ms each")
