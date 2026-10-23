# A small transformer of characters learning a text on the GPU (tiny Shakespeare, downloaded into
# projects/ai/data/text; gpt.compareWithTorch): its loss at every step against PyTorch's from the same
# weights on the same windows of the text. Skipped, with a line on stderr, without the text, the
# GPU, or Python with PyTorch. projects/ai/bench/transformer.zap measures the speed.

import gpt

test "a transformer learns a text on the GPU, its loss PyTorch's step by step":
	run = gpt.compareWithTorch(testDir()) ?? return eprint("skipped: no GPU or no {gpt.textPath}")
	expect run.curve[gpt.steps - 1] < run.curve[0] - 1.0
	if run.torch.isEmpty:
		eprint("skipped: the comparison, without Python and PyTorch")
		return
	expect run.torch.len == gpt.steps and gpt.farthest(run.curve, run.torch) < 0.001
