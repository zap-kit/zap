# Bitmaps (SWF specification v19, chapter 8), kept as their tags' bytes and decoded when asked:
# DefineBits (JPEG data completed by the movie's JPEGTables), DefineBitsJPEG2 (a JPEG, PNG or
# GIF), DefineBitsJPEG3 and 4 (a JPEG or PNG and a zlib plane of alpha), DefineBitsLossless 1 and
# 2 (zlib of 8-bit indices into a color table, 15-bit or 24-bit RGB, or premultiplied ARGB). The
# decoded image has straight alpha, rows from the top.

import deflate
import image
import image.jpeg

# a bitmap's tag kept as it came, decoded when drawn (decodeBitmap)
pub type Bitmap:
	id i64
	tag i64   # the tag it came in
	data u8[]   # the tag's bytes after the id

# a Scaleform DefineExternalImage (1001) or DefineExternalImage2 (1009): a file beside the movie
pub type ExternalImage:
	id i64
	format i64
	width i64
	height i64
	exportName str
	fileName str

# Scaleform's DefineSubImage (1008): a rectangle of another image, in pixels
pub type SubImage:
	id i64
	image i64
	x0 i64
	y0 i64
	x1 i64
	y1 i64

# the width and height a lossless bitmap declares, 0 for a JPEG (known when decoded)
pub fn bitmapSize(b Bitmap) (i64, i64):
	if (b.tag == 20 or b.tag == 36) and b.data.len >= 5: return (b.data.u16le(1), b.data.u16le(3))
	(0, 0)

# the bitmap's pixels; `tables` is the movie's JPEGTables (DefineBits uses them)
pub fn decodeBitmap(b Bitmap, tables u8[]) image.Image ? str:
	if b.tag == 20 or b.tag == 36: return decodeLossless(b.data, b.tag == 36)
	if b.tag == 6: return jpeg.decodeJpeg(joinJpeg(tables, b.data))
	if b.tag == 21: return decodeEmbedded(b.data)
	if b.tag == 35 or b.tag == 90:
		if b.data.len < 4: return "bitmap {b.id}: cut short"
		offset = i64(b.data.u32le(0))
		start = 4 if b.tag == 35 else 6
		if start + offset > b.data.len: return "bitmap {b.id}: its alpha runs past the tag"
		img = try decodeEmbedded(b.data[start..start + offset])
		if start + offset == b.data.len: return img
		alpha = try deflate.inflateZlib(b.data[start + offset..], img.width * img.height)
		if alpha.len >= img.cells.len:
			for k, mut cell in img.cells:
				cell.a = alpha[k]
		return img
	"bitmap {b.id}: tag {b.tag} is not a bitmap"

# a JPEG, PNG or GIF as DefineBitsJPEG2 and later hold it
fn decodeEmbedded(d u8[]) image.Image ? str:
	if d.len > 4 and d[0] == 0x89 and d.matchesAt(1, "PNG"): return image.decodePng(d)
	if d.startsWith("GIF8"): return "a GIF bitmap is not read"
	jpeg.decodeJpeg(joinJpeg([], d))

# One JPEG stream of the tables and the image: Flash writes some with an end and a start marker
# (FF D9 FF D8) before the real start, and the tables end with their own end marker.
fn joinJpeg(tables u8[], d u8[]):
	out = []
	t = stripBogusStart(tables)
	if t.len >= 2 and t[len - 2] == 255 and t[len - 1] == 0xD9:
		out.extend(t[..t.len - 2])
	else:
		out.extend(t)
	body = stripBogusStart(d)
	if not out.isEmpty and body.len >= 2 and body[0] == 255 and body[1] == 0xD8:
		out.extend(body[2..])
	else:
		out.extend(body)
	out

fn stripBogusStart(d u8[]) ref u8[]:
	at = 0
	while at + 4 <= d.len and d[at] == 255 and d[at + 1] == 0xD9 and d[at + 2] == 255 and
		d[at + 3] == 0xD8:
		at += 4
	d[at..]

fn decodeLossless(d u8[], alpha bool) image.Image ? str:
	if d.len < 5: return "a lossless bitmap cut short"
	format = i64(d[0])
	w = i64(d.u16le(1))
	h = i64(d.u16le(3))
	colors = i64(d[5]) + 1 if format == 3 and d.len > 5 else 0
	start = 6 if format == 3 else 5
	entry = 4 if alpha else 3
	pixels = try deflate.inflateZlib(d[start..], colors * entry + w * h * 4)
	img = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
	if format == 3:
		stride = (w + 3) & -4
		base = colors * entry
		if pixels.len < base + stride * h: return "a colormapped bitmap cut short"
		for y in 0..h:
			for x in 0..w:
				k = i64(pixels[base + y * stride + x])
				if k >= colors: continue
				at = k * entry
				a = pixels[at + 3] if alpha else 255
				img[x, y] = unpremultiplied(pixels[at], pixels[at + 1], pixels[at + 2], a, alpha)
	elif format == 4:
		stride = (w * 2 + 3) & -4
		if pixels.len < stride * h: return "a 15-bit bitmap cut short"
		for y in 0..h:
			for x in 0..w:
				v = i64(pixels.u16be(y * stride + x * 2))
				img[x, y] = image.Rgba8(five(v >> 10), five(v >> 5), five(v), 255)
	elif format == 5:
		if pixels.len < w * h * 4: return "a 32-bit bitmap cut short"
		for y in 0..h:
			for x in 0..w:
				at = (y * w + x) * 4
				a = pixels[at] if alpha else 255
				img[x, y] = unpremultiplied(
					pixels[at + 1],
					pixels[at + 2],
					pixels[at + 3],
					a,
					alpha
				)
	else:
		return "lossless bitmap format {format} is not one of 3, 4 or 5"
	img

# a 5-bit channel as 8 bits
fn five(v i64) u8:
	c = v & 31
	(c << 3) | (c >> 2)

# DefineBitsLossless2 stores colors multiplied by their alpha
fn unpremultiplied(r u8, g u8, b u8, a u8, premultiplied bool):
	if not premultiplied or a == 255: return image.Rgba8(r, g, b, a)
	if a == 0: return image.Rgba8(0, 0, 0, 0)
	image.Rgba8(undo(r, a), undo(g, a), undo(b, a), a)

fn undo(c u8, a u8) u8:
	((i64(c) * 255 + i64(a) / 2) / i64(a)).min(255)
