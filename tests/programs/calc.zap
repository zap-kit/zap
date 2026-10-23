# A tiny expression calculator: tokenizer + recursive-descent parser + evaluator over f64.
type Tok:
	Num(value f64)
	Op(ch str)
	LParen
	RParen
	End
fn isDigit(ch str):
	c = ch.charCode()
	c >= 48 and c <= 57
fn tokenize(src str):
	toks Tok[] = []
	chars = src.chars()
	i = 0
	while i < chars.len:
		ch = chars[i]
		if ch == " ":
			i += 1
		elif ch.isDigit() or ch == ".":
			j = i
			while j < chars.len and (chars[j].isDigit() or chars[j] == "."):
				j += 1
			text = chars[i..j].join("")
			toks.push(.Num(f64.parse(text) ?? 0.0))
			i = j
		elif ch == "(":
			toks.push(.LParen)
			i += 1
		elif ch == ")":
			toks.push(.RParen)
			i += 1
		else:
			toks.push(.Op(move chars[i]))
			i += 1
	toks.push(.End)
	toks
type Parser:
	toks Tok[]
	pos i64

	fn peek() ref Tok:
		toks[pos]

	# a token is read once: next() moves it out of the list
	fn next():
		pos += 1
		move toks[pos - 1]

	mut fn primary() f64 ? str:
		t = next()
		match t:
			Num(v): v
			LParen:
				v = try expr()
				match next():
					RParen: v
					_: "expected )"
			Op(ch):
				if ch == "-":
					v = try primary()
					return -v
				return "unexpected {ch}"
			_: "unexpected end"

	mut fn term() f64 ? str:
		v = try primary()
		going = true
		while going:
			match peek():
				Op(ch):
					if ch == "*" or ch == "/":
						times = ch == "*"
						next()
						r = try primary()
						if times:
							v *= r
						else:
							if r == 0.0: return "division by zero"
							v /= r
					else:
						going = false
				_: going = false
		v

	mut fn expr() f64 ? str:
		v = try term()
		going = true
		while going:
			match peek():
				Op(ch):
					if ch == "+" or ch == "-":
						plus = ch == "+"
						next()
						r = try term()
						if plus:
							v += r
						else:
							v -= r
					else:
						going = false
				_: going = false
		v
fn eval(src str) f64 ? str:
	p = Parser(toks = tokenize(src), pos = 0)
	v = try p.expr()
	match p.peek():
		End: v
		_: "trailing input"
for src in [
	"1 + 2 * 3",
	"(1 + 2) * 3",
	"10 / 4",
	"-(2 + 3) * 2",
	"2 * (3 + 4) - 5 / (1 + 1)",
	"1 / 0",
	"2 +",
	"(1 + 2"
]:
	match eval(src):
		v: print("{src} = {v}")
		error: print("{src} -> error: {error}")

test "the calculator tokenizes, parses and evaluates its expressions":
	main()
	prints """
	    1 + 2 * 3 = 7
	    (1 + 2) * 3 = 9
	    10 / 4 = 2.5
	    -(2 + 3) * 2 = -10
	    2 * (3 + 4) - 5 / (1 + 1) = 11.5
	    1 / 0 -> error: division by zero
	    2 + -> error: unexpected end
	    (1 + 2 -> error: expected )
	    """
