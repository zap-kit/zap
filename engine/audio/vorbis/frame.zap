# Vorbis audio packets and the public stream functions

import engine.audio.mdct

# the frame a packet holds: its mode's block size and the window's four edges
type FrameShape:
	mode Count
	leftStart Count
	leftEnd Count
	rightStart Count
	rightEnd Count

# the mode of an audio packet and the edges of its window
fn readShape(f Stream, mut br BitReader) FrameShape?:
	use noStops
	i = br.read(ilog(f.modes.len - 1))
	if i >= f.modes.len: return none
	m = f.modes[i]
	n = f.blocksize1 if m.blockflag != 0 else f.blocksize0
	prev = 0
	next = 0
	if m.blockflag != 0:
		prev = br.take(1)
		next = br.take(1)
	center = n >> 1
	s = FrameShape(mode = i, leftStart = 0, leftEnd = center, rightStart = center, rightEnd = n)
	if m.blockflag != 0 and prev == 0:
		s.leftStart = count((n - f.blocksize0) >> 2)
		s.leftEnd = count((n + f.blocksize0) >> 2)
	if m.blockflag != 0 and next == 0:
		s.rightStart = count((n * 3 - f.blocksize0) >> 2)
		s.rightEnd = count((n * 3 + f.blocksize0) >> 2)
	s

vorbisRanges i64[] = [256, 128, 86, 64]

# reads a channel's floor points into finalY; false when the channel is silent
fn readFloor(mut f Stream, mut br BitReader, floor Count, ch Count):
	use noStops
	if floor >= f.floors.len or ch >= f.finalY.len: return false
	g = f.floors[floor]
	if br.take(1) == 0: return false
	range = signed(vorbisRanges[g.multiplier - 1])
	bits = ilog(range) - 1
	y i64[256] = zeros(256)
	y[0] = signed(br.take(bits))
	y[1] = signed(br.take(bits))
	offset = 2
	for j in 0..g.partitions:
		pclass = g.partitionClass[j] & 15
		cdim = g.classDimensions[pclass] & 15
		cbits = g.classSubclasses[pclass] & 3
		csub = (1 << cbits) - 1
		cval = 0
		if cbits != 0:
			cval = f.decodeSymbol(br, count(g.classMasterbooks[pclass]))
		loop cdim:
			book = g.subclassBooks[pclass * 8 + (cval & csub)]
			cval >>= cbits
			y[offset & 255] = signed(f.decodeSymbol(br, count(book))) if book >= 0 else 0
			offset = count(offset) + 1
	if br.short: return false
	step2 bool[256] = zeros(256)
	step2[0] = true
	step2[1] = true
	for j in 2..g.values:
		low = g.neighborLow[j] & 255
		high = g.neighborHigh[j] & 255
		pred = predictPoint(
			signed(g.xList[j]),
			signed(g.xList[low]),
			signed(g.xList[high]),
			signed(y[low]),
			signed(y[high])
		)
		val = signed(y[j]).max(0)
		highroom = range - pred
		lowroom = pred
		room = signed(highroom * 2 if highroom < lowroom else lowroom * 2)
		if val != 0:
			step2[low] = true
			step2[high] = true
			step2[j] = true
			if val >= room:
				y[j] = val - lowroom + pred if highroom > lowroom else pred - val + highroom - 1
			elif (val & 1) != 0:
				y[j] = pred - ((val + 1) >> 1)
			else:
				y[j] = pred + (val >> 1)
		else:
			step2[j] = false
			y[j] = pred
	for j in 0..g.values:
		if not step2[j]:
			y[j] = -1
	f.finalY[ch].y = y
	true

# the inverse coupling of two channels' spectra: square polar to cartesian
fn uncouple(mut mag f32[], mut ang f32[], n Count):
	use noStops
	for j in 0..n.min(mag.len):
		if j >= ang.len: break
		mv = mag[j]
		av = ang[j]
		m2 = mv
		a2 = mv
		if mv > 0.0:
			if av > 0.0:
				a2 = mv - av
			else:
				m2 = mv + av
		else:
			if av > 0.0:
				a2 = mv + av
			else:
				m2 = mv - av
		mag[j] = m2
		ang[j] = a2

# decodes the rest of a packet into the channel buffers; the frame's length, -1 on failure
fn decodePacketRest(
	mut f Stream,
	mut br BitReader,
	granule0 i64,
	last bool,
	mut s FrameShape
) i64:
	use noStops
	mode = s.mode
	if mode >= f.modes.len: return -1
	m = f.modes[mode]
	mapping = m.mapping
	if mapping >= f.mappings.len: return -1
	n = f.blocksize1 if m.blockflag != 0 else f.blocksize0
	map = f.mappings[mapping]
	n2 = n >> 1
	ch = f.channels
	zero bool[16] = zeros(16)
	for i in 0..ch:
		floor = map.submapFloor[map.mux[i] & 15]
		zero[i] = not f.readFloor(br, count(floor), i)
		if f.failed: return -1
	reallyZero = zero
	for i in 0..map.couplingSteps:
		mag = map.magnitude[i] & 15
		ang = map.angle[i] & 15
		if not zero[mag] or not zero[ang]:
			zero[mag] = false
			zero[ang] = false
	for i in 0..map.submaps:
		chans = []
		for j in 0..ch:
			if map.mux[j] == i:
				chans.push(-1 if zero[j] else j)
		f.decodeResidue(br, chans, n2, count(map.submapResidue[i]))
	if f.failed: return -1
	# inverse coupling
	steps = map.couplingSteps
	for t in 0..steps:
		i = steps - 1 - t
		if i < 0: break
		mi = map.magnitude[i & 15]
		ai = map.angle[i & 15]
		if mi >= f.channelBuffers.len or ai >= f.channelBuffers.len or mi < 0 or ai < 0: return -1
		mag = move f.channelBuffers[mi]
		ang = move f.channelBuffers[ai]
		uncouple(mag, ang, n2)
		f.channelBuffers[mi] = mag
		f.channelBuffers[ai] = ang
	# the floors, then the inverse MDCT
	bt = m.blockflag
	if bt < 0 or bt >= f.mdcts.len: return -1
	for c in 0..ch:
		if c >= f.channelBuffers.len: return -1
		buffer = move f.channelBuffers[c]
		if reallyZero[c]:
			for j in 0..n2.min(buffer.len):
				buffer[j] = 0.0
		else:
			f.doFloor(mapping, count(c), n2, buffer)
		scratch = move f.scratch
		f.mdcts[bt].inverseMdct(buffer, scratch)
		f.scratch = scratch
		f.channelBuffers[c] = buffer
	f.placeFrame(n, granule0, last, s)

# where the frame lies in the stream: the samples a seek or the start leaves out, and the last
# page's granule position, which shortens the final frame; the frame's length
fn placeFrame(mut f Stream, n Block, granule0 i64, last bool, mut s FrameShape):
	use noStops
	n2 = n >> 1
	if f.firstDecode:
		f.currentLoc = position(-n2)
		f.discardSamplesDeferred = position(n - s.rightEnd)
		f.currentLocValid = true
		f.firstDecode = false
	elif f.discardSamplesDeferred > 0:
		window = s.rightStart - s.leftStart
		discard = f.discardSamplesDeferred
		if discard >= window:
			f.discardSamplesDeferred = position(discard - window)
			s.leftStart = s.rightStart
		else:
			s.leftStart = count(s.leftStart + discard)
			f.discardSamplesDeferred = 0
	# the last page's granule position: a short final frame
	if granule0 != -1:
		current = f.currentLoc
		granule = position(granule0)
		if f.currentLocValid and last:
			if granule < current + (s.rightEnd - s.leftStart):
				base = position(0 if granule < current else granule - current)
				length = count(base + s.leftStart).min(s.rightEnd)
				f.currentLoc = position(current + length)
				return length
		f.currentLoc = position(granule - (n2 - s.leftStart))
		f.currentLocValid = true
	if f.currentLocValid:
		f.currentLoc = position(f.currentLoc + (s.rightStart - s.leftStart))
	s.rightEnd

# which window of the two block sizes a frame of this length overlaps with
fn windowFor(f Stream, length Count):
	use noStops
	if length * 2 == f.blocksize0: return 0
	if length * 2 == f.blocksize1: return 1
	-1

# overlaps the frame with the last one's tail; the samples ready, from `left`
fn finishFrame(mut f Stream, length Count, left Count, right0 Count):
	use noStops
	if f.previousLength > 0:
		n = count(f.previousLength)
		w = f.windowFor(n)
		if w < 0 or w >= f.windows.len: return 0
		for c in 0..f.channels:
			if c >= f.channelBuffers.len or c >= f.previousWindow.len: return 0
			buffer = move f.channelBuffers[c]
			win = f.windows[w]
			prev = f.previousWindow[c]
			for j in 0..n.min(win.len):
				mirror = n - 1 - j
				at = left + j
				if mirror < 0 or mirror >= win.len or j >= prev.len or at >= buffer.len: break
				buffer[at] = buffer[at] * win[j] + prev[j] * win[mirror]
			f.channelBuffers[c] = buffer
	prev = f.previousLength
	f.previousLength = count(length - right0)
	for c in 0..f.channels:
		if c >= f.channelBuffers.len or c >= f.previousWindow.len: return 0
		src = f.channelBuffers[c]
		dst = move f.previousWindow[c]
		for j in 0..count(f.previousLength):
			at = right0 + j
			if j >= dst.len or at >= src.len: break
			dst[j] = src[at]
		f.previousWindow[c] = dst
	if prev == 0: return 0
	right = length if length < right0 else right0
	right - left

# decodes the next packet: the frame's sample count and where it starts in the channel buffers
fn decodeFrame(mut f Stream):
	use noStops
	loop:
		if f.failed: return (-1, 0)
		pkt = f.pages.nextPacket(f.bytes) ?? return (-1, 0)
		br = BitReader(d = pkt.bytes)
		if br.take(1) != 0: continue   # not an audio packet
		shape = f.readShape(br) ?? return (-1, 0)
		length = f.decodePacketRest(br, pkt.granule, pkt.last, shape)
		if length < 0: return (-1, 0)
		n = f.finishFrame(count(length), shape.leftStart, shape.rightStart)
		return (n, shape.leftStart)

# Appends the next packet's samples to `out` (interleaved): how many frames, 0 at the end.
pub fn readVorbis(mut f Stream, mut out f32[]) i64:
	use noStops
	loop:
		n, left = f.decodeFrame()
		if n < 0: return 0
		if n > 0:
			for j in 0..count(n):
				at = count(left) + j
				for channelBuffer in f.channelBuffers:
					if at < channelBuffer.len:
						out.push(channelBuffer[at])
			return n

# Back to the first audio packet.
pub fn rewindVorbis(mut f Stream):
	use noStops
	f.pages = f.resume.copy()
	f.failed = false
	f.previousLength = 0
	f.firstDecode = true
	f.currentLocValid = false
	f.discardSamplesDeferred = 0
	f.decodeFrame()   # the first packet gives no samples, only its tail
