# MP3 stereo processing, reordering, IMDCT and polyphase synthesis

fn midSideStereo(mut d Decoder, left i64, n i64):
	for i in left..left + n:
		a = d.grbuf[i]
		b = d.grbuf[i + 576]
		d.grbuf[i] = a + b
		d.grbuf[i + 576] = a - b

fn intensityStereoBand(mut d Decoder, left i64, n i64, kl f32, kr f32):
	for i in left..left + n:
		d.grbuf[i + 576] = d.grbuf[i] * kr
		d.grbuf[i] *= kl

# the last band with a nonzero value in the right channel, per window (-1: none)
fn stereoTopBand(d Decoder, sfbBase i64, nbands i64):
	maxBand i64[3] = [-1, -1, -1]
	right = 576
	for i in 0..nbands:
		w = bandWidth(sfbBase + i)
		k = 0
		while k < w:
			if d.grbuf[right + k] != 0.0 or d.grbuf[right + k + 1] != 0.0:
				maxBand[i % 3] = i
				break
			k += 2
		right += w
	maxBand

fn stereoProcess(mut d Decoder, istBase i64, sfbBase i64, maxBand i64[3], mpeg2Shift i64):
	h = d.header
	maxPos = 7 if h.isMpeg1() else 16   # as ffmpeg: an MPEG-2 position from 16 up is not intensity
	left = 0
	i = 0
	while bandWidth(sfbBase + i) != 0:
		w = bandWidth(sfbBase + i)
		ipos = d.istPos[istBase + i]
		if i > maxBand[i % 3] and ipos < maxPos:
			s = f32(1.41421356) if h.testMsStereo() else f32(1.0)
			kl = f32(1.0)
			kr = f32(1.0)
			if h.isMpeg1():
				kl = mp3Pan[2 * ipos]
				kr = mp3Pan[2 * ipos + 1]
			else:
				kr = ldexpQ2(1.0, (ipos + 1) >> 1 << mpeg2Shift)
				if (ipos & 1) != 0:
					kl = kr
					kr = 1.0
			d.intensityStereoBand(left, w, kl * s, kr * s)
		elif h.testMsStereo():
			d.midSideStereo(left, w)
		left += w
		i += 1

fn intensityStereo(mut d Decoder, firstGranule i64):
	gr = d.granules[firstGranule]
	right = d.granules[firstGranule + 1]
	nSfb = gr.nLongSfb + gr.nShortSfb
	maxBlocks = 3 if gr.nShortSfb != 0 else 1
	maxBand = d.stereoTopBand(gr.sfbBase, nSfb)
	if gr.nLongSfb != 0:
		top = maxBand[0].max(maxBand[1]).max(maxBand[2])
		maxBand = [top, top, top]
	istBase = 40   # the right channel's positions
	for i in 0..maxBlocks:
		itop = nSfb - maxBlocks + i
		prev = itop - maxBlocks
		d.istPos[istBase + itop] = d.istPos[istBase + prev]   # the top band has no position of its own: its neighbour's
	d.stereoProcess(istBase, gr.sfbBase, maxBand, right.scalefacCompress & 1)

# ---------- reordering, alias reduction, IMDCT ----------

# short blocks' values from band-major to window-interleaved order
fn reorder(mut d Decoder, start i64, sfbAt i64):
	src = start
	dst = 0
	sfb = sfbAt
	loop:
		length = bandWidth(sfb)
		if length == 0: break
		loop length:
			d.syn[dst] = d.grbuf[src]
			d.syn[dst + 1] = d.grbuf[src + length]
			d.syn[dst + 2] = d.grbuf[src + 2 * length]
			dst += 3
			src += 1
		sfb += 3
		src += 2 * length
	for k in 0..dst:
		d.grbuf[start + k] = d.syn[k]

fn antialias(mut d Decoder, start i64, nbands i64):
	g = start
	loop nbands.max(0):
		for i in 0..8:
			u = d.grbuf[g + 18 + i]
			dn = d.grbuf[g + 17 - i]
			d.grbuf[g + 18 + i] = u * mp3Aa[i] - dn * mp3Aa[8 + i]
			d.grbuf[g + 17 - i] = u * mp3Aa[8 + i] + dn * mp3Aa[i]
		g += 18

fn dct3of9(y f32[9]) f32[9]:
	s0 = y[0]
	s2 = y[2]
	s4 = y[4]
	s6 = y[6]
	s8 = y[8]
	t0 = s0 + s6 * 0.5
	s0 -= s6
	t4 = (s4 + s2) * 0.93969262
	t2 = (s8 + s2) * 0.76604444
	s6 = (s4 - s8) * 0.17364818
	s4 += s8 - s2
	s2 = s0 - s4 * 0.5
	y4 = s4 + s0
	s8 = t0 - t2 + s6
	s0 = t0 - t4 + t2
	s4 = t0 + t4 - s6
	s1 = y[1]
	s3 = y[3]
	s5 = y[5]
	s7 = y[7]
	s3 *= 0.86602540
	t0 = (s5 + s1) * 0.98480775
	t4 = (s5 - s7) * 0.34202014
	t2 = (s1 + s7) * 0.64278761
	s1 = (s1 - s5 - s7) * 0.86602540
	s5 = t0 - s3 - t2
	s7 = t4 - s3 - t0
	s3 = t4 + s3 - t2
	[s4 - s7, s2 + s1, s0 - s3, s8 + s5, y4, s8 - s5, s0 + s3, s2 - s1, s4 + s7]

# long blocks: 36-point IMDCT, windowed, overlapped with the previous granule
fn imdct36(mut d Decoder, start i64, overlapStart i64, window i64, nbands i64):
	g = start
	o = overlapStart
	loop nbands:
		co f32[9]
		si f32[9]
		co[0] = -d.grbuf[g]
		si[0] = d.grbuf[g + 17]
		for i in 0..4:
			si[8 - 2 * i] = d.grbuf[g + 4 * i + 1] - d.grbuf[g + 4 * i + 2]
			co[1 + 2 * i] = d.grbuf[g + 4 * i + 1] + d.grbuf[g + 4 * i + 2]
			si[7 - 2 * i] = d.grbuf[g + 4 * i + 4] - d.grbuf[g + 4 * i + 3]
			co[2 + 2 * i] = -(d.grbuf[g + 4 * i + 3] + d.grbuf[g + 4 * i + 4])
		co = dct3of9(co)
		si = dct3of9(si)
		si[1] = -si[1]
		si[3] = -si[3]
		si[5] = -si[5]
		si[7] = -si[7]
		for i in 0..9:
			ovl = d.overlap[o + i]
			sum = co[i] * mp3Twid9[9 + i] + si[i] * mp3Twid9[i]
			d.overlap[o + i] = co[i] * mp3Twid9[i] - si[i] * mp3Twid9[9 + i]
			d.grbuf[g + i] = ovl * mp3MdctWindow[window + i] - sum * mp3MdctWindow[window + 9 + i]
			d.grbuf[g + 17 - i] = ovl * mp3MdctWindow[window + 9 + i] +
				sum * mp3MdctWindow[window + i]
		g += 18
		o += 9

# a 12-point IMDCT of one short window: six outputs, and the new overlap (three values)
type Short12:
	out f32[6]
	next f32[3]

fn idct3(x0 f32, x1 f32, x2 f32) f32[3]:
	m1 = x1 * 0.86602540
	a1 = x0 - x2 * 0.5
	[a1 + m1, x0 + x2, a1 - m1]

# x0..x15: the window's six values (every third of the band), ov0..ov2: the overlap kept
fn imdct12(x0 f32, x3 f32, x6 f32, x9 f32, x12 f32, x15 f32, ov0 f32, ov1 f32, ov2 f32):
	ov f32[3] = [ov0, ov1, ov2]
	co = idct3(-x0, x6 + x3, x12 + x9)
	si = idct3(x15, x12 - x9, x6 - x3)
	si[1] = -si[1]
	r = Short12(out = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], next = [0.0, 0.0, 0.0])
	for i in 0..3:
		ovl = ov[i]
		sum = co[i] * mp3Twid3[3 + i] + si[i] * mp3Twid3[i]
		r.next[i] = co[i] * mp3Twid3[i] - si[i] * mp3Twid3[3 + i]
		r.out[i] = ovl * mp3Twid3[2 - i] - sum * mp3Twid3[5 - i]
		r.out[5 - i] = ovl * mp3Twid3[5 - i] + sum * mp3Twid3[2 - i]
	r

fn imdctShort(mut d Decoder, start i64, overlapStart i64, nbands i64):
	g = start
	o = overlapStart
	loop nbands:
		tmp f32[18]
		for k in 0..18:
			tmp[k] = d.grbuf[g + k]
		for k in 0..6:
			d.grbuf[g + k] = d.overlap[o + k]
		for w in 0..3:
			r = imdct12(
				tmp[w],
				tmp[w + 3],
				tmp[w + 6],
				tmp[w + 9],
				tmp[w + 12],
				tmp[w + 15],
				d.overlap[o + 6],
				d.overlap[o + 7],
				d.overlap[o + 8]
			)
			for k in 0..3:
				d.overlap[o + 6 + k] = r.next[k]
			for k in 0..6:
				if w == 0:
					d.grbuf[g + 6 + k] = r.out[k]
				elif w == 1:
					d.grbuf[g + 12 + k] = r.out[k]
				else:
					d.overlap[o + k] = r.out[k]
		g += 18
		o += 9

fn imdctGranule(mut d Decoder, ch i64, blockType i64, nLongBands i64):
	g = ch * 576
	o = ch * 288
	if nLongBands > 0:
		d.imdct36(g, o, 0, nLongBands)
	g2 = g + 18 * nLongBands
	o2 = o + 9 * nLongBands
	if blockType == 2:
		d.imdctShort(g2, o2, 32 - nLongBands)
	else:
		d.imdct36(g2, o2, 18 if blockType == 3 else 0, 32 - nLongBands)

fn changeSign(mut d Decoder, start i64):
	g = start + 18
	loop 16:
		i = 1
		while i < 18:
			d.grbuf[g + i] = -d.grbuf[g + i]
			i += 2
		g += 36

# ---------- synthesis ----------

# the 32-point DCT-II of the subbands at each of the granule's 18 times, in place
fn dctII(mut d Decoder, start i64):
	for k in 0..18:
		t f32[32]
		y = start + k
		for i in 0..8:
			x0 = d.grbuf[y + i * 18]
			x1 = d.grbuf[y + (15 - i) * 18]
			x2 = d.grbuf[y + (16 + i) * 18]
			x3 = d.grbuf[y + (31 - i) * 18]
			t0 = x0 + x3
			t1 = x1 + x2
			t2 = (x1 - x2) * mp3Sec[3 * i]
			t3 = (x0 - x3) * mp3Sec[3 * i + 1]
			t[i] = t0 + t1
			t[8 + i] = (t0 - t1) * mp3Sec[3 * i + 2]
			t[16 + i] = t3 + t2
			t[24 + i] = (t3 - t2) * mp3Sec[3 * i + 2]
		for r in 0..4:
			b = r * 8
			x0 = t[b]
			x1 = t[b + 1]
			x2 = t[b + 2]
			x3 = t[b + 3]
			x4 = t[b + 4]
			x5 = t[b + 5]
			x6 = t[b + 6]
			x7 = t[b + 7]
			xt = x0 - x7
			x0 += x7
			x7 = x1 - x6
			x1 += x6
			x6 = x2 - x5
			x2 += x5
			x5 = x3 - x4
			x3 += x4
			x4 = x0 - x3
			x0 += x3
			x3 = x1 - x2
			x1 += x2
			t[b] = x0 + x1
			t[b + 4] = (x0 - x1) * 0.70710677
			x5 += x6
			x6 = (x6 + x7) * 0.70710677
			x7 += xt
			x3 = (x3 + x4) * 0.70710677
			x5 -= x7 * 0.198912367
			x7 += x5 * 0.382683432
			x5 -= x7 * 0.198912367
			x0 = xt - x6
			xt += x6
			t[b + 1] = (xt + x7) * 0.50979561
			t[b + 2] = (x4 + x3) * 0.54119611
			t[b + 3] = (x0 - x5) * 0.60134488
			t[b + 5] = (x0 + x5) * 0.89997619
			t[b + 6] = (x4 - x3) * 1.30656302
			t[b + 7] = (xt - x7) * 2.56291556
		yy = y
		for i in 0..7:
			d.grbuf[yy] = t[i]
			d.grbuf[yy + 18] = t[16 + i] + t[24 + i] + t[24 + i + 1]
			d.grbuf[yy + 36] = t[8 + i] + t[8 + i + 1]
			d.grbuf[yy + 54] = t[16 + i + 1] + t[24 + i] + t[24 + i + 1]
			yy += 72
		d.grbuf[yy] = t[7]
		d.grbuf[yy + 18] = t[16 + 7] + t[24 + 7]
		d.grbuf[yy + 36] = t[8 + 7]
		d.grbuf[yy + 54] = t[24 + 7]

scalePcm f32 = 0.000030517578125

# two output samples (one at `dst`, one 16 samples later) from the window over the delay line at z
fn synthPair(mut d Decoder, dst i64, nch i64, z i64):
	s = d.syn
	a = (s[z + 14 * 64] - s[z]) * 29.0
	a += (s[z + 64] + s[z + 13 * 64]) * 213.0
	a += (s[z + 12 * 64] - s[z + 2 * 64]) * 459.0
	a += (s[z + 3 * 64] + s[z + 11 * 64]) * 2037.0
	a += (s[z + 10 * 64] - s[z + 4 * 64]) * 5153.0
	a += (s[z + 5 * 64] + s[z + 9 * 64]) * 6574.0
	a += (s[z + 8 * 64] - s[z + 6 * 64]) * 37489.0
	a += s[z + 7 * 64] * 75038.0
	d.pcm[dst] = a * scalePcm
	z2 = z + 2
	b = s[z2 + 14 * 64] * 104.0
	b += s[z2 + 12 * 64] * 1567.0
	b += s[z2 + 10 * 64] * 9727.0
	b += s[z2 + 8 * 64] * 64019.0
	b += s[z2 + 6 * 64] * -9975.0
	b += s[z2 + 4 * 64] * -45.0
	b += s[z2 + 2 * 64] * 146.0
	b += s[z2] * -5.0
	d.pcm[dst + 16 * nch] = b * scalePcm

# 64 samples per channel from two times of the subbands (xl: the left channel's, at grbuf)
fn synth(mut d Decoder, xl i64, dstl i64, nch i64, lins i64):
	xr = xl + 576 * (nch - 1)
	dstr = dstl + nch - 1
	zlin = lins + 15 * 64
	d.syn[zlin + 4 * 15] = d.grbuf[xl + 18 * 16]
	d.syn[zlin + 4 * 15 + 1] = d.grbuf[xr + 18 * 16]
	d.syn[zlin + 4 * 15 + 2] = d.grbuf[xl]
	d.syn[zlin + 4 * 15 + 3] = d.grbuf[xr]
	d.syn[zlin + 4 * 31] = d.grbuf[xl + 1 + 18 * 16]
	d.syn[zlin + 4 * 31 + 1] = d.grbuf[xr + 1 + 18 * 16]
	d.syn[zlin + 4 * 31 + 2] = d.grbuf[xl + 1]
	d.syn[zlin + 4 * 31 + 3] = d.grbuf[xr + 1]
	d.synthPair(dstr, nch, lins + 4 * 15 + 1)
	d.synthPair(dstr + 32 * nch, nch, lins + 4 * 15 + 64 + 1)
	d.synthPair(dstl, nch, lins + 4 * 15)
	d.synthPair(dstl + 32 * nch, nch, lins + 4 * 15 + 64)
	i = 14
	while i >= 0:
		d.syn[zlin + 4 * i] = d.grbuf[xl + 18 * (31 - i)]
		d.syn[zlin + 4 * i + 1] = d.grbuf[xr + 18 * (31 - i)]
		d.syn[zlin + 4 * i + 2] = d.grbuf[xl + 1 + 18 * (31 - i)]
		d.syn[zlin + 4 * i + 3] = d.grbuf[xr + 1 + 18 * (31 - i)]
		d.syn[zlin + 4 * (i + 16)] = d.grbuf[xl + 1 + 18 * (1 + i)]
		d.syn[zlin + 4 * (i + 16) + 1] = d.grbuf[xr + 1 + 18 * (1 + i)]
		d.syn[zlin + 4 * (i - 16) + 2] = d.grbuf[xl + 18 * (1 + i)]
		d.syn[zlin + 4 * (i - 16) + 3] = d.grbuf[xr + 18 * (1 + i)]
		a0 = f32(0.0)
		a1 = f32(0.0)
		a2 = f32(0.0)
		a3 = f32(0.0)
		b0 = f32(0.0)
		b1 = f32(0.0)
		b2 = f32(0.0)
		b3 = f32(0.0)
		s = d.syn
		for k in 0..8:
			w0 = mp3SynthWindow[(14 - i) * 16 + 2 * k]
			w1 = mp3SynthWindow[(14 - i) * 16 + 2 * k + 1]
			vz = zlin + 4 * i - k * 64
			vy = zlin + 4 * i - (15 - k) * 64
			b0 += s[vz] * w1 + s[vy] * w0
			b1 += s[vz + 1] * w1 + s[vy + 1] * w0
			b2 += s[vz + 2] * w1 + s[vy + 2] * w0
			b3 += s[vz + 3] * w1 + s[vy + 3] * w0
			if k == 0 or (k & 1) == 0:
				a0 += s[vz] * w0 - s[vy] * w1
				a1 += s[vz + 1] * w0 - s[vy + 1] * w1
				a2 += s[vz + 2] * w0 - s[vy + 2] * w1
				a3 += s[vz + 3] * w0 - s[vy + 3] * w1
			else:
				a0 += s[vy] * w1 - s[vz] * w0
				a1 += s[vy + 1] * w1 - s[vz + 1] * w0
				a2 += s[vy + 2] * w1 - s[vz + 2] * w0
				a3 += s[vy + 3] * w1 - s[vz + 3] * w0
		d.pcm[dstr + (15 - i) * nch] = a1 * scalePcm
		d.pcm[dstr + (17 + i) * nch] = b1 * scalePcm
		d.pcm[dstl + (15 - i) * nch] = a0 * scalePcm
		d.pcm[dstl + (17 + i) * nch] = b0 * scalePcm
		d.pcm[dstr + (47 - i) * nch] = a3 * scalePcm
		d.pcm[dstr + (49 + i) * nch] = b3 * scalePcm
		d.pcm[dstl + (47 - i) * nch] = a2 * scalePcm
		d.pcm[dstl + (49 + i) * nch] = b2 * scalePcm
		i -= 1

# a granule's 576 samples per channel into d.pcm at `pcmAt`
fn synthGranule(mut d Decoder, nch i64, pcmAt i64):
	for ch in 0..nch:
		d.dctII(576 * ch)
	for k in 0..15 * 64:
		d.syn[k] = d.qmfState[k]
	i = 0
	while i < 18:
		d.synth(i, pcmAt + 32 * nch * i, nch, i * 64)
		i += 2
	if nch == 1:
		k = 0
		while k < 15 * 64:
			d.qmfState[k] = d.syn[18 * 64 + k]
			k += 2
	else:
		for k in 0..15 * 64:
			d.qmfState[k] = d.syn[18 * 64 + k]
