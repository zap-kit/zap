type Owned:
	name str
	container str

test "a generic body checked for a reference and for a number keeps each instance's own code":
	ds = [
		Owned(name = "a", container = "b"),
		Owned(name = "b", container = "a"),
		Owned(name = "c", container = "z")
	]
	names = ds.map(.name)
	n = 0
	for d in ds:
		if d.container in names:
			n += 1
	xs = [3, 4, 5]
	expect n == 2
	expect (4 in xs)
	expect (xs.indexOf(5) ?? -1) == 2

fn applied<T>(x T, f fn(T) i64) i64:
	f(x)

fn doubled(v n32):
	i64(v) * 2

test "a range's value and a function of that range bind T to the range":
	xs n32[] = [3, 4]
	expect applied(xs[1], doubled) == 8
