# DOS games' shared readers: the planar bitmaps of EGA and VGA files, their palettes. Each game's
# own formats are a module of their own beside this one (dos/lemmings).
#
# The planar bitmaps of the DOS files: a picture of w x h pixels is `bpp` monochrome planes one
# after another, each row w / 8 bytes, the leftmost pixel of a byte its high bit; plane p gives
# bit p of a pixel's palette index. A mask is one plane: a set bit is a solid pixel.

import image

# the VGA palette of 16 entries of a level: the fixed colours of the game then a set's own
pub type Palette:
	colors image.Rgba8[16]

# the palette indices of a planar picture at `at` in `bytes`
pub fn planarIndices(bytes u8[], at i64, w i64, h i64, bpp i64) u8[]:
	lineBytes = w / 8
	planeBytes = lineBytes * h
	out u8[] = zeros(w * h)
	for y in 0..h:
		for x in 0..w:
			v = 0
			for p in 0..bpp:
				b = bytes[at + p * planeBytes + y * lineBytes + x / 8]
				if (b >> (7 - x % 8)) & 1 != 0:
					v |= 1 << p
			out[y * w + x] = u8(v)
	out

# one plane as solid flags
pub fn planarMask(bytes u8[], at i64, w i64, h i64) bool[]:
	planarIndices(bytes, at, w, h, 1).map(it != 0)

# the picture of palette indices as pixels; index 0 (and a mask's clear pixel) is transparent
pub fn paint(indices u8[], mask bool[]?, w i64, h i64, pal Palette) image.Image:
	img = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..h:
		for x in 0..w:
			i = y * w + x
			solid = true
			if mask is m:
				solid = m[i]
			if solid and indices[i] != 0:
				img[x, y] = pal.colors[indices[i]]
	img

# a VGA colour of 6 bits a channel as 8
pub fn vgaColor(r u8, g u8, b u8) image.Rgba8:
	image.Rgba8(r << 2, g << 2, b << 2, 255)
