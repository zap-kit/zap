# Records and behaviour: structs, enums with payloads, methods, closures, sorting of records,
# a bank with error values, a tiny stack-based expression evaluator, JSON round trip.
type Account:
	id i64
	owner str
	balance i64

	fn withdraw(amount i64) i64 ? TxError:
		if owner == "frozen": return TxError.Frozen
		if amount > balance: return TxError.Insufficient(amount - balance)
		balance -= amount
		balance

type Shape:
	Circle(r f64)
	Rect(w f64, h f64)
	Triangle(a f64, b f64, c f64)

	fn area():
		match self:
			Circle(r): return pi * r * r
			Rect(w, h): return w * h
			Triangle(a, b, c):
				s = (a + b + c) / 2.0
				return (s * (s - a) * (s - b) * (s - c)).sqrt()

	fn name():
		match self:
			Circle(r): return "circle"
			Rect(w, h): return "rect"
			Triangle(a, b, c): return "triangle"

type TxError:
	Insufficient(needed i64)
	Frozen
	Unknown(id i64)

fn describe(r i64 ? TxError):
	match r:
		v: return "ok, balance {v}"
		error:
			match error:
				Insufficient(n): return "insufficient funds, short by {n}"
				Frozen: return "account frozen"
				Unknown(id): return "unknown account {id}"

fn evalRpn(tokens str[]) i64?:
	stack i64[] = []
	for t in tokens:
		if t in ["+", "-", "*", "/"]:
			b = try stack.pop()
			a = try stack.pop()
			if t == "+":
				stack.push(a + b)
			elif t == "-":
				stack.push(a - b)
			elif t == "*":
				stack.push(a * b)
			else:
				if b == 0: return none
				stack.push(a / b)
		else:
			v = try i64.parse(t)
			stack.push(v)
	if stack.len != 1: return none
	stack[0]

fn makeCounter(step i64):
	count = [0]
	():
		count[0] += step
		count[0]

fn compose(move f fn(i64) i64, move g fn(i64) i64) fn(i64) i64:
	x: g(f(x))

shapes = [Shape.Circle(1.5), Shape.Rect(2.0, 3.5), Shape.Triangle(3.0, 4.0, 5.0), Shape.Circle(0.5)]
for s in shapes.sortedBy(.area()): print("{s.name()}: {s.area():.3}")
total = shapes.map(.area()).sum()
print("total area {total:.2}, largest {shapes.map(.area()).max() ?? 0.0}")

mut accounts = [
	Account(id = 1, owner = "ana", balance = 100),
	Account(id = 2, owner = "frozen", balance = 500),
	Account(id = 3, owner = "bo", balance = 20)
]
for mut account in accounts:
	print("{account.owner}: {describe(account.withdraw(50))}")
print(describe(TxError.Unknown(9)))
rich = accounts.filter(.balance >= 50).map(.owner)
print(
	"rich: {rich.join(", ")}; poorest: {accounts.sortedBy(.balance).first?.owner ?? "?"}"
)
copy = accounts[0].copy()
accounts[0].balance = 0
print("value semantics: copy {copy.balance}, original {accounts[0].balance}")

for expr in ["3 4 + 2 *", "5 1 2 + 4 * + 3 -", "1 0 /", "2 +", "10 3 /"]:
	match evalRpn(expr.split(" ")):
		v: print("{expr} = {v}")
		none: print("{expr} = error")

next = makeCounter(3)
other = makeCounter(10)
print("counters: {next()} {next()} {other()} {next()} {other()}")
inc = (x i64): x + 1
dbl = (x i64): x * 2
both = compose(inc.copy(), dbl.copy())
print("compose: {both(5)} {compose(dbl.copy(), inc.copy())(5)}")
fns = [inc, dbl, both]
print("applied: {fns.map(f: str(f(7))).join(" ")}")

json = accounts[2].toJson()
print(json)
match Account.fromJson(json):
	a: print("round trip: {a.owner} has {a.balance}")
	none: print("decode failed")
print("{[1, 2, 3].toJson()} {{"k": [true, false]}.toJson()} {"quote\"d".toJson()}")

test "structs, enums, methods, closures and sorted records work together":
	main()
	prints r"""
	    circle: 0.785
	    triangle: 6.000
	    rect: 7.000
	    circle: 7.069
	    total area 20.85, largest 7.0685834705770345
	    ana: ok, balance 50
	    frozen: account frozen
	    bo: insufficient funds, short by 30
	    unknown account 9
	    rich: ana, frozen; poorest: bo
	    value semantics: copy 50, original 0
	    3 4 + 2 * = 14
	    5 1 2 + 4 * + 3 - = 14
	    1 0 / = error
	    2 + = error
	    10 3 / = 3
	    counters: 3 6 10 9 20
	    compose: 12 11
	    applied: 8 14 16
	    {"id":3,"owner":"bo","balance":20}
	    round trip: bo has 20
	    [1,2,3] {"k":[true,false]} "quote\"d"
	    """
