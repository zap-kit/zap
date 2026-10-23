# Regions as QuickDraw keeps them and as the drawing here works on them. In memory a region is
# its size and bounding box, then, unless it is a rectangle, its inversion lines: each a v and the
# h's where the coverage differs from the line above, ended by 0x7FFF, and a last 0x7FFF. Here a
# region is bands: runs of rows (top to bottom, exclusive) covered by the same spans, each span a
# pair of h's, start included and end not.

import cpu

pub type Band:
	top i64
	bottom i64
	xs i64[]   # pairs of edges, sorted

pub type Area:
	bands Band[]

	pub fn isEmpty() bool:
		bands.isEmpty

	# the bounding box: top, left, bottom, right (zeros when empty)
	pub fn box() (i64, i64, i64, i64):
		if bands.isEmpty: return (0, 0, 0, 0)
		left = 0x7FFF_FFFF
		right = -0x7FFF_FFFF
		for b in bands:
			left = left.min(b.xs[0])
			right = right.max(b.xs[len - 1])
		(bands[0].top, left, bands[len - 1].bottom, right)

	pub fn isRect() bool:
		bands.len == 1 and bands[0].xs.len == 2

	# the spans of row y, empty when none covers it
	pub fn spansAt(y i64) ref i64[]?:
		for i in 0..bands.len:
			if y < bands[i].top: return none
			if y < bands[i].bottom: return bands[i].xs
		none

	pub fn containsPoint(x i64, y i64) bool:
		xs = spansAt(y) ?? return false
		i = 0
		while i < xs.len:
			if x >= xs[i] and x < xs[i + 1]: return true
			i += 2
		false

	pub fn offset(dx i64, dy i64) Area:
		Area(bands = bands.map(Band(top = .top + dy, bottom = .bottom + dy, xs = .xs.map(it + dx))))

	# the region inside its edges by dx and dy (outside for negative ones), row by row
	pub fn inset(dx i64, dy i64) Area:
		if dx == 0 and dy == 0: return self.copy()
		if isRect():
			t, l, b, r = box()
			return rectArea(t + dy, l + dx, b - dy, r - dx)
		# a general region: shrunk (or grown) as the intersection (or union) of shifted copies
		out = self.copy()
		isShrinking = dx >= 0 and dy >= 0
		for (sx, sy) in [(dx.abs(), 0), (-dx.abs(), 0), (0, dy.abs()), (0, -dy.abs())]:
			out = out.combine(offset(sx, sy), 1 if isShrinking else 0)
		out

pub endMark = 0x7FFF

pub fn emptyArea() Area:
	Area(bands = [])

pub fn rectArea(top i64, left i64, bottom i64, right i64) Area:
	if bottom <= top or right <= left: return emptyArea()
	Area(bands = [Band(top, bottom, xs = [left, right])])

fn isIn(xs i64[], x i64):
	i = 0
	while i < xs.len:
		if x >= xs[i] and x < xs[i + 1]: return true
		i += 2
	false

# the spans of a boolean of two span lists: op 0 union, 1 intersection, 2 difference, 3 xor
fn combineSpans(a i64[], b i64[], op i64):
	edges = []
	edges.extend(a)
	edges.extend(b)
	edges.sort()
	out = []
	inside = false
	k = 0
	while k < edges.len:
		x = edges[k]
		inA = isIn(a, x)
		inB = isIn(b, x)
		now = match op:
			0: inA or inB
			1: inA and inB
			2: inA and not inB
			_: inA != inB
		if now != inside:
			out.push(x)
			inside = now
		while k < edges.len and edges[k] == x:
			k += 1
	out

fn pushBand(mut out Band[], top i64, bottom i64, move xs i64[]):
	if xs.isEmpty or bottom <= top: return
	if not out.isEmpty:
		last = out.len - 1
		if out[last].bottom == top and out[last].xs == xs:
			out[last].bottom = bottom
			return
	out.push(Band(top, bottom, xs))

# A boolean of two regions: op 0 union, 1 intersection, 2 difference (a less b), 3 xor.
pub fn combine(a Area, b Area, op i64) Area:
	ys = []
	for band in a.bands:
		ys.push(band.top)
		ys.push(band.bottom)
	for band in b.bands:
		ys.push(band.top)
		ys.push(band.bottom)
	ys.sort()
	out = []
	noSpans = []
	for k in 0..ys.len - 1:
		top = ys[k]
		bottom = ys[k + 1]
		if bottom == top: continue
		sa = a.spansAt(top) ?? noSpans
		sb = b.spansAt(top) ?? noSpans
		pushBand(out, top, bottom, combineSpans(sa, sb, op))
	Area(bands = out)

# ---------- in memory ----------

# The region in memory at the pointer (a region's handle dereferenced).
pub fn readArea(p u32) Area:
	size = i64(cpu.read16(p))
	top = i64(i16.wrap(i64(cpu.read16(p + 2))))
	left = i64(i16.wrap(i64(cpu.read16(p + 4))))
	bottom = i64(i16.wrap(i64(cpu.read16(p + 6))))
	right = i64(i16.wrap(i64(cpu.read16(p + 8))))
	if size <= 10: return rectArea(top, left, bottom, right)
	out = []
	edges = []
	at = p + 10
	y = i64(i16.wrap(i64(cpu.read16(at))))
	while y != endMark:
		at += 2
		flips = []
		x = i64(i16.wrap(i64(cpu.read16(at))))
		while x != endMark:
			flips.push(x)
			at += 2
			x = i16.wrap(i64(cpu.read16(at)))
		at += 2
		edges = combineSpans(edges, flips, 3)
		next = i64(i16.wrap(i64(cpu.read16(at))))
		if next != endMark: pushBand(out, y, next, edges.copy())
		y = next
	Area(bands = out)

# the words of a region as QuickDraw stores it
pub fn areaWords(a Area) i64[]:
	t, l, b, r = a.box()
	words = [0, t, l, b, r]
	if a.isRect() or a.isEmpty:
		words[0] = 10
		return words
	previous = []
	lastBottom = 0
	for band in a.bands:
		if not previous.isEmpty and band.top != lastBottom:
			# a gap: the row where the band above ends
			words.push(lastBottom)
			words.extend(previous)
			words.push(endMark)
			previous = []
		flips = combineSpans(previous, band.xs, 3)
		words.push(band.top)
		words.extend(flips)
		words.push(endMark)
		previous = band.xs.copy()
		lastBottom = band.bottom
	words.push(lastBottom)
	words.extend(previous)
	words.push(endMark)
	words.push(endMark)
	words[0] = words.len * 2
	words

# Writes a region into its handle, resized to hold it.
pub fn writeArea(h u32, a Area):
	words = a.areaWords()
	setHandleSize(h, u32(words.len * 2))
	p = address(cpu.read32(h))
	for i, word in words:
		setWord(p + u32(2 * i), word)

pub fn areaOfHandle(h u32) Area:
	if h == 0: return emptyArea()
	readArea(address(cpu.read32(h)))
