# Vorbis floors and residues: the floor curve and the residue vectors of a packet

# the amplitude of the floor at point y, wherever y falls
fn amplitude(y Signed):
	use noStops
	vorbisInverseDb[y & 255]

fn predictPoint(x Signed, x0 Signed, x1 Signed, y0 Signed, y1 Signed) Signed:
	use noStops
	adx = x1 - x0
	if adx <= 0: return y0
	dy = y1 - y0
	err = dy.abs() * (x - x0)
	off = signed(err / adx)
	signed(y0 - off if dy < 0 else y0 + off)

# multiplies out[x0 ..] up to x1 (or n, or its end) by the line from (x0, y0) to (x1in, y1)
fn drawLine(mut out f32[], x0 Count, y0 Signed, x1in Count, y1 Signed, n Count):
	use noStops
	adx = x1in - x0
	if adx <= 0: return
	dy = y1 - y0
	base = dy / adx
	sy = base - 1 if dy < 0 else base + 1
	ady = dy.abs() - base.abs() * adx
	if x0 >= out.len or x0 >= n or x0 >= x1in: return
	out[x0] *= amplitude(y0)
	y Signed = y0
	err Signed = 0
	for x in x0 + 1..x1in.min(n).min(out.len):
		e = signed(err + ady)
		if e >= adx:
			err = signed(e - adx)
			y = signed(y + sy)
		else:
			err = e
			y = signed(y + base)
		out[x] *= amplitude(y)

# multiplies a channel's spectrum by its floor curve (finalY: the points, -1 where unused)
fn doFloor(f Stream, mapping Count, ch Count, n2 Count, mut target f32[]):
	use noStops
	if mapping >= f.mappings.len or ch >= f.finalY.len: return
	map = f.mappings[mapping]
	floor = map.submapFloor[map.mux[ch & 15] & 15]
	if floor < 0 or floor >= f.floors.len: return
	g = f.floors[floor]
	mult = i64(g.multiplier)
	lx Count = 0
	ly Signed = signed(signed(f.finalY[ch].y[0]) * mult)
	for q in 1..g.values:
		j = g.sortedOrder[q] & 255
		if f.finalY[ch].y[j] >= 0:
			hy = signed(signed(f.finalY[ch].y[j]) * mult)
			hx = count(g.xList[j])
			if lx != hx:
				drawLine(target, lx, ly, hx, hy, n2)
			lx = hx
			ly = hy
	for j in lx..n2.min(target.len):
		target[j] *= amplitude(ly)

# ---------- residues ----------

# one partition of a residue: n values from offset0 of the target, by the book
fn residueDecode(
	mut f Stream,
	mut br BitReader,
	book Count,
	mut target f32[],
	offset0 Count,
	n Count,
	rtype i64
):
	use noStops
	if book >= f.codebooks.len: return false
	dims = f.codebooks[book].dimensions
	if dims < 1: return false
	if rtype == 0:
		step = n / dims
		for k in 0..step:
			if not f.codebookDecodeStep(br, book, target, offset0 + k, n - offset0 - k, step):
				return false
	else:
		for k in 0..=n / dims:
			start = k * dims
			if start >= n: break
			if not f.codebookDecode(br, book, target, offset0 + start, n - start): return false
	true

# the residue vectors of the channels of a submap (`chans`: the channel of each, -1 when not
# decoded), into their channel buffers; n is half the block
fn decodeResidue(mut f Stream, mut br BitReader, chans i64[], n Count, rn Count):
	use noStops
	if rn >= f.residues.len: return
	r = f.residues[rn]
	classbook = r.classbook
	if classbook >= f.codebooks.len: return
	classwords = f.codebooks[classbook].dimensions
	ch = chans.len
	for j in 0..ch:
		c = chans[j]
		if c >= 0 and c < f.channelBuffers.len:
			for k in 0..n.min(f.channelBuffers[c].len):
				f.channelBuffers[c][k] = 0.0
	actualSize = n * 2 if r.kind == 2 else n
	limitBegin = r.begin.min(actualSize)
	limitEnd = r.end.min(actualSize)
	partRead = count(limitEnd - limitBegin) / r.partSize.max(1)
	if classwords < 1 or ch > 16: return
	if r.kind == 2 and ch != 1:
		anyDecoded = false
		for c in chans:
			if c >= 0:
				anyDecoded = true
		if not anyDecoded: return
		f.decodeResidue2(br, r, chans, n, partRead, classwords)
		return
	row = partRead + 1
	classSets = zeros(ch * row)
	for pass in 0..8:
		for p in 0..partRead:
			classSet = p / classwords
			i = p % classwords
			if pass == 0 and i == 0:
				for j in 0..ch:
					if chans[j] >= 0:
						temp = f.decodeSymbol(br, r.classbook)
						if temp < 0: return
						at = j * row + classSet
						if at >= classSets.len: return
						classSets[at] = temp
			for j in 0..ch:
				if chans[j] >= 0:
					at = j * row + classSet
					if at >= classSets.len: return
					cls = count(classSets[at]) * classwords + i
					if cls >= r.classdata.len: return
					bookAt = count(r.classdata[cls]) * 8 + pass
					if bookAt >= r.books.len: return
					b = r.books[bookAt]
					if b >= 0:
						c = chans[j]
						if c < 0 or c >= f.channelBuffers.len: return
						target = move f.channelBuffers[c]
						ok = f.residueDecode(
							br,
							count(b),
							target,
							count(r.begin + p * r.partSize),
							r.partSize,
							r.kind
						)
						f.channelBuffers[c] = target
						if not ok: return

# residue type 2 over several channels: one vector interleaving them
fn decodeResidue2(
	mut f Stream,
	mut br BitReader,
	r Residue,
	chans i64[],
	n Count,
	partRead Count,
	classwords Count
):
	use noStops
	ch = chans.len
	if ch < 1 or classwords < 1: return
	classSets = zeros(partRead + 1)
	for pass in 0..8:
		for p in 0..partRead:
			classSet = p / classwords
			i = p % classwords
			if pass == 0 and i == 0:
				q = f.decodeSymbol(br, r.classbook)
				if q < 0: return
				if classSet >= classSets.len: return
				classSets[classSet] = q
			z = r.begin + p * r.partSize
			if classSet >= classSets.len: return
			cls = count(classSets[classSet]) * classwords + i
			if cls >= r.classdata.len: return
			bookAt = count(r.classdata[cls]) * 8 + pass
			if bookAt >= r.books.len: return
			b = r.books[bookAt]
			if b >= 0:
				if not f.decodeDeinterleave(br, count(b), chans, z % ch, z / ch, n, r.partSize):
					return

# vectors of a codebook spread over the channels in turn, from channel cInter at pInter
fn decodeDeinterleave(
	mut f Stream,
	mut br BitReader,
	book Count,
	chans i64[],
	cInter0 i64,
	pInter0 i64,
	length0 i64,
	total0 i64
):
	use noStops
	ch = chans.len
	chn = count(ch)
	length = count(length0)
	if book >= f.codebooks.len: return false
	cInter Count = count(cInter0)
	pInter Count = count(pInter0)
	total Signed = signed(total0)
	while total > 0:
		z0 = f.decodeStart(br, book)
		if z0 < 0: return false
		c = f.codebooks[book]
		dims = c.dimensions
		effective Signed = dims
		if cInter + pInter * chn + effective > length * chn:
			effective = signed(length * chn - (pInter * chn - cInter))
		z = count(z0) * dims
		last = f32(0.0)
		for i in 0..effective:
			zi = z + i
			if zi >= c.vectors.len: return false
			val = c.vectors[zi] + last
			ci = count(cInter)
			if ci < chans.len:
				ch2 = chans[ci]
				p = count(pInter)
				if ch2 >= 0 and p < length:
					f.addSample(count(ch2), p, val)
			cInter = count(ci + 1)
			if cInter == chn:
				cInter = 0
				pInter = count(pInter + 1)
			if c.sequence:
				last = val
		total = signed(total - effective)
	true

# val added to sample p of the channel's buffer, when both are there
fn addSample(mut f Stream, channel Count, p Count, val f32):
	use noStops
	if channel < f.channelBuffers.len and p < f.channelBuffers[channel].len:
		f.channelBuffers[channel][p] += val
