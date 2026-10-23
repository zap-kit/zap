# The pictures of the .DAT files: a head of height, width and flags (bits 12..14 the bits a pixel
# less one, 8..11 how the rows are packed: raw, RLE or LZG, left to right or up to down) and the
# packed bytes; a sprite table's palette resource before its pictures. As SDLPoP (seg009.c
# decompress_rle_lr/ud, decompress_lzg_lr/ud, decode_image, load_sprites_from_file) decodes them.

import dos
import image

# a picture of palette indices, rows from the top
pub type Picture:
	width i64
	height i64
	indices u8[]

	# the picture in colours, index 0 transparent
	pub fn toImage(palette dos.Palette) image.Image:
		dos.paint(indices, none, width, height, palette)

# the pictures of a table (the game's chtab), the palette's resource being the first id and the
# pictures the ids after it; a picture the file leaves empty is none
pub type SpriteTable:
	palette dos.Palette
	pictures Picture?[]

# the 16 VGA colours of a palette resource (n_images, row_bits, n_colors, then vga[16])
pub fn paletteAt(b u8[], at i64) dos.Palette:
	colors image.Rgba8[16]
	for i in 0..16:
		colors[i] = dos.vgaColor(b[at + i * 3], b[at + i * 3 + 1], b[at + i * 3 + 2])
	dos.Palette(colors)

# runs: a count byte n >= 0 copies the n + 1 bytes after it, n < 0 repeats the next byte -n times
fn unpackRle(src u8[], size i64):
	out u8[] = zeros(size)
	s = 0
	d = 0
	while d < size:
		count = i64(i8.wrap(src[s]))
		s += 1
		if count >= 0:
			loop count + 1:
				if d == size: break
				out[d] = src[s]
				d += 1
				s += 1
		else:
			v = src[s]
			s += 1
			loop -count:
				if d == size: break
				out[d] = v
				d += 1
	out

# LZ in a window of 1024 bytes: a mask byte's bits low first, a set bit a literal byte, a clear
# one a big-endian word whose low 10 bits are where in the window and its high 6 the length less 3
fn unpackLzg(src u8[], size i64):
	out u8[] = zeros(size)
	window u8[] = zeros(0x400)
	w = 0x400 - 0x42
	s = 0
	d = 0
	mask = 0
	while d < size:
		mask >>= 1
		if mask & 0xFF00 == 0:
			mask = i64(src[s]) | 0xFF00
			s += 1
		if mask & 1 != 0:
			window[w] = src[s]
			out[d] = src[s]
			w = (w + 1) & 0x3FF
			d += 1
			s += 1
		else:
			info = i64(src[s]) << 8 | src[s + 1]
			s += 2
			from = info & 0x3FF
			loop (info >> 10) + 3:
				if d == size: break
				v = window[from]
				window[w] = v
				out[d] = v
				w = (w + 1) & 0x3FF
				from = (from + 1) & 0x3FF
				d += 1
	out

# bytes unpacked column by column put back in rows of `stride` bytes
fn columnsToRows(stream u8[], stride i64, height i64):
	out u8[] = zeros(stream.len)
	for k, v in stream:
		out[(k % height) * stride + k / height] = v
	out

# one palette index a pixel from rows of `depth` bits a pixel, the leftmost the high bits
fn pixelsOf(packed u8[], width i64, height i64, stride i64, depth i64):
	out u8[] = zeros(width * height)
	perByte = 8 / depth
	mask = (1 << depth) - 1
	for y in 0..height:
		for x in 0..width:
			b = i64(packed[y * stride + x / perByte])
			shift = 8 - depth * (x % perByte + 1)
			out[y * width + x] = u8((b >> shift) & mask)
	out

# the picture a resource holds; none for an empty one (two bytes or fewer, or no rows)
pub fn pictureOf(b u8[]) Picture?:
	if b.len <= 2: return none
	height = i64(b.u16le(0))
	width = i64(b.u16le(2))
	flags = i64(b.u16le(4))
	if height == 0: return none
	depth = ((flags >> 12) & 7) + 1
	method = (flags >> 8) & 15
	stride = (depth * width + 7) / 8
	size = stride * height
	data = b[6..]
	packed = match method:
		0: data[..size.min(len)].copy()
		1: unpackRle(data, size)
		2: unpackRle(data, size).columnsToRows(stride, height)
		3: unpackLzg(data, size)
		4: unpackLzg(data, size).columnsToRows(stride, height)
		_: fail("a picture packed by method {method}")
	if packed.len < size:
		packed.extend(zeros(size - packed.len))
	Picture(width, height, indices = pixelsOf(packed, width, height, stride, depth))

# the table whose palette is resource `first`, its count of pictures the palette's first byte,
# picture i the resource first + 1 + i; each looked for in the files open, the last opened first
pub fn spriteTableOf(dats DatChain, first i64) SpriteTable:
	head = dats.need(first)
	count = i64(head[0])
	pictures = []
	for i in 0..count:
		if dats.resource(first + 1 + i) is b:
			pictures.push(pictureOf(b))
		else:
			pictures.push(none)
	SpriteTable(palette = paletteAt(head, 4), pictures)
