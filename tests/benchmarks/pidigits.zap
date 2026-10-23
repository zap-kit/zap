# pidigits: the first n digits of pi by the spigot, step by step (Gibbons' streaming algorithm,
# as the Benchmarks Game's programs run it), over std/math's arbitrary integers: a term of the
# series composed in, a digit extracted when the numbers at 3 and at 4 agree on it, then taken
# out.
import math
import problems

# the linear fractional transformation (q r; 0 t), its term k, and a number reused for each
# extraction
type Spigot:
	q math.BigInt
	r math.BigInt
	t math.BigInt
	scratch math.BigInt
	k i64 = 0

	# the next term composed in: q k, r (2q + r)(2k + 1), t (2k + 1)
	fn nextTerm():
		k += 1
		k2 = 2 * k + 1
		r.combine(k2, q, 2 * k2)
		t.mulSmall(k2)
		q.mulSmall(k)

	# floor((q x + r) / t)
	fn extract(x i64):
		scratch.setMulAdd(q, x, r)
		scratch.div(t).toI64() ?? 0

	# the digit d taken out: r 10 (r - d t), q 10 q
	fn produce(d i64):
		r.combine(10, t, -10 * d)
		q.mulSmall(10)

	mut fn nextDigit():
		while true:
			self.nextTerm()
			if q.compare(r) > 0: continue
			d = self.extract(3)
			if d != self.extract(4): continue
			self.produce(d)
			return d
		0

n = arg(0, 27)
mut spigot = Spigot(
	q = math.BigInt.of(1),
	r = math.BigInt.of(0),
	t = math.BigInt.of(1),
	scratch = math.BigInt.of(0)
)
mut out = ""
mut done = 0
while done < n:
	count = (n - done).min(10)
	for i in 0..10:
		out += "{spigot.nextDigit()}" if i < count else " "
	done += count
	out += "\t:{done}\n"
stdout.write(out)

test "the spigot gives pi's first digits":
	main()
	prints """
	    3141592653	:10
	    5897932384	:20
	    6264338   	:27
	    """

test "the C, C++, Rust and Python programs print the same bytes":
	expect problems.agree("pidigits")
