# A compute stage (engine.newKernel, compute(...)) on the backend the environment picks: 1000
# numbers added by groups of 64 on the GPU (sums/: the lanes' sums, the group's memory, a barrier),
# the groups' totals read back. Each total must be the sum of its group's numbers, as the CPU adds
# them.
#   zap run projects/examples/compute/main.zap             (from the repository's root; ZAP_RUN=gpu=d3d12 for Direct3D 12)

import engine
import sums

count = 1000
groups = (count + 63) / 64
values = (0..count).map(f32(it % 17) * 0.5)

mut frames = engine.newFrames()
mut win = engine.openWindow("Compute", 64, 64)
kernel = engine.newKernel(compute(sums.sum, 64))
if not win.nextFrame(frames):
	fail("the window closed")
engine.setParams(
	kernel,
	sums.Sums(values = values.copy(), totals = zeros(groups), count = i32(count))
)
kernel.dispatch(groups)
bytes = kernel.readStorage(1, groups * 4)
mut wrong = 0
for g in 0..groups:
	expected f32 = 0.0
	for i in g * 64..(g * 64 + 64).min(count):
		expected += values[i]
	if (bytes.f32le(g * 4) - expected).abs() > 0.001:
		wrong += 1
print(
	"{engine.backendName()}: {groups} groups' totals, {"right" if wrong == 0 else "{wrong} WRONG"}"
)
if wrong != 0:
	exit(1)
