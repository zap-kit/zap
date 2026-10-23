# 7.9 Tables: `Table<T>`
#
# A `Table<T>` is a list of the struct `T` kept as columns: each field of
# `T` lives in a list of its own, so a loop that reads few fields reads only their columns. Choosing
# the layout is one word, `Particle[]` or `Table<Particle>`; by element a table is used as a list
# and gives the same results. The compiler writes a table as a struct with one list per field and
# its methods as functions of the `derive` module (`compiler/syntax/table.zap`).

type Vec2:
	x f64
	y f64

type Particle:
	pos Vec2
	vel Vec2
	mass f64

type Named:
	name str
	tags str[]
	score i64

	# declared after their uses: their row instances take their bodies once checked
	fn grow(by i64):
		score += by
		if by > 1: self.grow(by - 1)

	fn total():
		score + self.sizeOf()

type World:
	things Table<Named> = []

fn particle(i i64):
	Particle(
		pos = Vec2(x = i, y = 0.0),
		vel = Vec2(x = 1.0, y = i * 0.5),
		mass = i + 1
	)

# the same steps on a List and a Table of the same values print the same text
fn stepList(mut ps Particle[], dt f64):
	for p in 0..ps.len:
		ps[p].pos.x += ps[p].vel.x * dt
		ps[p].pos.y += ps[p].vel.y * dt

fn stepTable(mut ps Table<Particle>, dt f64):
	for p in ps:
		p.pos.x += p.vel.x * dt
		p.pos.y += p.vel.y * dt

# `Table<T>()`, `t Table<T> = []` or `= [a, b]` make one; `for r in t` and `for i, r in t` give
# rows: each `r.f` is `t.f[i]`, read or changed; `len` and `isEmpty` are its size.

test "a table reads as a list of the same values":
	list = []
	table = Table<Particle>()
	print("{table.len} {table.isEmpty}")
	for i in 0..4:
		list.push(particle(i))
		table.push(particle(i))
	stepList(list, 0.5)
	stepTable(table, 0.5)
	print("{table.len} {table.isEmpty}")
	print(list == table.map(it))
	print("{list.sum(.mass)} {table.sum(.mass)}")
	print("{list.count(.pos.x > 2.0)} {table.count(.pos.x > 2.0)}")
	print("{list.map(.pos.x + .vel.x)} {table.map(.pos.x + .vel.x)}")
	prints """
	    0 true
	    4 false
	    true
	    10 10
	    2 2
	    [1.5, 2.5, 3.5, 4.5] [1.5, 2.5, 3.5, 4.5]
	    """

# `t.f` (a field's name) is the column of field `f`, a list of its type, lent: its elements read and
# change in place (`t.f[i] = v`), its length and order only through the table.

test "a column lent whole":
	t Table<Particle> = []
	for i in 0..3:
		t.push(particle(i))
	masses = t.mass
	print("{masses} {t.mass.sum()}")
	t.mass[1] = 9.0
	print(t.mass)
	prints """
	    [1, 2, 3] 6
	    [1, 9, 3]
	    """

# `r = mut ref t[i]` is a row: `r.f` reads and changes `t.f[i]`; `r` alone is a copy of the element.

test "a mut ref row changes the columns and reads them":
	t = Table<Particle>()
	for i in 0..3:
		t.push(particle(i))
	r = mut ref t[2]
	r.pos.x = 5.0
	r.mass += 4.0
	expect t[2].pos.x == 5
	expect t.mass[2] == 7
	expect r.vel.x + r.pos.y + 1.0 == 2
	expect t[1].mass + r.mass == 9
	print(r)
	prints """
	    Particle(pos = Vec2(x = 5, y = 0), vel = Vec2(x = 1, y = 1), mass = 7)
	    """

# `t[i].f` and `t[i].f = v` are `t.f[i]`; `t[i]` and `t[i] = v` are the whole element, a copy made
# from the columns (parts that own memory copied) and stored field by field.

test "elements read and written whole, parts that own memory copied":
	t = Table<Named>()
	t.push(Named(name = "a", tags = ["x"], score = 1))
	t.push(Named(name = "b", tags = [], score = 2))
	first = t[0]
	print("{first.name} {first.tags} {first.score}")
	second = t[1]
	second.tags.push("y")
	t[1] = second
	print(
		"{t[1].name} {first.tags[1..1]} {t[1].score} | {t.name[1]} {t.tags[1]} {t.score[1]}"
	)
	t[1].name = "c"
	print("{t.name} {t.filter(.score > 1).map(.score)[0]}")
	prints """
	    a ["x"] 1
	    b [] 2 | b ["y"] 2
	    ["a", "c"] 2
	    """

test "a table in a struct, walked with its index":
	w = World()
	w.things.push(Named(name = "a", tags = [], score = 0))
	w.things.push(Named(name = "b", tags = [], score = 0))
	for i, n in w.things:
		n.score = i
	for n in w.things:
		print("{n.score} {n.name}")
	prints """
	    0 a
	    1 b
	    """

# `T` is a struct with fields, none named `len` or `isEmpty`.

test "a table's element is a struct" refuses TableElement:
	t = Table<i64>()
	print(t.len)

test "a field a table answers itself" refuses TableFieldName:
	type Span:
		len i64

	t = Table<Span>()
	print(t.len)

# Methods of a list that change its length or order are errors on a column, and so is a column given
# to a `mut` parameter or assigned whole; an element changes field by field.

test "a column keeps the table's length" refuses TableColumnChange:
	type Body:
		mass f64

	mut t = Table<Body>()
	t.mass.push(1.0)
	print(t.len)

test "a column is not replaced" refuses TableColumnLength:
	type Body:
		mass f64

	mut t = Table<Body>()
	t.mass = [1.0]
	print(t.len)

test "an element changes field by field" refuses TableElementChange:
	type Vec2:
		x f64
		y f64

	mut t = Table<Vec2>()
	t.push(Vec2(x = 1.0, y = 2.0))
	t[0] += Vec2(x = 1.0, y = 1.0)
	print(t.len)

# A table has what the list has that keeps its columns in step, nothing else.

fn heaviest(ps Table<Particle>):
	best = 0
	for i in 1..ps.len:
		if ps[i].mass > ps[best].mass:
			best = i
	best

fn countOver<T Ord>(ps Table<Particle>, limits T[], at T) i64:
	ps.count(.mass > 2.0) + limits.count(it > at)

# On a table named as a place (a variable or its fields) the steps `map`, `filter`, `sum`, `count`,
# `any`, `all`, `find`, `findIndex`, `reduce`, `flatMap`, `minBy`, `maxBy` and `sortedBy`
# give the lambda a row, read from the columns in place; only what the step gives is copied
# (`filter`'s and `sortedBy`'s elements, `find`'s, `minBy`'s and `maxBy`'s `T?`).

test "a table lent to functions, its rows read in lambdas":
	t = Table<Particle>()
	for i in 0..4:
		t.push(particle(i))
	print("{heaviest(t)} {countOver(t, [1, 2, 3], 2)} {countOver(t, ["a"], "b") - 1}")
	limits = [0.5, 2.5, 3.5]
	over = []
	for p in t:
		over.push(limits.count(it < p.mass))
	print(over.filter(it > 1))
	prints """
	    3 3 1
	    [2, 3]
	    """

fn named(name str, score i64):
	Named(name = name.copy(), tags = [name.copy()], score)

# `push`, `pop`, `insert`, `remove`, `swap`, `clear`, `truncate` and `reserve` are the list's, on
# every column; `copy()` is a deep copy.

test "the list's changes made on every column":
	t Table<Named> = [named("a", 1), named("b", 2), named("c", 3)]
	print("{t.name} {t.score}")
	t.insert(1, named("x", 9))
	t.swap(0, 3)
	print("{t.name} {t.score}")
	gone = t.remove(1)
	last = t.pop() ?? named("none", 0)
	print("{gone.name} {gone.score} {gone.tags} | {last.name}")
	t.reserve(10)
	print("{t.name} {t.score} {t.len}")
	t.truncate(1)
	t.clear()
	print("{t.len} {t.pop() == none}")
	prints """
	    ["a", "b", "c"] [1, 2, 3]
	    ["c", "x", "b", "a"] [3, 9, 2, 1]
	    x 9 ["x"] | a
	    ["c", "b"] [3, 2] 2
	    0 true
	    """

test "a copy of a table is a table of its own":
	t Table<Named> = [named("a", 1)]
	u = t.copy()
	u.name[0] = "b"
	expect t.name[0] == "a"
	expect u.name[0] == "b"

# `move t[i]` moves the element out, its place left the empty value.

test "an element moved out leaves the empty value, as a list's":
	t Table<Named> = [named("a", 1), named("b", 2), named("c", 3)]
	taken = move t[1]
	print("{t.name} {t.score} {taken.name} {taken.tags}")
	t[0] = move t[2]
	t.pop()
	print(t.name)
	prints """
	    ["a", "", "c"] [1, 0, 3] b ["b"]
	    ["c", ""]
	    """

fn allocationsOf(f fn() i64):
	before = allocations()
	f()
	allocations() - before

test "a pipeline reads the columns in place: no list of copies":
	t Table<Named> = [named("a", 1), named("b", 2), named("c", 3)]
	print("{t.findIndex(.name == "b") ?? -1} {t.count(.score > 1)} {t.any(.tags[0] == "c")} {t.all(.score > 1)} {t.reduce(0, (a, n): a + n.score)} {t.findIndex(.score == 3)} {t.sum(.tags.len)}")
	counts = [
		allocationsOf((): t.findIndex(.name == "b") ?? -1),
		allocationsOf((): t.count(.score > 1)),
		allocationsOf((): 1 if t.any(.tags[0] == "c") else 0),
		allocationsOf((): 1 if t.all(.name.len == 1) else 0),
		allocationsOf((): t.reduce(0, (a, n): a + n.score))
	]
	print(counts.map(str(it)).join(" "))
	for r in t: print(r.score)
	found = t.find(.score == 3) ?? named("-", 0)
	print("{t.filter(.score > 1).map(.name)} {found.name} {t.find(.score == 7) == none} {t.map(.score * 3)} {t.flatMap([.name.copy(), "x"])}")
	prints """
	    1 2 true false 6 some(2) 3
	    0 0 0 0 0
	    1
	    2
	    3
	    ["b", "c"] c true [3, 6, 9] ["a", "x", "b", "x", "c", "x"]
	    """

fn named30(i i64):
	named("n{i}", (i * 7) % 30)

test "minBy, maxBy and sortedBy read the columns in place: only what they give is copied":
	t Table<Named> = [named("b", 2), named("c", 3), named("a", 1)]
	low = t.minBy(.score) ?? named("-", 0)
	high = t.maxBy(.name) ?? named("-", 0)
	print("{low.name} {high.name} {t.sortedBy(.name).map(.score)} {t.sortedBy(-.score).map(.name)}")
	none3 = Table<Named>()
	print("{none3.minBy(.score) == none} {none3.sortedBy(.score).len}")
	big = Table<Named>()
	for i in 0..30:
		big.push(named30(i))
	# the keys and the indexes, then the one element given: no copy of each element (three
	# allocations an element)
	print(allocationsOf((): (big.minBy(.score) ?? named("-", 0)).score) < 30)
	print((big.maxBy(.score) ?? named("-", 0)).name)
	prints """
	    a c [1, 2, 3] ["c", "b", "a"]
	    true 0
	    true
	    n17
	    """

fn scoreOf(n Named):
	n.score + n.tags.count(.len > 1) + n.tags.map(.len).sum()

fn sizeOf(n Named):
	n.name.len + n.tags.len

fn rename(mut n Named, to str):
	n.name = to.copy()
	n.tags.push(to.copy())
	if n.score < 10: n.raise()

fn raise(mut n Named):
	n.score += 10

fn replace(mut n Named):
	n = named("z", 0)

# A function's read or `mut` parameter (or a method's `self`) given an element (`f(t[i])`, `f(r)`,
# `t[i].m()`, `r.m()`) is a row, its fields read and changed in the columns (the compiler makes the
# function's instance taking the table and the index); a function that binds the parameter again
# is given a copy.

test "a function given a table's element reads and changes its fields in the columns":
	t Table<Named> = [named("a", 1), named("bb", 2)]
	rename(t[0], "cc")
	for n in t:
		raise(n)
	print("{t.name} {t.score} {t.tags} {scoreOf(t[0])} {t.map(scoreOf(it))}")
	# read in place: the element is not copied out
	print(allocationsOf((): sizeOf(t[1])))
	# a parameter bound again takes a place of its own
	list = [named("y", 1)]
	list[0].replace()
	print(list[0].name)
	t[1].grow(2)
	for n in t:
		n.grow(1)
	print("{t.score} {t[0].total()}")
	prints """
	    ["cc", "bb"] [21, 12] [["a", "cc"], ["bb"]] 25 [25, 15]
	    0
	    z
	    [22, 16] 26
	    """

fn swapScores(mut a Named, mut b Named):
	s = a.score
	a.score = b.score
	b.score = s

fn sameScore(a Named, b Named):
	a.score == b.score

fn addScore(mut t Table<Named>, n Named):
	t[0].score += n.score

# A copy is given instead when another argument reaches the same table (unless both only read).

test "rows of one table given together: read both, or a copy where the table is lent too":
	t Table<Named> = [named("a", 1), named("b", 2)]
	u Table<Named> = [named("c", 7)]
	swapScores(t[0], u[0])
	print("{sameScore(t[0], t[1])} {t.score} {u.score}")
	addScore(t, t[1])
	print(t.score)
	prints """
	    false [7, 2] [1]
	    [9, 2]
	    """

fn table3() Table<Named>:
	[named("a", 1), named("b", 2), named("c", 3)]

# Any step of a table not named is the list's step over copies of the elements (a `T[]` made first).

test "a step of a table not named works on copies":
	print("{table3().map(.score)} {table3().filter(.score > 1).map(.name)}")
	prints """
		[1, 2, 3] ["b", "c"]
		"""

# A row names its table at each use, so the table of `r = mut ref t[i]` is a variable or its fields.

test "a row of a table not named" refuses CannotIndex:
	type Body:
		mass f64
	mut ts = [Table<Body>()]
	ts[0].push(Body(mass = 1.0))
	r = mut ref ts[0][0]
	r.mass = 2.0

test "a table is made empty" refuses TableEmpty:
	type Body:
		mass f64
	t = Table<Body>(Body(mass = 1.0))
	print(t.len)
