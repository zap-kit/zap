# 4.8 Shared values: `Channel` and `Atomic`
#
# The only values with many owners are the runtime's `shared type`s, which threads share. Each is a
# pointer with an atomic count: a copy is one more owner, and the last owner destroys it. Nothing
# else is counted.

# A `Channel<T>`'s copies are the same queue (see *Concurrency*), also inside structs and across
# threads.

type Sender:
	out Channel<str>
	id i64

fn worker(id i64, log Channel<str>):
	out = log
	for i in 0..id:
		out.send("w{id}.{i}")
	id

test "a channel's copies are the same queue":
	log = Channel<str>()
	senders = []
	for i in 0..4:
		senders.push(Sender(out = log, id = i))
	senders[2].out.send("from 2")
	other = log.copy()
	other.send("from a copy")
	print(log.len)
	senders.pop()
	senders.clear()
	reader = log
	print(reader.receive() ?? "")
	print(reader.receive() ?? "")
	jobs = (1..4).map(id: background((): worker(id, log)))
	lines = []
	while lines.len < 6:
		match reader.tryReceive():
			line: lines.push(line)
			none: sleepMs(1)
	print(lines.sorted())
	ids = 0
	for mut job in jobs:
		while not job.isDone:
			sleepMs(1)
		ids += job.tryReceive() ?? 0
	print(ids)
	prints """
		2
		from 2
		from a copy
		["w1.0", "w2.0", "w2.1", "w3.0", "w3.1", "w3.2"]
		6
		"""

# An `Atomic(v)` is an integer changed with one atomic instruction: `load()`, `store(v)`, `add(n)`
# returning the previous value, `compareSwap(old, new)`.

test "an atomic is one integer shared by every thread":
	counter = Atomic(0)
	squares = (0..100).parallel().map(i:
		counter.add(1)
		i * i
	)
	print("{counter.load()} {squares[99]}")
	print(counter.add(5))
	print(counter.compareSwap(105, 7))
	print(counter.compareSwap(105, 8))
	print(counter.load())
	counter.store(42)
	print(counter.load())
	prints """
		100 9801
		100
		true
		false
		7
		42
		"""

# They change only through their own methods: assigning a field or calling a built-in mutating
# method on one is rejected.

test "a shared value's field is not assigned" refuses AssignThroughShared:
	mut c = Atomic(0)
	c.value = 5
	print(c.load())

test "a shared value's parts are not changed" refuses MutateShared:
	log = Channel<str>()
	log.items.push("x")
	print(log.len)

# A program cannot declare a `shared type`: one value named from many places is kept in a `Pool`
# and reached through its handle.

test "a shared type is the runtime's" refuses SharedTypeOfRuntime:
	shared type Texture:
		uses i64
	print(Texture(uses = 0).uses)
