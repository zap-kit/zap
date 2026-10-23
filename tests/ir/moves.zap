# move out of places through the intermediate form: an owned value leaves a field (the place
# left empty), a map leaves a field; nothing leaks.
#
# a plain struct moved out of a local, and fields moved out of it: the places read zero after
#
# A struct of numbers moved into a function travels as its words on the stack (the one calling
# convention of both backends), read as leaves; a moved str or list is the callee's to drop.
#
# Owned values given to a function through the intermediate form (move parameters): kept,
# returned, dropped at their last use or at the end; nothing left behind.

type Bag:
	items str[]
	tags {str: i64}
	n i64

fn drain(mut b Bag):
	taken = move b.items
	b.n = 0
	taken

fn tagsOf(mut b Bag) {str: i64}:
	move b.tags

fn churnBags(k i64):
	before = liveBlocks()
	total = 0
	for i in 0..k:
		b = Bag(items = ["a", "b{i}"], tags = {"t": i}, n = 2)
		got = b.drain()
		total += got.len
		m = b.tagsOf()
		total += m.len
	total > 0 and liveBlocks() == before

test "moves out of places":
	b = Bag(items = ["x", "y"], tags = {"p": 1}, n = 2)
	got = b.drain()
	m = b.tagsOf()
	print("{got} {b.n} {m.len} {churnBags(40)}")
	prints "[\"x\", \"y\"] 0 1 true"

type S0:
	f0 i32
	f1 bool
	f2 u16

type Holder0:
	Some(s S0, k f32)
	Nothing

fn tuple0(s S0, k f32, b u8):
	(s, k, b)

fn maybe0(s S0) S0?:
	s

test "a plain struct moved out of a local, and fields moved out of it, leave zeros":
	v1 = S0(f0 = 1172, f1 = false, f2 = 24_865)
	v2 = move v1
	print("v2: {v2.f0} {v2.f1} {v2.f2}")
	x3 = move v1.f2
	print("x3: {x3}")
	x4 = move v1.f2
	print("x4: {x4}")
	x5 = move v1.f0
	print("x5: {x5}")
	print("v1: {v1.f0} {v1.f1} {v1.f2}")
	print("v2: {v2.f0} {v2.f1} {v2.f2}")
	prints """
	v2: 1172 false 24865
	x3: 0
	x4: 0
	x5: 0
	v1: 0 false 0
	v2: 1172 false 24865
	"""

type Sym:
	ptr i64
	value i64
	storage i64

type Symbols:
	syms {i64: Sym}
	names str[]

fn addSym(mut t Symbols, decl i64, move s Sym):
	t.syms[decl] = s

fn weight(move s Sym, move label str):
	s.ptr + s.value * 10 + s.storage * 100 + label.len

fn fill(mut t Symbols):
	t.addSym(1, Sym(ptr = 1, value = 2, storage = 3))
	t.addSym(2, Sym(ptr = 4, value = 5, storage = 6))
	t.names.push("a")

fn churnSymbols(n i64):
	before = liveBlocks()
	k = 0
	for i in 0..n:
		u = Symbols(syms = {}, names = ["n{i}"])
		u.fill()
		k += u.syms.len
	k == 2 * n and liveBlocks() == before

test "a struct of words moved into a map or a function travels whole":
	t = Symbols(syms = {}, names = [])
	t.fill()
	s = t.syms.get(2) ?? Sym(ptr = 0, value = 0, storage = 0)
	print(
		"{t.syms.len} {s.value} {weight(Sym(ptr = 1, value = 2, storage = 3), "x")} {churnSymbols(20)}"
	)
	prints "2 5 322 true"

fn keep(move words str[], move extra str):
	out = words
	out.push(extra)
	out

fn lengthOf(move s str):
	s.len

fn churnGiven(n i64):
	before = liveBlocks()
	total = 0
	for i in 0..n:
		ws = keep(["a{i}", "b"], "c{i}")
		total += ws.len + lengthOf("{i}xyz")
	total > 0 and liveBlocks() == before

test "given values kept, returned and dropped":
	print("{keep(["a", "b"], "c")} {lengthOf("abcd")} {churnGiven(200)}")
	prints "[\"a\", \"b\", \"c\"] 4 true"

fn matrixFirst():
	(Mat3(m = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]), Vec3(10.0, 11.0, 12.0))

type Frame:
	pivot Vec3
	axes Mat3

fn split(f Frame):
	m = f.axes.m
	(f.pivot * 2.0, Mat3(Vec3(m[0], m[1], m[2]), Vec3(m[3], m[4], m[5]), Vec3(m[6], m[7], m[8])))

fn splitTwice(f Frame):
	p, x = f.split()
	q, y = f.split()
	print("{x.m[0]} {y.m[0]} {p.x} {q.x}")

test "a value taken out of a tuple empties its own bytes alone, not its neighbour's":
	m, v = matrixFirst()
	print("{m.m[8]} {v}")
	splitTwice(Frame(pivot = Vec3(1, 2, 3), axes = Mat3(m = [0.5, 1, 0, 0, 0, 1, 1, 0, 0])))
	prints """
		9 Vec3(x = 10, y = 11, z = 12)
		0.5 0.5 2 2
		"""

# a local moved out before a loop that calls, and dropped on the way out of the loop (a failed
# try): the loop keeps no scalar of the empty place, whose reads the ownership check refuses
type Failed:
	why str

type Counter:
	seen i64[] = []
	step fn(i64) i64 = keepStep

fn keepStep(x i64):
	x

fn nth(c Counter, args str[], k i64) str ? Failed:
	if k >= args.len: return Failed(why = "none")
	args[k].copy()

fn rest(mut c Counter, text str, args str[]) str[] ? Failed:
	if args.isEmpty or args[0] == "": return [text.copy()]
	sep = try c.nth(args, 0)
	text.split(sep).map(.copy())

fn joined(mut c Counter, kind str, args str[]) str ? Failed:
	text = args[0].copy()
	match kind:
		"rest": c.seen.push((try c.rest(text, args)).len)
		"join":
			out = text
			for k in 0..args.len:
				out = "{out}{try c.nth(args, k)}"
			return out
		_: pass
	""

test "a loop that calls holds no scalar of a place already moved out":
	c = Counter()
	print(c.joined("join", ["a", "b", "c"]) ?? "failed")
	prints """
		aabc
		"""
