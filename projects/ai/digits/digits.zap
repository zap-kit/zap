# MNIST's handwritten digits (LeCun, Cortes and Burges: 60000 to train on, 10000 to test, 28 by 28
# grey pixels each) read from their gzip files, and a network of two layers that tells them.
# The files are downloaded data, not trusted: each is checked against the format's sizes.

import deflate
import fs
import gpu
import tensor

# the folder the files are downloaded into, outside the repositories
pub dataDir = "projects/ai/data/mnist"

# a data set's images, a row of 784 numbers 0..1 each, and their digits
pub type Digits:
	images tensor.Tensor
	labels tensor.Tensor
	count i64

# the images and labels of one part ("train" or "t10k"), none when the files are missing
pub fn load(part str) Digits ? str:
	images = try readIdx("{dataDir}/{part}-images-idx3-ubyte.gz", 2051, 3)
	labels = try readIdx("{dataDir}/{part}-labels-idx1-ubyte.gz", 2049, 1)
	n = i64(images.u32be(4))
	if labels.u32be(4) != n or images.u32be(8) != 28 or images.u32be(12) != 28:
		return "the {part} files do not agree"
	if images.len != 16 + n * 784 or labels.len != 8 + n: return "the {part} files are short"
	pixels = images[16..].map(f32(it) / 255.0)
	digits = labels[8..].map(f32(it))
	Digits(
		images = tensor.fromList([n, 784], pixels),
		labels = tensor.fromList([n], digits),
		count = n
	)

# an idx file's bytes, its magic and its dimensions checked
fn readIdx(path str, magic i64, dims i64) u8[] ? str:
	packed = fs.readBytes(path) ?? return "no {path}"
	bytes = try deflate.inflateGzip(packed)
	if bytes.len < 4 + 4 * dims or bytes.u32be(0) != magic: return "{path} is not an idx file"
	bytes

# A network of two layers: 784 pixels, a hidden layer of 128 with ReLU, 10 logits.
pub type Mlp:
	w1 tensor.Tensor
	b1 tensor.Tensor
	w2 tensor.Tensor
	b2 tensor.Tensor

	pub fn gpu() Mlp:
		Mlp(w1 = w1.gpu(), b1 = b1.gpu(), w2 = w2.gpu(), b2 = b2.gpu())

# the weights PyTorch's Linear starts with (uniform in +-1 / sqrt(inputs)), the same for a seed
pub fn newMlp(seed i64) Mlp:
	Mlp(
		w1 = tensor.randomUniform([784, 128], seed, 1.0 / 28.0),
		b1 = tensor.randomUniform([128], seed + 1, 1.0 / 28.0),
		w2 = tensor.randomUniform([128, 10], seed + 2, 0.08838835),
		b2 = tensor.randomUniform([10], seed + 3, 0.08838835)
	)

pub fn logits(m Mlp, x tensor.Tensor) tensor.Tensor:
	(x @ m.w1 + m.b1).relu() @ m.w2 + m.b2

pub fn loss(m Mlp, x tensor.Tensor, labels tensor.Tensor) tensor.Tensor:
	m.logits(x).crossEntropy(labels)

# the share of the images whose largest logit is their digit
pub fn accuracy(m Mlp, d Digits) f32:
	scores = m.logits(d.images).toList()
	digits = d.labels.toList()
	right = 0
	for i in 0..d.count:
		best = 0
		for k in 1..10:
			if scores[i * 10 + k] > scores[i * 10 + best]:
				best = k
		if f32(best) == digits[i]:
			right += 1
	f32(right) / f32(d.count)

# an epoch's sizes: the steps, the images a step, Adam's rate
pub steps = 468
pub batch = 128
pub rate f32 = 0.001

# what a run of an epoch measured, and PyTorch's of the same epoch when it ran
pub type Run:
	curve f32[]
	seconds f64
	accuracy f32
	torch f32[] = []
	torchSeconds f64 = 0.0
	torchAccuracy f32 = 0.0
	torchDevice str = ""

# An epoch on the GPU from the weights of seed 7, a batch after the other, its losses read back
# once it ends; then PyTorch's (projects/ai/reference/mnist.py) from the same weights, when Python
# and torch are there, its files written in dir. None without the data or the GPU.
pub fn compareWithTorch(dir str) Run?:
	if not gpu.available() or not fs.exists("{dataDir}/train-images-idx3-ubyte.gz"): return none
	train = load("train") ?? return none
	test = load("t10k") ?? return none
	start = newMlp(7)
	m = start.gpu()
	images = train.images.gpu()
	labels = train.labels.gpu()
	adam = tensor.Optimiser(method = .Adam, rate = rate)
	losses = []
	began = clockSeconds()
	for k in 0..steps:
		x = images.rows(k * batch, batch)
		y = labels.rows(k * batch, batch)
		loss, g = grad(loss)(m, x, y)
		adam.step(m, g)
		losses.push(loss)
	curve = losses.map(.item())
	seconds = clockSeconds() - began
	accuracy = m.accuracy(
		Digits(images = test.images.gpu(), labels = test.labels.gpu(), count = test.count)
	)
	run = Run(curve, seconds, accuracy)
	if Process.output("python -I -c \"import torch\"").code != 0: return run
	_ = fs.writeBytes("{dir}weights.bin", start.weightBytes())
	script = fs.normalize("projects/ai/reference/mnist.py")
	out = "{dir}torch.txt"
	if Process.run("python -I {script} {dataDir} {dir}weights.bin {steps} {batch} {rate} {out}") !=
		0:
		return run
	lines = (fs.readFile(out) ?? "").lines()
	head = lines[0].split(" ")
	run.torch = lines[1..].filter(not .isEmpty).map(f32.parse(it) ?? 0.0)
	run.torchSeconds = f64.parse(head[1]) ?? 0.0
	run.torchAccuracy = f32.parse(head[2]) ?? 0.0
	run.torchDevice = head[0]
	run

# the weights' numbers in order, as the reference reads them
fn weightBytes(m Mlp):
	out = []
	for t in [m.w1.toList(), m.b1.toList(), m.w2.toList(), m.b2.toList()]:
		out.extend(t.bytes())
	out

# the largest difference of two curves of losses
pub fn farthest(a f32[], b f32[]) f32:
	worst f32 = 0.0
	for k in 0..a.len.min(b.len):
		worst = worst.max((a[k] - b[k]).abs())
	worst
