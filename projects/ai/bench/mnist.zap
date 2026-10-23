# The speed of an epoch of MNIST on the GPU against PyTorch's (digits.compareWithTorch), and how
# closely their losses agree.
#   zap run projects/ai/bench/mnist.zap   (from the repository's root)

import digits
import fs
import gpu

dir = "build/ai/"
_ = fs.createDir(dir)
run = digits.compareWithTorch(dir) ?? fail("no GPU or no MNIST in {digits.dataDir}")
print("zap {gpu.deviceName()}: {digits.steps} steps of {digits.batch} in {run.seconds:.3} s, loss {run.curve[0]:.4} -> {run.curve[digits.steps - 1]:.4}, test accuracy {run.accuracy:.4}")
if not run.torch.isEmpty:
	print("torch {run.torchDevice}: {run.torchSeconds:.3} s, test accuracy {run.torchAccuracy:.4}; zap/torch time {run.seconds / run.torchSeconds:.2}; the largest difference of the losses {digits.farthest(run.curve, run.torch)}")
