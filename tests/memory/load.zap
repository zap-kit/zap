# Allocation stress for the ownership model: a hundred thousand iterations creating strings, lists,
# structs and map entries. Every block is freed by the end and the count is exact.
#
# Memory under load: every phase allocates and frees in rounds, the same work each round, so the
# memory the process holds must not grow with the number of rounds (a leak, or a structure kept
# growing, shows as memory that does). The phases: strings, lists, maps, Box trees, closures kept
# in lists, tuples and fixed arrays, a Pool, JSON and binary encoding, sorting, background jobs
# with channels, and .parallel() on every processor.

type Item:
	name str
	tags str[]

fn buildItem(i i64):
	Item(name = "item{i}", tags = ["a{i}", "b{i}", "c"])

mut total i64 = 0
mut m {str: i64} = {}
for i in 0..100000:
	item = buildItem(i)
	total = total + item.tags.len + item.name.len
	words = "x y z {i}".split(" ")
	total += words.len
	m["k{i % 100}"] = i
	if m.get("k7") is v:
		total += v % 2
print(total)

test "a hundred thousand turns of allocations free every block":
	main()
	prints "1688883"

type Tree:
	Leaf
	Node(left Box<Tree>, right Box<Tree>, label str)

type Unit:
	name str
	hp i64
	tags str[]

fn buildTree(depth i64, move label str) Tree:
	if depth == 0: return .Leaf
	.Node(Box(buildTree(depth - 1, "{label}l")), Box(buildTree(depth - 1, "{label}r")), label)

fn count(t Tree) i64:
	match t:
		Leaf: 1
		Node(left, right, label): 1 + count(left) + count(right) + label.len % 2

fn strings(rounds i64):
	sum = 0
	for r in 0..rounds:
		s = ""
		for i in 0..200:
			s += "{i % 10}"
			if s.len > 64:
				s = s[32..].copy()   # the tail kept as a text of its own
		parts = s.split("5")
		sum += parts.len + s.replace("1", "one").len + r % 2
	sum

fn lists(rounds i64):
	sum = 0
	loop rounds:
		xs = []
		for i in 0..100:
			xs.push(["a{i}", "b{i}"])
			if xs.len > 40:
				xs.remove(0)
		flat = xs.flatMap(.copy()).filter(.len > 2)
		sum += flat.len + xs.map(.len).sum()
	sum

fn maps(rounds i64):
	sum = 0
	m {str: i64[]} = {}
	for r in 0..rounds:
		for i in 0..200:
			key = "k{(i * 7 + r) % 150}"
			m[key] = [i, r]
			if i % 3 == 0:
				m.remove("k{i % 150}")
		sum += m.len
	sum

fn trees(rounds i64):
	sum = 0
	loop rounds:
		sum += count(buildTree(10, "t"))
	sum

fn closures(rounds i64):
	sum = 0
	for r in 0..rounds:
		fs = []
		for i in 0..50:
			suffix = "s{i}{r % 3}"
			fs.push((x str): x + suffix)
		for f in fs:
			sum += f("x").len
	sum

fn values(rounds i64):
	sum = 0
	for r in 0..rounds:
		units Unit[8]
		for i in 0..8:
			units[i] = Unit(name = "u{i}", hp = i * r % 100, tags = ["t{i}"])
		pairs = (0..8).map((-units[it].hp, units[it].name.copy()))
		best = pairs.sorted()
		less, name = best[0]
		sum += name.len - less
	sum

fn pool(rounds i64):
	sum = 0
	units = Pool<Unit>()
	live = []
	for r in 0..rounds:
		for i in 0..50:
			live.push(units.add(Unit(name = "p{i}", hp = r, tags = ["x", "y"])))
		while live.len > 20:
			units.remove(live.remove(0))
		sum += units.len
	sum

fn encoding(rounds i64):
	sum = 0
	for r in 0..rounds:
		u = Unit(name = "enc{r % 7}", hp = r, tags = ["a", "bb", "ccc"])
		text = u.toJson()
		back = Unit.fromJson(text) ?? Unit(name = "", hp = 0, tags = [])
		bytes = back.toBytes()
		again = Unit.fromBytes(bytes) ?? Unit(name = "", hp = 0, tags = [])
		sum += text.len + again.tags.len + again.name.len
	sum

fn producer(ch Channel<str>, n i64):
	out = ch
	for i in 0..n:
		out.send("m{i}")
	out.close()
	n

fn threads(rounds i64):
	sum = 0
	loop rounds:
		ch = Channel<str>(8)
		job = background((): producer(ch, 30))
		going = true
		while going:
			match ch.receive():
				msg: sum += msg.len
				none: going = false
		while not job.isDone:
			sleepMs(1)
		sum += job.tryReceive() ?? 0
	sum

fn parallel(rounds i64):
	sum = 0
	loop (rounds / 10).max(1):
		parts = (0..64).parallel().map(k:
			words = (0..100).map("w{k}-{it}")
			words.filter(.endsWith("7")).len
		)
		sum += parts.sum()
	sum

fn run(name str, rounds i64):
	match name:
		"strings": strings(rounds)
		"lists": lists(rounds)
		"maps": maps(rounds)
		"trees": trees(rounds / 10)
		"closures": closures(rounds)
		"values": values(rounds)
		"pool": pool(rounds)
		"encoding": encoding(rounds)
		"threads": threads(rounds)
		_: parallel(rounds)

phases = [
	"strings",
	"lists",
	"maps",
	"trees",
	"closures",
	"values",
	"pool",
	"encoding",
	"threads",
	"parallel"
]

test "a phase's memory does not grow with its rounds" for name in phases:
	run(name, 20)
	before = memoryCommitted()
	run(name, 200)
	expect memoryCommitted() - before < 1_048_576
