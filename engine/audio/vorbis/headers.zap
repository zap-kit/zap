# Vorbis headers: codebooks, floors, residues, mappings and modes

import engine.audio.mdct

# A Vorbis stream over an Ogg file's bytes (moved in); none when the headers do not read.
pub fn openVorbis(move bytes u8[]) Stream?:
	use noStops
	f = Stream(bytes)
	if not f.readHeaders(): return none
	f.resume = f.pages.copy()
	f.decodeFrame()
	f

fn readHeaders(mut f Stream):
	use noStops
	first = f.pages.nextPacket(f.bytes) ?? return false
	if (f.pages.flags & 7) != 2 or f.pages.lacing.len != 1 or first.bytes.len != 30: return false
	if first.bytes[0] != 1 or not first.bytes.matchesAt(1, "vorbis"): return false
	r = Reader(d = first.bytes, at = 7)
	version = r.u32()
	channels = i64(r.u8())
	rate = r.u32()
	r.u32()
	r.u32()
	r.u32()
	sizes = r.u8()
	framing = r.u8()
	if r.short or version != 0 or rate == 0: return false
	if channels < 1 or channels > 16: return false
	log0 = i64(sizes & 15)
	log1 = i64(sizes >> 4)
	if log0 < 6 or log0 > 13 or log1 < 6 or log1 > 13 or log0 > log1: return false
	if (framing & 1) == 0: return false
	f.channels = channels
	f.sampleRate = rate
	f.blocksize0 = 1 << log0
	f.blocksize1 = 1 << log1
	# the comment packet: skipped
	comment = f.pages.nextPacket(f.bytes) ?? return false
	if comment.bytes.len < 7: return false
	if comment.bytes[0] != 3 or not comment.bytes.matchesAt(1, "vorbis"): return false
	# the setup packet
	setup = f.pages.nextPacket(f.bytes) ?? return false
	if setup.bytes.len < 7: return false
	if setup.bytes[0] != 5 or not setup.bytes.matchesAt(1, "vorbis"): return false
	br = BitReader(d = setup.bytes)
	br.take(32)
	br.take(24)
	if not f.readCodebooks(br): return false
	# time domain transforms: unused, zeros
	times = br.take(6) + 1
	loop times:
		if br.take(16) != 0: return false
	if not f.readFloors(br) or not f.readResidues(br) or not f.readMappings(br) or
		not f.readModes(br):
		return false
	if br.short: return false
	loop f.channels:
		f.channelBuffers.push(zeros(f.blocksize1))
		f.previousWindow.push(zeros(f.blocksize1 / 2))
		f.finalY.push(Curve())
	f.scratch = zeros(f.blocksize1 / 2)
	f.initBlocksize(f.blocksize0)
	f.initBlocksize(f.blocksize1)
	not f.failed

fn readCodebooks(mut f Stream, mut br BitReader):
	use noStops
	books = br.take(8) + 1
	loop books:
		if br.take(24) != 0x56_4342: return false
		c = Codebook()
		dimensions = br.read(16)
		entries = br.read(24)
		ordered = br.take(1) != 0
		sparse = not ordered and br.take(1) != 0
		if dimensions == 0 and entries != 0 or br.short: return false
		lengths u8[] = fill(entries, vorbisNoCode)
		if ordered:
			if not br.readOrderedLengths(lengths): return false
		else:
			for j in 0..lengths.len:
				present = br.take(1) if sparse else 1
				if present != 0:
					length = br.take(5) + 1
					if length > 31: return false
					lengths[j] = length
		if br.short: return false
		c.dimensions = dimensions
		c.entries = entries
		if not c.buildCodes(lengths): return false
		lookupType = br.take(4)
		if lookupType > 2: return false
		if lookupType > 0:
			if not c.readVectors(br, lookupType): return false
		f.codebooks.push(c)
	true

# the lengths of an ordered codebook: runs of entries of one length, the length growing by one
fn readOrderedLengths(mut br BitReader, mut lengths u8[]):
	use noStops
	current = 0
	length = br.take(5) + 1
	while current < lengths.len:
		cur = count(current)
		n = br.read(ilog(lengths.len - cur))
		l = length
		if l < 1 or l > 31 or br.short: return false
		end = cur + n
		if end > lengths.len: return false
		for k in cur..end.min(lengths.len):
			lengths[k] = l
		current = end
		length = l + 1
	true

# The Huffman codes of the lengths (a code per entry, in order, each the lowest free one): the
# table of the codes up to 10 bits, and the longer ones in a tree walked bit by bit. False when
# the lengths over-fill the tree.
fn buildCodes(mut c Codebook, lengths u8[]):
	use noStops
	codes = assignCodes(lengths) ?? return false
	c.lengths = lengths.copy()
	for i in 0..lengths.len:
		length = i64(lengths[i])
		if length == vorbisNoCode: continue
		if length < 1 or length > 31: return false
		if i >= codes.len: return false
		code = count(codes[i])
		if length <= fastHuffmanBits:
			for k in 0..(1024 >> length):
				slot = code + (k << length)
				if slot >= 1024: return false
				c.fast[slot] = i
		elif not c.addLongCode(code, length, count(i)):
			return false
	true

# the code of an entry longer than the fast table holds, put in the tree
fn addLongCode(mut c Codebook, code Count, length0 i64, entry Count):
	use noStops
	length = length0.clamp(1, 31)
	node = 0
	for b in 0..length:
		slot = count(count(node) * 2 + ((code >> b) & 1))
		if slot >= c.tree.len: return false
		cur = c.tree[slot]
		if b == length - 1:
			if cur != 0: return false
			c.setSlot(slot, entry * 2 + 1)
		elif cur == 0:
			child = count(c.tree.len / 2)
			c.setSlot(slot, child * 2)
			c.tree.push(0)
			c.tree.push(0)
			node = child
		elif (cur & 1) == 1:
			return false   # a shorter code begins this one
		else:
			node = count(cur) >> 1
	true

fn setSlot(mut c Codebook, slot Count, value i64):
	use noStops
	if slot < c.tree.len:
		c.tree[slot] = value

# the codes of the lengths in the order of the entries: the lowest free leaf for each; none when
# the lengths over-fill the tree
fn assignCodes(lengths u8[]) i64[]?:
	use noStops
	codes = zeros(lengths.len)
	available i64[32] = zeros(32)
	started = false
	for i in 0..lengths.len:
		length = i64(lengths[i])
		if length == vorbisNoCode: continue
		if length < 1 or length > 31 or i >= codes.len: return none
		if not started:
			started = true
			for d in 1..=length:
				available[d] = 1 << (32 - d)
			continue
		z = 0
		for d in 0..length:
			depth = length - d
			if z == 0 and available[depth & 31] != 0:
				z = depth
		if z == 0: return none
		res = available[z & 31] & 0xFFFF_FFFF
		available[z & 31] = 0
		codes[i] = bitReverse32(res)
		zz = z.clamp(0, 31)
		for y in zz + 1..=length:
			available[y & 31] = res + (1 << (32 - y))
	codes

# the lookup of a codebook: its vectors laid out whole (lookup type 1 expanded, so decoding never
# divides)
fn readVectors(mut c Codebook, mut br BitReader, lookupType i64):
	use noStops
	c.minimum = float32Unpack(br.take(32))
	delta = float32Unpack(br.take(32))
	valueBits = br.take(4) + 1
	c.sequence = br.take(1) != 0
	values = c.entries * c.dimensions
	if lookupType == 1:
		values = lookup1Values(c.entries, c.dimensions)
		if values <= 0: return false
	if values == 0 or values > 1 << 24 or c.entries * c.dimensions > 1 << 24: return false
	mults = []
	loop values:
		mults.push(br.read(valueBits))
	if br.short: return false
	if lookupType == 1: return c.expandLookup1(mults, delta)
	last = f32(0.0)
	for q in mults:
		val = f32(q) * delta + c.minimum + last
		c.vectors.push(val)
		if c.sequence:
			last = val
	true

# the vector of each entry of a lookup-1 book: the digits of its number in base lookupValues
fn expandLookup1(mut c Codebook, mults i64[], delta f32):
	use noStops
	for j in 0..c.entries:
		div = 1
		last = f32(0.0)
		loop c.dimensions:
			off = (j / count(div).max(1)) % mults.len.max(1)
			if off >= mults.len: return false
			val = f32(mults[off]) * delta + c.minimum + last
			c.vectors.push(val)
			if c.sequence:
				last = val
			div = count(div) * count(mults.len)
	true

fn readFloors(mut f Stream, mut br BitReader):
	use noStops
	floors = br.take(6) + 1
	loop floors:
		if br.take(16) != 1: return false   # floor 0: not supported
		g = Floor1()
		partitions = br.take(5) & 31
		g.partitions = partitions
		maxClass = -1
		for j in 0..partitions:
			pc = br.take(4) & 15
			g.partitionClass[j] = pc
			maxClass = maxClass.max(pc)
		last = maxClass.clamp(-1, 15)
		for j in 0..=last:
			g.classDimensions[j] = br.take(3) + 1
			subclasses = br.take(2) & 3
			g.classSubclasses[j] = subclasses
			if subclasses != 0:
				master = br.take(8) & 255
				g.classMasterbooks[j] = master
				if master >= f.codebooks.len: return false
			for k in 0..(1 << subclasses):
				b = i64(br.take(8) & 255) - 1
				if b >= f.codebooks.len: return false
				g.subclassBooks[j * 8 + k] = b
		g.multiplier = i64(br.take(2) & 3) + 1
		rangebits = i64(br.take(4) & 15)
		g.rangebits = rangebits
		g.xList[1] = 1 << rangebits
		n = 2
		for j in 0..partitions:
			loop (g.classDimensions[g.partitionClass[j] & 15] & 15):
				g.xList[n & 255] = br.take(rangebits)
				n = count(n) + 1
		values = count(n)
		if values < 2 or values > 31 * 8 + 2: return false
		g.values = values
		if not g.orderPoints(): return false
		f.floors.push(g)
	true

# the points in order of their x (sortedOrder), false when two share one, and the neighbours
# (the nearest lower and higher x among the points before) of each point
fn orderPoints(mut g Floor1):
	use noStops
	for j in 0..g.values:
		xj = g.xList[j]
		rank = 0
		for i in 0..g.values:
			xi = g.xList[i]
			if xi < xj:
				rank += 1
			elif xi == xj and i != j:
				return false
		g.sortedOrder[rank & 255] = j
	for j in 2..g.values:
		xj = g.xList[j]
		low = -1
		high = 65_536
		for i in 0..j:
			x = g.xList[i]
			if x > low and x < xj:
				g.neighborLow[j] = i
				low = x
			if x < high and x > xj:
				g.neighborHigh[j] = i
				high = x
	true

fn readResidues(mut f Stream, mut br BitReader):
	use noStops
	residues = br.take(6) + 1
	loop residues:
		kind = br.take(16)
		if kind > 2: return false
		r = Residue()
		r.kind = kind
		r.begin = br.read(24)
		r.end = br.read(24)
		r.partSize = count(br.read(24) + 1)
		classifications = i64(br.take(6) & 63) + 1
		r.classifications = classifications
		classbook = br.read(8)
		r.classbook = classbook
		if r.end < r.begin or classbook >= f.codebooks.len: return false
		cascade i64[64] = zeros(64)
		for j in 0..classifications:
			low = br.take(3)
			more = br.take(1) != 0
			high = br.take(5) if more else 0
			cascade[j] = high * 8 + low
		for j in 0..classifications:
			for k in 0..8:
				if (cascade[j] & (1 << k)) != 0:
					b = br.take(8) & 255
					if b >= f.codebooks.len: return false
					r.books.push(b)
				else:
					r.books.push(-1)
		entries = f.codebooks[classbook].entries
		classwords = f.codebooks[classbook].dimensions
		if classwords < 1 or entries * classwords > 1 << 24: return false
		r.classdata = zeros(entries * classwords)
		for j in 0..entries:
			temp = j
			for k in 0..classwords:
				at = j * classwords + (classwords - 1 - k)
				if at < 0 or at >= r.classdata.len: return false
				r.classdata[at] = temp % classifications
				temp /= classifications
		f.residues.push(r)
	true

fn readMappings(mut f Stream, mut br BitReader):
	use noStops
	mappings = br.take(6) + 1
	loop mappings:
		if br.take(16) != 0: return false
		m = Mapping()
		several = br.take(1) != 0
		m.submaps = i64(br.take(4) & 15) + 1 if several else 1
		if br.take(1) != 0:
			steps = i64(br.take(8) & 255) + 1
			if steps > 16 or steps > f.channels: return false
			m.couplingSteps = steps
			bits = ilog(f.channels - 1)
			for i in 0..steps:
				mag = br.take(bits) & 15
				ang = br.take(bits) & 15
				if mag >= f.channels or ang >= f.channels or mag == ang: return false
				m.magnitude[i] = mag
				m.angle[i] = ang
		if br.take(2) != 0: return false
		if m.submaps > 1:
			for j in 0..f.channels:
				mux = br.take(4) & 15
				m.mux[j] = mux
				if mux >= m.submaps: return false
		for j in 0..m.submaps:
			br.take(8)
			floor = br.take(8) & 255
			residue = br.take(8) & 255
			m.submapFloor[j] = floor
			m.submapResidue[j] = residue
			if floor >= f.floors.len or residue >= f.residues.len: return false
		f.mappings.push(m)
	true

fn readModes(mut f Stream, mut br BitReader):
	use noStops
	modes = br.take(6) + 1
	loop modes:
		blockflag = br.take(1)
		windowType = br.take(16)
		transformType = br.take(16)
		mapping = br.read(8)
		if windowType != 0 or transformType != 0 or mapping >= f.mappings.len: return false
		f.modes.push(Mode(blockflag, mapping))
	true

# the inverse MDCT and the window of a block size
fn initBlocksize(mut f Stream, n Block):
	use noStops
	n2 = n >> 1
	w = []
	for i in 0..n2:
		s = ((i + 0.5) / n2 * 0.5 * pi).sin()
		w.push(f32((0.5 * pi * s * s).sin()))
	f.mdcts.push(mdct.newMdct(n))
	f.windows.push(w)
