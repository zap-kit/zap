# Strs through the intermediate form: literals, comparisons through the runtime, lengths; and a
# place whose list a call in the value moves (the value comes first, the address after it).
type N:
	kind i64
	text str
	kids i64[] = []

type P:
	nodes N[]
	pos i64

fn mk(mut p P, t str):
	p.nodes.push(N(kind = 1, text = t.copy()))
	p.nodes.len - 1

fn stmt(mut p P) i64:
	p.pos += 1
	p.mk("$splice" if p.pos % 3 == 0 else "x")

fn block(mut p P):
	b = p.mk("b")
	while p.pos < 40:
		st = p.stmt()
		if p.nodes[st].kind == 1 and p.nodes[st].text == "$splice":
			p.nodes[b].kids.push(p.mk("y"))
		elif p.nodes[st].text < "y" and p.nodes[st].text.len == 1:
			p.nodes[b].kids.push(st)
	b

test "strs and places moved by the value":
	p = P(nodes = [], pos = 0)
	b = p.block()
	expect p.nodes[b].kids.len == 40
	expect (p.nodes.filter(.text == "y").len) == 13

type Named:
	name str
	n i64

type Dot:
	x i64
	y i64

	fn shift(by i64):
		x += by
		y -= by

fn rename(mut ns Named[], mut words str[], k i64):
	for mut n in ns:
		n.name = "{n.name}{k}"
		words.push(n.name.copy())
		words.push("w")
	words.len

fn shiftAll(mut ds Dot[], by i64):
	for mut d in ds:
		d.shift(by)
	ds[0].x + ds[len - 1].y

test "owned stores and pushes, a mut method of an element":
	ns = [Named(name = "a", n = 1), Named(name = "b", n = 2)]
	words = []
	k = rename(ns, words, 1)
	ds = [Dot(x = 1, y = 2), Dot(x = 3, y = 4)]
	print("{ns[0].name} {ns[1].name} {k} {words} {shiftAll(ds, 1)}")
	prints "a1 b1 4 [\"a1\", \"w\", \"b1\", \"w\"] 5"

fn firstWord(s str) ref str:
	at = s.indexOf(' ') ?? s.len
	s[..at]

fn tidy(lines str[]):
	out = []
	for line in lines:
		t = line.trimmed()
		if t.isEmpty or t[0] == '#': continue
		w = firstWord(t)
		out.push("{w.upper()}:{t.len}:{t.indexOf("=") ?? -1}:{"{w}!"}")
	out

test "str methods and windows":
	expect tidy(["  a b ", "# no", "", "key = val", "x=1 y=2"]).join(" ") ==
		"A:3:-1:a! KEY:9:4:key! X=1:7:1:x=1!"

fn countTo(n i64):
	before = liveBlocks()
	i = 0
	while "{i}" != "{n}" and "{i}".len < 4:
		i += 1
	i == n and liveBlocks() == before

test "temporaries of a condition dropped as it is left":
	expect countTo(50)
