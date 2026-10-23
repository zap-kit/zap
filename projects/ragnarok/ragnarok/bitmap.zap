# The textures of the client's maps and models: Windows bitmaps (BMP: 8 bits through a palette,
# 24 or 32 bits, rows from the bottom unless the height is negative) and Targa images (TGA:
# 24 or 32 bits, plain or run-length coded, rows from the bottom unless the descriptor says
# otherwise). Both become RGBA rows from the top. The client draws a BMP's magenta (near
# 255, 0, 255) as see-through: keyMagenta does that.

import image

# the image a BMP file holds, or why it cannot be read
pub fn decodeBmp(d u8[]) image.Image ? str:
	if d.len < 54 or not d.startsWith("BM"): return "not a BMP file"
	dataAt = i64(d.i32le(10))
	headerSize = i64(d.i32le(14))
	width = i64(d.i32le(18))
	rawHeight = d.i32le(22)
	bits = i64(d.u16le(28))
	compression = d.i32le(30)
	if compression != 0 and compression != 3: return "a compressed BMP ({compression})"
	height = rawHeight.abs()
	topDown = rawHeight < 0
	if width <= 0 or height <= 0 or width > 8192 or height > 8192:
		return "a BMP of {width} x {height}"
	colors = d.i32le(46)
	if colors == 0:
		colors = 256
	paletteAt = 14 + headerSize
	stride = (width * bits + 31) / 32 * 4
	if dataAt + stride * height > d.len: return "the BMP's pixels run past the end"
	out = image.Image(width, height, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..out.height:
		row = dataAt + (y if topDown else height - 1 - y) * stride
		for x in 0..out.width:
			if bits == 8:
				p = paletteAt + i64(d[row + x]) * 4
				out[x, y] = image.Rgba8(d[p + 2], d[p + 1], d[p], 255) if p + 3 <= d.len
					else image.Rgba8(0, 0, 0, 255)
			elif bits == 24 or bits == 32:
				p = row + x * (bits / 8)
				out[x, y] = image.Rgba8(d[p + 2], d[p + 1], d[p], 255)
			else:
				return "a BMP of {bits} bits a pixel"
	out

# the image a TGA file holds, or why it cannot be read
pub fn decodeTga(d u8[]) image.Image ? str:
	if d.len < 18: return "not a TGA file"
	idLength = i64(d[0])
	kind = i64(d[2])
	width = i64(d.u16le(12))
	height = i64(d.u16le(14))
	bits = i64(d[16])
	topDown = (d[17] & 32) != 0
	if (kind != 2 and kind != 10) or (bits != 24 and bits != 32):
		return "a TGA of kind {kind} with {bits} bits a pixel"
	size = bits / 8
	out = image.Image(width, height, fill = image.Rgba8(0, 0, 0, 0))
	at = 18 + idLength + i64(d.u16le(5)) * ((i64(d[7]) + 7) / 8)
	k = 0
	n = width * height
	while k < n:
		count = 1
		repeated = false
		if kind == 10:
			if at >= d.len: return "the TGA's pixels run past the end"
			head = i64(d[at])
			at += 1
			count = (head & 127) + 1
			repeated = head >= 128
		for i in 0..count:
			if k >= n: break
			p = at if repeated else at + i * size
			if p + size > d.len: return "the TGA's pixels run past the end"
			x = k % width
			y = k / width if topDown else height - 1 - k / width
			out[x, y] = image.Rgba8(d[p + 2], d[p + 1], d[p], d[p + 3] if size == 4 else 255)
			k += 1
		at += size if repeated else count * size
	out

# the client's see-through color made see-through: near-magenta pixels get alpha 0 and black
# (so smoothing does not bleed magenta into their neighbours)
pub fn keyMagenta(mut img image.Image):
	for i in 0..img.cells.len:
		p = img.cells[i]
		if p.r > 230 and p.g < 20 and p.b > 230:
			img.cells[i] = image.Rgba8(0, 0, 0, 0)

# whether some pixel is neither opaque nor see-through (the image is to be blended)
pub fn isPartlyTransparent(img image.Image) bool:
	for i in 0..img.width * img.height:
		a = img.cells[i].a
		if a > 0 and a < 255: return true
	false
