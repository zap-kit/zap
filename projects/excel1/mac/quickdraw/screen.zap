# The screen as a picture: its 512x342 one-bit pixels, black where set.

import cpu
import image

pub fn screenImage() image.Image:
	px = fill(screenWidth * screenHeight * 4, u8(255))
	for y in 0..screenHeight:
		for x in 0..screenWidth:
			byte = cpu.mem[screenBase + y * screenRowBytes + (x >> 3)]
			if byte >> (7 - (x & 7)) & 1 != 0:
				at = (y * screenWidth + x) * 4
				px[at] = 0
				px[at + 1] = 0
				px[at + 2] = 0
	image.fromBytes(screenWidth, screenHeight, px)
