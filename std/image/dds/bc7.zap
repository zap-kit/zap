# BC7 blocks (16 bytes, 8 modes), decoded as Direct3D 11 defines them: the mode is the number of
# zero bits before the first one; then, by mode, the partition, a rotation, an index selector, the
# endpoints (all reds, all greens, all blues, all alphas), the p-bits and the indices, each
# subset's anchor texel with one bit less. The tables a mode is made of are the lists below, one
# entry a mode.

import image

modeSubsets = [3, 2, 3, 2, 1, 1, 1, 2]
partitionBits = [4, 6, 6, 6, 0, 0, 0, 6]
colorBits = [4, 6, 5, 7, 5, 7, 7, 5]
alphaBits = [0, 0, 0, 0, 6, 8, 7, 5]

# 0 none, 1 one for each endpoint, 2 one for each subset's pair
pbitKind = [1, 2, 0, 1, 0, 0, 1, 1]
indexBits = [3, 3, 2, 2, 2, 2, 4, 2]

# the second index of modes 4 and 5, which have a channel of their own (0 none)
channelIndexBits = [0, 0, 0, 0, 3, 2, 0, 0]
weights2 = [0, 21, 43, 64]
weights3 = [0, 9, 18, 27, 37, 46, 55, 64]
weights4 = [0, 4, 9, 13, 17, 21, 26, 30, 34, 38, 43, 47, 51, 55, 60, 64]

# the next bits of a block, as its four 32-bit words
type Bits:
	words i64[4]
	at i64

fn take(mut b Bits, n i64):
	word = b.at / 32
	shift = b.at % 32
	v = b.words[word] >> shift
	if shift + n > 32 and word < 3: v |= b.words[word + 1] << (32 - shift)
	b.at += n
	v & ((1 << n) - 1)

fn bc7Block(src u8[], at i64, mut px image.Rgba8[16]):
	bits = Bits(
		[
			src.u32le(at),
			src.u32le(at + 4),
			src.u32le(at + 8),
			src.u32le(at + 12)
		],
		0
	)
	mode = 0
	while mode < 8 and bits.take(1) == 0:
		mode += 1
	if mode == 8:
		for i in 0..16:
			px[i] = image.Rgba8(0, 0, 0, 0)
		return
	partition = bits.take(partitionBits[mode])
	rotation = bits.take(2) if mode == 4 or mode == 5 else 0
	selector = bits.take(1) if mode == 4 else 0
	ep i64[24]
	bits.readEndpoints(mode, ep)
	first i64[16]
	second i64[16]
	bits.readIndices(mode, partition, first, 0)
	if channelIndexBits[mode] > 0: bits.readIndices(mode, partition, second, 1)
	for i in 0..16:
		pair = subsetOf(mode, partition, i) * 8
		ci = first[i]
		ai = first[i]
		cbits = indexBits[mode]
		abits = cbits
		if channelIndexBits[mode] > 0 and selector == 0:
			ai = second[i]
			abits = channelIndexBits[mode]
		elif channelIndexBits[mode] > 0:
			ci = second[i]
			cbits = channelIndexBits[mode]
		c i64[4]
		for k in 0..3:
			c[k] = lerp(ep[pair + k], ep[pair + 4 + k], ci, cbits)
		c[3] = lerp(ep[pair + 3], ep[pair + 7], ai, abits)
		if rotation > 0:
			kept = c[3]
			c[3] = c[rotation - 1]
			c[rotation - 1] = kept
		px[i] = image.Rgba8(u8.wrap(c[0]), u8.wrap(c[1]), u8.wrap(c[2]), u8.wrap(c[3]))

# the endpoints of a block, 4 values each (rgba) widened to 8 bits, with their p-bits in
fn readEndpoints(mut bits Bits, mode i64, mut ep i64[24]):
	n = modeSubsets[mode] * 2
	for k in 0..3:
		for e in 0..n:
			ep[e * 4 + k] = bits.take(colorBits[mode])
	for e in 0..n:
		if alphaBits[mode] > 0: ep[e * 4 + 3] = bits.take(alphaBits[mode])
	kind = pbitKind[mode]
	if kind == 1:
		for e in 0..n:
			p = bits.take(1)
			for k in 0..4:
				ep[e * 4 + k] = (ep[e * 4 + k] << 1) | p
	elif kind == 2:
		for pair in 0..n / 2:
			p = bits.take(1)
			for e in pair * 2..pair * 2 + 2:
				for k in 0..4:
					ep[e * 4 + k] = (ep[e * 4 + k] << 1) | p
	extra = 1 if kind > 0 else 0
	for e in 0..n:
		for k in 0..3:
			ep[e * 4 + k] = widen(ep[e * 4 + k], colorBits[mode] + extra)
		ep[e * 4 + 3] = widen(ep[e * 4 + 3], alphaBits[mode] + extra) if alphaBits[mode] > 0
			else 255

# a value of `precision` bits as 8, its high bits repeated into the low ones
fn widen(v i64, precision i64):
	left = v << (8 - precision)
	left | (left >> precision)

# the indices of every texel in raster order: the block's own, or with `channel` 1 the second set
fn readIndices(mut bits Bits, mode i64, partition i64, mut out i64[16], channel i64):
	width = channelIndexBits[mode] if channel == 1 else indexBits[mode]
	for i in 0..16:
		subset = subsetOf(mode, partition, i) if channel == 0 else 0
		anchored = i == anchorOf(mode, partition, subset)
		out[i] = bits.take(width - (1 if anchored else 0))

fn subsetOf(mode i64, partition i64, i i64):
	match modeSubsets[mode]:
		1: 0
		2: i64(partitions2[partition][i]) - 48
		_: i64(partitions3[partition][i]) - 48

fn anchorOf(mode i64, partition i64, subset i64):
	if subset == 0: return 0
	if modeSubsets[mode] == 2: return anchors2[partition]
	anchors3a[partition] if subset == 1 else anchors3b[partition]

fn lerp(e0 i64, e1 i64, index i64, precision i64):
	w = weights4[index]
	if precision == 2: w = weights2[index]
	elif precision == 3: w = weights3[index]
	((64 - w) * e0 + w * e1 + 32) >> 6
