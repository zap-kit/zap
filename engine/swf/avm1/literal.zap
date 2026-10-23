# A call written as text, "Path.To.Method(1, 'text', true, [2, 3])", read into its path and
# arguments: numbers, quoted strings, true, false, null, undefined and arrays of them. Tools and
# tests drive a movie with it as the game would by Invoke.

# the path and the argument values of a call's text; arrays are made in the machine
pub fn parseCall(mut m Machine, text str) (str, Value[]):
	open = text.indexOf("(") ?? return (text.trimmed().copy(), [])
	close = text.lastIndexOf(")") ?? text.len
	path = text[..open].trimmed().copy()
	r = LiteralReader(text = text[open + 1..close].copy())
	args = []
	loop 256:
		r.skipSpaces()
		if r.at >= r.text.len: break
		args.push(m.readLiteral(r))
		r.skipSpaces()
		if r.at < r.text.len and r.text[r.at] == ',': r.at += 1
	(path, args)

type LiteralReader:
	text str
	at i64 = 0

	fn skipSpaces():
		while at < text.len and text[at] == ' ':
			at += 1

fn readLiteral(mut m Machine, mut r LiteralReader) Value:
	c = r.text[r.at]
	if c == '"' or c == '\'':
		end = r.text.indexOf(r.text[r.at..r.at + 1], r.at + 1) ?? r.text.len
		v = Value.Str(r.text[r.at + 1..end].copy())
		r.at = (end + 1).min(r.text.len)
		return v
	if c == '[':
		r.at += 1
		items = []
		loop 256:
			r.skipSpaces()
			if r.at >= r.text.len: break
			if r.text[r.at] == ']':
				r.at += 1
				break
			items.push(m.readLiteral(r))
			r.skipSpaces()
			if r.at < r.text.len and r.text[r.at] == ',': r.at += 1
		return .Obj(m.newArray(items))
	start = r.at
	while r.at < r.text.len and r.text[r.at] != ',' and r.text[r.at] != ']' and r.text[r.at] != ' ':
		r.at += 1
	word = r.text[start..r.at]
	match word:
		"true": .Bool(true)
		"false": .Bool(false)
		"null": .Null
		"undefined": .Undefined
		_: .Num(textNumber(word))
