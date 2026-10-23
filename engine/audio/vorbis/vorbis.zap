# An Ogg Vorbis decoder, a port of stb_vorbis's pull decoder (public domain, Sean Barrett,
# github.com/nothings/stb): Ogg pages and packets read from the file's bytes (ogg.zap), the three
# header packets (identification, comments skipped, setup: codebooks with their Huffman codes and
# vector lookups, floors of type 1, residues 0, 1 and 2, mappings with channel coupling, modes),
# and each audio packet: floor curves, residue vectors, inverse coupling, the inverse MDCT and the
# windowed overlap with the packet before. Packet by packet, so a song streams from its
# compressed bytes. Floor type 0 (no encoder in use writes it) is refused. The last page's granule
# position trims the final packet, as ffmpeg trims it.
#
# A damaged or hostile file never stops the program (`use noStops`, checked through every call):
# the bits of a packet are read through std's `BitReader`, the bytes of the pages through its
# `Reader`, and every index is proven inside by a check just before it or by a mask on a table of
# a power of two. What a damaged stream breaks ends the stream or leaves a frame silent.

import engine.audio.mdct

# the floor's amplitudes: 256 steps of about 0.47 dB, from the specification
vorbisInverseDb f32[] = [
	0.00000010649863,
	0.00000011341951,
	0.00000012079015,
	0.00000012863978,
	0.00000013699951,
	0.00000014590251,
	0.00000015538408,
	0.00000016548181,
	0.00000017623575,
	0.00000018768855,
	0.00000019988561,
	0.0000002128753,
	0.00000022670913,
	0.00000024144197,
	0.00000025713223,
	0.00000027384213,
	0.00000029163793,
	0.00000031059021,
	0.00000033077411,
	0.00000035226968,
	0.00000037516214,
	0.00000039954229,
	0.0000004255068,
	0.00000045315863,
	0.00000048260743,
	0.00000051396998,
	0.00000054737065,
	0.00000058294187,
	0.00000062082472,
	0.00000066116941,
	0.00000070413592,
	0.00000074989464,
	0.00000079862701,
	0.0000008505263,
	0.00000090579828,
	0.00000096466216,
	0.0000010273513,
	0.0000010941144,
	0.0000011652161,
	0.0000012409384,
	0.0000013215816,
	0.0000014074654,
	0.0000014989305,
	0.0000015963394,
	0.0000017000785,
	0.0000018105592,
	0.0000019282195,
	0.0000020535261,
	0.0000021869758,
	0.0000023290978,
	0.0000024804557,
	0.0000026416497,
	0.000002813319,
	0.0000029961443,
	0.0000031908506,
	0.0000033982101,
	0.0000036190449,
	0.0000038542308,
	0.0000041047004,
	0.000004371447,
	0.0000046555282,
	0.0000049580707,
	0.000005280274,
	0.000005623416,
	0.0000059888572,
	0.0000063780469,
	0.0000067925283,
	0.0000072339451,
	0.0000077040476,
	0.0000082047,
	0.0000087378876,
	0.0000093057248,
	0.0000099104632,
	0.000010554501,
	0.000011240392,
	0.000011970856,
	0.000012748789,
	0.000013577278,
	0.000014459606,
	0.000015399272,
	0.000016400004,
	0.000017465768,
	0.000018600792,
	0.000019809576,
	0.000021096914,
	0.000022467911,
	0.000023928002,
	0.000025482978,
	0.000027139006,
	0.000028902651,
	0.000030780908,
	0.000032781225,
	0.000034911534,
	0.000037180282,
	0.000039596466,
	0.000042169667,
	0.00004491009,
	0.000047828601,
	0.000050936773,
	0.000054246931,
	0.000057772202,
	0.000061526565,
	0.000065524908,
	0.000069783085,
	0.000074317983,
	0.000079147585,
	0.00008429104,
	0.000089768747,
	0.000095602426,
	0.00010181521,
	0.00010843174,
	0.00011547824,
	0.00012298267,
	0.00013097477,
	0.00013948625,
	0.00014855085,
	0.00015820453,
	0.00016848555,
	0.00017943469,
	0.00019109536,
	0.00020351382,
	0.00021673929,
	0.00023082423,
	0.00024582449,
	0.00026179955,
	0.00027881276,
	0.00029693158,
	0.00031622787,
	0.00033677814,
	0.00035866388,
	0.00038197188,
	0.00040679456,
	0.00043323036,
	0.00046138411,
	0.00049136745,
	0.00052329927,
	0.00055730621,
	0.00059352311,
	0.00063209358,
	0.00067317058,
	0.000716917,
	0.0007635063,
	0.00081312324,
	0.00086596457,
	0.00092223983,
	0.00098217216,
	0.0010459992,
	0.0011139742,
	0.0011863665,
	0.0012634633,
	0.0013455702,
	0.0014330129,
	0.0015261382,
	0.0016253153,
	0.0017309374,
	0.0018434235,
	0.0019632195,
	0.0020908006,
	0.0022266726,
	0.0023713743,
	0.0025254795,
	0.0026895994,
	0.0028643847,
	0.0030505286,
	0.0032487691,
	0.0034598925,
	0.0036847358,
	0.0039241906,
	0.0041792066,
	0.004450795,
	0.0047400328,
	0.0050480668,
	0.0053761186,
	0.0057254891,
	0.0060975636,
	0.0064938176,
	0.0069158225,
	0.0073652516,
	0.0078438871,
	0.0083536271,
	0.0088964928,
	0.009474637,
	0.010090352,
	0.01074608,
	0.011444421,
	0.012188144,
	0.012980198,
	0.013823725,
	0.014722068,
	0.015678791,
	0.016697687,
	0.017782797,
	0.018938423,
	0.020169149,
	0.021479854,
	0.022875735,
	0.02436233,
	0.025945531,
	0.027631618,
	0.029427276,
	0.031339626,
	0.033376252,
	0.035545228,
	0.037855157,
	0.040315199,
	0.042935108,
	0.045725273,
	0.048696758,
	0.051861348,
	0.055231591,
	0.05882085,
	0.062643361,
	0.066714279,
	0.071049749,
	0.075666962,
	0.080584227,
	0.085821044,
	0.091398179,
	0.097337747,
	0.1036633,
	0.11039993,
	0.11757434,
	0.12521498,
	0.13335215,
	0.14201813, 0.15124727, 0.16107617, 0.1715438, 0.18269168, 0.19456402, 0.20720788, 0.22067342,
	0.23501402, 0.25028656, 0.26655159, 0.28387361, 0.30232132, 0.32196786, 0.34289114, 0.36517414,
	0.38890521, 0.41417847, 0.44109412, 0.4697589, 0.50028648, 0.53279791, 0.56742212, 0.6042964,
	0.64356699, 0.68538959, 0.72993007, 0.77736504, 0.8278826, 0.88168307, 0.9389798, 1.0
]

vorbisNoCode = 255
fastHuffmanBits = 10

# a count or an offset kept inside 0..=2^30, so that a sum or a product of two never overflows
type Count = i64 in 0..=1_073_741_824

fn count(x i64) Count:
	x.clamp(0, 1_073_741_824)

# a number that may be negative, kept inside -2^30..=2^30 for the same reason
type Signed = i64 in -1_073_741_824..=1_073_741_824

fn signed(x i64) Signed:
	x.clamp(-1_073_741_824, 1_073_741_824)

# a sample position: far more samples than a song holds
type Position = i64 in -1_099_511_627_776..=1_099_511_627_776

fn position(x i64) Position:
	x.clamp(-1_099_511_627_776, 1_099_511_627_776)

# the bits a number takes
type Bits = i64 in 0..=64

# an unsigned field of up to 30 bits
fn read(mut br BitReader, n i64) Count:
	count(br.take(n))

# a codebook: the codes of its entries and the vectors they stand for
type Codebook:
	dimensions Count = 0
	entries Count = 0
	lengths u8[] = []   # per entry, vorbisNoCode where it has no code
	fast i64[1024] = fill(1024, -1)   # the entry of each 10 bits that begin a code, else -1
	tree i64[] = [0, 0]   # the longer codes bit by bit: a node's two slots, 0 none, node * 2, entry * 2 + 1
	vectors f32[] = []   # entries * dimensions values, or none when the book has no lookup
	minimum f32 = 0.0
	sequence bool = false

# a floor of type 1: the points the packet moves, and how they are read
type Floor1:
	partitions i64 in 0..=31 = 0
	partitionClass i64[32] = zeros(32)
	classDimensions i64[16] = zeros(16)
	classSubclasses i64[16] = zeros(16)
	classMasterbooks i64[16] = zeros(16)
	subclassBooks i64[128] = zeros(128)
	xList i64[256] = zeros(256)
	sortedOrder i64[256] = zeros(256)
	neighborLow i64[256] = zeros(256)
	neighborHigh i64[256] = zeros(256)
	multiplier i64 in 1..=4 = 1
	rangebits i64 in 0..=15 = 0
	values i64 in 2..=250 = 2

type Residue:
	kind i64 in 0..=2 = 0
	begin Count = 0
	end Count = 0
	partSize Count = 1
	classifications i64 in 1..=64 = 1
	classbook Count = 0
	classdata i64[] = []   # per classbook entry, its classwords classes
	books i64[] = []   # per classification, 8 passes: a codebook or -1

type Mapping:
	couplingSteps i64 in 0..=16 = 0
	magnitude i64[16] = zeros(16)
	angle i64[16] = zeros(16)
	mux i64[16] = zeros(16)
	submaps i64 in 1..=16 = 1
	submapFloor i64[16] = zeros(16)
	submapResidue i64[16] = zeros(16)

type Mode:
	blockflag i64
	mapping Count

# the points of a channel's floor, -1 where unused
type Curve:
	y i64[256] = zeros(256)

# a block size: 2^6 to 2^13
type Block = i64 in 64..=8192

# A Vorbis stream in an Ogg file, decoded packet by packet.
pub type Stream:
	bytes u8[]
	pages Pages = Pages()
	resume Pages = Pages()   # where the first audio packet begins
	failed bool = false
	channels i64 in 1..=16 = 1
	sampleRate i64 = 0
	blocksize0 Block = 64
	blocksize1 Block = 64
	codebooks Codebook[] = []
	floors Floor1[] = []
	residues Residue[] = []
	mappings Mapping[] = []
	modes Mode[] = []
	channelBuffers f32[,] = []
	previousWindow f32[,] = []
	finalY Curve[] = []
	mdcts mdct.Mdct[] = []   # of blocksize0 and blocksize1
	windows f32[,] = []
	scratch f32[] = []
	firstDecode bool = true
	previousLength Count = 0
	currentLoc Position = 0
	currentLocValid bool = false
	discardSamplesDeferred Position = 0

# whether the bytes begin as an Ogg file
pub fn isOggVorbis(b ref u8[]) bool:
	use noStops
	b.len >= 36 and b.startsWith("OggS") and b.matchesAt(29, "vorb")

# ---------- small helpers ----------

fn bitReverse32(x i64):
	use noStops
	n = x & 0xFFFF_FFFF
	n = (n & 0xAAAA_AAAA) >> 1 | (n & 0x5555_5555) << 1
	n = (n & 0xCCCC_CCCC) >> 2 | (n & 0x3333_3333) << 2
	n = (n & 0xF0F0_F0F0) >> 4 | (n & 0x0F0F_0F0F) << 4
	n = (n & 0xFF00_FF00) >> 8 | (n & 0x00FF_00FF) << 8
	(n >> 16 | n << 16) & 0xFFFF_FFFF

# the bits needed for n: ilog(0) 0, ilog(1) 1, ilog(4) 3 (the specification's ilog)
fn ilog(n i64) Bits:
	use noStops
	v = n
	bits = 0
	loop 64:
		if v <= 0: break
		bits += 1
		v >>= 1
	bits.clamp(0, 64)

# the specification's packed float: 21 bits of mantissa, a sign, an exponent biased by 788
fn float32Unpack(x i64):
	use noStops
	mantissa = x & 0x1F_FFFF
	sign = x & 0x8000_0000
	e = (x & 0x7FE0_0000) >> 21
	v = mantissa * 2.0.pow(e - 788)
	f32(-v if sign != 0 else v)

# the values per dimension of a lookup-1 codebook: the largest r with r^dim <= entries
fn lookup1Values(entries Count, dim Count):
	use noStops
	if dim <= 0 or entries <= 0: return -1
	lo = 1
	hi = entries + 1
	loop 32:
		low = count(lo)
		high = count(hi)
		if high - low <= 1: break
		mid = (low + high) >> 1
		if powAtMost(mid, dim, entries):
			lo = mid
		else:
			hi = mid
	lo

# whether base^exp <= limit (without overflowing)
fn powAtMost(base Count, exp Count, limit Count):
	use noStops
	v = 1
	loop exp:
		v = count(v) * base
		if v > limit: return false
	true

# ---------- codebooks ----------

# the entry the next code of the book stands for: -1 at the end of the packet, -2 for a code the
# book has none of
fn decodeEntry(c Codebook, mut br BitReader) i64:
	use noStops
	look = br.peek(32)
	i = c.fast[look & 1023]
	if i >= 0 and i < c.lengths.len:
		br.skip(c.lengths[i])
		return -1 if br.short else i
	c.searchTree(look, br)

# the entry of a code longer than the fast table holds, walked bit by bit
fn searchTree(c Codebook, look Taken, mut br BitReader):
	use noStops
	node = 0
	for b in 0..32:
		slot = count(node) * 2 + ((look >> b) & 1)
		if slot >= c.tree.len: return -2
		next = c.tree[slot]
		if next <= 0: return -2
		if (next & 1) == 1:
			br.skip(b + 1)
			return -1 if br.short else count(next) >> 1
		node = count(next) >> 1
	-2

# the book's next entry, -1 at the end of the packet; a code the book has none of, or a book
# without vectors, ends the stream
fn decodeStart(mut f Stream, mut br BitReader, book Count):
	use noStops
	if book >= f.codebooks.len: return -1
	if f.codebooks[book].vectors.isEmpty:
		f.failed = true
		return -1
	z = f.codebooks[book].decodeEntry(br)
	if z == -2:
		f.failed = true
		return -1
	z

# the book's next entry as a symbol, -1 at the end of the packet
fn decodeSymbol(mut f Stream, mut br BitReader, book Count):
	use noStops
	if book >= f.codebooks.len: return -1
	z = f.codebooks[book].decodeEntry(br)
	if z == -2:
		f.failed = true
		return -1
	z

# adds a vector of the book to target[offset ..] (at most len0 values): false when the packet ends
fn codebookDecode(
	mut f Stream,
	mut br BitReader,
	book Count,
	mut target f32[],
	offset0 i64,
	len0 i64
):
	use noStops
	z0 = f.decodeStart(br, book)
	if z0 < 0 or book >= f.codebooks.len: return false
	c = f.codebooks[book]
	offset = count(offset0)
	length = count(len0).min(c.dimensions)
	z = count(z0) * c.dimensions
	last = f32(0.0)
	for i in 0..length:
		zi = z + i
		at = offset + i
		if zi >= c.vectors.len or at >= target.len: return false
		val = c.vectors[zi] + last
		target[at] += val
		if c.sequence:
			last = val + c.minimum
	true

# adds a vector of the book to target[offset], target[offset + step], ...
fn codebookDecodeStep(
	mut f Stream,
	mut br BitReader,
	book Count,
	mut target f32[],
	offset0 i64,
	len0 i64,
	step0 i64
):
	use noStops
	z0 = f.decodeStart(br, book)
	if z0 < 0 or book >= f.codebooks.len: return false
	c = f.codebooks[book]
	offset = count(offset0)
	step = count(step0)
	length = count(len0).min(c.dimensions)
	z = count(z0) * c.dimensions
	last = f32(0.0)
	for i in 0..length:
		zi = z + i
		if zi >= c.vectors.len: return false
		val = c.vectors[zi] + last
		at = offset + i * step
		if at < target.len:
			target[at] += val
		if c.sequence:
			last = val
	true
