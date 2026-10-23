# 3.6 Generics

# Type parameters go in `<>` on functions and types; a bound follows the parameter's name, several
# joined with `+` (`<T Ord>`, `<K Hash + Ord>`). There are no `where` clauses.

type Stack<T>:
	items T[]

	fn push(move v T):
		items.push(v)

	fn pop() T?:
		items.pop()

	fn last() ref T?:
		items.last

	fn len() i64:
		items.len

fn drain<T>(mut s Stack<T>) T[]:
	out T[] = []
	while s.pop() is v:
		out.push(v)
	out

fn second<T>(items T[]) ref T?:
	if items.len < 2: return none
	items[1]

fn larger<T Ord + Copy>(a T, b T) T:
	a if a > b else b

test "generic functions and types":
	s = Stack<i64>(items = [])
	s.push(1)
	s.push(2)
	s.push(3)
	print("{s.pop()} {s.last} {s.len} {s}")
	names = Stack<str>(items = [])
	names.push("ana")
	names.push("bia")
	print("{names.drain()} {names.len}")
	nested = Stack<i64[]>(items = [])
	nested.push([1, 2])
	nested.push([3])
	print(nested)
	print("{[10, 20].second()} {[1].filter(it > 5).second()} {["ana", "bia"].second()}")
	expect larger == {(3, 7): 7, (2.5, 1.5): 2.5}
	prints """
		some(3) some(2) 2 Stack<i64>(items = [1, 2])
		["bia", "ana"] 0
		Stack<i64[]>(items = [[1, 2], [3]])
		some(20) none some("bia")
		"""

# Six bounds are built in. `Eq` gives `==`, `!=`, `contains` (`in`) and `indexOf`; `Ord` gives `Eq`,
# `< <= > >=`, `sort`, `min` and `max`; `Hash` gives `Eq`, use as a map key and `hash()`; `Num` gives
# `Ord`, `Show`, `Copy`, `+ - * / % **`, unary `-` and a number literal as a `T`; `Show` gives
# `print` and interpolation, and every type but `()` and functions has it.
fn position<T Eq>(xs T[], v T) i64:
	for i in 0..xs.len:
		if xs[i] == v: return i
	-1

fn has<T Eq>(xs T[], v T) bool:
	position(xs, v) >= 0 and v in xs and xs.indexOf(v) != none

fn largest<T Ord>(xs T[]) ref T:
	best = 0
	for i in 1..xs.len:
		if xs[i] > xs[best]:
			best = i
	xs[best]

fn ordered<T Ord + Show>(xs T[]) str:
	"{xs.sorted()} {xs.min()} {xs.max()}"

fn counts<K Hash>(keys K[]) {K: i64}:
	m {K: i64} = {}
	for k in keys:
		m.add(k, 1)
	m

fn sameHash<K Hash>(a K, b K) bool:
	a.hash() == b.hash()

fn sum<T Num>(xs T[]) T:
	acc T = 0
	for x in xs:
		acc += x
	acc

fn mirrored<T Num>(x T) T:
	-x * 2 % 7

# a bound passes on: Num gives Ord and Eq
fn spread<T Num>(xs T[]) T:
	one T[] = [xs[0]]
	largest(xs) - sum(one)

fn tag<T Show>(x T) str:
	"<{x}>"

type Color:
	Red
	Green

test "the built-in bounds":
	expect has ==
		{(["Eq", "Ord"], "Ord"): true, ([1, 2, 3], 4): false, ([Color.Red], Color.Green): false}
	print("{largest([3, 9, 4])} {largest(["pear", "apple", "zucchini"])} {ordered([3, 1, 2])}")
	print("{counts(["a", "b", "a"])["a"]} {sameHash("ab", "ab")}")
	fs = [1.5, 2.25]
	halves f32[] = [0.5, 1.5]
	print("{sum(fs)} {sum(halves)} {mirrored(5)} {spread([2, 10, 5])}")
	expect tag == {7: "<7>", true: "<true>", [1, 2]: "<[1, 2]>", Color.Red: "<Red>"}
	prints """
		9 zucchini [1, 2, 3] some(1) some(3)
		2 true
		3.75 2 -3 8
		"""

# A program declares other bounds: the functions taking a type first that it must have, written as
# signatures without bodies, one per line, each taking `self` of the bound's name first (`mut self`
# for one that changes the value). `bound` is a word only there.
type Canvas:
	lines str[]

bound Drawable:
	fn grow(mut self Drawable, by i64)
	fn draw(self Drawable, mut c Canvas)
	fn extent(self Drawable) i64

type Circle:
	radius i64

	fn grow(by i64):
		radius += by

	fn draw(mut c Canvas):
		c.lines.push("circle {radius}")

	fn extent():
		radius * 2

type Square:
	side i64

	fn grow(by i64):
		side *= by

	fn draw(mut c Canvas):
		c.lines.push("square {side}")

	fn extent():
		side

fn drawAll<T Drawable>(mut xs T[], mut c Canvas) i64:
	total = 0
	for i in 0..xs.len:
		xs[i].grow(2)
		xs[i].draw(c)
		total += xs[i].extent()
	total

# a bound beside a built-in one
fn biggest<T Drawable + Eq>(xs T[]) i64:
	xs.map(.extent()).max() ?? 0

test "a generic calls the functions its bound declares, each instance its type's":
	c = Canvas(lines = [])
	circles = [Circle(radius = 1), Circle(radius = 2)]
	squares = [Square(side = 3)]
	a = drawAll(circles, c)
	b = drawAll(squares, c)
	expect c.lines == ["circle 3", "circle 4", "square 6"]
	expect a + b == 20
	expect biggest(circles) == 8

test "a bound's function takes self of the bound first" refuses BoundSelfFirst:
	bound Shape:
		fn extent() i64

# A type, of any kind, has the bound when it has each function: a method of its own, else a
# function taking it first that its module or the caller's imports hold (as `x.f()` finds one, 5.2;
# `fn area(xs i64[]) i64` makes `i64[]` meet `area`), taking it as `mut` when the bound's does, with
# the same other parameters (modes and types) and result. Each instance calls its own type's
# functions, compiled for it: no dispatch at run time. A bound of another module is written
# `module.Bound`, and is `pub` to be seen from others.
bound Sized:
	fn area(self Sized) i64
	fn widen(mut self Sized, by i64)

type Box2:
	w i64

	fn area():
		w * w

	fn widen(by i64):
		w += by

fn area(xs i64[]):
	xs.len

fn widen(mut xs i64[], by i64):
	xs.push(by)

fn grown<T Sized>(mut x T) i64:
	x.widen(2)
	x.area()

type Tally:
	count i64

bound Keeper:
	fn tally(mut self Keeper) mut ref Tally
	fn pair(mut self Keeper) (i64, i64)
	fn add(mut self Keeper, n i64)

type Counter:
	tally Tally

	fn tally() mut ref Tally:
		mut ref tally

	mut fn pair():
		(1, 2)

	fn add(n i64):
		tally.count += n

fn bumpWith<K Keeper>(mut k K) i64:
	n = 2
	k.add(n)
	a, _ = k.pair()
	k.tally().count + a

test "a bound is met by functions taking the type first, of any type":
	b = Box2(w = 2)
	xs = [7]
	c = Counter(tally = Tally(count = 0))
	expect grown == {b: 16, xs: 2}
	expect bumpWith(c) == 3

test "a type without the bound's function" refuses BoundNotMet("i64 is not Drawable (no function extent takes it first), required by T of show"):
	bound Drawable:
		fn extent(self Drawable) i64

	fn show<T Drawable>(x T) i64:
		x.extent()

	print(show(5))

# A generic function is checked once, at its definition, whether or not anything instantiates it.
# Each type parameter is a type of its own, no other type, with only what its bounds give: the
# operations of the built-in ones, the functions of the declared ones, and `copy()` and `move`,
# which every type has. Any other use is an error there that names the bound. A call to another
# generic passes the bounds on, and the methods of a generic type take their bounds from the type
# (`type Ranked<T Ord>`).
type Ranked<T Ord>:
	items T[]

	fn best() ref T:
		largest(items)

# checked at its definition too: nothing instantiates it
pub fn countTwice<K Keeper>(mut k K) i64:
	t = k.tally()
	t.count += 1
	n = 3
	k.add(n)
	a, b = k.pair()
	k.tally().count + a + b

test "a generic type's methods take its bounds":
	expect (Ranked<i64>(items = [1, 5, 2]).best()) == 5

test "an operator the bounds do not give is an error at the definition" refuses NeedsBound("'+' on T needs the bound Num: declare <T Num> on twice"):
	fn twice<T>(x T) T:
		x + x

	pass

test "a method needs a bound that declares it" refuses MemberNeedsBound:
	fn lengthOf<T>(x T) i64:
		x.len

	print(lengthOf("abc"))

test "a method the bound does not declare" refuses BoundLacksMethod:
	bound Drawable:
		fn extent(self Drawable) i64

	fn show<T Drawable>(x T) i64:
		x.extent() + x.radius2()

	pass

test "a type parameter has no fields" refuses FieldOfTypeParameter:
	type P:
		x i64

	fn xOf<T>(p T) i64:
		p.x

	print(xOf(P(x = 1)))

test "a call to another generic passes the bounds on" refuses BoundNotMet:
	fn largest<T Ord>(xs T[]) ref T:
		xs[0]

	fn pick<T Eq>(xs T[]) ref T:
		largest(xs)

	print(pick([1]))

# At every instance the types given must satisfy the bounds; the error is at the call.

# `Copy` is plain data: a value copies where it is used, as an `i64` does (4.1). Numbers, `bool`,
# references, structs without a drop function, enums and optionals of such, and shared values (a
# copy counts one more owner) have it. What copies and what moves is decided at the definition too:
# a type parameter owns memory unless it is `Copy`, so a value of `T` is given away by `move` or
# duplicated by `copy()`.
fn firstOf<T Copy>(xs T[]) T:
	xs[0]

fn firstCopy<T>(xs T[]) T:
	xs[0].copy()

fn give<T>(move x T) T:
	x

fn pushed<T>(move xs T[], move x T) T[]:
	out = move xs
	out.push(x)
	out

type Point:
	x i64
	y i64

test "a Copy T copies, any T copies with copy() or moves":
	expect firstOf == {[1, 2]: 1, [2.5]: 2.5}
	expect firstOf([Point(x = 3, y = 4)]).x == 3
	expect firstCopy == {["a", "b"]: "a", [7]: 7}
	print("{give("z")} {pushed(["x"], "y")}")
	prints """
		z ["x", "y"]
		"""

test "an element of T given away is an error at the definition" refuses MoveOfPart:
	fn firstOf<T>(xs T[]) T:
		xs[0]

	print(firstOf([1, 2]))

test "a borrowed T given away is an error at the definition" refuses MoveOfBorrowed:
	fn same<T>(x T) T:
		x

	pass

test "a type that owns memory is not Copy" refuses BoundNotMet("str is not Copy, required by T of firstOf"):
	fn firstOf<T Copy>(xs T[]) T:
		xs[0]

	print(firstOf(["a"]))

# An instance substitutes its types: a literal in the body takes each instance's type. Its body is
# a copy of its own, checked once with its types for the code it compiles: what the body may do was
# checked at the definition, so an instance reports no error of its own.
fn biased<T Num>(xs T[], bias T) T:
	acc T = 0
	for i in 0..xs.len:
		acc += xs[i]
	acc + bias

fn scaled<T Num>(x T) T:
	x * 2 + 1

type Named:
	text str
	n i64

test "a literal in a generic body takes each instance's type":
	fs = [1.5, 2.5]
	bs u8[] = [200, 100]
	ns = [1, 2, 3]
	expect biased == {(fs, 0.25): 4.25, (bs, u8(1)): 45, (ns, 10): 16}
	expect scaled == {2.5: 6.0, u8(3): 7, 7: 15}
	bytes u8[] = [1, 2, 3]
	expect 3 in bytes and bytes.indexOf(2) == 1

test "an instance of references after one of values: each lends its own way":
	counts {str: i64} = {}
	counts["a"] = 5
	nodes = [Named(text = "kiwi", n = 3)]
	byName {ref str: ref Named} = {}
	for node in nodes:
		byName[node.text] = node
	expect counts["a"] == 5
	expect byName["kiwi"].n == 3

# A generic type is instantiated on first use (`Stack<i32>`, `Tree<i32>.Node(1, [])`). A literal
# without type arguments takes them from the expected type or from its fields. Instances print with
# their written name.
type Pair<A, B>:
	left A
	right B

	fn swap() Pair<B, A>:
		Pair<B, A>(left = right.copy(), right = left.copy())

type Tree<T>:
	Leaf
	Node(value T, left Tree<T>[], right Tree<T>[])

fn sumAll(ts Tree<i64>[]) i64:
	total = 0
	for t in ts:
		total += sumTree(t)
	total

fn sumTree(t Tree<i64>) i64:
	match t:
		Leaf: 0
		Node(v, l, r): v + sumAll(l) + sumAll(r)

test "generic types are instantiated on first use":
	p = Pair(left = 1, right = "one")
	q = p.swap()
	print("{p} {q}")
	t = Tree<i64>.Node(5, [Tree<i64>.Node(2, [], [])], [Tree<i64>.Leaf])
	print("{sumTree(t)} {t}")
	print(p.toJson())
	if Pair<i64, str>.fromJson(p.toJson()) is back:
		print(back.right)
	prints r"""
		Pair<i64, str>(left = 1, right = "one") Pair<str, i64>(left = "one", right = 1)
		7 Node(5, [Node(2, [], [])], [Leaf])
		{"left":1,"right":"one"}
		one
		"""

# Number parameters: a parameter written with an integer type instead of bounds is a number known
# when compiling, as Mojo's parameters and Rust's const generics are. It sizes arrays, is given
# where a type argument goes, and reads in the body as a constant of its type. A call takes the
# number from its arguments as it takes a type (from an array's type, or an array literal's length);
# each value used is an instance. `fill(N, x)` fills a `T[N]`. Each instance is a copy of the
# body with its numbers known, so it compiles as the same body written with literals would: an
# array the parameter sizes lives in registers and the loops over `0..N` that index it unroll (3.5),
# and `Simd<N, T>` is the vector of that many lanes (7.8), a size the processor lacks an error at
# the call. `@` on fixed arrays and on a struct holding one is the product of their shapes (7.8):
# `Mat<R, K> @ Mat<K, C>` is a `Mat<R, C>`, and sizes that do not meet are a compile error.
fn dot<N n64>(a f32[N], b f32[N]) f32:
	acc f32 = 0.0
	for i in 0..N:
		acc += a[i] * b[i]
	acc

fn zeros<N n64>(like i64[N]) i64[N]:
	fill(N, 0)

fn total<N n64>(a i64[N]) i64:
	s = 0
	for x in a:
		s += x
	s + doubledLength(a)

# a number parameter passed on to another generic
fn doubledLength<M n64>(a i64[M]) i64:
	M * 2

fn small<N n64>(a i64[N]) bool:
	N < 3

type Mat<R n64, C n64>:
	cells f32[R, C]

	fn rows() i64:
		R

fn mul<R n64, K n64, C n64>(a Mat<R, K>, b Mat<K, C>) Mat<R, C>:
	out f32[R, C]
	for r in 0..R:
		for c in 0..C:
			s f32 = 0.0
			for k in 0..K:
				s += a.cells[r][k] * b.cells[k][c]
			out[r][c] = s
	Mat<R, C>(cells = out)

test "a number parameter takes the length or the size its argument has":
	a f32[3] = [1.0, 2.0, 3.0]
	b f32[3] = [4.0, 5.0, 6.0]
	c f32[2] = [1.0, 2.0]
	expect dot == {(a, b): 32.0, (c, c): 5.0}
	q i64[4] = [1, 2, 3, 4]
	print("{zeros(q)} {total([1, 2, 3])}")
	expect small == {[1, 2]: true, [1, 2, 3]: false}
	m = Mat<2, 3>(cells = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
	n = Mat<3, 2>(cells = [[1.0, 0.0], [0.0, 1.0], [1.0, 1.0]])
	print("{m.mul(n).cells} {m.mul(n).rows()}")
	print(m)
	print("{m @ n} {(n @ m).rows()}")
	prints """
		[0, 0, 0, 0] 12
		[[4, 5], [10, 11]] 2
		Mat<2, 3>(cells = [[1, 2, 3], [4, 5, 6]])
		Mat<2, 2>(cells = [[4, 5], [10, 11]]) 3
		"""

test "shapes that do not meet are a compile error" refuses ArgumentType:
	type Mat<R n64, C n64>:
		cells f32[R, C]

	fn mul<R n64, K n64, C n64>(a Mat<R, K>, b Mat<K, C>) Mat<R, C>:
		Mat<R, C>(cells = fill(R, C, 0.0))

	a = Mat<3, 2>(cells = fill(3, 2, 0.0))
	b = Mat<3, 3>(cells = fill(3, 3, 0.0))
	print(mul(a, b).cells)

# The body is checked once at its definition, with `N` a value of its type and `T[N]` an array of
# that unknown length; a value that does not fit the type, a type given for a number or a number
# for a type is an error at the use.

test "a number parameter's type is an integer type" refuses NumberParameterNotInteger:
	fn f<N f32>(a i64[N]) i64:
		1

	print(f([1]))

# A call may write its type arguments after the function's name, against it, numbers and types in
# the order the declaration lists them: `zeros<3>()` gives what no argument can. Spaced, `n < 3` is a
# comparison.

fn none3<N n64>() i64[N]:
	fill(N, 0)

fn same<T Copy>(x T) T:
	x

test "a call's own type arguments":
	n = 2
	print("{none3<3>()} {same<u8>(250) + 5} {same<f64>(1)} {n<3}")
	prints "[0, 0, 0] 255 1 true"

test "an instance's arrays and loops are a literal length's":
	body = "\tt f32[N]\n\tfor i in 0..N:\n\t\tt[i] = a[i] * a[i]\n\ts f32 = 0.0\n\tfor i in 0..N:\n\t\ts += t[i]\n\ts\n"
	call = "x f32[4] = [f32(args.len), 2.0, 3.0, 4.0]\nprint(squares(x))\n"
	generic = disassembly("fn squares<N n64>(a f32[N]) f32:\n{body}\n{call}", "squares_4")
	sized = body.replace("N", "4")
	written = disassembly("fn squares(a f32[4]) f32:\n{sized}\n{call}", "squares")
	expect "vmulsd" in generic and "jl" not in generic
	expect generic == written

# `Simd<N, T>` in a generic: N's lanes in each instance.

fn splat<N n64>(x f32) Simd<N, f32>:
	Simd<N, f32>(x)

fn tripledSum<N n64, T Num>(v Simd<N, T>) T:
	(v + v * 2).sum()

test "vectors of a number parameter's lanes":
	v = splat<8>(2.0)
	print("{v} {tripledSum(v)} {tripledSum(Simd<4>(1.0, 2.0, 3.0, 4.0))}")
	prints "[2, 2, 2, 2, 2, 2, 2, 2] 48 30"
