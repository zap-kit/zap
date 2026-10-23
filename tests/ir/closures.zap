# Closures through the intermediate form: lambdas held by locals and called, passed to functions
# taking fn parameters, capturing numbers, strs and lists (copied or moved), named functions as
# values; environments freed.
#
# Lambdas with block bodies through the intermediate form: the block's value is the lambda's
# (the parser's implicit return), an early return leaves the lambda, locals of the block are
# dropped each turn; nothing leaks.

type Op:
	name str
	apply fn(i64) i64

fn twice(f fn(i64) i64, x i64):
	f(f(x))

fn double(x i64):
	x * 2

fn adder(n i64) fn(i64) i64:
	x: x + n

fn tagger(move prefix str):
	(s str): "{prefix}:{s}"

fn applyAll(ops Op[], x i64):
	v = x
	for op in ops:
		v = op.apply(v)
	v

fn churnClosures(n i64):
	before = liveBlocks()
	total = 0
	for i in 0..n:
		add = adder(i)
		tag = tagger("p{i}")
		words = ["a", "b"]
		count = (s str): words.len + s.len
		total += add(1) + tag("x").len + count("yy") + twice(double, i)
	total > 0 and liveBlocks() == before

test "lambdas held, passed and capturing values are called and freed":
	add = adder(4)
	tag = tagger("pre")
	words = ["a", "b"]
	count = (s str): words.len + s.len
	ops = [Op(name = "d", apply = double), Op(name = "a", apply = adder(10))]
	expect twice(double, 3) == 12
	expect add(3) == 7
	expect tag("x") == "pre:x"
	expect count("abc") == 5
	expect applyAll(ops, 10) == 30
	expect churnClosures(20)

type Note:
	text str
	line i64

fn labels(notes Note[]):
	notes.map(n:
		prefix = "late" if n.line > 1 else "early"
		"{prefix}:{n.text}"
	)

fn firstLong(words str[]):
	words.findIndex(w:
		if w.len > 3: return true
		w == "zz"
	) ?? -1

fn total(xs i64[]):
	xs.reduce(0, (acc, x): acc + x * 2)

fn churnLambdas(n i64):
	before = liveBlocks()
	k = 0
	for i in 0..n:
		k += labels([Note(text = "a{i}", line = i)]).len
	k == n and liveBlocks() == before

test "a lambda's block returns early and reads what it captured":
	ns = [Note(text = "a", line = 1), Note(text = "b", line = 2)]
	print("{labels(ns)} {firstLong(["ab", "cdef"])} {firstLong(["a", "b", "zz"])} {total([1, 2, 3])} {churnLambdas(20)}")
	prints "[\"early:a\", \"late:b\"] 1 2 12 true"
