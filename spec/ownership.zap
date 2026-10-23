# 4. Memory model
#
# Ownership with borrowing: no garbage collector, no reference counting of ordinary values, and no
# copy the model forces. Origins are inferred, so everyday code shows none of the machinery. Runtime
# cost: no collector, no counters, no pause. Writing cost: `move`, `mut ref` and an occasional
# reordering. Reading cost: who owns and who may change what is in the signature.
#
# 4.1 Ownership and destruction
#
# One owner: every value has exactly one, a variable, a field, a list element, a map entry or a
# `move` parameter. The owner holds it inline: a struct in a list is its bytes, not a pointer; `T[]`
# is one contiguous block of `T`; `str` is one buffer.
#
# Destruction at the last use: a value is destroyed right after its owner's last use on each path
# (in each branch of an `if` after the branch's own last use, after a loop that uses it), at the
# end of the scope when no statement after the one that made it uses it, when stored over, or
# never by this owner if moved out. A temporary is destroyed right after the call that reads it,
# unless the call's value may point into it (a reference, a window, an optional of one, a list of
# them): then it lives to the end of the statement, or, bound to a variable, to that variable's
# last use. A borrow keeps its origin alive until the borrow's last use.

fn made():
	[1, 2, 3].map(it * 2)

fn longText():
	"abc".repeat(10)

type Pair:
	name str
	note str

fn makePair():
	Pair(name = "abc".repeat(5), note = "x".repeat(50))

test "a temporary dies right after the call that reads it":
	before = liveBlocks()
	a = made().len == 3 and liveBlocks() == before
	b = ("{longText()}!").len == 31 and liveBlocks() == before
	c = "ca" in longText() and liveBlocks() == before
	expect a
	expect b
	expect c

test "a result pointing into a temporary keeps it to the statement's end":
	expect ((made().first ?? 0) + (made().last ?? 0)) == 8
	expect longText()[..3] == "abc"

test "a value is destroyed after its owner's last use":
	before = liveBlocks()
	xs = made()
	n = xs.len
	kept = 0
	for i in 0..2:
		kept += xs[i]
	expect n == 3
	expect kept == 6
	expect liveBlocks() == before

test "a value dies right after its last use, inside a statement too":
	before = liveBlocks()
	xs = made()
	gone = xs.len == 3 and liveBlocks() == before
	expect gone

fn lastIn(big bool):
	before = liveBlocks()
	xs = made()
	if big: return xs.len == 3 and liveBlocks() == before
	liveBlocks() == before   # the branch that does not use it drops it on entry

test "a value dies on each path where it is used no more":
	expect lastIn == {true: true, false: true}

# Moves: assignment, passing to a `move` parameter, returning, pushing into a list and storing into
# a field move the value; a local not used again moves. A field or element of a local that is not
# read again moves out, leaving that place empty, and so does a binding of one at the local's last
# use (no statement after it names the local, no next iteration reads it), where it would borrow it
# otherwise. No `move` is written there (zap fmt drops it). A field or element of a temporary moves
# out of it; the rest is destroyed at the end of the statement.

type Tok:
	text str
	kind i64

type Glb:
	order str[]
	clips str[]
	toks Tok[]

type Rig:
	order str[]
	clips str[]

fn rigOf(move g Glb):
	Rig(order = g.order, clips = g.clips)

fn fromLocal():
	g = Glb(order = ["a"], clips = ["b"], toks = [])
	Rig(order = g.order, clips = g.clips)

fn boundField():
	g = Glb(order = ["a"], clips = ["b"], toks = [])
	order = g.order   # g's last use: the field moves into the binding
	order

fn boundMutField():
	g = Glb(order = ["a"], clips = ["b"], toks = [])
	order = g.order
	order.push("c")
	order

fn elementText(i i64):
	g = Glb(order = [], clips = [], toks = [Tok(text = "x", kind = 1), Tok(text = "y", kind = 2)])
	text = g.toks[i].text
	text

fn earlyMove():
	g = Glb(order = ["a"], clips = ["b"], toks = [])
	order = move g.order   # explicit: g is used again below
	g.clips.push("c")
	Rig(order, clips = g.clips)

test "fields of a local not used again move out without move":
	r = rigOf(Glb(order = ["p"], clips = ["q"], toks = []))
	l = fromLocal()
	expect r.order == ["p"]
	expect r.clips == ["q"]
	expect l.order == ["a"]
	expect l.clips == ["b"]
	print("{boundField()} {boundMutField()} {elementText(1)} {earlyMove().clips}")
	prints """
		["a"] ["a", "c"] y ["b", "c"]
		"""

test "a field moved out of a temporary leaves the rest destroyed":
	before = liveBlocks()
	n = makePair().name
	expect liveBlocks() == before + 1 and n.len == 15

test "a field read after it moved out" refuses UseAfterPartGiven:
	type G:
		order str[]
		clips str[]
	g = G(order = ["a"], clips = ["b"])
	mut out str[,] = []
	out.push(g.order)
	print(g.order)

test "a binding of a field given away takes the field out of its owner when nothing reads it after":
	g = Glb(order = ["a"], clips = ["b"], toks = [])
	order = g.order   # a borrow of the field
	print(g.clips)   # the owner's other fields stay usable
	out = []
	out.push(order)   # the field taken out of g: g.order is not read again
	print(out)
	prints """
		["b"]
		[["a"]]
		"""

test "a binding of a field inside a loop borrows it: the next iteration reads the owner" refuses MoveOfPart:
	type G:
		order str[]
		clips str[]
	g = G(order = ["a"], clips = ["b"])
	mut out str[,] = []
	loop 2:
		order = g.order
		out.push(order)

fn firstOrAll(words str[]):
	out = ["start"]
	first = words.first ?? return out   # out moves only when it leaves
	out.push(first.copy())
	out

test "a value moved by a leaving ?? stays on the other path":
	expect firstOrAll(["a"]) == ["start", "a"]
	expect firstOrAll([]) == ["start"]

test "a moved value is gone" refuses UseAfterMove:
	names = ["ana", "bo"]
	taken = move names
	print("{taken.len} {names.len}")

# No hidden copy: where a move would be wrong (the variable is used again, the value belongs to a
# parameter or is behind a reference, the next iteration reads it), the program does not compile,
# and the error says what to write: use the value before giving it away, take a `move` parameter,
# keep a reference, `move` the value out of its place, or write `.copy()` (a deep copy). Every deep
# copy is written, so a reviewer sees each one; zap fmt drops one a borrow or a move serves, the
# program checked again without it, its ownership too (13.1.3).

type P:
	name str
	tags str[]

fn pick(xs str[]) ref str:
	xs[0]

test "the explicit way":
	names = ["a", "b"]
	first = names[0].copy()
	names.push("c")
	print("{first} {pick(names)}")
	s = "x"
	out = []
	loop 3:
		out.push(s.copy())
	ps = [P(name = "a", tags = ["t"])]
	p = ps[0].copy()
	p.name = "b"
	print("{out.len} {p.name} {ps[0].name}")
	stock {str: P} = {}
	stock["k"] = P(name = "potion", tags = [])
	item = stock.get("k")?.name ?? "none"
	stock["k"] = P(name = "elixir", tags = [])
	label = stock.get("k")?.name ?? "-"
	print("{item} {label}")
	greet = (who str): "hi {who}"
	prefix = "pre"
	mk = (): "{prefix}!"
	print("{greet(prefix)} {mk()}")
	prints """
		a a
		3 b a
		potion elixir
		hi pre pre!
		"""

test "an element is not returned as a value" refuses MoveOfPart:
	fn pick(xs str[]) str:
		xs[0]
	print(pick(["a"]))

test "a part given away in a loop's turn: the next turn's binding is a value of its own":
	names = []
	texs = []
	for line in "new a\nmap b\nnew c".lines():
		parts = line.split(" ")
		if parts[0] == "new":
			names.push(parts[1])
		elif parts[0] == "map":
			texs.push(parts[len - 1])
	print("{names} {texs}")
	prints """
		["a", "c"] ["b"]
		"""

test "a lambda's element is not given away: a later turn may read the same one" refuses MoveOfPart:
	words = ["pear", "fig"]
	idx = [0, 0]
	print(idx.map(words[it]))

test "a value is not given away in every iteration" refuses GivenAwayInLoop:
	s = "x"
	mut out str[] = []
	loop 3:
		out.push(s)
	print(out.len)

test "a mut binding needs a value of its own" refuses MutBindingOfBorrowed:
	type P:
		name str
	ps = [P(name = "a")]
	mut p = ps[0]
	p.name = "b"
	print("{p.name} {ps[0].name}")

# Plain data copies implicitly: numbers, `bool`, and structs, enums, tuples and arrays made only of
# plain data. They own nothing, so the copy is free. A copy of plain data that is only changed and
# never read is refused (a lost change): the message shows `m = mut ref monsters[i]` or writing
# it back.

type Spot:
	x i64
	y i64

test "plain data copies":
	a = Spot(x = 1, y = 2)
	b = a
	b.x = 5
	t = 1, 2.5
	u = t
	u = 2, 0.5
	print("{a.x} {b.x} {t} {u}")
	prints "1 5 (1, 2.5) (2, 0.5)"

test "a lost change is an error" refuses ChangedCopyLost:
	type M:
		hp i64
	monsters = [M(hp = 3)]
	mut m = monsters[0]
	m.hp -= 1

# Drop functions: a struct that releases something besides memory declares `mut fn drop()` in its block,
# called wherever a value of T is destroyed (a store over it, the end of the list, map or struct
# holding it), once, before its fields are destroyed; a program never calls it. A local holding
# such a value (or a struct, list or optional holding one) lives to its scope's end instead of its
# last use, since what it releases may still be used without naming it; locals end the last bound
# first. Such a type is not plain data: it moves, does not meet `Copy`, and `.copy()` of it is
# refused unless the type declares `fn copy() T` in its block. Each value made of it is dropped once,
# whatever its fields hold (`Handle(id = 0)` too); the empty value `move` leaves in a place is not.
# `if x is v`, and `x ?? y` or a match of a place whose other arms leave (`?? fail(...)`, `??
# return`), lend it where it is; when another arm gives a value, it is taken out of the place if
# nothing reads the place after, and refused otherwise.
# The type takes no type parameters.

type Noisy:
	id i64

	mut fn drop():
		print("drop {id}")

type NoisyPair:
	a Noisy
	b Noisy
	name str

type Holder:
	n Noisy
	name str

fn noisy(id i64):
	Noisy(id)

fn eat(move n Noisy):
	print("eat {n.id}")

fn sum(ok bool):
	a = noisy(1)
	b = noisy(2)
	if ok: return a.id + b.id
	print("not ok")
	0

fn takeOut(mut h Holder):
	move h.n

fn twoLocals():
	a = noisy(1)
	b = noisy(2)
	print("{a.id} {b.id}")
	print("after")

test "a local is dropped at its scope's end, not at its last use, the last bound first":
	twoLocals()
	prints """
		1 2
		after
		drop 2
		drop 1
		"""

test "a moved value is dropped once, by its new owner":
	c = noisy(3)
	eat(c)
	print("after eat")
	prints """
		eat 3
		drop 3
		after eat
		"""

fn containers():
	xs = []
	xs.push(noisy(4))
	xs.push(noisy(5))
	print(xs.len)
	p = NoisyPair(a = noisy(6), b = noisy(7), name = "p")
	print("{p.a.id} {p.name}")
	m {str: Noisy} = {}
	m["x"] = noisy(8)
	m["x"] = noisy(9)   # the value stored over is dropped
	print(m.len)
	o Noisy? = noisy(10)
	if o is v: print(v.id)

test "values in a list, a struct, a map and an optional are dropped with them":
	containers()
	prints """
		2
		6 p
		drop 8
		1
		10
		drop 10
		drop 9
		drop 6
		drop 7
		drop 4
		drop 5
		"""

fn storeOver():
	v = noisy(1)
	v = noisy(2)
	print(v.id)

test "a store over a value drops it":
	storeOver()
	prints """
		drop 1
		2
		drop 2
		"""

test "an early return and a break drop what is live":
	print(sum(true))
	print(sum(false))
	for i in 0..3:
		t = noisy(10 + i)
		if i == 1: break
		print("loop {t.id}")
	print("end")
	prints """
		drop 2
		drop 1
		3
		not ok
		drop 2
		drop 1
		0
		loop 10
		drop 10
		drop 11
		end
		"""

fn movedOut():
	h = Holder(n = noisy(5), name = "h")
	n = h.takeOut()
	print("took {n.id}")
	print(h.name)

test "a value moved out of its place leaves the empty value, which is not dropped":
	movedOut()
	prints """
		took 5
		h
		drop 5
		"""

type Counted:
	id i64

	mut fn drop():
		print("drop {id}")

	fn copy():
		Counted(id = id + 100)

fn copied():
	a = Counted(id = 1)
	b = a.copy()
	print("{b.id} {a.id}")

test "a type with a drop function copies through its own copy function":
	copied()
	prints """
		101 1
		drop 101
		drop 1
		"""

test "a value with a drop function is not copied" refuses DropTypeNotCopied:
	type Noisy:
		id i64

		mut fn drop():
			print(id)
	a = Noisy(id = 1)
	b = a.copy()
	print(b.id)

test "drop is not called by the program" refuses DropCalled:
	type Noisy:
		id i64

		mut fn drop():
			print(id)
	a = Noisy(id = 1)
	a.drop()

test "a drop function changes its value and takes nothing else" refuses DropSignature:
	type Noisy:
		id i64

		fn drop(n i64):
			print(id + n)
	print(Noisy(id = 1).id)

test "a drop function belongs to a struct without type parameters" refuses DropGeneric:
	type Cell<T>:
		v T

		mut fn drop():
			print("x")
	print(Cell(v = 1).v)

# `move place` takes a value out of a field, an element, a `mut` parameter or a variable that
# changes (2.4), which keeps its type's empty value (`""`, `[]`, `none`, `0`, `{}`) and stays
# usable. A variable nothing changes is moved whole, and a later use is an error. On a number it reads and zeroes the place,
# so `xs[k] = move xs[k + 1]` shifts elements of any type without copies (`str(move bytes)`: 7.5).

type Player:
	name str
	tags str[]

fn grab(mut slot str[]) str[]:
	move slot

test "move takes a value out of its place":
	p = Player(name = "ana", tags = ["a", "b"])
	old = move p.name
	print("{old}|{p.name}|{p.tags.len}")
	p.name = "bia"
	xs = ["x", "y", "z"]
	xs[0] = move xs[1]
	print("{p.name} {xs}")
	words = ["keep"]
	got = grab(words)
	print("{got} {words.len}")
	words.push("again")
	line = "first"
	lines = []
	lines.push(move line)
	line = "second"
	lines.push(move line)
	print("{words} {lines} [{line}]")
	n = 7
	k = move n
	print("{k} {n}")
	prints """
		ana||2
		bia ["y", "", "z"]
		["keep"] 0
		["again"] ["first", "second"] []
		7 0
		"""

test "move of a field needs a mutable root" refuses NeedsMut:
	type P:
		name str

	fn take(p P) str:
		move p.name
	print(take(P(name = "a")))

# A choice of places that is only read lends the place it picks (never freed by the reader).
# `filter` copies the elements it keeps; lookups (`first`, `max`, `get`, ...) and a part
# (`xs[a..b]`) lend.

type Person:
	name str
	tags str[]

fn shout(s str):
	s.upper()

test "a choice of places is read, not freed":
	a = Person(name = "{"al".repeat(1)}pha", tags = ["x", "y"])
	b = Person(name = "{"be".repeat(1)}ta", tags = ["x"])
	pickA = a.name.len > 3
	print("{shout(a.name if pickA else b.name)} {a.name if not pickA else b.name}")
	tags = a.tags if pickA else b.tags
	print(
		"{a.name if pickA else b.name} {tags.len} {(b.tags if pickA else a.tags)[0]} {a.name}"
	)
	prints """
		ALPHA beta
		alpha 2 x alpha
		"""

type Frame:
	width i64
	pixels u8[]

# a reference into the list a choice of places picks: into the place itself, no copy made
fn frameOf(small Frame[], large Frame[], big bool, i i64) ref Frame?:
	frames = large if big else small
	if i >= frames.len: return none
	frames[i]

test "an element of a choice of places is the place's own":
	small = [Frame(width = 2, pixels = [1, 2])]
	large = [Frame(width = 8, pixels = [3])]
	loop 2:
		if frameOf(small, large, false, 0) is f: print("{f.width} {f.pixels}")
		if frameOf(small, large, true, 0) is f: print("{f.width} {f.pixels}")
	prints """
		2 [1, 2]
		8 [3]
		2 [1, 2]
		8 [3]
		"""

test "filter copies, lookups and parts lend":
	words = ["ab", "cd", "ef"]
	kept = words.filter(.len == 2)
	words[0] = "zz"
	print("{kept} {words}")
	prints "[\"ab\", \"cd\", \"ef\"] [\"zz\", \"cd\", \"ef\"]"

type Tables:
	a {str: i64} = {}
	b {str: i64} = {}

fn lookupIn(c Tables, first bool):
	table = c.a if first else c.b
	table.get("k") ?? -1

test "a map of a choice of places is the place's own":
	c = Tables()
	c.a["k"] = 1
	c.b["k"] = 2
	loop 2:
		print("{c.lookupIn(true)} {c.lookupIn(false)}")
	prints """
		1 2
		1 2
		"""
