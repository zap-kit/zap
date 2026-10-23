# WMA's blocks, a port of wma_decode_block and the functions it calls in FFmpeg's
# libavcodec/wmadec.c and wma.c (LGPL 2.1 or later, ffmpeg.org): the block lengths, the channels
# coded, the gain, the noise-coded high bands, the exponents, the run-level coefficients, their
# scaling into the spectrum, mid/side stereo, the inverse MDCT and the windowed overlap.

# decodes the next block of the frame: -1 when it is damaged, 1 when it ends the frame
fn decodeWmaBlock(mut d Decoder, mut br BitReader, limit i64):
	if not d.readBlockLengths(br): return -1
	bsize = d.frameLenBits - d.blockLenBits
	if bsize < 0 or bsize >= d.blockSizes: return -1
	d.blockLen = 1 << d.blockLenBits
	if d.blockPos + d.blockLen > d.frameLen: return -1
	if d.channels == 2: d.msStereo = br.take(1) == 1
	anyCoded = false
	for ch in 0..d.channels:
		d.channelCoded[ch] = br.take(1) == 1
		anyCoded = anyCoded or d.channelCoded[ch]
	if anyCoded:
		if not d.decodeSpectrum(br, limit, bsize): return -1
	d.transformChannels(bsize)
	d.blockPos += d.blockLen
	1 if d.blockPos >= d.frameLen else 0

# the lengths of this block and its neighbours, log2: read at a frame's start, then each block's next
fn readBlockLengths(mut d Decoder, mut br BitReader):
	if not d.useVariableBlockLen:
		d.prevBlockLenBits = d.frameLenBits
		d.blockLenBits = d.frameLenBits
		d.nextBlockLenBits = d.frameLenBits
		return true
	n = log2Floor(d.blockSizes - 1) + 1
	if d.resetBlockLengths:
		d.resetBlockLengths = false
		v = br.take(n)
		if v >= d.blockSizes: return false
		d.prevBlockLenBits = d.frameLenBits - v
		v = br.take(n)
		if v >= d.blockSizes: return false
		d.blockLenBits = d.frameLenBits - v
	else:
		d.prevBlockLenBits = d.blockLenBits
		d.blockLenBits = d.nextBlockLenBits
	v = br.take(n)
	if v >= d.blockSizes: return false
	d.nextBlockLenBits = d.frameLenBits - v
	true

# the coded channels' spectra, from the gain to mid/side stereo
fn decodeSpectrum(mut d Decoder, mut br BitReader, limit i64, bsize i64):
	gain = 1
	loop:
		if limit - br.bitsRead() < 7: return false
		a = br.take(7)
		gain += a
		if a != 127: break
	escapeBits = gainToBits(gain)
	coefCount i64[2] = [0, 0]
	for ch in 0..d.channels:
		coefCount[ch] = d.coefsEnd[bsize]
	if d.useNoiseCoding: d.readHighBands(br, bsize, coefCount)
	# exponents can be kept from the block before in a short block
	if d.blockLenBits == d.frameLenBits or br.take(1) == 1:
		for ch in 0..d.channels:
			if not d.channelCoded[ch]: continue
			if d.useExpVlc:
				if not d.decodeExpVlc(br, ch): return false
			else:
				d.decodeExpLsp(br, ch)
			d.exponentsBsize[ch] = bsize
			d.exponentsInitialized[ch] = true
	for ch in 0..d.channels:
		if d.channelCoded[ch] and not d.exponentsInitialized[ch]: return false
	for ch in 0..d.channels:
		if not d.channelCoded[ch]: continue
		# the side channel of mid/side stereo has its own table
		t = 1 if ch == 1 and d.msStereo else 0
		if not d.readCoefs(br, ch, t, coefCount[ch], escapeBits): return false
	for ch in 0..d.channels:
		if not d.channelCoded[ch]: continue
		if d.useNoiseCoding:
			d.scaleNoisy(ch, bsize, gain)
		else:
			d.scaleCoefs(ch, bsize, gain, coefCount[ch])
	if d.msStereo and d.channelCoded[1]:
		if not d.channelCoded[0]:
			for i in 0..d.blockLen:
				d.coefs[0][i] = 0.0
			d.channelCoded[0] = true
		for i in 0..d.blockLen:
			m = d.coefs[0][i]
			s = d.coefs[1][i]
			d.coefs[0][i] = m + s
			d.coefs[1][i] = m - s
	true

# ff_wma_total_gain_to_bits: the bits of an escaped level
fn gainToBits(gain i64):
	if gain < 15: return 13
	if gain < 32: return 12
	if gain < 40: return 11
	if gain < 45: return 10
	9

# which high bands of each coded channel are noise, and their gains; the noise bands' coefficients
# are not sent
fn readHighBands(mut d Decoder, mut br BitReader, bsize i64, mut coefCount i64[2]):
	bands = d.highBands[bsize]
	for ch in 0..d.channels:
		if not d.channelCoded[ch]: continue
		for i, band in bands:
			coded = br.take(1) == 1
			d.highBandCoded[ch][i] = coded
			if coded: coefCount[ch] -= band
	for ch in 0..d.channels:
		if not d.channelCoded[ch]: continue
		first = true
		value = 0
		for i in 0..bands.len:
			if not d.highBandCoded[ch][i]: continue
			if first:
				value = br.take(7) - 19
				first = false
			else:
				value += d.hgainVlc.readVlc(br)
			d.highBandValues[ch][i] = value

# 10^(e / 16), the exponents' steps
fn expPower(e i64):
	f32(10.0.pow(e / 16.0))

# the exponents of channel ch, as deltas of AAC's scale factor code over the block's bands
fn decodeExpVlc(mut d Decoder, mut br BitReader, ch i64):
	bands = d.exponentBands[d.frameLenBits - d.blockLenBits]
	last = 36
	maxScale = 0.0
	q = 0
	band = 0
	while q < d.blockLen:
		code = d.expVlc.readVlc(br)
		if code == vlcInvalid: return false
		last += code - 60
		if last < -60 or last >= 96: return false
		v = expPower(last)
		maxScale = maxScale.max(v)
		if band >= bands.len: return false
		loop bands[band]:
			if q < d.blockLen: d.exponents[ch][q] = v
			q += 1
		band += 1
	d.maxExponent[ch] = maxScale
	true

# the exponents of channel ch from ten line spectral pairs (as Vorbis's floor 0)
fn decodeExpLsp(mut d Decoder, mut br BitReader, ch i64):
	lsp f32[10] = zeros(10)
	for i in 0..10:
		bits = 3 if i == 0 or i >= 8 else 4
		lsp[i] = lspCodebook[lspStarts[i] + br.take(bits)]
	maxValue = 0.0
	for i in 0..d.blockLen:
		w = d.lspCosTable[i]
		p = 0.5
		q = 0.5
		for j in [1, 3, 5, 7, 9]:
			q *= w - lsp[j - 1]
			p *= w - lsp[j]
		p *= p * (2.0 - w)
		q *= q * (2.0 + w)
		v = (p + q).pow(-0.25)
		maxValue = maxValue.max(v)
		d.exponents[ch][i] = v
	d.maxExponent[ch] = maxValue

# the run-level coded coefficients of channel ch into coefs1 (ff_wma_run_level_decode, version 0)
fn readCoefs(mut d Decoder, mut br BitReader, ch i64, t i64, count i64, escapeBits i64):
	mask = d.blockLen - 1
	for i in 0..d.blockLen:
		d.coefs1[ch][i] = 0.0
	table = d.coefCodes[t]
	offset = 0
	while offset < count:
		code = table.vlc.readVlc(br)
		if code == vlcInvalid: return false
		if code > 1:
			offset += table.runs[code]
			level = table.levels[code]
			d.coefs1[ch][offset & mask] = level if br.take(1) == 1 else -level
		elif code == 1:
			break
		else:
			level = f32(br.take(escapeBits))
			offset += br.take(d.frameLenBits)
			d.coefs1[ch][offset & mask] = level if br.take(1) == 1 else -level
		offset += 1
	offset <= count

# channel ch's spectrum without noise: the coefficients times the exponents and the gain
fn scaleCoefs(mut d Decoder, ch i64, bsize i64, gain i64, count i64):
	esize = d.exponentsBsize[ch]
	mult = d.gainMult(ch, gain)
	for i in 0..count:
		d.coefs[ch][i] = d.coefs1[ch][i] * d.exponents[ch][i << bsize >> esize] * mult
	for i in count..d.blockLen:
		d.coefs[ch][i] = 0.0

# 10^(gain / 20) over the largest exponent, normalized for the block's length
fn gainMult(d Decoder, ch i64, gain i64):
	mult = f32(10.0.pow(gain * 0.05) / f64(d.maxExponent[ch]))
	mult * (1.0 / f32(d.blockLen / 2))

# the next value of the noise table
fn nextNoise(mut d Decoder):
	v = d.noiseTable[d.noiseIndex]
	d.noiseIndex = (d.noiseIndex + 1) & (noiseTableSize - 1)
	v

# channel ch's spectrum with noise: noise below the first coded coefficient and above the last,
# noise of the band's power in the noise-coded high bands, the coefficients plus a little noise
# elsewhere
fn scaleNoisy(mut d Decoder, ch i64, bsize i64, gain i64):
	esize = d.exponentsBsize[ch]
	mult = d.gainMult(ch, gain)
	bands = d.highBands[bsize]
	exps = d.exponents[ch]
	# the power of each noise-coded band
	power f32[] = zeros(bands.len)
	lastHigh = 0
	e = d.highBandStart[bsize] << bsize >> esize
	for j, n in bands:
		if d.highBandCoded[ch][j]:
			sum = 0.0
			for i in 0..n:
				v = exps[e + (i << bsize >> esize)]
				sum += v * v
			power[j] = sum / f32(n)
			lastHigh = j
		e += n << bsize >> esize
	out = 0
	coded = 0
	e = 0
	for j in -1..bands.len:
		n = d.highBandStart[bsize] if j < 0 else bands[j]
		if j >= 0 and d.highBandCoded[ch][j]:
			m = (power[j] / power[lastHigh]).sqrt()
			m = f32(f64(m) * 10.0.pow(d.highBandValues[ch][j] * 0.05))
			m /= d.maxExponent[ch] * d.noiseMult
			m *= 1.0 / f32(d.blockLen / 2)
			for i in 0..n:
				d.coefs[ch][out] = d.nextNoise() * exps[e + (i << bsize >> esize)] * m
				out += 1
		else:
			for i in 0..n:
				noise = d.nextNoise()
				d.coefs[ch][out] = (d.coefs1[ch][coded] + noise) * exps[e + (i << bsize >> esize)] *
					mult
				out += 1
				coded += 1
		e += n << bsize >> esize
	# the highest frequencies: noise at the last exponent
	high = mult * exps[(e + (-(1 << bsize) >> esize)).max(0)]
	loop d.blockLen - d.coefsEnd[bsize]:
		d.coefs[ch][out] = d.nextNoise() * high
		out += 1
