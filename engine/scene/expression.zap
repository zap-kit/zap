# Arithmetic and logical expressions over named numbers ("(speed > 5) && !blocked", "clamp(1 - 2 * w,
# 0, 1)"), as the conditions and assignments of an animation graph are written: numbers, names (a
# name that is not set is 0), the operators ! - * / + - < <= > >= == != && || in C's order,
# parentheses and the functions clamp, min, max and abs. A truth is 1, a falsehood 0.

type Token:
	text str
	number bool

type Parser:
	tokens Token[]
	at i64
	names {str: f32}

fn isNameByte(c u8):
	c.isAlpha() or c.isDigit() or c == 95 or c == 46

# the numbers, names, operators and brackets of the text
fn tokensOf(text str):
	s = text.bytes()
	out = []
	i = 0
	while i < s.len:
		c = s[i]
		if c == 32 or c == 9:
			i += 1
			continue
		start = i
		if isNameByte(c):
			while i < s.len and isNameByte(s[i]):
				i += 1
			out.push(Token(text = str(s[start..i]), number = c.isDigit() or c == 46))
			continue
		i += 1
		pair = i < s.len and ((c in [61, 33, 60, 62]) and s[i] == 61 or
				(c == 38 and s[i] == 38) or (c == 124 and s[i] == 124))
		if pair: i += 1
		out.push(Token(text = str(s[start..i]), number = false))
	out

fn peek(p Parser):
	p.tokens[p.at].text.copy() if p.at < p.tokens.len else ""

fn take(mut p Parser):
	t = p.peek()
	p.at += 1
	t

fn truth(b bool) f32:
	1.0 if b else 0.0

fn orOf(mut p Parser):
	v = p.andOf()
	while p.peek() == "||":
		p.at += 1
		r = p.andOf()
		v = truth(v != 0.0 or r != 0.0)
	v

fn andOf(mut p Parser):
	v = p.equalityOf()
	while p.peek() == "&&":
		p.at += 1
		r = p.equalityOf()
		v = truth(v != 0.0 and r != 0.0)
	v

fn equalityOf(mut p Parser):
	v = p.comparisonOf()
	while p.peek() == "==" or p.peek() == "!=":
		op = p.take()
		r = p.comparisonOf()
		v = truth((v == r) == (op == "=="))
	v

fn comparisonOf(mut p Parser):
	v = p.sumOf()
	while p.peek() in ["<", "<=", ">", ">="]:
		op = p.take()
		r = p.sumOf()
		match op:
			"<": v = truth(v < r)
			"<=": v = truth(v <= r)
			">": v = truth(v > r)
			_: v = truth(v >= r)
	v

fn sumOf(mut p Parser):
	v = p.productOf()
	while p.peek() == "+" or p.peek() == "-":
		op = p.take()
		r = p.productOf()
		v = v + r if op == "+" else v - r
	v

fn productOf(mut p Parser):
	v = p.unaryOf()
	while p.peek() == "*" or p.peek() == "/":
		op = p.take()
		r = p.unaryOf()
		if op == "*":
			v *= r
		else:
			v = v / r if r != 0.0 else 0.0
	v

fn unaryOf(mut p Parser) f32:
	t = p.peek()
	if t == "!":
		p.at += 1
		return truth(p.unaryOf() == 0.0)
	if t == "-":
		p.at += 1
		return -p.unaryOf()
	p.primaryOf()

# the arguments of a call, up to its closing bracket
fn argumentsOf(mut p Parser):
	out = []
	while p.at < p.tokens.len and p.peek() != ")":
		out.push(p.orOf())
		if p.peek() == ",": p.at += 1
	p.at += 1
	out

fn called(name str, args f32[]) f32:
	if args.isEmpty: return 0.0
	match name:
		"clamp": args[0].clamp(args[1], args[2]) if args.len >= 3 else args[0]
		"min": args[0].min(args[1]) if args.len >= 2 else args[0]
		"max": args[0].max(args[1]) if args.len >= 2 else args[0]
		"abs": args[0].abs()
		_: 0.0

fn primaryOf(mut p Parser):
	t = p.take()
	if t == "(":
		v = p.orOf()
		p.at += 1
		return v
	if t.isEmpty: return 0.0
	if t.bytes()[0].isDigit() or t.bytes()[0] == 46: return f32.parse(t) ?? 0.0
	if p.peek() == "(":
		p.at += 1
		return called(t, p.argumentsOf())
	p.names.get(t) ?? 0.0

# the value of the expression with the names' values; 0 for an empty one
pub fn evaluate(text str, names {str: f32}) f32:
	p = Parser(tokens = tokensOf(text), at = 0, names = names.copy())
	if p.tokens.isEmpty: return 0.0
	p.orOf()
