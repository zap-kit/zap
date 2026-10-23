# Values that own memory through the intermediate form: lists made, copied, returned, lent from a
# temporary, dropped at the end of their statement, their scope, and a break.
type P:
	name str
	tags i64[]
	n i64

fn make(k i64):
	out = []
	for i in 0..k:
		out.push(i * i)
	out

fn twice(xs i64[]):
	ys = xs.copy()
	for i in 0..ys.len:
		ys[i] *= 2
	ys

fn sum(xs i64[]):
	s = 0
	for x in xs:
		s += x
	s

fn pick(ps P[], i i64):
	p = ps[i]
	p.n + sum(p.tags)

fn churn(n i64):
	total = 0
	for k in 0..n:
		a = make(k % 10)
		b = twice(a)
		total += sum(b) + sum(make(3))
		if k == n - 1: break
	total

ps = [P(name = "a", tags = [1, 2], n = 5), P(name = "b", tags = [3], n = 7)]
print("{sum(make(5))} {sum(twice(make(4)))} {pick(ps, 1)} {churn(1000)}")

test "values that own memory are dropped at the end of their statement, their scope or a break":
	main()
	prints "30 28 10 113000"
