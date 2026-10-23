# Escape analysis (spec 14.3): a statement of a loop that keeps nothing it allocates runs in an
# implicit region, its temporaries made of the region's blocks given back whole at its end; one
# that outgrows the region's chunk goes on from the heap and drops them as anywhere else.

type Tree:
	Leaf(value i64)
	Node(left Box<Tree>, right Box<Tree>, name str)

	fn total() i64:
		match self:
			Leaf(v): v
			Node(a, b, name): a.total() + b.total() + name.len

fn grow(depth i64, at i64) Tree:
	if depth == 0: return .Leaf(at)
	.Node(Box(grow(depth - 1, at * 2)), Box(grow(depth - 1, at * 2 + 1)), "a node named {at} here")

type Handle:
	id i64

	mut fn drop():
		released += 1

mut released = 0

fn handles(n i64):
	(0..n).map(Handle(id = it + 1))   # (an all-zero value reads as one moved out: not dropped)

test "a loop's statement whose trees go with it":
	live = liveBlocks()
	sum = 0
	for i in 0..200:
		sum += grow(i % 7, 1).total()
	print("{sum} {liveBlocks() == live}")
	prints "294049 true"

test "a statement that outgrows its region drops what it made":
	live = liveBlocks()
	sum = 0
	for i in 0..20:
		sum += grow(10 + i % 3, 1).total() % 1000
	print("{sum} {liveBlocks() == live}")
	prints "12324 true"

test "values a statement keeps or takes in leave it out of a region":
	kept = []
	outside = ["a text that lives outside the loop".copy()]
	n = 0
	for i in 0..10:
		kept.push(grow(2, i))
		n += [outside[0].copy(), "x"].len + handles(3).len
	print("{kept.len} {kept[9].total()} {n} {released}")
	prints "10 209 50 30"
