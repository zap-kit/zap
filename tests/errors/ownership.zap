# Ownership cases the spec does not state: a borrowed value taken apart, a module variable grown
# while a loop goes over it, the elements a filter or a text's words give, and an error of a
# module's body said once wherever it is inlined.

test "an element a filter gives is the filtered list's to give":
	xs = ["a".repeat(2), "b"]
	out = []
	for x in xs.filter(not .isEmpty):
		out.push(x)
	expect out == ["aa", "b"]

test "a borrowed variable taken apart" refuses TakeApartBorrowed:
	fn show(t (str, i64)) str:
		a, b = t
		"{a}{b}"

	print(show(("a".repeat(2), 1)))

test "a call that grows a module variable while a loop goes over it" refuses ChangeWhileLooped:
	mut items i64[] = [1, 2, 3]

	fn grow():
		items.push(4)

	for x in items:
		if x == 1:
			grow()

test "a map keeps the windows a loop over a text's words gives: they point into the text":
	text = "b a b".repeat(1)
	counts {ref str: i64} = {}
	for word in text.words():
		counts.add(word, 1)
	expect counts.len == 2

# the error lines a zap command said in the program of the two files written (module and main)
fn errorsSaid(module str, moduleText str, main str, mainText str, command str):
	dir = testProgram(module, moduleText, main, mainText)
	Process.output("{zapPath()} {command} {main}", dir = dir).out
		.replace("\r\n", "\n")
		.lines()
		.filter(
			"error[" in it
		)

# whether the zap command said one error line, starting with at
fn saidOnceAt(at str, module str, moduleText str, main str, mainText str, command str):
	said = errorsSaid(module, moduleText, main, mainText, command)
	said.len == 1 and said[0].startsWith(at)

# saidOnceAt for main.zap beside a module m whose one() gives 1
fn saidBesideOne(at str, mainText str, command str):
	saidOnceAt(at, "m/m.zap", "pub fn one() i64:\n\t1\n", "main.zap", mainText, command)

test "an error in a module's body is said once, at its own file, wherever the body is inlined":
	expect saidOnceAt(
		"kinds/kinds.zap:6:3: error[move-of-part]",
		"kinds/kinds.zap",
		"names = \{0: \"zero\", 1: \"one\"}\n\npub fn pick(kind str, wrapped bool) str:\n\tname = kind.copy()\n\tif wrapped:\n\t\tname = names.get(1) ?? \"none\"\n\tname\n",
		"main.zap",
		"import kinds\n\nprint(kinds.pick(\"plain\", true))\n",
		"build"
	)

test "a value moved into a tuple of a list is gone, though a call of another file's function reads it after":
	said = errorsSaid(
		"m/m.zap",
		"pub type W:\n\tframeDuration f32\n\tnames str[]\n\npub fn pose(w W, k i64) f32:\n\tw.frameDuration * f32(k)\n\npub fn count(xs (str, W)[]) i64:\n\txs.len\n",
		"walk.zap",
		"import m\n\ntest \"walk\":\n\twalk = m.W(frameDuration = 3.0, names = [\"a\"])\n\tprint(m.count([(\"walk\", walk)]))\n\tprint(m.pose(walk, 17))\n",
		"test --only tests"
	)
	print(said.any(.startsWith("walk.zap:6:2: error[use-after-given]")))
	prints "true"

# an error in a lambda's expression body: at the lambda's line, not line 0; in a test block,
# once, in the test's file
test "an error in a lambda is said once, at its line" for (at, mainText, command) in [
	("main.zap:11:", "# a comment\n# another\nimport m\n\ntype G:\n\torder str[]\n\tclips str[]\n\nprint(m.one())\ng = G(order = [\"a\"], clips = [\"b\"])\nf = (n i64): g.order\nprint(f(1))\n", "build"),
	("main.zap:9:", "# a comment\nimport m\n\ntype G:\n\torder str[]\n\ntest \"lambda\":\n\tg = G(order = [\"a\"])\n\tf = (n i64): g.order\n\tprint(f(m.one()))\n", "test"),
]:
	expect saidBesideOne(at, mainText, command)

test "a part given away in a list literal is said at its statement, not where an inlined call ended":
	expect saidOnceAt(
		"main.zap:7:2: error[move-of-part]",
		"m/m.zap",
		"pub fn dirOf(s str) str:\n\tt = s.copy()\n\tt\n",
		"main.zap",
		"import m\n\ntype Args:\n\tdir str\n\nfn pick(args Args, romPath str) str:\n\tdirs = [m.dirOf(romPath), args.dir]\n\tdirs[0]\n\nprint(pick(Args(dir = \"n\"), \"x\"))\n",
		"build"
	)

test "a name an `is` test binds is given away like a let: reading it after is an error":
	said = errorsSaid(
		"m/m.zap",
		"pub fn one() i64:\n\t1\n",
		"main.zap",
		"type T:\n\txs i64[]\n\nfn make(ok bool) T?:\n\tif ok: return T(xs = [1, 2, 3])\n\tnone\n\nfn show(t T):\n\tprint(t.xs.len)\n\nfn run(mut all T[]):\n\tif make(true) is t:\n\t\tall.push(t)\n\t\tshow(t)\n\nall T[] = []\nrun(all)\n",
		"build"
	)
	expect said.any(.startsWith("main.zap:14:3: error[use-after-given]"))

type Named:
	name str

type Holder:
	opt Named?

fn took(move s str):
	"took {s}"

test "a part moved out of an optional field ends when the whole optional is assigned":
	holder = Holder(opt = Named(name = "a".repeat(2)))
	if holder.opt is v:
		print(took(v.name))
	holder.opt = none
	print(holder.opt)
	holder.opt = Named(name = "b".repeat(2))
	if holder.opt is w:
		print(took(w.name))
	holder.opt = Named(name = "c")
	print(holder.opt)
	prints """
		took aa
		none
		took bb
		some(Named(name = "c"))
		"""
