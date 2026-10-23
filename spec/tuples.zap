# 3.4 Tuples
#
# `(a, b)` groups 2 to 8 values without declaring a type; its type is written `(A, B)`. A tuple is
# what a function returns or a sort key groups, taken apart where it is made.

fn divmod(a i64, b i64):
	(a / b, a % b)

fn eight():
	(1, "b", 3.5, true, 5, 6, 7, "h")

# A tuple prints as `(1, "x")`; it is the runtime's struct `Tuple2<A, B>` (to `Tuple8`), shown as
# `(i64, str)` in messages.

test "a tuple groups values and prints them":
	t = 1, "a"
	print(t)
	print(divmod(17, 5))
	nested = (1, 2.5), "x"
	print(nested)
	print([(1, true), (2, false)])
	print(eight())
	prints """
		(1, "a")
		(3, 2)
		((1, 2.5), "x")
		[(1, true), (2, false)]
		(1, "b", 3.5, true, 5, 6, 7, "h")
		"""

test "a tuple is shown as its types in messages" refuses PushType("(i64, str)"):
	mut pairs = [(1, 2)]
	t = 1, "s"
	pairs.push(t)
	print(pairs)

# Names take a tuple apart and give one, without parentheses: `a, b = t`, `a, b = b, a` swaps (every
# value reads the names as they were before the statement), `mut lo, hi = 0, n` binds two mutable
# names. `for (k, v) in pairs`, `if f() is (x, y)` and a match arm `(x, y):` take it apart too.

test "names take a tuple's parts, and give one":
	q, r = divmod(17, 5)
	print("{q} {r}")
	a, b = r, q
	print("{a} {b}")
	lo, hi = 0, 9
	lo += 1
	print("{lo} {hi}")
	nested = (1, 2.5), "x"
	inner, _ = nested
	_, half = inner
	print(half)
	first, _, _, _, _, _, g, h = eight()
	print("{first + g} {h}")
	found = -1, -1
	found = 3, 4
	print(found)
	prints """
		3 2
		2 3
		1 9
		2.5
		8 h
		(3, 4)
		"""

test "a swap reads the names as they were":
	a = 0
	b = 1
	loop 10:
		a, b = b, a + b
	expect a == 55
	x = 1.5
	y = 2.5
	x, y = y, x
	expect x == 2.5 and y == 1.5

test "for, is and match take a tuple apart":
	squares = (0..3).map((it, it * it))
	sum = 0
	for (n, square) in squares:
		sum += n + square
	print(sum)
	if divmod(7, 2) is (q, r):
		print("{q} {r}")
	match divmod(9, 3):
		(x, 0): print("exact {x}")
		_: print("not")
	prints """
		8
		3 1
		exact 3
		"""

test "the parentheses are not written" refuses TupleTargetParentheses:
	(a, b) = (1, 2)
	print(a + b)

test "taking apart into names only" refuses TupleTargetNames:
	a, 1 = 1, 2
	print(a)

# Its values have no positions to read: more values, or values with meaning beyond their position,
# get a `type` with named fields.

test "a tuple's value by position" refuses TuplePosition:
	t = 1, "a"
	print(t.0)

# A field keeps no tuple, alone or in a list, an optional, an array or as a map's value: what a
# field keeps has a meaning, so it gets a type with named fields. A map's key may be a tuple, and
# a local, a parameter or a test table may hold a list of them.

test "a field holding a tuple" refuses TupleField:
	type Hero:
		at (i64, i64)
	print(Hero((1, 2)))

type Cell:
	x i64
	y i64

type Walker:
	path Cell[]
	seen {(i64, i64): bool}

test "named fields instead, a tuple as a map's key":
	w = Walker(path = [Cell(1, 2)], seen = {})
	w.seen[(1, 2)] = true
	pairs = [(3, 4), (5, 6)]
	for (x, y) in pairs:
		w.path.push((x, y))
	expect w.path.map(.x + .y) == [3, 7, 11]
	expect (1, 2) in w.seen

# Where the type is known (an annotated binding or list, a push, an argument, a field's value, a
# return) a tuple is made as that struct, its values filling the fields in order; with names, in
# any order: `(name = "Zapdos", level = 50)`. The type is written once, not for every value.

type Pokemon:
	name str
	level i64

type Party:
	lead Pokemon
	size i64

fn train(p Pokemon):
	p.level + 1

fn caught() Pokemon:
	("Mew", 5)

fn caughtNamed() Pokemon:
	(level = 7, name = "Ditto")

test "a tuple becomes the struct its place expects":
	team Pokemon[] = [("Zapdos", 50), ("Articuno", 50)]
	team.push(("Moltres", 50))
	team.push((level = 70, name = "Lugia"))
	party = Party(lead = ("Mew", 9), size = 1)
	expect team.map(.name) == ["Zapdos", "Articuno", "Moltres", "Lugia"]
	expect train(("Zapdos", 50)) + train((name = "X", level = 1)) == 53
	print(party.lead.name)
	expect caught().level + caughtNamed().level == 12
	prints """
		Mew
		"""

test "a tuple with names has no type of its own" refuses NamedTupleNeedsType:
	x = (a = 1, b = 2)
	print(x)

# A sort key groups values as a tuple, compared part by part. sortedBy, sortBy, minBy and maxBy
# also take the parts as their arguments, the first deciding and each next one breaking its ties:
# `sortedBy(-.points, .team)` is `sortedBy((-.points, .team))`.

type Score:
	team str
	points i64

test "a tuple as a sort key":
	scores = [Score("b", 3), Score("a", 3), Score("c", 5)]
	print(scores.sortedBy(.team, -.points).map(.team))
	print(scores.sortedBy(-.points, .team).map(.team))
	print(scores.sortedBy((-.points, .team)).map(.team))
	prints """
		["a", "b", "c"]
		["c", "a", "b"]
		["c", "a", "b"]
		"""

test "the keys of sortBy, minBy and maxBy, and of a parallel sort":
	scores = [Score("b", 3), Score("a", 3), Score("c", 5)]
	print(scores.minBy(.points, .team)?.team ?? "")
	print(scores.maxBy(.points, -.team.len)?.team ?? "")
	print(scores.parallel().sortedBy(-.points, .team).map(.team))
	scores.sortBy(.points, .team)
	print(scores.map(.team))
	prints """
		a
		c
		["c", "a", "b"]
		["a", "b", "c"]
		"""
