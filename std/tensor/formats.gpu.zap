# The products of formats past f32 (products.zap's packedProduct): a row of weights per set of
# lanes that run together (64 / laneCount rows a group), each lane reading every laneCount-th
# word of the row (the lanes' reads side by side), their sums added across the lanes.
pub type PackedParams:
	x f32[]   # the inputs; for blocks, each block of 32 as integers (quantizeKernel)
	words u32[]   # the weights' halves or blocks, a row per output
	scales f32[]   # a block's scale (Q8, Q4)
	xScales f32[]   # for blocks: each input block's scale
	out f32[]
	n i32
	k i32
	bfloat i32   # halves: 1 bf16, 0 f16

# a number stored as halves: an f16's or a bf16's
fn halfOf(h u32, bfloat i32) f32:
	bfloatValue(h) if bfloat == 1 else halfValue(h)

# the output row of this invocation's lanes
fn productRow() i32:
	groupId.x * (64 / laneCount) + localIndex / laneCount

pub fn halvesProductKernel(mut p PackedParams):
	row = productRow()
	t = groupId.y
	if row < p.n:
		words = p.k / 2
		base = row * words
		xb = t * p.k
		s = 0.0
		w = lane
		while w < words:
			word = p.words[base + w]
			s += halfOf(word & 0xFFFF, p.bfloat) * p.x[xb + 2 * w] +
				halfOf(word >> 16, p.bfloat) * p.x[xb + 2 * w + 1]
			w += laneCount
		total = s.laneSum()
		if lane == 0:
			p.out[t * p.n + row] = total

# byte e (0..3) of a word as a signed number
fn signedByte(word u32, e i32) f32:
	b = (word >> u32(8 * e)) & 0xFF
	f32(b) - 256.0 if b >= 128 else f32(b)

# a word of a row's Q8 blocks: 4 of a block's 32 integers
pub fn q8ProductKernel(mut p PackedParams):
	row = productRow()
	t = groupId.y
	if row < p.n:
		words = p.k / 4
		blocks = p.k / 32
		xb = t * p.k
		s = 0.0
		w = lane
		while w < words:
			word = p.words[row * words + w]
			b = w / 8
			at = xb + 4 * w
			d = signedByte(word, 0) * p.x[at] + signedByte(word, 1) * p.x[at + 1] +
				signedByte(word, 2) * p.x[at + 2] + signedByte(word, 3) * p.x[at + 3]
			s += d * (p.scales[row * blocks + b] * p.xScales[t * blocks + b])
			w += laneCount
		total = s.laneSum()
		if lane == 0:
			p.out[t * p.n + row] = total

# a word of a row's Q4 blocks: bytes 4j..4j + 3 of a block, numbers 4j..4j + 3 in their low
# nibbles and those 16 after in their high ones
pub fn q4ProductKernel(mut p PackedParams):
	row = productRow()
	t = groupId.y
	if row < p.n:
		words = p.k / 8
		blocks = p.k / 32
		xb = t * p.k
		s = 0.0
		w = lane
		while w < words:
			word = p.words[row * words + w]
			b = w / 4
			at = xb + b * 32 + (w % 4) * 4
			d = 0.0
			for e in 0..4:
				byte = (word >> u32(8 * e)) & 0xFF
				d += (f32(byte & 15) - 8.0) * p.x[at + e] +
					(f32(byte >> 4) - 8.0) * p.x[at + e + 16]
			s += d * (p.scales[row * blocks + b] * p.xScales[t * blocks + b])
			w += laneCount
		total = s.laneSum()
		if lane == 0:
			p.out[t * p.n + row] = total

pub type QuantizeParams:
	x f32[]
	q f32[]
	scales f32[]
	blocks i32
	stride i32

# Each block of 32 inputs as GGUF's Q8_0 holds it, as llama.cpp quantizes a layer's inputs for
# its blocks of weights: its largest magnitude over 127 the scale (kept as an f16), each number
# over it rounded; an invocation per block.
pub fn quantizeKernel(mut p QuantizeParams):
	b = globalId.y * p.stride + globalId.x
	if b < p.blocks:
		most = 0.0
		for j in 0..32:
			most = most.max(p.x[b * 32 + j].abs())
		d = most / 127.0
		inverse = 1.0 / d if d != 0.0 else 0.0
		for j in 0..32:
			p.q[b * 32 + j] = (p.x[b * 32 + j] * inverse).round()
		p.scales[b] = halfValue(halfBits(d))
