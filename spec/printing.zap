# 7.6 Printing and streams
#
# `print(x)` (stdout) and `eprint(x)` (stderr) write any value and a newline. Strings print bare at
# the top level and quoted inside containers; lists print as `[1, 2]`, maps as `{"a": 1}`,
# optionals as `some(5)` / `none`, structs as they are made, variants as `Node(5, [])`, results as
# `ok(v)` / `err(e)`.

type Point:
	x i64
	y i64

type Tree:
	Node(v i64, kids Tree[])
	Leaf

fn half(n i64) i64 ? i32:
	n / 2 if n % 2 == 0 else i32(1)

test "print writes any value":
	print("bare")
	print(["a", "b"])
	print([[1, 2], [3]])
	print({"a": [1]})
	opt i64? = 5
	none5 i64? = none
	print("{opt} {none5} {[1.5, 2.5]} {true and false or true}")
	print(Point(x = 1, y = 2))
	print("{Tree.Node(5, [])} {Tree.Leaf}")
	print("{half(4)} {half(3)}")
	prints r"""
		bare
		["a", "b"]
		[[1, 2], [3]]
		{"a": [1]}
		some(5) none [1.5, 2.5] true
		Point(x = 1, y = 2)
		Node(5, []) Leaf
		ok(2) err(1)
		"""

# `stdout` and `stderr` are values, `Stream`s with `write(text)` and `writeBytes(bytes)` (no
# newline) and `print(value)` (the one way to write a line), for output without a newline or with
# a destination chosen as a value.

test "streams are values":
	out = stdout
	out.write("name: ")
	out.print("ana")
	for i in 0..3:
		out.write("{i} ")
	out.print("")
	out.print(Point(x = 1, y = 2))
	stdout.writeBytes([104, 105, 10])
	chosen = stdout if args.len > 99 else stderr
	chosen.print("to stderr")
	eprint("warning: to stderr too")
	stderr.write("no newline on stderr\n")
	stdout.print(3.5)
	prints """
		name: ana
		0 1 2 
		Point(x = 1, y = 2)
		hi
		3.5
		"""

# `stdin` is the standard input as a stream: `stdin.line()` (the next line, `str?`), `stdin.all()`
# (the rest, `str`), `stdin.text(n)` (`n` bytes as text, `str?`), `stdin.until(b)` (up to the byte
# `b`, left unread, `str?`); tests/io reads it.
#
# Stdout is buffered (64 KB): on a console each line goes out as it completes; into a file or pipe
# the buffer is written when full, at exit, before anything goes to stderr, before stdin is read
# and before a child process starts.
