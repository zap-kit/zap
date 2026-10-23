# A contact sheet of a segment's bytes read as 32x32 RGBA16 textures every `step` bytes, to find one.
#   zap run projects/mario/contact.zap 2 2048 build/marioscan/seg2.png

import image
import n64

_, lv = n64.readCastleGrounds()
a = args
seg = i64.parse(a[0]) ?? 2
step = i64.parse(a[1]) ?? 2048
bank = lv.segments.banks[seg]
first = (i64.parse(a[3]) ?? 0) if a.len > 3 else 0
last = (i64.parse(a[4]) ?? bank.len) if a.len > 4 else bank.len
n = (last.min(bank.len - 2048) - first) / step
cols = 16
rows = (n + cols - 1) / cols
w = cols * 34
h = rows * 34
mut sheet = image.Image(w, h, fill = image.Rgba8(0, 0, 0, 0))
for i in 0..n:
	t = n64.decodeTexels(bank, first + i * step, 32, 32, 0, 2, [], 0)
	ox = (i % cols) * 34
	oy = (i / cols) * 34
	for y in 0..t.height:
		for x in 0..t.width:
			sheet[ox + x, oy + y] = image.Rgba8(t[x, y].r, t[x, y].g, t[x, y].b, 255)
_ = sheet.savePng(a[2])
print("{n} tiles, {cols} a row, from {first}")
