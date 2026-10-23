# An integer narrowed, or its sign changed, where it lands and its values are proven inside the
# type (spec 3.1): arguments, generic and runtime calls, variants, function values, generators,
# signed shifts and u64 operations; the rest asks for the conversion.

type Shape:
	Dot(size u8)
	Line

fn first<T Copy>(x T, tag u8) (T, u8):
	(x, tag)

fn small(n i64) Seq<i8>:
	for i in 0..3:
		yield n >> 61 + i

fn apply(f fn(u16) i64, v i64):
	f(v & 0xffff)

test "narrowing where a value lands":
	r = u64(args.len) * 977 + 1_000_000_007
	n = -(args.len + 1_000)
	pair = first(1.5, r % 200)
	d = Shape.Dot(r & 127)
	size = match d:
		Dot(s): s
		Line: 0
	shifted i32 = n >> 40
	high u32 = r >> 33
	print("{pair} {size} {shifted} {high} {small(n).toList()} {apply(i64(it) * 2, n)}")
	prints """
		(1.5, 7) 7 -1 0 [-1, 0, 1] 129072
		"""

test "a sum that may pass the type is no narrowing" refuses InitializerType("'x' declared u8 but initializer is i64 in 0..=269 (its values are not proven inside it: convert it with u8(x), which stops the program outside it)"):
	n = args.len
	x u8 = n % 16 + n % 255
	print(x)
