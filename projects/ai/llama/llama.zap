# A Llama read from a GGUF file and run on the GPU a token at a time, with a cache of keys and
# values, as llama.cpp runs one: SentencePiece's tokenizer (merged as llama.cpp merges it), RMS
# norms, rotary positions, grouped-query attention, a SwiGLU MLP; the weights kept as the file
# stores them (Q8_0, Q4_0, halves).

import fs
import gguf
import gpu
import tensor

pub type Layer:
	attnNorm tensor.Tensor
	query tensor.Tensor
	key tensor.Tensor
	value tensor.Tensor
	out tensor.Tensor
	ffnNorm tensor.Tensor
	gate tensor.Tensor
	up tensor.Tensor
	down tensor.Tensor

pub type Llama:
	file gguf.File
	vocab Vocab
	width i64
	heads i64
	kvHeads i64
	eps f32
	theta f32
	context i64
	layers Layer[]
	outNorm tensor.Tensor
	output tensor.Tensor
	keys tensor.Tensor[]   # per layer: [context, kvHeads * head width]
	values tensor.Tensor[]

# the model of a GGUF file of a Llama, its cache room for `context` positions
pub fn load(path str, context i64) Llama ? str:
	f = try gguf.open(path)
	if (f.text("general.architecture") ?? "") != "llama": return "{path} is not a Llama"
	width = f.int("llama.embedding_length") ?? return "no llama.embedding_length"
	heads = f.int("llama.attention.head_count") ?? return "no head count"
	kvHeads = f.int("llama.attention.head_count_kv") ?? heads
	count = f.int("llama.block_count") ?? return "no block count"
	layers = []
	keys = []
	values = []
	kvWidth = width / heads * kvHeads
	for l in 0..count:
		b = "blk.{l}."
		layers.push(Layer(
			attnNorm = try f.tensor("{b}attn_norm.weight"),
			query = try f.tensor("{b}attn_q.weight"),
			key = try f.tensor("{b}attn_k.weight"),
			value = try f.tensor("{b}attn_v.weight"),
			out = try f.tensor("{b}attn_output.weight"),
			ffnNorm = try f.tensor("{b}ffn_norm.weight"),
			gate = try f.tensor("{b}ffn_gate.weight"),
			up = try f.tensor("{b}ffn_up.weight"),
			down = try f.tensor("{b}ffn_down.weight")))
		keys.push(tensor.zeros([context, kvWidth]).gpu())
		values.push(tensor.zeros([context, kvWidth]).gpu())
	outNorm = try f.tensor("output_norm.weight")
	output = try f.tensor("output.weight")
	vocab = try f.readVocab()
	eps = f32(f.number("llama.attention.layer_norm_rms_epsilon") ?? 0.00001)
	theta = f32(f.number("llama.rope.freq_base") ?? 10000.0)
	Llama(
		file = f,
		vocab,
		width,
		heads,
		kvHeads,
		eps,
		theta,
		context,
		layers,
		outNorm,
		output,
		keys,
		values
	)

# The logits [1, vocabulary] of the token after `tokens`, the first at position `at`, their keys
# and values kept in the cache: a prompt's tokens at once, each attending to those before it.
pub fn step(mut m Llama, tokens i64[], at i64) tensor.Tensor:
	n = tokens.len
	if at + n > m.context: fail("llama: positions {at}..{at + n} past the cache's {m.context}")
	rows = []
	for token in tokens:
		rows.extend(m.file.rows("token_embd.weight", token, 1) ?? fail("{error}"))
	x = tensor.fromList([n, m.width], rows).gpu()
	for l in 0..m.layers.len:
		layer = m.layers[l]
		h = x.rmsNorm(layer.attnNorm, m.eps)
		q = h.linear(layer.query).rope(m.heads, at, m.theta)
		k = h.linear(layer.key).rope(m.kvHeads, at, m.theta)
		v = h.linear(layer.value)
		m.keys[l].writeRows(at, k)
		m.values[l].writeRows(at, v)
		attended = q.attend(m.keys[l], m.values[l], at, m.heads, m.kvHeads)
		x += attended.linear(layer.out)
		g = x.rmsNorm(layer.ffnNorm, m.eps)
		x += (g.linear(layer.gate).silu() * g.linear(layer.up)).linear(layer.down)
	x.rows(n - 1, 1).rmsNorm(m.outNorm, m.eps).linear(m.output)

# the index of the largest number (the first of equal ones)
pub fn argmax(xs f32[]) i64:
	best = 0
	for i in 1..xs.len:
		if xs[i] > xs[best]:
			best = i
	best

# what generate gives: the tokens, the seconds the prompt took (to its first token) and those
# the tokens after it took
pub type Generated:
	tokens i64[]
	promptSeconds f64
	seconds f64

# The tokens after the prompt's, each the likeliest (greedy), until n of them or the end of text.
pub fn generate(mut m Llama, prompt i64[], n i64) Generated:
	began = clockSeconds()
	logits = m.step(prompt, 0)
	out = []
	first = 0.0
	loop n:
		next = argmax(logits.toList())
		if out.isEmpty:
			first = clockSeconds()
		if next == m.vocab.eos: break
		out.push(next)
		if out.len < n:
			logits = m.step([next], prompt.len + out.len - 1)
	Generated(tokens = out, promptSeconds = first - began, seconds = clockSeconds() - first)

# ---------- the tokenizer ----------

pub type Vocab:
	tokens str[]
	scores f32[]
	index {str: i64}
	bos i64
	eos i64

fn readVocab(f gguf.File) Vocab ? str:
	tokens = f.texts("tokenizer.ggml.tokens") ?? return "no tokens"
	if (f.text("tokenizer.ggml.model") ?? "") != "llama": return "not SentencePiece's tokenizer"
	given = (f.numbers("tokenizer.ggml.scores") ?? []).map(f32(it))
	scores = given if given.len == tokens.len else fill(tokens.len, f32(0))
	index {str: i64} = {}
	for i, t in tokens:
		index[t.copy()] = i
	Vocab(
		tokens,
		scores,
		index,
		bos = f.int("tokenizer.ggml.bos_token_id") ?? 1,
		eos = f.int("tokenizer.ggml.eos_token_id") ?? 2
	)

# SentencePiece's mark of a space, U+2581
spaceMark = "▁"

# The tokens of text as llama.cpp's SentencePiece tokenizer gives them: a space put before it and
# each space the mark, its characters merged a pair at a time (the pair whose merge is a token of
# the highest score, the leftmost of those), a piece no token holds as its bytes' tokens; the
# beginning of text first.
pub fn tokenize(v Vocab, text str) i64[]:
	marked = " {text}".replace(" ", spaceMark).bytes()
	# the pieces: each a run of the bytes, at first one character
	starts = []
	lengths = []
	i = 0
	while i < marked.len:
		b = marked[i]
		n = 1 if b < 0x80 else 2 if b < 0xE0 else 3 if b < 0xF0 else 4
		starts.push(i)
		lengths.push(n.min(marked.len - i))
		i += n
	loop:
		best = -1
		bestScore = 0.0
		k = 0
		while k + 1 < starts.len:
			s = starts[k]
			joined = str(marked[s..s + lengths[k] + lengths[k + 1]])
			if v.index.get(joined) is id:
				if best < 0 or v.scores[id] > bestScore:
					best = k
					bestScore = v.scores[id]
			k += 1
		if best < 0: break
		lengths[best] += lengths[best + 1]
		starts.remove(best + 1)
		lengths.remove(best + 1)
	out = [v.bos]
	for k, start in starts:
		piece = str(marked[start..start + lengths[k]])
		if v.index.get(piece) is id:
			out.push(id)
		else:
			for b in piece.bytes():
				out.push(v.index.get("<0x{hexByte(b)}>") ?? 0)
	out

# a byte as two hexadecimal digits, upper case
fn hexByte(b u8):
	digits = "0123456789ABCDEF"
	str([digits[i64(b) >> 4], digits[i64(b) & 15]])

# the text of tokens: the mark a space again, a byte's token its byte
pub fn detokenize(v Vocab, ids i64[]) str:
	out = []
	for id in ids:
		t = v.tokens[id]
		if t.len == 6 and t.startsWith("<0x") and t.endsWith(">"):
			out.push(u8(i64.parse("0x{t[3..5]}") ?? 63))
		else:
			out.extend(t.replace(spaceMark, " ").bytes())
	str(move out)

# ---------- the run the test and the benchmark make ----------

pub modelPath = "projects/ai/data/llama/tinyllama-1.1b-chat-v1.0.Q8_0.gguf"
pub prompt = "The capital of France is"
pub count = 32

# what a run measured, and llama.cpp's of the same prompt (llama-tokenize, llama-completion on
# Vulkan0) when it ran
pub type Run:
	tokens i64[]   # the prompt's
	text str   # what came after it
	loadSeconds f64
	made Generated
	cppTokens str = ""   # llama-tokenize's ids of the prompt, as it prints them
	cppText str = ""
	cppPromptSpeed f64 = 0.0   # tokens per second
	cppSpeed f64 = 0.0

# what a command writes on stdout, and on stderr, in dir; none when it fails
fn ran(command str, dir str) (str, str)?:
	out = "{dir}out.txt"
	err = "{dir}err.txt"
	if Process.run(shellLine("{command} > {out} 2> {err}")) != 0: return none
	((fs.readFile(out) ?? "").replace("\r\n", "\n"), (fs.readFile(err) ?? "").replace("\r\n", "\n"))

# the tokens per second llama.cpp's log says a phase ran at ("eval time = ... tokens per second")
fn speedOf(log str, phase str):
	for line in log.lines():
		if "common_perf_print: {phase}" in line:
			at = line.indexOf("(") ?? -1
			parts = line[at + 1..].split(",")
			if parts.len == 2: return f64.parse(parts[1].trimmed().split(" ")[0]) ?? 0.0
	0.0

# TinyLlama run on the GPU for `count` tokens after the prompt (read at once), greedily; then
# llama.cpp's run of the same, when it is there. None without the model or the GPU.
pub fn compareWithLlamaCpp(dir str) Run?:
	if not gpu.available() or not fs.exists(modelPath): return none
	began = clockSeconds()
	m = load(modelPath, 256) ?? return none
	loadSeconds = clockSeconds() - began
	tokens = m.vocab.tokenize(prompt)
	made = m.generate(tokens, count)
	text = m.vocab.detokenize(made.tokens)
	run = Run(tokens, text, loadSeconds, made)
	if ran("llama-tokenize -m {modelPath} -p \"{prompt}\" --ids --log-disable", dir) is (said, _):
		run.cppTokens = said.trimmed().copy()
	if ran("llama-completion -m {modelPath} -p \"{prompt}\" -n {count} --temp 0 -ngl 99 --device Vulkan0 -no-cnv", dir) is (said, log):
		run.cppText = said[" {prompt}".len..].trimmedEnd().copy()
		run.cppPromptSpeed = speedOf(log, "prompt eval time")
		run.cppSpeed = speedOf(log, "       eval time")
	run
