# WMA's inverse MDCT and windows, a port of wma_decode_block's end and wma_window in FFmpeg's
# libavcodec/wmadec.c (LGPL 2.1 or later, ffmpeg.org): each channel's block transformed and added
# into the frame's output with sine windows as long as the shorter of two neighbouring blocks.

import engine.audio.mdct

# FFmpeg's scale of the transform: -1/32768 (the spectrum is in 16-bit units)
mdctScale f32 = -1.0 / 32_768.0

# each channel's block through the inverse MDCT, windowed into frameOut
fn transformChannels(mut d Decoder, bsize i64):
	n = d.blockLen
	t = d.mdcts[bsize]
	for ch in 0..d.channels:
		if d.channelCoded[ch]:
			u = move d.output
			for i in 0..n:
				u[i] = d.coefs[ch][i]
			v = move d.scratch
			t.inverseMdct(u, v)
			for i in 0..2 * n:
				u[i] *= mdctScale
			d.output = u
			d.scratch = v
		elif not (d.msStereo and ch == 1):
			for i in 0..2 * n:
				d.output[i] = 0.0
		d.window(ch, d.frameLen / 2 + d.blockPos - n / 2)

# the block's 2n samples in `output`, windowed and added into channel ch's frame at `at`
fn window(mut d Decoder, ch i64, at i64):
	n = d.blockLen
	out = move d.frameOut[ch]
	# the left half: a window as long as the shorter of this block and the one before
	if d.blockLenBits <= d.prevBlockLenBits:
		w = d.windows[d.frameLenBits - d.blockLenBits]
		for i in 0..n:
			out[at + i] += d.output[i] * w[i]
	else:
		m = 1 << d.prevBlockLenBits
		pad = (n - m) / 2
		w = d.windows[d.frameLenBits - d.prevBlockLenBits]
		for i in 0..m:
			out[at + pad + i] += d.output[pad + i] * w[i]
		for i in pad + m..n:
			out[at + i] = d.output[i]
	# the right half, the window reversed
	right = at + n
	if d.blockLenBits <= d.nextBlockLenBits:
		w = d.windows[d.frameLenBits - d.blockLenBits]
		for i in 0..n:
			out[right + i] = d.output[n + i] * w[n - 1 - i]
	else:
		m = 1 << d.nextBlockLenBits
		pad = (n - m) / 2
		w = d.windows[d.frameLenBits - d.nextBlockLenBits]
		for i in 0..pad:
			out[right + i] = d.output[n + i]
		for i in 0..m:
			out[right + pad + i] = d.output[n + pad + i] * w[m - 1 - i]
		for i in pad + m..n:
			out[right + i] = 0.0
	d.frameOut[ch] = out
