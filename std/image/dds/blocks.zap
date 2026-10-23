# The levels of a DDS decoded to pixels: BC1 to BC5 here (a color block of two 5:6:5 endpoints and
# 2-bit indices, an alpha or single-channel block of two endpoints and 3-bit indices), BC7 in
# bc7.zap, and the 8-bit formats as they are. Colors come out as stored, sRGB or not.

import image

# the level as an image; BC4 fills red, green and blue with its channel, BC5 puts its two
# channels in red and green (a normal map's x and y) and 255 in blue and alpha
pub fn decodeLevel(d Dds, level i64) image.Image:
	width = levelDim(d.width, level)
	height = levelDim(d.height, level)
	src = d.levelBytes(level)
	img = image.Image(width, height, fill = image.Rgba8(0, 0, 0, 255))
	if not d.format.isBlock():
		for y in 0..height:
			for x in 0..width:
				img[x, y] = d.format.rawPixel(src, (y * width + x) * 4)
		return img
	size = d.format.blockBytes()
	px image.Rgba8[16]
	for by in 0..(height + 3) / 4:
		for bx in 0..(width + 3) / 4:
			d.format.decodeBlock(src, (by * ((width + 3) / 4) + bx) * size, px)
			for i in 0..16:
				x = bx * 4 + (i & 3)
				y = by * 4 + (i >> 2)
				if x < width and y < height: img[x, y] = px[i]
	img

fn rawPixel(f Format, src u8[], at i64):
	if f == .Bgra8: return image.Rgba8(src[at + 2], src[at + 1], src[at], src[at + 3])
	image.Rgba8(src[at], src[at + 1], src[at + 2], src[at + 3])

# the 16 pixels of the block at `at`, row after row
fn decodeBlock(f Format, src u8[], at i64, mut px image.Rgba8[16]):
	match f:
		Bc1: colorBlock(src, at, px, false)
		Bc2: explicitAlphaBlock(src, at, px)
		Bc3: gradientAlphaBlock(src, at, px)
		Bc4: singleChannelBlock(src, at, px)
		Bc5: twoChannelBlock(src, at, px)
		Bc7: bc7Block(src, at, px)
		_: fail("not a block format")

fn explicitAlphaBlock(src u8[], at i64, mut px image.Rgba8[16]):
	colorBlock(src, at + 8, px, true)
	for i in 0..16:
		px[i].a = u8.wrap(((i64(src[at + i / 2]) >> ((i & 1) * 4)) & 15) * 17)

fn gradientAlphaBlock(src u8[], at i64, mut px image.Rgba8[16]):
	colorBlock(src, at + 8, px, true)
	alpha i64[16]
	channelBlock(src, at, alpha)
	for i in 0..16:
		px[i].a = u8.wrap(alpha[i])

fn singleChannelBlock(src u8[], at i64, mut px image.Rgba8[16]):
	value i64[16]
	channelBlock(src, at, value)
	for i in 0..16:
		v = u8.wrap(value[i])
		px[i] = image.Rgba8(v, v, v, 255)

fn twoChannelBlock(src u8[], at i64, mut px image.Rgba8[16]):
	xs i64[16]
	ys i64[16]
	channelBlock(src, at, xs)
	channelBlock(src, at + 8, ys)
	for i in 0..16:
		px[i] = image.Rgba8(u8.wrap(xs[i]), u8.wrap(ys[i]), 255, 255)

# a 5:6:5 color widened to 8 bits a channel, the high bits repeated into the low ones
fn expand565(c i64):
	r = (c >> 11) & 31
	g = (c >> 5) & 63
	b = c & 31
	image.Rgba8((r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2), 255)

fn mix(a u8, b u8, wa i64, wb i64, total i64) u8:
	u8.wrap((a * wa + b * wb) / total)

# A BC1 color block: two endpoints and a 2-bit index a texel. Endpoint 0 above endpoint 1 (or
# `opaque`, as BC2 and BC3 have it) gives four colors, else the middle and a transparent black.
fn colorBlock(src u8[], at i64, mut px image.Rgba8[16], opaque bool):
	c0 = i64(src.u16le(at))
	c1 = i64(src.u16le(at + 2))
	e0 = expand565(c0)
	e1 = expand565(c1)
	pal image.Rgba8[4]
	pal[0] = e0
	pal[1] = e1
	if c0 > c1 or opaque:
		pal[2] = image.Rgba8(
			mix(e0.r, e1.r, 2, 1, 3),
			mix(e0.g, e1.g, 2, 1, 3),
			mix(e0.b, e1.b, 2, 1, 3),
			255
		)
		pal[3] = image.Rgba8(
			mix(e0.r, e1.r, 1, 2, 3),
			mix(e0.g, e1.g, 1, 2, 3),
			mix(e0.b, e1.b, 1, 2, 3),
			255
		)
	else:
		pal[2] = image.Rgba8(
			mix(e0.r, e1.r, 1, 1, 2),
			mix(e0.g, e1.g, 1, 1, 2),
			mix(e0.b, e1.b, 1, 1, 2),
			255
		)
		pal[3] = image.Rgba8(0, 0, 0, 0)
	indices = i64(src.u32le(at + 4))
	for i in 0..16:
		px[i] = pal[(indices >> (i * 2)) & 3]

# A single-channel block (BC4, a BC3 alpha, one of BC5's): endpoints a0 and a1 and a 3-bit index
# a texel; a0 above a1 gives six values between them, else four, then 0 and 255.
fn channelBlock(src u8[], at i64, mut out i64[16]):
	a0 = i64(src[at])
	a1 = i64(src[at + 1])
	pal i64[8]
	pal[0] = a0
	pal[1] = a1
	if a0 > a1:
		for k in 1..7:
			pal[k + 1] = ((7 - k) * a0 + k * a1) / 7
	else:
		for k in 1..5:
			pal[k + 1] = ((5 - k) * a0 + k * a1) / 5
		pal[6] = 0
		pal[7] = 255
	indices = src.u32le(at + 2) | (i64(src.u16le(at + 6)) << 32)
	for i in 0..16:
		out[i] = pal[(indices >> (i * 3)) & 7]
