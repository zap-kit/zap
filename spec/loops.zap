# 6. Control flow, optionals and errors
#
# 6.1 Conditions and loops
#
# `if c:` runs its block when c holds; `elif c:` is another condition after it and `else:` the
# rest. An `if` is a statement; a value picked by a condition is `a if c else b`, chained as
# `a if c else b if d else e`. The choice binds looser than every operator but `??` (so
# `x + y if c else z` is `(x + y) if c else z`, and `a ?? b if c else d` is `a ?? (b if c else d)`),
# and a lambda's body takes the whole choice. Its condition and the value before `if` are
# parenthesised when they are choices themselves.

fn kind(n i64):
	if n < 0: "negative"
	elif n == 0: "zero"
	elif n < 10:
		"small"
	else: "large"

fn sign(n i64):
	"neg" if n < 0 else "zero" if n == 0 else "pos"

test "elif chains conditions":
	expect kind == {-1: "negative", 0: "zero", 5: "small", 50: "large"}

test "an if on one line is a value":
	expect sign == {-2: "neg", 0: "zero", 9: "pos"}
	n = 7
	expect (n if n > 4 else 4) == 7
	expect [1, 2, 3].map(it * 10 if it == 2 else it) == [1, 20, 3]

test "a choice binds looser than the operators":
	n = 3
	expect (n + 1 if n > 2 else n - 1) == 4
	expect (n * 2 if n > 5 else n * 3 if n > 2 else 0) == 9
	expect ((1 if n > 2 else 2) + 10) == 11
	print("big" if n > 2 and n < 9 else "small")
	prints """
		big
		"""

test "a choice and the fallback":
	missing i64? = none
	n = 3
	expect (missing ?? 8 if n > 2 else 9) == 8
	expect (missing ?? 8 if n > 5 else missing ?? 7) == 7
	print("{n if n > 1 else 0} {[1, 2].map(it * 2 if it > 1 else it)}")
	prints """
		3 [1, 4]
		"""

# `x is pattern` tests any pattern of *Match* (`Circle(r)`, `[first, ..rest]`,
# `"SET {key}={value}"`) and binds its names; `while x is pattern` loops while it matches. It joins
# other conditions with `and` (each part may test one, and sees the names the parts before it
# bind), never with `or` (an error: the names would not always be there); `is _` and `is none`
# are errors pointing to `!= none` and `== none` (see *Optionals*).

test "is binds the names of a pattern, and joins conditions with and":
	opt i64? = 5
	if opt is x:
		print(x)
	xs = [3, 4, 5]
	if xs is [first, ..rest] and first > 2:
		print("{first} {rest}")
	queue = [1, 2, 3]
	while queue.pop() is v:
		print(v)
	prints """
		5
		3 [4, 5]
		3
		2
		1
		"""

# `while c:` loops while c holds; `loop:` until a `break`; `loop n:` n rounds with no variable
# (`for _ in 0..n` is an error, and so is `while true`). `break` and `continue` are valid only
# inside a loop.

test "while, loop and loop n":
	i = 0
	total = 0
	while i < 10:
		i += 1
		total += i
	print(total)
	rounds = 0
	loop:
		rounds += 1
		if rounds == 4: break
	print(rounds)
	count = 0
	loop 3:
		loop 4:
			count += 1
	print(count)
	n = 0
	loop n:
		print("never")
	prints """
		55
		4
		12
		"""

test "a loop over nothing but a count is loop n" refuses LoopVariable:
	for _ in 0..3:
		print(1)

test "break is valid only inside a loop" refuses BreakOutsideLoop:
	break

# `for item in xs:` goes over a list's elements, `for i, x in xs:` with the index; `continue` goes
# on to the next, `break` leaves. A loop's names are new ones: a name bound before the loop is
# hidden inside it and keeps its value. Written `mut` (`for mut m in monsters`, `for i, mut x in
# xs`), the name is the element itself, as a `match`'s or an `is`'s `mut` name is: `m.hp -= 1`
# changes each monster, `x *= 2` each number, and `m.heal()` or `damage(m)` (a `mut` parameter)
# changes it in place, so the list is a place that changes (spec 2.4). The list is lent to the
# loop meanwhile: the body does not change it but through the name. Without `mut` the name only
# reads its element, and a loop over a range, a text or a sequence has no element to change.

test "for over a list, with its index, continue and break":
	names = ["ana", "bia", "caio", "dani"]
	for name in names:
		if name == "bia": continue
		if name == "dani": break
		print(name)
	for i, name in names:
		if i < 2:
			print("{i} {name}")
	prints """
		ana
		caio
		0 ana
		1 bia
		"""

type Monster:
	name str
	hp i64

	fn heal():
		hp += 5

test "a loop's mut name changes the element":
	monsters = [Monster(name = "slime", hp = 10), Monster(name = "orc", hp = 40)]
	for mut m in monsters:
		m.hp -= 1
		m.heal()
	xs = [1, 2, 3]
	for mut x in xs:
		x *= 2
	for i, mut x in xs:
		x += i
	print("{monsters.map(.hp)} {xs}")
	prints "[14, 44] [2, 5, 8]"

test "a loop's name without mut changes nothing" refuses AssignThroughImmutable:
	type Monster:
		hp i64
	monsters = [Monster(hp = 10)]
	for m in monsters:
		m.hp -= 1

test "a loop over a range has no element to change" refuses MutLoopNoElement:
	for mut i in 0..3:
		print(i)

test "a loop's index is never mut" refuses MutLoopIndex:
	xs = [1, 2]
	for mut i, x in xs:
		print(i + x)

test "it is no loop variable" refuses ItIsNoName:
	for it in [1, 2]:
		print(it)

test "it is no mut loop variable" refuses ItIsNoName:
	for mut it in [1, 2]:
		print(it)

test "it is no loop index element" refuses ItIsNoName:
	for i, it in [1, 2]:
		print(i)

test "a loop's element pattern is a tuple or a struct" refuses TargetPattern:
	for 1 in [1, 2]:
		print(1)

test "an indexed loop's element pattern is a tuple or a struct" refuses TargetPattern:
	for i, 1 in [1, 2]:
		print(i)

test "while the loop changes its elements the list is not read another way" refuses ReadWhileLent:
	xs = [1, 2, 3]
	for mut x in xs:
		x += xs[0]
		x += 1

test "while the loop changes its elements the list is lent to it" refuses ChangeWhileBorrowed:
	xs = [1, 2, 3]
	for mut x in xs:
		x += 1
		xs.push(x)

test "a loop's names hide the names bound before it":
	xs = [4, 5]
	text = "hi"
	numbers i64[2] = [6, 7]
	i = 9
	x = 0
	b u8 = 0
	for i, x in xs:
		print("{i} {x}")
	for b in text:
		print(b)
	for x in numbers:
		print(x)
	print("{i} {x} {b}")
	i = 1
	x = 1
	b = 1
	prints """
		0 4
		1 5
		104
		105
		6
		7
		9 0 0
		"""

# `for i in a..b:` is half-open, a literal bound taking the other's type; `a..=b` takes its end
# (zap fmt writes `a..b + 1` so). `a..b step s` gives a, a + s, ... below b; a negative literal
# step counts down (`n..0 step -1`), and a step that is not a literal is checked to be positive
# when the loop starts (0 or less stops the program: such a loop would never end).

test "ranges: half-open, with their end, with a step":
	squares = 0
	for i in 0..5:
		squares += i * i
	print(squares)
	big i64 = 3
	acc = 0
	for k in 0..big:
		acc += k * 1_000_000_000_000
	print(acc)
	parts = []
	for i in 1..=3:
		parts.push("{i}")
	print(parts.join(" "))
	xs = []
	for i in 0..10 step 3:
		xs.push(i)
	print(xs)
	down = []
	for i in 5..0 step -2:
		down.push(i)
	print(down)
	workers = 4
	total = 0
	for w in 0..workers:
		for i in w..22 step workers:
			total += i
	print(total)
	never = 0
	for i in 1..1 step 5:
		never += i + 1
	print(never)
	prints """
		30
		3000000000000
		1 2 3
		[0, 3, 6, 9]
		[5, 3, 1]
		231
		0
		"""

test "the step is a word, not a method" refuses RangeStepWord:
	for i in (0..10).by(3):
		print(i)

# `for line in text.lines():` goes over windows of the text, one a line, with no allocation; a
# generator's walk is a `for` too (see *Generators*). `x.max(y)` and `x.min(y)` pick between two
# numbers.

test "lines, and the larger and smaller of two numbers":
	for line in "a\nbc".lines():
		print(line.len)
	print("{3.max(8)} {3.min(8)}")
	prints """
		1
		2
		8 3
		"""

# a body that ends in `while true` gives its value by a `return` inside it, a list alive there
fn firstAbove(xs i64[], at i64):
	seen = zeros(4)
	i = 0
	while true:
		seen[i % 4] = xs[i]
		if xs[i] > at: return xs[i] + seen[0]
		i += 1

test "a function ending in an endless loop returns from inside it":
	expect firstAbove([1, 5, 9], 4) == 6
