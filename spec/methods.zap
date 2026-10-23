# 5.2 Methods
#
# A method is a `fn` in its type's block after its fields (or its variants), its receiver
# implicit, of the block's type: the fields named bare in its body (reading or assigning `count`
# there is the field), `self` the receiver, a generic type's parameters in scope (`fn map<U>(f
# fn(T) U) Stack<U>` adds its own). It borrows the receiver to change it when its body assigns a
# field or the receiver, calls a method that changes it, lends it to a `mut` parameter, binds a `mut
# ref`, a loop's or a match's `mut` name to a part of it, or moves a field out; else it reads it.
# The methods are checked before the other bodies, in any order, their calls of one another solved
# together. Where the body does not tell it, a change inside a lambda (which may be stored and run
# later), or a generic's method found changing after another read it as reading it, is an error
# asking for `mut fn`, which says it outright. A `pub` method writes `mut fn` (its callers in other
# modules depend on it, as on a `pub` function's result, 5.1); the receiver is lent, never taken
# (`move fn` is an error). zap fmt drops a `mut fn`'s `mut` where the body tells it alike.

type Orbit:
	yaw f32
	distance f32

	fn forward():
		yaw * 2.0

	fn eye():
		distance - forward() - lift(1.0)

	fn zoom(f f32):
		distance *= f

type Stack<T>:
	items T[]

	fn top() ref T?:
		items.last

	fn push(move x T):
		items.push(move x)

	fn map<U>(f fn(T) U) Stack<U>:
		out U[] = []
		for x in items:
			out.push(f(x))
		Stack<U>(items = out)

	fn retarget<U Show>(tag U) str:
		items = []
		"{tag} {top() == none}"

type Counter:
	count i64

	fn half():
		count / 2

	fn increment():
		count += 1

	fn twice():
		Counter(count = self.count * 2)

type Mat2:
	a f32
	d f32

type Tally:
	hits i64
	seen str[]

	fn add(move word str):
		seen.push(move word)
		bump()

	fn bump():
		hits += 1

	fn shown():
		"{seen.join(",")}/{hits}"

	pub mut fn clear():
		seen = []
		hits = 0

test "a method names the fields bare":
	c = Counter(count = 1)
	c.increment()
	expect c.half() == 1
	expect c.twice().count == 4

test "a method in its type's block":
	t = Tally(hits = 0, seen = [])
	t.add("a")
	t.add("b")
	print(t.shown())
	t.clear()
	print(t.shown())
	prints """
		a,b/2
		/0
		"""

test "a pub method writes mut fn" refuses PubMethodChanges("'reset' changes its receiver: a pub method writes `mut fn reset`"):
	type Counter:
		count i64

		pub fn reset():
			count = 0

test "the receiver is lent" refuses SelfLent:
	type A:
		v i64

		move fn take() i64:
			v

# A function over a type from any module is a plain function, its value named as any parameter's
# (`pub fn describe(h Hero)`), called `describe(h)` or `h.describe()`: any function taking a `T`
# first is called `x.f(a)` as well as `f(x, a)`, whatever `T` is: a struct, an enum, a number, a
# `str`, a list, a map (`fn isVowel(c u8) bool` gives `c.isVowel()`). For a struct's, an enum's and
# the byte tests (`c.isDigit()`) zap fmt writes the first form.
fn isVowel(c u8):
	c in "aeiou".bytes()

fn shout(s str):
	"{s}!"

fn total<T Num>(xs T[]) T:
	t T = 0
	for x in xs:
		t += x
	t

fn grow(mut xs i64[], by i64):
	xs.push(by)

fn lift(o Orbit, k f32):
	o.yaw * k

test "a function taking a number, a str or a list first is called on it":
	c = 'a'
	print("{c.isVowel()} {'x'.isVowel()} {isVowel('e')}")
	print("{"hi".shout()} {[1.5, 2.5].total()}")
	xs = [1]
	xs.grow(5)
	print(xs)
	print(Orbit(yaw = 2.0, distance = 0.0).lift(3.0))
	prints """
		true false true
		hi! 4
		[1, 5]
		6
		"""

# Inside a method, a bare call to a function taking `T` first, short of that argument, passes
# `self`, as a field is named bare (`eye` above calls `lift(1.0)`).
test "a bare call passes self":
	o = Orbit(yaw = 1.0, distance = 9.0)
	o.zoom(2.0)
	expect o.eye() == 15

# No local, parameter, loop variable, pattern name or lambda parameter of a method takes a field's
# name, and a bare call whose name is both a method of the type and a top-level or built-in
# function is an error, since a reader cannot tell which runs: `self.stop()` calls the method,
# `audio.stop()` the function of an imported module.
test "a parameter named like a field" refuses FieldNameTaken:
	type Counter:
		count i64

		fn add(count i64):
			self.count += count
	c = Counter(0)
	c.add(2)

test "a bare call that is a method and a function" refuses AmbiguousCall("'stopMusic' is both a method of Player and a top-level function: write self.stopMusic(...) for the method, or rename one of them"):
	type Player:
		volume i64

		fn stopMusic(x i64):
			print(x + volume)

		fn quit():
			stopMusic(3)
	fn stopMusic(x i64):
		print(x)
	p = Player(volume = 1)
	p.quit()

# `self` is the whole value, lent. Outside a method `self` is a name like any other.
test "a generic type's methods, with type parameters of their own":
	s = Stack<i64>(items = [])
	s.push(3)
	print(s.top() ?? 0)
	s.push(8)
	print(s.map(x: "<{x}>").items)
	t = Stack<str>(items = ["a"])
	print(t.retarget("ok"))
	self = 7
	print(self)
	prints """
		3
		["<3>", "<8>"]
		ok true
		7
		"""

# `x.f(...)` is a method of `x`'s type (its block's), or a built-in type's own method (a list's
# `push`, a str's `split`), else a field holding a function, else a function taking `x`'s type
# first that the caller sees: its module's own or an import's, never one looked up in the type's
# module unless the caller imports it (two such are an error naming both, `AmbiguousMethod`;
# tests/programs/methods holds the modules that show it). A target's system dir (`linux/`, 8)
# replaces a method of the same name with its function.
type Button:
	label str
	onClick fn(str) str

fn upper(s str):
	"no"

fn sum(xs i64[]):
	0

test "a built-in method goes first, then a field holding a function":
	print("{[1, 2].sum()} {"a".upper()}")
	b = Button(label = "ok", onClick = (s str): "clicked {s}")
	print(b.onClick(b.label))
	prints """
		3 A
		clicked ok
		"""

type Purse:
	coins i64

	fn take():
		coins * 10

test "a type's own method goes first, named as a value's built-in one too":
	p = Purse(coins = 4)
	print("{p.take()} {p.coins}")
	prints "40 4"

# `T.f(...)`, `T` a struct's name, calls a function of the type: one giving a `T` and taking none
# first (`fn perspective(fovY f32, ...) Mat4` gives `Mat4.perspective(...)`), found the same way.
fn scaling(by f32):
	Mat2(a = by, d = by)

test "a function giving the type is called on its name":
	expect Mat2.scaling(2.0).d == 2

test "a type's call names a function giving it" refuses NoTypeFunction:
	type Mat2:
		a f32
	fn trace(m Mat2) f32:
		m.a
	print(Mat2.trace(1.0))

# Locals, parameters and fields shadow module variables; a module variable is seen only in its own
# module (others reach a `pub` one as `module.name`). Everything is visible within its module; `pub`
# exports a function, type, method or binding to other modules (*Modules*).
level = 3

fn levelAbove(level i64):
	level + 1

test "a parameter shadows a module variable":
	expect levelAbove(10) == 11
	expect level == 3
