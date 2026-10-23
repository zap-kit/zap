# 6.3 Taking values apart
#
# The pattern has the shape the value is made with: `a, b = t` (a tuple, its parentheses left out),
# `Point(x, y) = p` (fields in order), `Point(y = py) = p` (by name), `_` for a part not wanted. The
# same shapes follow `for`: `for (n, s) in pairs`, `for i, (n, s) in pairs`, `for Point(x, y) in
# points`.

type Point:
	x i64
	y i64

type Named:
	name str
	at Point

test "tuples and structs taken apart in bindings and loops":
	pairs = [(1, "a"), (2, "b")]
	line = ""
	for (n, s) in pairs:
		line += "{n}{s} "
	print(line.trimmed())
	line = ""
	for i, (n, s) in pairs:
		line += "{i}:{n}{s} "
	print(line.trimmed())
	Point(x, y) = Point(3, 4)
	Point(y = py) = Point(5, 6)
	_, last = 7, 8
	print("{x + y} {py} {last}")
	ps = [Point(1, 2), Point(7, 8)]
	line = ""
	for Point(a, b) in ps:
		line += "{a * b} "
	print(line.trimmed())
	people = [Named(name = "ana", at = Point(1, 1))]
	for Named(name, at) in people:
		print("{name} {at.x}")
	prints """
		1a 2b
		0:1a 1:2b
		7 6 8
		2 56
		ana 1
		"""

# A pattern of another type than the value's is an error.

# Each part is lent from the element of a `for`, and from a field or an element taken apart in a
# binding (`name, count = pairs[0]`), plain data copied; a variable or a temporary gives its parts
# to the names.

fn firstPair(pairs (str, i64)[]):
	name, count = pairs[0]
	"{name}{count}"

fn nameOf(people Named[], i i64) ref str:
	Named(name, _) = people[i]
	name

fn made():
	Named(name = "cy".repeat(2), at = Point(5, 6))

fn keep(move s str):
	s

test "an element of a borrowed list is taken apart in place, its parts lent":
	print(firstPair([("ann".repeat(1), 3)]))
	people = [
		Named(name = "al".repeat(1), at = Point(1, 2)),
		Named(name = "bo".repeat(1), at = Point(3, 4))
	]
	print(nameOf(people, 1))
	prints """
		ann3
		bo
		"""

test "a temporary gives its parts to the names":
	Named(name, at) = made()
	kept = keep(name)
	expect kept == "cycy"
	expect at.y == 6
