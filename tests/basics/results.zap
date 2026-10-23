# Results a body gives (spec 5.1): checked when a caller first needs them, in any order, and the
# errors that ask for the written result.

type Box:
	v i64

	fn get():
		v * 2

	fn bump():
		v += 1

fn early():
	later(3)   # checked before its callee: the callee's body is checked first, once

fn later(x i64):
	x + 100

fn helper(x i64):
	x + 1

fn twice<T Show>(x T, n i64):
	print("{helper(n)} {x}")   # a generic's definition needs it: checked again once it is known

limit = helper(9)   # a module binding's value calls one

fn pick(c bool, x i64?):
	if c: return none   # none takes the type the other return gives
	x

fn none3(c bool):
	if c: return []
	[1, 2, 3]

mut seen i64[] = []

fn either(k i64):
	match k:
		0: seen.push(1)
		_: print("other")   # arms of different types: a statement

fn walk(n i64):
	if n == 0: return
	walk(n - 1)   # recursive, and gives nothing

test "results found in any order, through methods, generics and module bindings":
	b = Box(v = 3)
	b.bump()
	twice("a", 4)
	f = (x i64): helper(x)
	g = helper
	print("{b.get()} {early()} {limit} {f(1)} {g(5)}")
	prints """
		5 a
		8 103 10 2 6
		"""

test "untold values take the others' type, statements stay statements":
	either(0)
	either(1)
	walk(3)
	print("{pick(false, 4) ?? 0} {pick(true, 4) ?? 0} {none3(true).len} {seen}")
	prints """
		other
		4 0 0 [1]
		"""

test "an optional reference asks for the result" refuses ResultReference:
	fn find(m {str: i64}, k str):
		m.get(k)
	print(find({"a": 1}, "a") ?? 0)

test "only untold values ask for the result" refuses ResultUntold:
	fn nothing():
		return none
	print(nothing() == none)

type Frame:
	buffers f32[,]
	scratch f32[]

fn rest(mut f Frame, channels i64):
	use noStops
	for c in 0..channels:
		if c >= f.buffers.len: return -1
		buffer = move f.buffers[c]
		f.filled(buffer)   # its body checked here first: the facts above stay known
		f.buffers[c] = buffer
	0

fn filled(f Frame, mut b f32[]):
	use noStops
	if not b.isEmpty and not f.scratch.isEmpty: b[0] = f.scratch[0]

test "a body checked in the middle of another keeps the other's length facts":
	f = Frame(buffers = [[0.0]], scratch = [2.0])
	expect f.rest(1) == 0
	expect f.buffers == [[2]]

type Cell:
	x f32

fn cellsShown(cells Table<Cell>):
	firstShown(cells)   # its body checked here first, the row instance of shown made in it

fn firstShown(cells Table<Cell>):
	cells[1].shown()

fn shown(c Cell):
	"{c.x}"

test "a row instance made in a body checked in the middle of another keeps its row":
	cells Table<Cell> = [Cell(x = 1.0), Cell(x = 2.0)]
	print(cellsShown(cells))
	prints "2"
