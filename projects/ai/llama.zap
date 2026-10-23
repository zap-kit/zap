# A Llama of 1.1B parameters (TinyLlama 1.1B Chat, GGUF Q8_0, downloaded into projects/ai/data/llama) run on
# the GPU (llama.compareWithLlamaCpp): its prompt's tokens llama.cpp's (llama-tokenize) and its
# greedy continuation llama.cpp's on the same GPU (llama-completion with Vulkan). Skipped, with a
# line on stderr, without the file, the GPU or llama.cpp. projects/ai/bench/llama.zap measures the
# speed.

import llama

test "TinyLlama on the GPU gives llama.cpp's tokens for the same prompt":
	run = llama.compareWithLlamaCpp(testDir()) ??
		return eprint("skipped: no GPU or no {llama.modelPath}")
	expect run.tokens == [1, 450, 7483, 310, 3444, 338] and run.made.tokens.len == llama.count
	if run.cppText.isEmpty:
		eprint("skipped: the comparison, without llama.cpp")
		return
	expect run.cppTokens == str(run.tokens)
	expect run.cppText == run.text.trimmedEnd()
