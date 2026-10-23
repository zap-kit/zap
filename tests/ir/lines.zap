# for over text.lines(), a choice lending one of two places, map literals of structs of numbers,
# a let that copies a borrowed str, a return inside a coalesce; through the intermediate form.
type Sym:
	ptr i64
	kind i64

type Tok:
	text str
	line i64

evens = [2, 4, 6]
odds = [1, 3, 5]

fn lineLengths(text str):
	out = []
	for line in text.lines():
		out.push(line.len)
	out

fn pick(flag bool):
	xs = evens if flag else odds
	xs[1]

fn syms():
	{1: Sym(ptr = 10, kind = 1), 2: Sym(ptr = 20, kind = 2)}

fn firstTok(toks Tok[]):
	toks[0].copy()

fn firstText(toks Tok[]):
	last = firstTok(toks).text
	last += "!"
	last

fn third(xs i64[]):
	(xs.find(it > 2) ?? return -1) * 10

test "lines, lent choices, struct maps":
	m = syms()
	print("{lineLengths("ab\n\r\ncde\n")} {pick(true)} {pick(false)} {(m.get(2) ?? Sym(ptr = 0, kind = 0)).ptr} {firstText([Tok(text = "ab", line = 1)])} {third([1, 3])} {third([1])}")
	prints "[2, 0, 3] 4 3 20 ab! 30 -1"

# fills the stack below its caller with negative words, which a later call's frame finds
fn dirty(k i64) i64:
	a i64[16] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
	for i in 0..16:
		a[i] = -k - i
	(dirty(k - 1) if k > 0 else 0) + a[k]

mut texts {str: str} = {}

# a line of a text kept by name (the shape of the compiler's sourceLineOf), not inlined
fn lineOf(name str, text str, line i64) str:
	if line < 0: return lineOf(name, text, line + 1)
	if name not in texts:
		texts[name.copy()] = text.copy()
	if texts.get(name) is t: return textLine(t, line) ?? ""
	""

test "a line a loop over lines names is copied as its own text, whatever the frame held":
	text = "first\nthe second line, longer than a short text"
	lengths = []
	for k in 0..4:
		dirty(k)
		lengths.push(lineOf("a", text, 2).len)
	expect lengths == [41, 41, 41, 41]
