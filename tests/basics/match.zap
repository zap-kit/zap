# Enum matches: the tag read once for every arm, payloads of a local or temporary scrutinee read
# in place in the frame (a temporary's owned parts dropped once, moved ones not at all).
#
# a match over a local held in a register (an inlined call's computed argument): its slot is made
# current and the arms read it there

type Msg:
	Text(body str, times i64)
	Pair(a f32, b u8)
	Quit

fn make(i i64) Msg:
	if i % 3 == 0: return .Text("m{i}", i)
	if i % 3 == 1: return .Pair(f32(i) * 0.5, u8(i * 7))
	.Quit

fn describe(i i64):
	match make(i):
		Text(body, times): "{body}x{times}"
		Pair(a, b): "p{a}/{b}"
		Quit: "q"

fn keep(i i64):
	match make(i):
		Text(body, _): body
		_: "-"

test "local and temporary scrutinees":
	local = Msg.Pair(2.5, 200)
	s = ""
	match local:
		Text(body, times): s = "{body}{times}"
		Pair(a, b): s = "{a + 1.0} {b}"
		Quit: s = "quit"
	expect s == "3.5 200"
	expect describe(3) == "m3x3"
	expect describe(4) == "p2/28"
	expect describe(5) == "q"
	expect keep(6) == "m6" and keep(7) == "-"
	all = ""
	for i in 0..6:
		all += "{describe(i)},"
	expect all == "m0x0,p0.5/7,q,m3x3,p2/28,q,"

type Mode:
	Opaque
	CutOut
	Blended

fn modeOf(kind i64) Mode:
	match kind:
		1: .CutOut
		2: .Blended
		_: .Opaque

mut blended = 0
mut cut = 0
for k in [0, 1, 2, 1, 5]:
	m = modeOf(k + 1)
	if m == .Blended: blended += 1
	if m == .CutOut: cut += 1
print("{blended} {cut}")

test "match over a register local":
	main()
	prints """
		2 1
		"""

type Slot<T>:
	Full(held T)
	Empty

test "a variant's value of a generic enum, and through an optional":
	words = Slot<str>.Full("ab".repeat(2))
	none1 = Slot<i64>.Empty
	maybe Slot<i64>? = Slot<i64>.Full(3)
	nothing Slot<i64>? = none
	print("{words.Full ?? "-"} {none1.Full ?? 7} {maybe?.Full} {nothing?.Full}")
	prints "abab 7 some(3) none"
