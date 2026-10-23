# Optionals without a tag (spec 14.2): a pool's Handle<T>? is the handle alone, 0 for none (a
# pool's generations start at 1); an enum's optional is the enum, none the variant count. Every
# test of the first word (try, ??, == none, patterns, ?., the drop and copy functions, the empty
# value move leaves) compares with the type's absent word.

type Color:
	Red
	Green
	Blue

type Shape:
	Circle(radius f64)
	Label(text str)
	Empty

type Unit:
	name str

type Slot:
	color Color? = none
	shape Shape? = none
	unit Handle<Unit>? = none

fn colorAt(i i64) Color?:
	if i == 0: return .Red
	if i == 1: return .Blue
	none

fn shapeAt(i i64) Shape?:
	if i == 0: return .Label("a{i}")
	if i == 1: return .Circle(2.0)
	none

fn named(c Color):
	match c:
		Red: "red"
		Green: "green"
		Blue: "blue"

fn colorName(i i64) str?:
	c = try colorAt(i)
	c.named()

fn shapeText(i i64) str?:
	s = try shapeAt(i)
	match s:
		Label(t): t
		Circle(r): "circle {r}"
		Empty: "empty"

fn firstOf<T Copy>(xs T[]) T?:
	xs[0] if xs.len > 0 else none

type Node:
	v i64

fn boxed(i i64) Box<Node>?:
	Box(Node(v = i)) if i > 0 else none

fn boxedTwice(i i64) Box<Node>?:
	b = try boxed(i)
	Box(Node(v = b.v * 2))

fn found(pool Pool<Unit>, name str) Handle<Unit>?:
	for h in pool.handles():
		if pool[h].name == name: return h
	none

fn foundTwice(pool Pool<Unit>, name str) Handle<Unit>?:
	h = try found(pool, name)
	h

test "an enum's optional: the first variant is a value, none another word":
	out = []
	for i in 0..3:
		c = colorAt(i)
		out.push("{c} {c == none} {c != none} {named(c ?? .Green)}")
		match c:
			Red: out.push("is red")
			v: out.push("is {v.named()}")
			none: out.push("is none")
		if c is v:
			out.push("bound {v.named()}")
	expect out.join("|") == "some(Red) false true red|is red|bound red|some(Blue) false true blue|is blue|bound blue|none true false green|is none"
	expect colorName == {0: "red", 1: "blue", 2: none}

test "an enum carrying values: its optional owns what the variant holds":
	out = []
	for i in 0..3:
		s = shapeAt(i)
		kept = s
		out.push("{s} {s == none} {shapeText(i) ?? "-"}")
		if kept is Label(t):
			out.push("label {t}")
		taken = s ?? .Empty
		out.push("{taken}")
	print(out.join("|"))
	prints """
		some(Label("a0")) false a0|label a0|Label("a0")|some(Circle(2)) false circle 2|Circle(2)|none true -|Empty
		"""

test "a moved optional leaves none, and an array of optionals starts from it":
	c Color? = .Red
	s Shape? = .Label("x")
	a = move c
	b = move s
	cs Color?[3]
	ss Shape?[2]
	ns n32?[2]
	n n32? = 3
	m = move n
	print("{a} {c} {b} {s} {cs[0]} {cs[2]} {ss[1]} {ns} {m} {n}")
	list = [colorAt(0), colorAt(2)]
	first = move list[0]
	print("{first} {list}")
	c = .Blue
	s = .Empty
	n = 4
	print("{c} {s} {n}")
	prints """
		some(Red) none some(Label("x")) none none none none [none, none] some(3) none
		some(Red) [none, none]
		some(Blue) some(Empty) some(4)
		"""

test "a pool's handle optional: none is no handle, and handles start at generation 1":
	pool = Pool<Unit>()
	a = pool.add(Unit(name = "orc"))
	b = pool.add(Unit(name = "elf"))
	print("{a.gen} {found(pool, "elf") == none} {found(pool, "imp") == none}")
	print("{foundTwice(pool, "orc")?.index} {foundTwice(pool, "imp")?.index}")
	pool.remove(a)
	c = pool.add(Unit(name = "bat"))
	hs Handle<Unit>?[] = [a, none, c]
	alive = 0
	for h in hs:
		match h:
			x: alive += 1 if x in pool else 0
			none: alive += 10
	print("{c.gen} {alive} {(found(pool, "bat") ?? b).index}")
	prints """
		1 false true
		some(0) none
		2 11 0
		"""

test "struct fields of tagless optionals, copied and dropped":
	slots = [Slot(), Slot(color = .Blue, shape = .Label("deep"))]
	pool = Pool<Unit>()
	slots[0].unit = pool.add(Unit(name = "u"))
	copied = slots.copy()
	slots[1].shape = none
	print("{copied[1].shape} {slots[1].shape} {copied[0].unit != none} {copied[1].unit == none}")
	print("{copied[1].color} {slots[0].color}")
	prints """
		some(Label("deep")) none true true
		some(Blue) none
		"""

test "nested, in maps, compared, encoded, and tried for a box":
	nested Color?[] = [none, .Green]
	print("{firstOf(nested)} {firstOf([Color.Blue])} {firstOf(nested) == none}")
	m {str: Color?} = {}
	m["a"] = .Red
	m["b"] = none
	print("{m.get("a")} {m.get("b")} {m.get("c")} {m["a"]}")
	print("{nested[0] == nested[0]} {nested[0] == nested[1]} {nested[1] == nested[1]}")
	p = Slot(color = .Red, shape = .Label("hi"))
	text = p.toJson()
	print("{text} {Slot().toJson()}")
	print("{Slot.fromJson(text) ?? Slot()} {Slot.fromBytes(p.toBytes()) ?? Slot()}")
	pool = Pool<Unit>()
	q = Slot(unit = pool.add(Unit(name = "u")))
	print(Slot.fromBytes(q.toBytes()) ?? Slot())
	print("{boxedTwice(3)?.v} {boxedTwice(0)?.v}")
	prints r"""
		some(none) some(Blue) false
		some(some(Red)) some(none) none some(Red)
		true false true
		{"color":{"$tag":"Red"},"shape":{"$tag":"Label","text":"hi"},"unit":null} {"color":null,"shape":null,"unit":null}
		Slot(color = some(Red), shape = some(Label("hi")), unit = none) Slot(color = some(Red), shape = some(Label("hi")), unit = none)
		Slot(color = none, shape = none, unit = some(Handle<Unit>(index = 0, gen = 1)))
		some(6) none
		"""

type Pair<T>:
	v T?
	n u8

fn kept<T>(x T, keep bool) T?:
	if keep: return x
	none

fn wordOf(s str, i i64) ref str?:
	if i == 0: return none
	s

test "an optional's own tag keeps none for its optional, a window's length for its":
	inner i64? = none
	four i64? = 4
	nested = [kept(inner, true), kept(inner, false), kept(four, true)]
	print("{nested} {nested.byteSize / 3} {nested[0] == nested[1]} {nested[2] == nested[2]}")
	m {str: i64?} = {"a": 1, "b": none}
	print("{m.get("a")} {m.get("b")} {m.get("c")}")
	pairs Pair<i64?>?[] = [Pair<i64?>(v = kept(inner, true), n = 7), none]
	copied = pairs.copy()
	pairs[0] = none
	print("{copied} {pairs} {pairs.byteSize}")
	p = Pair<i64?>(v = kept(four, true), n = 1)
	text = p.toJson()
	print("{text} {Pair<i64?>.fromJson(text) ?? p} {Pair<i64?>.fromBytes(p.toBytes()) ?? p}")
	moved = nested[2]
	nested[2] = none
	print("{moved} {nested[2]}")
	words = [wordOf("abc", 0), wordOf("de", 1)]
	print("{words} {words.byteSize / 2} {words[1] ?? "-"} {words[0] ?? "-"}")
	match words[1]:
		none: print("empty")
		w: print("holds {w.len}")
	prints r"""
		[some(none), none, some(some(4))] 16 false true
		some(some(1)) some(none) none
		[some(Pair<i64?>(v = some(none), n = 7)), none] [none, none] 48
		{"v":4,"n":1} Pair<i64?>(v = some(some(4)), n = 1) Pair<i64?>(v = some(some(4)), n = 1)
		some(some(4)) none
		[none, some("de")] 16 de -
		holds 2
		"""

type Named:
	name str
	tags str[]
	n i64

type Outer:
	inner Named
	k u8

fn namedAt(i i64) Named?:
	if i == 0: return none
	Named(name = "n{i}", tags = ["t{i}"], n = i)

fn took(move s str):
	"took {s}"

fn firstName(move o Named?):
	if o is v: return took(v.name)
	"-"

test "a str's or a list's cap keeps a struct's none, a part moved out leaving it some":
	kept Named?[] = [namedAt(1), none, namedAt(2)]
	copied = kept.copy()
	kept[0] = none
	print("{copied} {kept} {kept.byteSize / 3}")
	x = namedAt(5)
	if x is w:
		print(took(w.name))
	print("{x} {x == none}")
	print("{firstName(namedAt(3))} {firstName(none)}")
	y = namedAt(6)
	moved = move y
	print(moved)
	m {str: Named?} = {"a": namedAt(7), "b": none}
	print("{m.get("b")} {m.get("c")} {m.get("a") != none}")
	text = namedAt(8).toJson()
	print("{text} {Named.fromJson(text)?.name}")
	outers Outer?[] = [Outer(inner = namedAt(9) ?? Named(name = "", tags = [], n = 0), k = 1), none]
	if outers[0] is o:
		print("{o.inner.name} {outers[1]} {outers.byteSize / 2}")
	total = 0
	for i in 0..4:
		match namedAt(i % 2):
			none: total += 100
			v:
				total += took(v.name).len
	print(total)
	prints r"""
		[some(Named(name = "n1", tags = ["t1"], n = 1)), none, some(Named(name = "n2", tags = ["t2"], n = 2))] [none, none, some(Named(name = "n2", tags = ["t2"], n = 2))] 56
		took n5
		some(Named(name = "", tags = ["t5"], n = 5)) false
		took n3 -
		some(Named(name = "n6", tags = ["t6"], n = 6))
		some(none) none true
		{"name":"n8","tags":["t8"],"n":8} some("n8")
		n9 none 64
		214
		"""

type Maybe<T>:
	v T?

test "an optional of a tagless optional takes its niche's next value":
	t bool? = true
	n bool? = none
	flags = [Maybe<bool?>(v = t), Maybe<bool?>(v = n), Maybe<bool?>(v = none)]
	print("{flags} {flags.byteSize / 3} {flags[1].v == none} {flags[2].v == none}")
	f i64? = 4
	g i64? = none
	nums = [
		kept(kept(f, true), true),
		kept(kept(g, true), true),
		kept(kept(f, false), true),
		kept(kept(f, true), false)
	]
	print("{nums} {nums.byteSize / 4}")
	w str? = "w".repeat(2)
	e str? = none
	words = [Maybe<str?>(v = w.copy()), Maybe<str?>(v = e), Maybe<str?>(v = none)]
	copied = words.copy()
	words[0].v = none
	print("{copied} {words} {words.byteSize / 3} {copied[0].v ?? none}")
	ms {str: str?} = {"a": w, "b": none}
	print("{ms.get("a")} {ms.get("b")} {ms.get("c")}")
	r = Maybe<Color?>(v = kept(Color.Blue, true))
	print("{Maybe<Color?>.fromBytes(r.toBytes()) ?? r} {kept(kept(kept(t, true), false), true)}")
	prints """
		[Maybe<bool?>(v = some(some(true))), Maybe<bool?>(v = some(none)), Maybe<bool?>(v = none)] 1 false true
		[some(some(some(4))), some(some(none)), some(none), none] 16
		[Maybe<str?>(v = some(some("ww"))), Maybe<str?>(v = some(none)), Maybe<str?>(v = none)] [Maybe<str?>(v = none), Maybe<str?>(v = some(none)), Maybe<str?>(v = none)] 24 some("ww")
		some(some("ww")) some(none) none
		Maybe<Color?>(v = some(some(Blue))) some(none)
		"""
