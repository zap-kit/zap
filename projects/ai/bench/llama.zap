# The speed of TinyLlama on the GPU against llama.cpp's on the same GPU
# (llama.compareWithLlamaCpp), and whether they write the same.
#   zap run projects/ai/bench/llama.zap   (from the repository's root)

import fs
import gpu
import llama

dir = "build/ai/"
_ = fs.createDir(dir)
run = llama.compareWithLlamaCpp(dir) ?? fail("no GPU or no {llama.modelPath}")
made = run.made
print("zap {gpu.deviceName()}: loaded in {run.loadSeconds:.2} s; the prompt's {run.tokens.len} tokens at {run.tokens.len / made.promptSeconds:.1} tokens/s, then {made.tokens.len - 1} at {(made.tokens.len - 1) / made.seconds:.1} tokens/s")
print("zap writes: {run.text.replace("\n", " / ")}")
if not run.cppText.isEmpty:
	print("llama.cpp Vulkan0: the prompt at {run.cppPromptSpeed:.1} tokens/s, then {run.cppSpeed:.1} tokens/s; the same tokens: {run.cppTokens == str(run.tokens)}, the same text: {run.cppText == run.text.trimmedEnd()}")
