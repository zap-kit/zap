# Prefix codes read through lookup tables, as FFmpeg's VLC reads them: the next `rootBits` bits
# index the root table, whose entry is a symbol and its length, or a link to a table indexed by
# the bits after them, for the codes longer than the root.

# a symbol no code gives: the bits read are no code of the table
vlcInvalid = -1_000_000

# A prefix code as tables: each entry a symbol and its length (from the table's first bit), or a
# link to the next table (a negative length: minus the bits that index it; the symbol: where it
# starts), or neither (length 0: no code begins so).
type Vlc:
	rootBits i64
	symbols i64[] = []
	lengths i64[] = []

# The tables of codes[i] of lengths[i] bits standing for symbols[i] (none longer than 32 bits).
fn newVlc(codes i64[], lengths i64[], symbols i64[], rootBits i64):
	v = Vlc(rootBits)
	v.addTable(codes, lengths, symbols, (0..codes.len).map(it), 0, rootBits)
	v

# appends the table of `bits` bits over the codes `which`, whose first `done` bits the tables
# before it read; where it starts
fn addTable(
	mut v Vlc,
	codes i64[],
	lengths i64[],
	symbols i64[],
	which i64[],
	done i64,
	bits i64
) i64:
	start = v.symbols.len
	size = 1 << bits
	v.symbols.extend(zeros(size))
	v.lengths.extend(zeros(size))
	longer {i64: i64[]} = {}
	for i in which:
		left = lengths[i] - done
		rest = codes[i] & ((1 << left) - 1)
		if left <= bits:
			first = rest << (bits - left)
			for e in first..first + (1 << (bits - left)):
				v.symbols[start + e] = symbols[i]
				v.lengths[start + e] = left
		else:
			key = rest >> (left - bits)
			if key not in longer: longer[key] = []
			longer[key].push(i)
	for key in longer.keys():
		group = longer[key]
		deepest = 0
		for i in group:
			deepest = deepest.max(lengths[i] - done - bits)
		subBits = deepest.min(v.rootBits)
		v.symbols[start + key] = v.addTable(codes, lengths, symbols, group, done + bits, subBits)
		v.lengths[start + key] = -subBits
	start

# The next symbol of the code, its bits taken; vlcInvalid when they are no code of it.
fn readVlc(v Vlc, mut br BitReader):
	start = 0
	bits = v.rootBits
	loop 8:
		e = start + br.peek(bits)
		length = v.lengths[e]
		if length > 0:
			br.skip(length)
			return v.symbols[e]
		if length == 0: return vlcInvalid
		br.skip(bits)
		start = v.symbols[e]
		bits = -length
	vlcInvalid
