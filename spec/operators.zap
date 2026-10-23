# 2.5 Operators
#
# `zap doc operators` prints the levels from loosest to tightest after this section, from the
# compiler's table of the operators: the value a condition picks (6.1; `?` is the types' alone,
# `T?` and `T ? E`), the ranges, `??` (6.4), the binary operators, the unary ones (6.5), `**` and
# the postfix forms. `or` and `and` short-circuit.

fn loud(b bool):
	print("asked")
	b

test "operators bind by their precedence, and and or stop at the side that decides":
	expect 1 + 2 * 3 == 7
	expect 1 | 2 + 4 == 7
	expect 6 & 3 * 1 == 2
	expect (1 << 2 + 1) == 5
	expect (2 + 1 << 2) == 6
	expect true or false and false
	expect 1 < 2 == true
	expect 1 + 1 in [2]
	expect not (false and loud(true))
	expect true or loud(false)

test "** is right-associative and binds tighter than unary minus":
	expect 2 ** 3 ** 2 == 512
	expect -2 ** 2 == -4

# `not` binds as `-` does: `not a == b` is `(not a) == b`
test "not binds tight" refuses NotNeedsBool:
	print(not 1 == 2)

# `x in xs` and `x not in xs` ask what a list's or a str's `contains`, a map's keys and a type's own
# `contains` method (`h in pool`, 4.6) tell. With a list literal it is a chain of `==`, no list made;
# `x in lo..hi` is `lo <= x and x < hi` (`lo..=hi` its end included), x read twice.

type Kind:
	Int
	Float
	Text

fn named(k Kind):
	k in [.Int, .Text]

test "in asks lists, strings and maps":
	xs = [1, 2, 3]
	s = "hello"
	m = {"a": 1}
	expect 2 in xs
	expect not (5 in xs)
	expect 4 not in xs
	expect "ell" in s
	expect not ("x" in s)
	expect "a" in m
	expect not ("b" in m)

test "in a list literal or a range compares":
	k = 7
	print("{k in [1, 7, 9]} {k not in [1, 7, 9]} {named(.Text) and not named(.Float)}")
	a = args.len
	print("{a in 0..3} {a in 1..=3} {5 in 1..=5} {a not in 0..1}")
	prints """
		true false true
		true false true false
		"""

test "in a range reads a name, a field or a literal" refuses InRangeNeedsName:
	xs = [1, 2]
	print(xs.len + 1 in 0..3)

# `==` compares any value made of comparable parts, part by part: numbers, strings, bools, structs
# and tuples field by field, lists and arrays element by element, optionals, enums by variant and
# values. `<` orders numbers, strings (byte order), and tuples, lists and arrays lexicographically,
# so they sort and serve as `sortedBy` keys.

type P:
	x i64
	name str

type Shape:
	Circle(r f64)
	Rect(w f64, h f64)
	Dot

test "equality and order of composite values":
	expect P(x = 1, name = "a") == P(x = 1, name = "a")
	expect P(x = 1, name = "a") != P(x = 1, name = "b")
	expect (1, "x") == (1, "x") and [1, 2] == [1, 2] and [1, 2] != [1, 2, 3]
	expect [2] in [[1], [2]]
	a i64[2] = [1, 2]
	b i64[2] = [1, 3]
	o i64? = 3
	p i64? = 3
	expect a != b and o == p and o != none
	print("{Shape.Circle(1.0) == .Circle(1.0)} {Shape.Rect(1.0, 2.0) == .Circle(1.0)} {Shape.Dot == .Dot}")
	expect "abc" < "abd" and "B" < "a" and (1, "b") < (1, "c") and [1, 2] < [1, 2, 0]
	expect [(2, "b"), (1, "z"), (1, "a")].sorted() == [(1, "a"), (1, "z"), (2, "b")]
	prints "true false true"

test "a map has no equality" refuses NoEquality:
	a {str: i64} = {}
	print([a] == [a])

test "a struct has no order" refuses CannotOrder:
	type Q:
		x i64
	print(Q(x = 1) < Q(x = 2))

# Postfix: `x?.f` is safe access (none propagates). Inside an index's brackets `len` is the indexed
# list's length, the innermost list's in nested brackets.

type Mon:
	hp i64
	name str

test "safe access and len inside brackets":
	m Mon? = none
	k Mon? = Mon(hp = 2, name = "k")
	print("{m?.hp} {k?.hp}")
	xs = [1, 2, 3, 4, 5]
	ys = [7, 8, 9]
	print("{xs[len - 1]} {xs[ys[len - 1] - 7]} {xs[len - 3..]} {xs[len / 2..]}")
	s = "abc"
	print(s[len - 1] - 'a')
	prints """
		none some(2)
		5 3 [3, 4, 5] [3, 4, 5]
		2
		"""

type Block:
	insts i64[]

test "len inside brackets on a list reached through another len":
	blocks = [Block(insts = [1, 2, 3]), Block(insts = [4, 5])]
	way = [0, 1]
	expect blocks[way[len - 1]].insts[len - 1] == 5

test "len inside brackets on a list a call gives" refuses LenNeedsPlace:
	fn scores() i64[]:
		[3, 1, 2]

	print(scores()[len - 1])

test "len stands inside brackets alone" refuses UnknownVariable:
	xs = [1, 2]
	print(len + xs.len)

# A name after a leading dot is a field's function when lower case: `.hp` is `it.hp`, the value of
# the call's argument it is in (6.3). Upper case, it is a variant of the enum the place expects.

# There is no operator overloading: the math operators have one fixed meaning, on numbers, on lists
# of numbers and the SIMD types (7.8), on grids of numbers (7.10), and on structs
# whose fields are all one number type (3.2). Anything else uses named methods.
