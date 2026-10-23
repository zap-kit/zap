# A small transformer of characters (GPT's form: token and place embeddings, blocks of causal
# self-attention and a GELU MLP, each after a layer norm and added back, a last norm and a head),
# its text a file of characters, each its own token.

import fs
import gpu
import tensor

pub type Block:
	norm1Gain tensor.Tensor
	norm1Bias tensor.Tensor
	query tensor.Tensor
	key tensor.Tensor
	value tensor.Tensor
	out tensor.Tensor
	norm2Gain tensor.Tensor
	norm2Bias tensor.Tensor
	up tensor.Tensor
	upBias tensor.Tensor
	down tensor.Tensor
	downBias tensor.Tensor

pub type Gpt:
	tokens tensor.Tensor   # [vocabulary, width]
	places tensor.Tensor   # [context, width]
	blocks Block[]
	normGain tensor.Tensor
	normBias tensor.Tensor
	head tensor.Tensor   # [width, vocabulary]
	heads i64

# the sizes of a model
pub type Shape:
	vocabulary i64
	context i64
	width i64
	heads i64
	layers i64

# GPT-2's start: weights drawn from a normal of deviation 0.02, biases 0, the norms' gains 1
pub fn newGpt(s Shape, seed i64) Gpt:
	d = s.width
	blocks = []
	for l in 0..s.layers:
		k = seed + 10 * (l + 1)
		blocks.push(Block(
			norm1Gain = tensor.full([d], 1.0),
			norm1Bias = tensor.zeros([d]),
			query = tensor.randomNormal([d, d], k, scale = 0.02),
			key = tensor.randomNormal([d, d], k + 1, scale = 0.02),
			value = tensor.randomNormal([d, d], k + 2, scale = 0.02),
			out = tensor.randomNormal([d, d], k + 3, scale = 0.02),
			norm2Gain = tensor.full([d], 1.0),
			norm2Bias = tensor.zeros([d]),
			up = tensor.randomNormal([d, 4 * d], k + 4, scale = 0.02),
			upBias = tensor.zeros([4 * d]),
			down = tensor.randomNormal([4 * d, d], k + 5, scale = 0.02),
			downBias = tensor.zeros([d])))
	Gpt(
		tokens = tensor.randomNormal([s.vocabulary, d], seed, scale = 0.02),
		places = tensor.randomNormal([s.context, d], seed + 1, scale = 0.02),
		blocks,
		normGain = tensor.full([d], 1.0),
		normBias = tensor.zeros([d]),
		head = tensor.randomNormal([d, s.vocabulary], seed + 2, scale = 0.02),
		heads = s.heads
	)

# x [batch, t, width] as [batch * heads, t, width / heads]: each head's part of each position
fn split(x tensor.Tensor, heads i64):
	b = x.dim(0)
	t = x.dim(1)
	x.reshape([b, t, heads, -1]).swapped(1, 2).reshape([b * heads, t, -1])

# the reverse of split
fn merged(x tensor.Tensor, batch i64):
	t = x.dim(1)
	x.reshape([batch, -1, t, x.dim(2)]).swapped(1, 2).reshape([batch, t, -1])

# one block: causal self-attention, then the MLP, each added to what came in
pub fn block(b Block, x tensor.Tensor, heads i64) tensor.Tensor:
	batch = x.dim(0)
	h = x.layerNorm(b.norm1Gain, b.norm1Bias)
	q = (h @ b.query).split(heads)
	k = (h @ b.key).split(heads)
	v = (h @ b.value).split(heads)
	scale = 1.0 / f32(q.dim(2)).sqrt()
	weights = (q @ k.transposed() * scale).softmax(causal = true)
	attended = x + (weights @ v).merged(batch) @ b.out
	g = attended.layerNorm(b.norm2Gain, b.norm2Bias)
	attended + ((g @ b.up + b.upBias).gelu() @ b.down + b.downBias)

# the logits of each position of ids [batch, t] (the characters' numbers)
pub fn logits(m Gpt, ids tensor.Tensor) tensor.Tensor:
	t = ids.dim(1)
	x = m.tokens.embedding(ids) + m.places.rows(0, t)
	for b in m.blocks:
		x = b.block(x, m.heads)
	x.layerNorm(m.normGain, m.normBias) @ m.head

# the mean cross-entropy of each position's next character (targets [batch, t])
pub fn loss(m Gpt, ids tensor.Tensor, targets tensor.Tensor) tensor.Tensor:
	out = m.logits(ids)
	out.reshape([-1, out.dim(-1)]).crossEntropy(targets.reshape([-1]))

# the model with its tensors on the GPU
pub fn gpu(move m Gpt) Gpt:
	moved = move m
	for k in 0..moved.tensorCount():
		t = moved.tensorAtMut(k)
		t = t.gpu()
	moved

# A text as characters: its alphabet (the bytes it holds, in order) and each byte's number in it.
pub type Text:
	alphabet u8[]
	ids f32[]

pub fn readText(path str) Text ? str:
	bytes = fs.readBytes(path) ?? return "no {path}"
	seen = fill(256, false)
	for b in bytes:
		seen[b] = true
	alphabet = (0..256).filter(seen[it]).map(u8(it))
	index = zeros(256)
	for i, b in alphabet:
		index[b] = i
	Text(alphabet, ids = bytes.map(f32(index[it])))

# a batch of `count` windows of t characters from the given starts, and the characters after each
pub fn batchAt(text Text, starts i64[], t i64) (tensor.Tensor, tensor.Tensor):
	ids = []
	next = []
	for s in starts:
		ids.extend(text.ids[s..s + t])
		next.extend(text.ids[s + 1..s + t + 1])
	(tensor.fromList([starts.len, t], ids), tensor.fromList([starts.len, t], next))

# ---------- the run the tests and the benchmark make ----------

pub textPath = "projects/ai/data/text/tinyshakespeare.txt"
pub steps = 200
pub batch = 16
pub context = 64
pub rate f32 = 0.003

# each batch's windows: their starts, drawn the same for the same seed
fn startsOf(textLength i64, seed i64):
	rng = Random(seed)
	out = []
	loop steps:
		row = []
		loop batch:
			row.push(rng.nextInt(0, textLength - context - 1))
		out.push(row)
	out

# the model's tensors as the reference reads them: their numbers, and a line of each shape
fn writeInputs(m Gpt, starts i64[,], dir str):
	bytes = []
	shapes = []
	for k in 0..m.tensorCount():
		t = m.tensorAt(k)
		bytes.extend(t.toList().bytes())
		shapes.push(t.shape.map(str(it)).join(" "))
	_ = fs.writeBytes("{dir}weights.bin", bytes)
	_ = fs.writeFile("{dir}shapes.txt", "{shapes.join("\n")}\n")
	_ = fs.writeFile("{dir}starts.txt", "{starts.map(.map(str(it)).join(" ")).join("\n")}\n")

# the losses and the seconds of PyTorch's run, none when it cannot run
fn reference(s Shape, dir str) (f32[], f64, str)?:
	if Process.output("python -I -c \"import torch\"").code != 0: return none
	script = fs.normalize("projects/ai/reference/gpt.py")
	out = "{dir}torch.txt"
	if Process.run(
		"python -I {script} {textPath} {dir} {context} {s.heads} {s.layers} {rate} {out}"
	) !=
		0:
		return none
	lines = (fs.readFile(out) ?? "").lines()
	head = lines[0].split(" ")
	(
		lines[1..].filter(not .isEmpty).map(f32.parse(it) ?? 0.0),
		f64.parse(head[1]) ?? 0.0,
		head[0]
	)

# the next n characters after `prompt`, each the likeliest
pub fn generated(m Gpt, text Text, prompt str, n i64) str:
	ids = prompt.bytes().map(f32(text.alphabet.indexOf(it) ?? 0))
	out = []
	loop n:
		window = ids[len - len.min(context)..]
		scores = m.logits(tensor.fromList([1, window.len], window).gpu()).toList()
		v = text.alphabet.len
		last = scores[(window.len - 1) * v..]
		best = 0
		for k in 1..v:
			if last[k] > last[best]:
				best = k
		ids.push(f32(best))
		out.push(text.alphabet[best])
	str(move out)

# what a run measured, and PyTorch's of the same steps when it ran
pub type Run:
	curve f32[]
	seconds f64
	sample str   # what the model writes after "ROMEO:"
	torch f32[] = []
	torchSeconds f64 = 0.0
	torchDevice str = ""

# The model of seed 11 (width 64, 4 heads, 2 layers) learning the text for `steps` steps of
# windows drawn by seed 5, its losses read back once they end; then PyTorch's
# (projects/ai/reference/gpt.py) from the same weights on the same windows, when Python and torch
# are there, its files written in dir. None without the text or the GPU.
pub fn compareWithTorch(dir str) Run?:
	if not gpu.available() or not fs.exists(textPath): return none
	text = readText(textPath) ?? return none
	shape = Shape(
		vocabulary = text.alphabet.len,
		context = context,
		width = 64,
		heads = 4,
		layers = 2
	)
	start = shape.newGpt(11)
	starts = startsOf(text.ids.len, 5)
	start.writeInputs(starts, dir)
	m = gpu(move start)
	adam = tensor.Optimiser(method = .Adam, rate = rate)
	losses = []
	began = clockSeconds()
	for k in 0..steps:
		x, y = text.batchAt(starts[k], context)
		loss, g = grad(loss)(m, x.gpu(), y.gpu())
		adam.step(m, g)
		losses.push(loss)
	curve = losses.map(.item())
	seconds = clockSeconds() - began
	run = Run(curve, seconds, sample = m.generated(text, "ROMEO:", 40))
	if shape.reference(dir) is (torch, torchSeconds, device):
		run.torch = torch
		run.torchSeconds = torchSeconds
		run.torchDevice = device
	run

# the largest difference of two curves of losses
pub fn farthest(a f32[], b f32[]) f32:
	worst f32 = 0.0
	for k in 0..a.len.min(b.len):
		worst = worst.max((a[k] - b[k]).abs())
	worst
