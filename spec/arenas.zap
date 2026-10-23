# 4.9 Arenas
#
# `arena:` opens a block whose allocations go at once: the strings, lists, maps and boxes made
# inside it, in its statements and in the functions they call, come from one region of the thread
# that the block's end gives back whole; a value of the region dropped inside the block frees
# nothing.

fn labels(n i64):
	kept = []
	for i in 0..n:
		arena:
			words = (0..8).map("w{it * i}")
			joined = words.join(",")
			parts = joined.split(",").map(.copy())
			if i % 50 == 0:
				kept.push("{i}:{parts.len}:{joined.len}")
	kept

fn labelsOnHeap(n i64):
	kept = []
	for i in 0..n:
		words = (0..8).map("w{it * i}")
		joined = words.join(",")
		parts = joined.split(",").map(.copy())
		if i % 50 == 0:
			kept.push("{i}:{parts.len}:{joined.len}")
	kept

# the blocks freed one by one while f runs
fn freesDuring(f fn(i64) str[], n i64):
	before = allocations() - liveBlocks()
	out = f(n)
	allocations() - liveBlocks() - before - out.len - 1

test "temporary strings and lists in an arena: the same output, fewer frees":
	print(labels(200).join(" "))
	arenaFrees = freesDuring(labels, 200)
	heapFrees = freesDuring(labelsOnHeap, 200)
	print("{labels(200) == labelsOnHeap(200)} {arenaFrees < heapFrees / 10}")
	prints """
		0:8:23 50:8:36 100:8:37 150:8:38
		true true
		"""

# Leaving the block by `break`, `continue` or `return` ends it too, and arenas nest.

fn firstLong(words str[]):
	for w in words:
		arena:
			up = w.upper()
			if up.len > 3: return "{up}!"
	"none"

test "break, continue and return leave the arena":
	outer = []
	names = ""
	for i in 0..10:
		arena:
			t = "item{i}"
			if i == 7: break
			if i % 2 == 0: continue
			outer.push("{t}+")
			names = "{names}{t.len}"
			arena:
				deep = [t.copy(), t.copy()]
				outer.push(deep.join("/"))
	print(outer.join(" "))
	print("{names} {firstLong(["ab", "abc", "abcd"])}")
	prints """
		item1+ item1/item1 item3+ item3/item3 item5+ item5/item5
		555 ABCD!
		"""

# Ownership makes it safe. A statement of the block that changes a place bound before it (an
# assignment, a `mut` argument or receiver, a call of a function that changes a module variable),
# returns, uses `try` or makes a lambda that is kept allocates from the heap instead, so what it
# puts there outlives the block.

mut notes str[] = []

fn note(i i64):
	notes.push("note {i}")

test "a call that keeps a value in a module variable allocates it outside the arena":
	arena:
		for i in 0..3:
			note(i)
	expect notes.join(",") == "note 0,note 1,note 2"

test "a copy of an arena's value is the heap's":
	kept = []
	arena:
		h = (0..3).map("h{it}")
		kept = h.copy()
	expect kept == ["h0", "h1", "h2"]

# A value bound inside the block that such a statement moves out is an error naming the block, and
# so is a value of an inner arena going to a binding of an outer one.

test "a value of the arena given to an outer binding" refuses ArenaEscape:
	mut last str[] = []
	arena:
		h = (0..3).map("h{it}")
		last = h
	print(last.len)

# A shared value (4.8) bound inside the block cannot leave it even copied, since its copies are the
# same value: it is made before the block.

test "a shared value of the arena copied to an outer binding" refuses ArenaEscape("'a' is made in the arena at line 3, which frees it at the block's end: it cannot go to a place outside the block (a shared value's copies are the same value"):
	mut keep = Atomic(0)
	arena:
		a = Atomic(5)
		keep = a
		a.add(1)
	print(keep.load())

test "a shared value made before the arena is copied inside it":
	counter = Atomic(0)
	ch = Channel<i64>(4)
	kept = []
	arena:
		c = counter
		c.add(7)
		kept.push(counter)
		ch.send(1)
	expect kept[0].load() == 7
	expect ch.len == 1

# A generator cannot `yield` inside an arena: the loop walking it may stop there.

test "yield inside an arena" refuses YieldInArena:
	fn doubled() Seq<str>:
		arena:
			yield "a".repeat(2)
	for w in doubled():
		print(w)

# A lambda's `return` leaves only the arena blocks opened inside it: one made in a block, run there
# (by a parallel step too), leaves the block's allocations in its region.

fn grownAfterLambda(n i64):
	grown = 0
	arena:
		parts = (0..4).parallel().map(i: i * n)
		before = liveBlocks()
		s = "word".repeat(50 + parts.len)
		grown = liveBlocks() - before if not s.isEmpty else -1
	grown

test "a lambda run in an arena block leaves its region open":
	expect grownAfterLambda(2) == 0

# Other threads allocate from their own heaps. A `Pool` nothing is removed from stays an arena too; `arena:` is the scoped one.
