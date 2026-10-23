# A tokenizer over a str that returns windows into the source: no string is copied until a
# token is kept.
type Token:
	kind i64   # 0 symbol, 1 number, 2 name
	text ref str

fn kindName(k i64):
	if k == 1: return "num"
	if k == 2: return "name"
	"sym"

fn isDigit(c i64):
	c >= 48 and c <= 57

fn isLetter(c i64):
	(c >= 97 and c <= 122) or (c >= 65 and c <= 90) or c == 95

# the next token starting at byte i, or none at the end
fn next(src str, i i64) Token?:
	at = i
	while at < src.len and src[at] == 32:
		at += 1
	if at >= src.len: return none
	c = src[at]
	end = at + 1
	kind = 0
	if c.isDigit():
		kind = 1
		while end < src.len and src[end].isDigit():
			end += 1
	elif isLetter(c):
		kind = 2
		while end < src.len and (isLetter(src[end]) or src[end].isDigit()):
			end += 1
	Token(kind, text = src[at..end])

src = "let total = price * 12 + tax2 - (3)"
mut i = 0
mut names = []
mut sum = 0
mut going = true
while going:
	match next(src, i):
		t:
			print("{kindName(t.kind)}: {t.text}")
			if t.kind == 2:
				names.push(t.text)
			elif t.kind == 1:
				sum += i64.parse(t.text) ?? 0
			i += t.text.len
			while i < src.len and src[i] == 32:
				i += 1
		none: going = false
print(names)
print(sum)

test "tokens are windows into the source, copied only when kept":
	main()
	prints """
	    name: let
	    name: total
	    sym: =
	    name: price
	    sym: *
	    num: 12
	    sym: +
	    name: tax2
	    sym: -
	    sym: (
	    num: 3
	    sym: )
	    ["let", "total", "price", "tax2"]
	    15
	    """
