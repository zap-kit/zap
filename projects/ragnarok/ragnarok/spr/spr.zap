# SPR, Ragnarok Online's image banks: "SP", a version, the counts of palette images and (from
# 0x200) RGBA images, then each image's width and height and its pixels. A palette image has
# one byte a pixel, an index into the 256-colour palette that ends the file (index 0 is
# transparent; the palette's own alpha bytes are not used); from 0x201 its bytes are
# run-length coded, a 0 followed by how many transparent pixels. An RGBA image has four bytes
# a pixel (alpha, blue, green, red) and its rows run from the bottom up.

import image

pub type Spr:
	indexed image.Image[]
	rgba image.Image[]

# the images of an SPR file, decoded with its own palette, or why it cannot be read
pub fn parseSpr(d u8[]) Spr ? str:
	if d.len < 1032 or not d.startsWith("SP"): return "not an SPR file"
	version = d.u16le(2)
	palCount = i64(d.u16le(4))
	at = 6
	rgbaCount = 0
	if version >= 0x200:
		rgbaCount = d.u16le(6)
		at = 8
	palette = d.len - 1024
	indexed = []
	loop palCount:
		if at + 4 > d.len: return "an SPR image header runs past the end"
		w = i64(d.u16le(at))
		h = i64(d.u16le(at + 2))
		at += 4
		size = w * h
		coded = false
		if version >= 0x201:
			size = d.u16le(at)
			at += 2
			coded = true
		if at + size > d.len: return "an SPR image runs past the end"
		indexed.push(decodeIndexed(d, at, size, coded, w, h, palette))
		at += size
	rgba = []
	loop rgbaCount:
		if at + 4 > d.len: return "an SPR image header runs past the end"
		w = i64(d.u16le(at))
		h = i64(d.u16le(at + 2))
		at += 4
		if at + w * h * 4 > d.len: return "an SPR image runs past the end"
		rgba.push(decodeRgba(d, at, w, h))
		at += w * h * 4
	Spr(indexed, rgba)

fn decodeIndexed(
	d u8[],
	start i64,
	size i64,
	coded bool,
	w i64,
	h i64,
	palette i64
):
	n = w * h
	out = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
	p = 0
	j = start
	end = start + size
	while j < end and p < n:
		idx = i64(d[j])
		if idx == 0 and coded:
			if j + 1 >= end: break
			p += d[j + 1]   # transparent: left as zeros
			j += 2
		else:
			if idx != 0:
				out.cells[p] = image.Rgba8(
					d[palette + idx * 4],
					d[palette + idx * 4 + 1],
					d[palette + idx * 4 + 2],
					255
				)
			p += 1
			j += 1
	out

fn decodeRgba(d u8[], start i64, w i64, h i64):
	out = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
	for y in 0..out.height:
		for x in 0..out.width:
			s = start + (y * w + x) * 4
			out[x, h - 1 - y] = image.Rgba8(d[s + 3], d[s + 2], d[s + 1], d[s])   # stored from the bottom row up
	out
