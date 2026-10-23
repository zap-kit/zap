# `x is pattern` in conditions: it takes a variant or an optional apart, joins other conditions with
# and (each part sees the names bound before it), and loops with while.

type Shape:
	Circle(radius f32)
	Rect(width f32, height f32)

shapes = [
	(Shape.Circle(2.0), "big circle 2"),
	(Shape.Circle(0.5), "not a big circle"),
	(Shape.Rect(1.0, 1.0), "a rect")
]

test "is takes a variant apart, its names seen by the parts after it" for (s, said) in shapes:
	if s is Circle(r) and r > 1.0:
		print("big circle {r}")
	elif s is Rect:
		print("a rect")
	else:
		print("not a big circle")
	prints said

test "is on an optional, joined with other conditions":
	seen = []
	limit = 5
	xs i64?[] = []
	xs.push(7)
	xs.push(none)
	xs.push(3)
	for x in xs:
		if limit > 0 and x is v and v > limit:
			seen.push("found {v}")
		elif x == none:
			seen.push("none")
	expect seen.join(" ") == "found 7 none"

test "while is goes on while the pattern matches and the parts after it hold":
	q = [1, 2, 3, 4, 5]
	out = []
	while q.pop() is v and v > 3:
		out.push(v)
	expect out.map("{it}").join(" ") == "5 4"

test "is joins conditions with and only" refuses IsJoinedByOr:
	o i64? = 3
	if o is v or true:
		print(v)

type Counter:
	n i64

	fn bump(by i64):
		n += by

# a value small enough to be read into registers is written back when its name is `mut`, whatever
# changes it (a method, a field)
test "a mut name changes a small value through a method or a field":
	c Counter? = Counter(n = 1)
	loop 3:
		if c is mut v: v.bump(2)
	match c:
		mut v: v.n *= 10
		none: pass
	expect c?.n == 70
