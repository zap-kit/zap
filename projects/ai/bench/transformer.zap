# The speed of a transformer of characters learning a text on the GPU against PyTorch's
# (gpt.compareWithTorch), and how closely their losses agree.
#   zap run projects/ai/bench/transformer.zap   (from the repository's root)

import fs
import gpt
import gpu

dir = "build/ai/"
_ = fs.createDir(dir)
run = gpt.compareWithTorch(dir) ?? fail("no GPU or no {gpt.textPath}")
print("zap {gpu.deviceName()}: {gpt.steps} steps of {gpt.batch} x {gpt.context} in {run.seconds:.3} s, loss {run.curve[0]:.4} -> {run.curve[gpt.steps - 1]:.4}")
print("zap writes after ROMEO: {run.sample.replace("\n", " / ")}")
if not run.torch.isEmpty:
	print("torch {run.torchDevice}: {run.torchSeconds:.3} s; zap/torch time {run.seconds / run.torchSeconds:.2}; the largest difference of the losses {gpt.farthest(run.curve, run.torch)}")
