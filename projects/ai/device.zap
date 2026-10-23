# std/gpu: kernels run on the machine's GPU, without a window (skipped where there is none).

import gpu
import basics

test "a kernel scales a buffer's numbers into another":
	if not gpu.available():
		print("skipped: {gpu.unavailableReason()}")
		return
	n = 1000
	xs = (0..n).map(f32(it) * 0.5)
	values = gpu.newBuffer(n * 4)
	out = gpu.newBuffer(n * 4)
	values.upload(xs)
	gpu.run(
		compute(basics.scale, 64),
		basics.Scaled(values = [], out = [], factor = 3.0, count = i32(n)),
		[values.handle, out.handle],
		(n + 63) / 64
	)
	got = fill(n, f32(0))
	out.download(got)
	wrong = 0
	for i in 0..n:
		if got[i] != xs[i] * 3.0: wrong += 1
	print("{wrong} wrong of {n}, {got[999]}")
	prints "0 wrong of 1000, 1498.5"

# a buffer's handle, the buffer let go
fn letGo(bytes i64):
	b = gpu.newBuffer(bytes)
	b.handle

test "the lanes' sums, the group's memory and a barrier; a buffer copied, zeroed and handed out again":
	if not gpu.available():
		print("skipped: {gpu.unavailableReason()}")
		return
	n = 1000
	groups = (n + 63) / 64
	xs = (0..n).map(f32(it % 17) * 0.5)
	values = gpu.newBuffer(n * 4)
	values.upload(xs)
	again = values.copy()
	totals = gpu.zeroBuffer(groups * 4)
	gpu.run(
		compute(basics.sum, 64),
		basics.Sums(values = [], totals = [], count = i32(n)),
		[again.handle, totals.handle],
		groups
	)
	got = fill(groups, f32(0))
	totals.download(got)
	wrong = 0
	for g in 0..groups:
		expected = 0.0
		for i in g * 64..(g * 64 + 64).min(n):
			expected += xs[i]
		if (got[g] - expected).abs() > 0.001: wrong += 1
	print("{wrong} wrong of {groups}")
	handle = letGo(n * 4)
	gpu.finish()
	reused = gpu.newBuffer(n * 4)
	print(reused.handle == handle)
	prints """
		0 wrong of 16
		true
		"""
