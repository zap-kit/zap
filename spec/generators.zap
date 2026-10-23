# 7.3 Generators: `Seq<T>`
#
# A function whose result is `Seq<T>` is a generator: its body gives the elements by `yield v` (`v`
# a `T`), and a bare `return` ends it. A `for` or a step over its call compiles into one loop: the
# generator's body is lowered in place, each `yield` writing the element and running the loop's
# turn (the `for`'s body, the steps'), then going on after it. No list is built, nothing is
# allocated and no closure is made; `break` leaves the walk (what the generator owns is dropped),
# `continue` goes on after the yield.

fn upTo(n i64) Seq<i64>:
	i = 0
	while i < n:
		yield i
		i += 1

fn evensBelow(n i64) Seq<i64>:
	for x in upTo(n):
		if x % 2 == 0:
			yield x

fn greetings() Seq<str>:
	yield "hello"
	yield "n{1 + 1}"
	yield "bye"

fn untilZero(xs i64[]) Seq<i64>:
	for x in xs:
		if x == 0: return
		yield x

type Node:
	value i64
	kids i64[]
	alive bool
	name str

type Tree:
	nodes Node[]

	# depth first from the root, a stack of what is left (a generator cannot recurse)
	fn walk() Seq<Node>:
		stack = [0]
		while not stack.isEmpty:
			i = stack.pop() ?? 0
			yield nodes[i]
			for k in nodes[i].kids.reversed():
				stack.push(k)

fn sample():
	Tree(
		nodes = [
			Node(value = 1, kids = [1, 2], alive = true, name = "root"),
			Node(value = 2, kids = [3], alive = false, name = "left"),
			Node(value = 3, kids = [], alive = true, name = "right"),
			Node(value = 4, kids = [], alive = true, name = "leaf")
		]
	)

fn nameOf(t Tree, value i64):
	for n in t.walk():
		if n.value == value:
			return n.name.copy()   # the walk is left: what the generator holds is dropped
	"none"

test "a range-like generator, walked by a for":
	total = 0
	for x in upTo(5):
		total += x
	expect total == 10
	expect evensBelow(6).toList().map("{it}").join(" ") == "0 2 4"

test "yields in a row, a return that ends the walk":
	for g in greetings():
		print(g)
	print(untilZero([3, 1, 0, 5]).toList())
	prints """
		hello
		n2
		bye
		[3, 1]
		"""

# A `Seq`'s steps are `filter(p)` and `map(f)`, which give a `Seq` and run in the walk, and `each`,
# `all`, `any`, `count(p)`, `count()` (the elements), `reduce`, `sum`, `mean`, `groupBy`, `countBy`
# and `zip`, which give what a list's give (*Pipelines*); `.toList()` makes a list of its elements.
test "steps over a Seq run in the walk":
	print(upTo(10).filter(it % 4 == 0).filter(it > 0).count())
	print(upTo(4).map(it * 10).sum())
	print("{upTo(5).any(it == 3)} {upTo(5).all(it < 3)}")
	print(upTo(5).reduce(0, (a, b): a + b))
	print(upTo(3).map(it * it).toList())
	for x in upTo(4).filter(it >= 2): print(x)
	print("{upTo(5).mean()} {upTo(6).countBy(it % 2)} {upTo(3).zip([7, 8, 9])}")
	print(upTo(5).groupBy(it % 2))
	prints r"""
		2
		60
		true false
		10
		[0, 1, 4]
		2
		3
		2 {0: 3, 1: 3} [(0, 7), (1, 8), (2, 9)]
		{0: [0, 2, 4], 1: [1, 3]}
		"""

test "a tree walked through a method":
	t = sample()
	print(t.walk().map(.value).toList().map("{it}").join(" "))
	print(t.walk().filter(.alive).count())
	print(t.walk().map(.name).toList())
	print("{t.nameOf(2)} {t.nameOf(9)}")
	prints """
		1 2 4 3
		3
		["root", "left", "leaf", "right"]
		left none
		"""

test "break and continue in a walk":
	for x in upTo(100):
		if x == 4: break
		if x % 2 == 0: continue
		print(x)
	prints """
		1
		3
		"""

# The elements are lent to the turn: a `str` element is copied to be kept.
test "a Seq's str elements are lent: toList copies them":
	print(greetings().toList())
	prints """
		["hello", "n2", "bye"]
		"""

# A `Seq` is walked where it is made, once: the collection of a `for`, or the receiver of a step,
# never stored, passed, returned or indexed (a parameter, a field or a list element is not a `Seq`).
test "a Seq is not stored" refuses SeqWalkedWhereMade:
	fn upTo(n i64) Seq<i64>:
		i = 0
		while i < n:
			yield i
			i += 1
	s = upTo(3)
	print(s.count())

test "a Seq is not a parameter" refuses SeqNotStored:
	fn total(s Seq<i64>) i64:
		s.sum()
	print(total([1].first ?? 0))

test "a Seq has no len" refuses SeqLacksMethod:
	fn upTo(n i64) Seq<i64>:
		i = 0
		while i < n:
			yield i
			i += 1
	print(upTo(3).len)

# A generator is inlined into each loop that walks it, so it cannot walk itself, directly or
# through another generator (a recursive walk keeps what is left in a list, as `walk` does), and it
# has no type parameters.
test "a generator cannot recurse" refuses GeneratorRecursion:
	fn down(n i64) Seq<i64>:
		yield n
		if n > 0:
			for x in down(n - 1):
				yield x
	print(down(3).count())

test "a generator has no type parameters" refuses GenericGenerator:
	fn each<T>(xs T[]) Seq<T>:
		for x in xs:
			yield x
	print(each([1]).count())

test "a generator returns no value" refuses GeneratorReturn:
	fn f() Seq<i64>:
		return 1
	print(f().count())

# `map`'s values own nothing: a number, a part of the element.
test "a Seq's map gives values that own nothing" refuses SeqMapOwns:
	fn upTo(n i64) Seq<i64>:
		i = 0
		while i < n:
			yield i
			i += 1
	print(upTo(3).map("{it}").count())

# The generator reads its arguments in place, so the walk's turns cannot change them.
test "a walk's arguments do not change during it" refuses ChangeWhileRead:
	fn items(xs i64[]) Seq<i64>:
		for x in xs:
			yield x
	mut xs = [1, 2]
	for v in items(xs):
		xs.push(v)
	print(xs)
