# Values owned by one system thread and taken by another through a channel: a background job and
# the thread that started it, each sending and receiving at once; every value arrives once and is
# freed once (the tests poison freed memory and count the blocks left).

import fs

fn echo(orders Channel<str>, replies Channel<str>):
	ins = orders
	outs = replies
	n = 0
	loop:
		order = ins.receive() ?? break
		outs.send("{order}!")
		n += 1
	outs.close()
	n

test "texts go to a job and come back, each once":
	orders = Channel<str>()
	replies = Channel<str>(4)
	job = background((): echo(orders, replies))
	send = orders
	back = replies
	got = 0
	sum = 0
	for i in 0..2000:
		send.send("t{i}")
		while back.tryReceive() is r:
			got += 1
			sum += r.len
	send.close()
	loop:
		r = back.receive() ?? break
		got += 1
		sum += r.len
	while not job.isDone:
		sleepMs(1)
	print("{got} {sum} {job.tryReceive() ?? -1}")
	prints "2000 10890 2000"

fn makeLists(out Channel<i64[]>, n i64):
	to = out
	for i in 0..n:
		to.send((0..i % 50).map(it * i))
	n

test "lists a job makes are dropped by the thread that receives them":
	lists = Channel<i64[]>(8)
	job = background((): makeLists(lists, 3000))
	from = lists
	total = 0
	loop 3000:
		xs = from.receive() ?? break
		total += xs.len
	while not job.isDone:
		sleepMs(1)
	print("{total} {job.tryReceive() ?? -1}")
	prints "73500 3000"

fn slowText(n i64):
	total = 0
	for i in 0..n:
		total += i % 7
	"{total}".repeat(3)

test "a job given up frees its result, before or after it is in":
	early = background((): slowText(5_000_000))   # still running when it goes
	late = background((): slowText(10))
	while not late.isDone:
		sleepMs(1)
	_ = early
	_ = late
	print("given up")
	prints "given up"

# a program that ends while the background threads its waiting jobs asked for are still starting
lateStarts = """
	fn wait(k i64):
		rt.blockingBegin()
		sleepMs(20)
		rt.blockingEnd()
		k

	mut jobs = []
	for k in 0..200:
		jobs.push(background((): wait(k)))
	"""

test "a program ends cleanly before the threads it just made have started":
	file = "{testDir()}latestarts.zap"
	_ = fs.writeFile(file, lateStarts)
	expect Process.output("{zapPath()} build {file}").code == 0
	failed = (0..20).count(_: Process.output(builtExe("latestarts")).code != 0)
	print("failed runs {failed}")
	prints "failed runs 0"

# rounds of a job sending one value and closing the channel while its receiver waits, which
# exits with 4 when a value went missing
lastValues = """
	fn producer(ch Channel<i64>):
		out = ch
		out.send(1)
		out.close()

	received = 0
	loop arg(0, 0):
		ch = Channel<i64>(1)
		job = background((): producer(ch))
		while ch.receive() is v:
			received += v
		_ = job
	if received != arg(0, 0):
		exit(4)
	"""

test "a receive that waits as the last job closes its channel is no deadlock, on a loaded machine":
	file = "{testDir()}lastvalues.zap"
	_ = fs.writeFile(file, lastValues)
	expect Process.output("{zapPath()} build {file}").code == 0
	runs = (0..8).map(_: Process.start("{builtExe("lastvalues")} 50000"))
	failed = 0
	for mut r in runs:
		if r.wait() != 0: failed += 1
	print("failed runs {failed}")
	prints "failed runs 0"
