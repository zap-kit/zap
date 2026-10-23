# MNIST learned by a network of two layers on the GPU (digits.compareWithTorch): its loss at every
# step of an epoch against PyTorch's from the same weights on the same batches, and its accuracy on
# the test images. Skipped, with a line on stderr, without the data (downloaded into projects/ai/data/mnist),
# the GPU, or Python with PyTorch. Its times are a checked build's: projects/ai/bench/mnist.zap
# measures the speed.

import digits

test "an epoch of MNIST on the GPU follows PyTorch's loss step by step":
	run = digits.compareWithTorch(testDir()) ??
		return eprint("skipped: no GPU or no MNIST in {digits.dataDir}")
	expect run.curve[digits.steps - 1] < 0.5 and run.accuracy > 0.9
	if run.torch.isEmpty:
		eprint("skipped: the comparison, without Python and PyTorch")
		return
	expect run.torch.len == digits.steps and digits.farthest(run.curve, run.torch) < 0.001
	expect (run.accuracy - run.torchAccuracy).abs() < 0.002
