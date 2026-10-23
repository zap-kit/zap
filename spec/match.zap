# 6.2 Match
#
# `match` is exhaustive (every variant, or a `_` / binding catch-all) and is an expression or a
# statement. Its arms are tried in order: the first whose pattern matches (and whose condition
# holds) runs. A variant written alone matches whatever it holds.

type Shape:
	Circle(radius f64)
	Rect(width f64, height f64)
	Ring(radius f64, hole f64)
	Dot

type Command:
	Move(dx i64, dy i64)
	Say(text str)
	Rest
	Quit

type Pos:
	x i64
	y i64

fn area(s Shape):
	match s:
		Circle(r): 3.0 * r * r
		Rect(w, h) and w == h: w * w
		Rect(w, h): w * h
		Ring(r, hole): 3.0 * (r * r - hole * hole)
		Dot: 0.0

test "a match is a value, its arms tried in order":
	expect area == {.Circle(2.0): 12.0, .Rect(2.0, 2.0): 4.0, .Rect(2.0, 3.0): 6.0, .Dot: 0.0}
	r = Shape.Rect(1.0, 2.0)
	isRect = match r:
		Rect: true
		_: false
	expect isRect

test "every variant is handled" refuses NonExhaustiveMatch:
	type Shape:
		Circle(radius f64)
		Rect(width f64, height f64)
		Point

	fn area(s Shape) f64:
		match s:
			Circle(radius): 3.14 * radius * radius
			Rect(width, height): width * height

	print(area(Shape.Point))

# As a statement its arms may be blocks or statements, with `return`, `break` and `continue`. In an
# expression, a block arm's last statement is its value, and arms may mix the ok and error types of
# an expected `T ? E`.
fn firstQuit(cmds Command[]):
	i = 0
	for c in cmds:
		match c:
			Quit: return i
			_: i += 1
	-1

fn parsed(text str) i64 ? str:
	match text:
		"one": 1
		"": "empty"
		_:
			n = text.len
			n * 10

test "a statement's arms are blocks, with return, break and continue":
	cmds = [
		Command.Move(1, 2),
		Command.Say("hi"),
		Command.Rest,
		Command.Move(3, 3),
		Command.Quit,
		Command.Say("late")
	]
	pos = Pos(x = 0, y = 0)
	rested = 0
	for c in cmds:
		match c:
			Move(dx, dy):
				pos.x += dx
				pos.y += dy
				print("moved to {pos.x},{pos.y}")
			Say(text): print("says {text}")
			Rest:
				rested += 1
				continue
			Quit: break
	print("rested {rested}, quit at {firstQuit(cmds)}")
	print("{parsed("one")} {parsed("")} {parsed("abc")}")
	prints """
		moved to 1,2
		says hi
		moved to 4,5
		rested 1, quit at 4
		ok(1) err("empty") ok(30)
		"""

test "a block arm of a value ends with its value" refuses ArmMissingValue:
	fn pick(n i64) i64:
		return match n:
			0:
				x = 1
			_: 2
	print(pick(0))

# Literal arms on integers, strings or bools: a number's and a string's end with a catch-all; on
# `bool`, `true` and `false` are exhaustive.
fn command(cmd str):
	match cmd:
		"add": "adds"
		"list": "lists"
		_: "unknown"

fn count(n i64):
	match n:
		0: "zero"
		1: "one"
		_: "many"

test "an arm of a literal matches the values equal to it, _ the rest":
	expect command == {"add": "adds", "zzz": "unknown"}
	expect count == {1: "one", 7: "many"}
	match true:
		true: print("yes")
		false: print("no")
	prints "yes"

test "literal arms end with a catch-all" refuses NonExhaustiveMatch("add a final '_' arm"):
	x = 3
	match x:
		1: print("one")
		2: print("two")

# A name bound by an arm points into the matched value. Written `mut` (`Rect(mut w, h)`, `if o is
# mut v`), it is that part itself: changing it changes the value matched in place, which is then a
# place that changes (spec 2.4): a local, a `mut` parameter, a field or an element of one. Without
# `mut` the name only reads its part.
test "a mut name of a variant's field changes the value matched":
	s = Shape.Rect(2.0, 3.0)
	if s is Rect(mut w, mut h):
		w += 10.0
		h *= 2.0
	print(s)
	prints "Rect(12, 6)"

test "a mut name needs a place that may change" refuses MutNameNoPlace:
	fn f(o i64?):
		if o is mut v:
			v += 1
			print(v)
	f(1)

# An arm's patterns are separated by commas; the names they bind must be the same, with the same
# types. A condition after them (`pattern and cond`, as `if s is Rect(w, h) and w == h:` writes it
# outside a `match`) holds for the whole arm and reads the names they bind; when it fails, the next
# arm is tried, and an arm with a condition counts for nothing in exhaustiveness. A lowercase name
# always binds: a constant is compared in the condition (`n and n == maxHp`).
fn outer(s Shape):
	match s:
		Circle(r), Ring(r, _): r
		Rect, Dot: 0.0

fn half(n i64) i64 ? str:
	if n < 0: return "no"
	n / 2

maxHp = 100

fn health(hp i64):
	match hp:
		n and n == maxHp: "full"
		_: "hurt"

test "an arm of several patterns, and an arm's condition":
	expect outer == {.Circle(3.0): 3.0, .Dot: 0.0, .Ring(1.5, 0.5): 1.5}
	for r in [half(6), half(60), half(-1)]:
		match r:
			v and v < 10: print("small {v}")
			v: print("big {v}")
			error: print("error {error}")
	expect health == {100: "full", 3: "hurt"}
	prints """
		small 3
		big 30
		error no
		"""

test "the patterns of one arm bind the same names" refuses ArmBindingsDiffer:
	type Shape:
		Circle(radius f32)
		Rect(width f32, height f32)

	s = Shape.Circle(1.0)
	x = match s:
		Circle(r), Rect(w, _): 1.0
	print(x)

test "a guarded arm covers nothing" refuses NonExhaustiveMatch("non-exhaustive match: variant 'Circle' not handled"):
	type Shape:
		Circle(radius f32)
		Rect(width f32, height f32)

	s = Shape.Circle(1.0)
	x = match s:
		Circle(r) and r > 0.0: r
		Rect: 0.0
	print(x)

test "an or in an arm's condition goes in parentheses" refuses ArmConditionOr:
	n = 5
	match n:
		x and x > 9 or x < 0: print(x)
		_: print(0)

# A range of numbers: `lo..hi` up to, not including, `hi`; `lo..=hi` includes it; `lo..` has no end.
# Ranges of floats work too, but a float literal alone is an error.
fn classify(b u8):
	match b:
		0x04, 0x0A: "control"
		'0'..':': "digit"
		'a'..='z', 'A'..'[': "letter"
		_: "other"

fn bucket(n i64):
	match n:
		-10..0: -1
		0..10 and n % 2 == 0: 0
		0..10: 1
		_: 2

fn band(x f64):
	match x:
		0.0..0.5: "low"
		0.5..=1.0: "high"
		1.0..: "over"
		_: "under"

test "ranges of integers and of floats":
	expect classify ==
		{10: "control", '7': "digit", 'q': "letter", 'z': "letter", 'Q': "letter", '+': "other"}
	expect bucket == {-3: -1, 4: 0, 5: 1, 10: 2}
	expect band == {-1.0: "under", 0.25: "low", 0.5: "high", 1.0: "high", 2.5: "over"}

test "lo..= takes its end" refuses RangePatternInclusiveEnd:
	n = 5
	match n:
		1..=: print("positive")
		_: print("other")

test "a float alone is refused" refuses FloatPattern:
	x = 0.5
	print(match x:
		0.5: 1
		_: 0
	)

# Wherever a pattern binds a name it may hold a pattern, each written as its value is built:
# variants nested at any depth, with literals inside; `name is pattern` binds the whole too.
type Button:
	Left
	Right

type Key:
	Up
	Down
	Char(c u8)

type Event:
	Press(key Key, shift bool)
	Click(button Button, x i64, y i64)
	Mouse(click Touch)
	Leave

type Touch:
	Tap(button Button, x i64)
	Drag(dx i64)

fn describe(e Event):
	match e:
		Press(Down, _): "down"
		Press(Char('w'), false): "w"
		Press(Char(c), true): "shifted {c}"
		Press(k, _): "another key"
		Click(Left, 0, y): "left on the edge at {y}"
		Click(Left, x, _): "left at {x}"
		Click(Right, _, _): "right"
		Mouse(t is Tap(Left, x)): "tap at {x} of {t.tapX()}"
		Mouse(Tap(Right, _)): "right tap"
		Mouse(Drag(d)): "drag {d}"
		Leave: "leave"

fn tapX(t Touch):
	match t:
		Tap(_, x): x
		Drag: -1

type Named:
	Item(name str, shape Shape)
	Nothing

fn made(i i64) Named:
	if i == 0: return .Item("ball", .Circle(1.5))
	if i == 1: return .Item("box", .Rect(2.0, 2.0))
	.Nothing

type Found:
	name str
	n i64

fn found(i i64) Found?:
	if i == 0: return none
	Found("p{i}", i)

test "nested variants, literals inside, a name binding the whole":
	events = [
		Event.Press(.Down, false),
		Event.Press(.Char('w'), false),
		Event.Press(.Char('w'), true),
		Event.Press(.Up, false),
		Event.Click(.Left, 0, 4),
		Event.Click(.Left, 3, 9),
		Event.Mouse(.Tap(.Left, 7)),
		Event.Mouse(.Tap(.Right, 1)),
		Event.Mouse(.Drag(2)),
		Event.Leave
	]
	for e in events:
		print(e.describe())
	prints """
		down
		w
		shifted 119
		another key
		left on the edge at 4
		left at 3
		tap at 7 of 7
		right tap
		drag 2
		leave
		"""

test "the parts of a temporary go to the names; a condition reads them":
	for i in 0..3:
		match made(i):
			Item(name, Circle(r)): print("round {name} {r}")
			Item(name, Rect(w, h)) and w == h: print("square {name}")
			Item(name, _): print("other {name}")
			Nothing: print("nothing")
	prints """
		round ball 1.5
		square box
		nothing
		"""

test "a mut name inside a place changes it":
	n = Named.Item("ball", .Circle(1.5))
	if n is Item(_, Circle(mut r)):
		r += 2.0
	if n is Item(_, Circle(r)):
		print(r)
	prints "3.5"

test "a name binding the whole of a temporary while its parts are tested":
	kept = []
	for i in 0..3:
		match made(i):
			w is Item(_, Circle): kept.push(w)
			Item(name, s) and name.len == 3: kept.push(.Item(name, s))
			_: pass
	names = []
	for n in kept:
		if n is Item(name, _):
			names.push(name.copy())
	expect names.join(", ") == "ball, box"

test "a temporary's parts given away from inside its variant or its optional":
	names = []
	if made(0) is Item(name, Circle):
		names.push(name)
	for i in 0..3:
		if found(i) is Found(name, 1..):
			names.push(name)
	expect names.join(" ") == "ball p1 p2"

test "a variant's value of another type" refuses PatternType:
	type Event:
		Move(dx i64)

	e = Event.Move(1)
	print(match e:
		Move("x"): 1
		_: 2
	)

# A struct's pattern names its type and gives every field by position, or some by name (`field =
# pattern`, the others anything), with literals and ranges inside; a tuple's parts the same.
type Point:
	x i64
	y i64

type Placed:
	name str
	at Point

fn side(p Point):
	match p:
		Point(0, 0): "origin"
		Point(x = 1..): "right side"
		Point(0, y) and y < 0: "below"
		_: "left side"

type Phase:
	Menu
	Playing
	Done

type Input:
	Start
	Stop
	Wait

fn step(phase Phase, input Input) Phase:
	match (phase, input):
		(Menu, Start): .Playing
		(_, Stop): .Done
		(s, _): s

fn both(a bool, b bool):
	match (a, b):
		(true, true): 3
		(true, false): 2
		(false, true): 1
		(false, false): 0

test "a struct by position or by name, and a tuple's parts":
	expect side == {
		Point(0, 0): "origin",
		Point(3, -1): "right side",
		Point(0, -1): "below",
		Point(-2, 5): "left side"
	}
	placed = [Placed("a", Point(1, 2)), Placed("b", Point(0, 0))]
	out = []
	for p in placed:
		match p:
			Placed(n, Point(x, 2)): out.push("{n} at {x}")
			Placed(name = n): out.push(n)
	print(out.join(", "))
	expect step == {
		(.Menu, .Start): .Playing,
		(.Playing, .Stop): .Done,
		(.Menu, .Wait): .Menu,
		(.Playing, .Start): .Playing
	}
	expect both == {(true, true): 3, (true, false): 2, (false, true): 1, (false, false): 0}
	prints "a at 1, b"

# On an optional, `none` tests for none and any other pattern tests the value (the arm's own name
# takes the value).
fn label(hp i64?):
	match hp:
		none: "dead"
		1..=20: "low"
		n: "{n}"

fn greet(name str?):
	match name:
		"root": "admin"
		n: "hi {n}"
		none: "nobody"

fn where(p Point?):
	match p:
		Point(0, 0): "origin"
		Point(x, _): "at {x}"
		none: "nowhere"

test "any pattern for an optional's value":
	expect label == {none: "dead", 1: "low", 20: "low", 21: "21", 0: "0"}
	print("{greet("root")}, {greet("ann")}, {greet(none)}")
	expect where == {Point(0, 0): "origin", Point(3, 4): "at 3", none: "nowhere"}
	out = []
	x i64? = 5
	if x is 5: out.push("five")
	if x is 1..10: out.push("a range")
	y i64? = none
	if y is 1..10: out.push("in") else: out.push("none")
	print(out.join(", "))
	prints """
		admin, hi ann, nobody
		five, a range, none
		"""

# On a result, a name takes the value (`error` the error), a variant of the error's enum tests the
# error, and any other pattern the value.
type FsError:
	NotFound
	Denied(who str)

fn readFile(path str) str ? FsError:
	if path == "a": return "text of a"
	if path == "b": return FsError.Denied("bob")
	FsError.NotFound

fn load(path str):
	match readFile(path):
		text: "read {text}"
		Denied(who): "denied to {who}"
		NotFound: "created {path}"

fn sign(r i64 ? str):
	match r:
		0: "zero"
		1..: "positive"
		n: "negative {n}"
		error: "error {error}"

test "patterns on both sides of a result":
	print("{load("a")}, {load("b")}, {load("c")}")
	expect sign == {0: "zero", 7: "positive", -3: "negative -3", "no": "error no"}
	prints "read text of a, denied to bob, created c"

# A list's pattern is its literal's brackets, `..rest` the elements between (lent as `xs[1..]` would
# be, one rest at most); exhaustive by length (`[]` and `[x, ..rest]` are all).
fn route(line str):
	commands = ["run", "stop"]
	match line.words():
		[]: "empty"
		["GET", path]: "serve {path}"
		[cmd, ..args] and cmd in commands: "{cmd} with {args.len}"
		[..init, last]: "unknown {init.len} then {last}"

fn sumList(xs i64[]) i64:
	match xs:
		[]: 0
		[x, ..rest]: x + sumList(rest)

fn ends(xs i64[]):
	match xs:
		[a, .., b] and a == b: "same ends"
		[0, ..]: "starts with 0"
		[_, _, ..]: "two or more"
		[_]: "one"
		[]: "none"

test "a list's pattern by its elements and its rest":
	expect route == {
		"": "empty",
		"GET /index": "serve /index",
		"run a b": "run with 2",
		"stop": "stop with 0",
		"a b c": "unknown 2 then c",
		"x": "unknown 0 then x"
	}
	expect sumList == {[1, 2, 3, 4]: 10, []: 0}
	expect ends == {
		[1, 2, 1]: "same ends",
		[0, 5]: "starts with 0",
		[1, 2]: "two or more",
		[7]: "one",
		[]: "none",
		[0]: "starts with 0"
	}
	queue = [1, 2, 3]
	out = []
	while queue is [next, ..rest]:
		out.push("{next}")
		queue = rest.copy()
	print(out.join(" "))
	prints "1 2 3"

test "a list's lengths left out" refuses NonExhaustiveMatch("non-exhaustive match: [_, _, ..] not handled"):
	xs = [1, 2]
	print(match xs:
		[]: 0
		[_]: 1
	)

test "one rest in a list" refuses ListPatternRests:
	xs = [1, 2]
	print(match xs:
		[..a, ..b]: 0
		_: 1
	)

# A string's pattern is an interpolation run backwards, each capture a lent `str`: a capture runs to
# the first place the text after it is found, the last one to the end; two captures side by side are
# an error.
fn handle(request str):
	match request:
		"GET /users/{id} HTTP/1.1": "user {id}"
		"GET /{path}": "file {path}"
		"{verb} {_}": "bad verb {verb}"
		_: "bad request"

test "a string taken apart by the text around its captures":
	expect handle == {
		"GET /users/42 HTTP/1.1": "user 42",
		"GET /a/b.txt": "file a/b.txt",
		"PUT /x": "bad verb PUT",
		"nothing": "bad request"
	}
	out = []
	for line in ["SET volume=11", "SET name=", "GET x"]:
		if line is "SET {key}={value}":
			out.push("{key} is [{value}]")
	print(out.join(", "))
	first = match "a.b.zap":
		"{stem}.zap": stem
		_: ""
	second = match "c.zap.txt":
		"{s}.zap": s
		"{s}.zap.txt": s
		_: ""
	print("{first} {second}")
	prints """
		volume is [11], name is []
		a.b c
		"""

test "two captures side by side" refuses StrPatternAdjacentCaptures:
	s = "ab"
	print(match s:
		"{a}{b}": 1
		_: 0
	)

test "a capture is a name" refuses StrPatternCaptures:
	s = "ab"
	print(match s:
		"{a:>4}": 1
		_: 0
	)

# A map's pattern names keys that must be there, each value tested by the pattern after it; the
# other keys are ignored. Its keys are literals.
fn act(message {str: str}):
	match message:
		{"type": "move", "x": x, "y": y}: "move to {x}, {y}"
		{"type": "say", "text": text}: "say {text}"
		_: "drop"

fn mapTotal(counts {str: i64}):
	match counts:
		{"a": 0}: 0
		{"a": a, "b": 1..}: a + 100
		{"a": a}: a
		_: -1

test "a map's entries by key":
	moving = {"type": "move", "x": "1", "y": "2", "extra": "z"}
	say = {"type": "say", "text": "hi"}
	other = {"type": "jump"}
	missing = {"type": "move", "x": "1"}
	expect act == {moving: "move to 1, 2", say: "say hi", other: "drop", missing: "drop"}
	expect mapTotal == {{"a": 0}: 0, {"a": 5, "b": 2}: 105, {"a": 3, "b": 0}: 3, {"b": 1}: -1}

test "a map's keys are literals" refuses MapPatternKeys:
	m = {"a": 1}
	print(match m:
		{k: 1}: 1
		_: 0
	)

# Exhaustiveness covers variants, bools, optionals, results, tuples and structs of them at any
# depth, and lists by length; numbers, strings and maps end with `_` or a name. The error names a
# case left out.

# A name an arm only reads is not written back when the arm ends: a call that changes the matched
# module variable keeps its change, even when the name is an argument of that call.
type Stage:
	Idle
	Pinned(index i64)

mut stage = Stage.Idle

fn setStage(next Stage):
	stage = next

fn pinStage(index i64):
	print("pin {index}")
	setStage(.Pinned(index + 1))

test "a call in an arm that changes the matched module variable is not undone":
	loop 3:
		match stage:
			Idle: setStage(.Pinned(0))
			Pinned(index): pinStage(index)
	prints """
		pin 0
		pin 1
		"""
