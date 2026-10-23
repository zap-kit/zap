# lru: an LRU cache of `size` entries through n operations of the programming-language-benchmarks
# suite: each step puts a key of one LCG and gets a key of another; prints the hits and the misses.
# A map from key to slot, the slots in a doubly linked list from the oldest to the newest.
import problems

type Cache:
	size i32
	head i32
	tail i32
	key i32[]
	value i32[]
	prev i32[]
	next i32[]
	slot {i32: i32}

	fn unlink(s i32):
		p, n = prev[s], next[s]
		if p < 0:
			head = n
		else:
			next[p] = n
		if n < 0:
			tail = p
		else:
			prev[n] = p

	fn append(s i32):
		prev[s] = tail
		next[s] = -1
		if tail < 0:
			head = s
		else:
			next[tail] = s
		tail = s

	mut fn moveToEnd(s i32):
		if s == tail: return
		unlink(s)
		append(s)

	fn put(k i32, v i32):
		if slot.get(k) is found:
			s = found
			value[s] = v
			moveToEnd(s)
			return
		s = 0
		if slot.len == size:
			s = head
			slot.remove(key[s])
			unlink(s)
		else:
			s = i32(slot.len)
		key[s] = k
		value[s] = v
		slot[k] = s
		append(s)

	mut fn get(k i32):
		if slot.get(k) is found:
			moveToEnd(found)
			return true
		false

type Lcg:
	state u64

	# the next number of an LCG: 31 bits
	fn next():
		state = (state * 1_103_515_245 + 12_345) & 0x7fff_ffff
		state

size i32 = arg(0, 100)
n = arg(1, 10_000)
modular = u64(size) * 10
mut cache = Cache(
	size,
	head = -1,
	tail = -1,
	key = zeros(size),
	value = zeros(size),
	prev = zeros(size),
	next = zeros(size),
	slot = {})
cache.slot.reserve(i64(size))   # as Rust's with_capacity: the table made once
mut rng0 = Lcg(state = 0)
mut rng1 = Lcg(state = 1)
mut hit = 0
mut missed = 0
loop n:
	k0 = i32(rng0.next() % modular)
	cache.put(k0, k0)
	k1 = i32(rng1.next() % modular)
	if cache.get(k1):
		hit += 1
	else:
		missed += 1
print(hit)
print(missed)

test "the cache's hits and misses are the known counts":
	main()
	prints """
		952
		9048
		"""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("lru")
