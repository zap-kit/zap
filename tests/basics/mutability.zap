# Mutability inferred (spec 2.4): each way what follows a binding changes it makes it mutable.

import fs

type Bag:
	items i64[]
	name str

	fn fill(n i64):
		items.push(n)

fn put(mut xs i64[], v i64):
	xs.push(v)

fn into(v i64, mut xs i64[]):
	xs.push(v)

test "assigned, through a field or an element, by a method of it or of a part":
	a = 1
	a += 2
	b = Bag(items = [], name = "b")
	b.fill(4)
	c = Bag(items = [0], name = "c")
	c.items[0] = 7
	c.items.push(8)
	d = Bag(items = [], name = "d")
	d.name = "dd"
	print("{a} {b.items} {c.items} {d.name}")
	prints "3 [4] [7, 8] dd"

test "lent to a mut parameter, by a function, a method or a module's function":
	xs = [1]
	put(xs, 2)
	ys = [1]
	3.into(ys)
	zs = [1]
	into(4, zs)
	print("{xs} {ys} {zs}")
	prints "[1, 2] [1, 3] [1, 4]"

test "a part moved out, the bytes made a text, changed in a lambda":
	b = Bag(items = [5], name = "moved")
	n = move b.name
	bytes u8[] = [104, 105]
	s = str(move bytes)
	count = 0
	bump = ():
		count += 1
	bump()
	bump()
	expect n == "moved"
	expect b.name.isEmpty
	expect s == "hi"
	expect bytes.isEmpty
	expect count == 2

test "a binding nothing changes stays immutable, a number read as its literal":
	half = 0.5
	x f32 = 3.0
	expect x * half == 1.5

type Cell:
	n i64

fn store(c Cell, v i64, mut out i64[]):
	out.push(v + c.n)

test "a local named like an imported module is a receiver, not the module":
	fs = Cell(n = 5)
	out = []
	fs.store(1, out)
	expect out == [6]
	expect fs.n == 5
