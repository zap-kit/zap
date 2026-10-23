# Module variables are seen only by the module that declares them, and a parameter or a field of
# the same name shadows them. The runtime's generic functions, instantiated in the program, bind
# their own locals (listRepeat's `total`, `n`, `r`) whatever the program declares.
mut total = 5
mut n = 1
mut r = 2
mut names str[] = []

type Bag:
	names str[]

	fn first():
		names[0].copy()

fn keep(move names str[]):
	names

fn sum(xs i64[]):
	acc = 0
	for x in xs:
		acc += x
	acc

test "the runtime's locals are not the program's module variables":
	expect fill(3, 7) == [7, 7, 7]
	expect total == 5
	expect n == 1
	expect r == 2

test "parameters and fields shadow module variables":
	print(sum([1, 2, 3]))
	print(keep(["a", "b"]))
	b = Bag(names = ["x"])
	print(b.first)
	names.push("c")
	print(names)
	print(total)
	prints """
		6
		["a", "b"]
		x
		["c"]
		5
		"""

type Player:
	volume i64

	fn stopMusic(x i64):
		"method {x + volume}"

	fn fadeOut():
		"{louder(1)}"

	fn louder(x i64):
		x + 1

	fn quit():
		"{self.stopMusic(3)}, {louder(fadeOut().len)}"

fn stopMusic(x i64):
	"module {x}"

test "inside a method, self. calls the method a top-level function is also named":
	p = Player(volume = 1)
	expect p.quit() == "method 4, 2"
	expect stopMusic(2) == "module 2"

limit = 1000

type Calc:
	limit i64
	op fn(i64) i64

	fn run(x i64):
		op(x) + limit

fn op(x i64):
	x + 1000

test "a field shadows a constant and a function of the module":
	c = Calc(limit = 1, op = (x i64): x * 2)
	expect c.run(5) == 11
	expect limit == 1000
