# vgaspecX.dat: a special level's whole terrain, 960 x 160, under a second compression after the
# .DAT one: raw runs (0x00..0x7F, the count less one, then the bytes), repeats (0x81..0xFF, 257
# minus the byte is the count, then the byte) and 0x80 ending one of four sections, each a
# planar picture of 3 planes of 40 rows whose indices 1..7 are the palette's 9..15.

import dos
import fs
import image

specialWidth = 960
specialRows = 40
sectionBytes = 14_400

fn unpackSpecial(packed u8[], at i64):
	sections = []
	cur = []
	i = at
	while i < packed.len:
		b = i64(packed[i])
		i += 1
		if b == 0x80:
			sections.push(cur)
			cur = []
		elif b < 0x80:
			for k in 0..=b:
				cur.push(packed[i + k])
			i += b + 1
		else:
			loop 257 - b:
				cur.push(packed[i])
			i += 1
	if not cur.isEmpty:
		sections.push(cur)
	sections

# the picture and the eight custom colours of a special set
pub fn loadSpecial(path str) (image.Image, image.Rgba8[]):
	sections = sectionsOf(fs.readBytes(path) ?? fail("cannot read {path}: {error}"))
	if sections.len != 1: fail("{path} has {sections.len} sections, not 1")
	data = sections[0].bytes
	custom = vgaEntries(data, 0)
	parts = unpackSpecial(data, 40)
	if parts.len < 4: fail("{path} unpacks to {parts.len} parts, not 4")
	pal = levelPalette(custom)
	picture = image.Image(specialWidth, specialRows * 4, fill = image.Rgba8(0, 0, 0, 0))
	for s in 0..4:
		if parts[s].len < sectionBytes: fail("{path} part {s} has {parts[s].len} bytes")
		indices = dos.planarIndices(parts[s], 0, specialWidth, specialRows, 3)
		shifted = indices.map(u8(0) if it == 0 else it + 8)
		picture.paste(dos.paint(shifted, none, specialWidth, specialRows, pal), 0, s * specialRows)
	(picture, custom)
