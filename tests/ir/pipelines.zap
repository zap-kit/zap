# Pipelines through the intermediate form: map, filter, sum, any, all and count over a list or
# a range, inline as loops; a list local moved into another (its last use the move) and extended.
#
# More pipelines and conversions through the intermediate form: filter keeping elements that own
# memory, reduce, find of a reference, intoStr, bytes, a choice of windows, for over a reference.

type U:
	tops i64[]
	names str[]

fn order(mut u U, words str[]):
	ordered = []
	rest = []
	for t in u.tops:
		if t % 2 == 0:
			ordered.push(t)
		else:
			rest.push(t)
	u.names = ordered.map(words[it].copy())
	tops = ordered
	tops.extend(rest)
	u.tops = tops

fn stats(xs i64[], k i64):
	squares = xs.map(it * it)
	big = squares.filter(it > k)
	(
		big.sum(),
		(1..k).map(it * 2).sum(),
		xs.any(it == k),
		(0..k).all(it < k),
		xs.count(it % 2 == 1)
	)

test "pipelines and a moved list":
	u = U(tops = [0, 1, 2, 3, 4], names = [])
	u.order(["a", "b", "c", "d", "e"])
	print("{u.tops} {u.names} {stats([1, 2, 3, 4, 5, 6], 5)}")
	prints "[0, 2, 4, 1, 3] [\"a\", \"c\", \"e\"] (86, 20, true, true, 3)"

test "a sum or a reduce of maps and filters runs in their loop, no list between":
	xs = [1, 2, 3, 4, 5]
	ws = ["a", "bb", "ccc"]
	expect (xs.filter(it > 2).map(it * 2).sum()) == 24
	expect xs.sum(it * it) == 55
	expect ws.sum(.len) == 6
	expect xs.map(f64(it)).sum() == 15
	expect xs.map(it + 1).reduce(10, (a, b): a * b) == 7200

type Note:
	text str
	line i64

fn onLine(notes Note[], line i64):
	notes.filter(.line == line)

fn total(xs i64[]):
	xs.reduce(10, (a, b): a + b)

fn longest(words str[]):
	words.reduce(0, (best, w): w.len if w.len > best else best)

fn textOf(notes Note[], line i64):
	match notes.find(.line == line):
		n: n.text
		none: "?"

fn joined(mut bs u8[]) str:
	bs.push(33)
	str(move bs)

fn head(path str) ref str:
	i = path.indexOf(47) ?? -1
	path if i < 0 else path[..i]

fn count(words ref str[]):
	n = 0
	for w in words:
		n += w.bytes().len
	n

test "pipelines and conversions":
	ns = [Note(text = "a", line = 1), Note(text = "b", line = 2), Note(text = "c", line = 2)]
	bs u8[] = [65, 66]
	ws = ["ab", "cde"]
	expect onLine(ns, 2).len == 2
	expect total([1, 2, 3]) == 16
	expect longest(["ab", "cdefg"]) == 5
	expect textOf(ns, 2) == "b"
	expect joined(bs) == "AB!"
	expect head == {"ab/cd": "ab", "xy": "xy"}
	expect count(ws) == 5
