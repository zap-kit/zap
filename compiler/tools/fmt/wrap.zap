# Lines past lineWidth columns (a tab counted as four) broken at their outermost place first:
# formatFile breaks every line that does not fit once, lays the lines out again, and repeats
# until each fits or none can be broken further. The places, from the outermost: a statement's
# one-line body goes below its `:` (a lambda argument on a line of its own takes the block form
# the same way); a condition or a sum breaks after the last of its loosest operators that lets
# the line fit (the first when none does), the rest one tab in; a choice breaks before each
# `else`, the parts one tab in; a chain of two or more calls
# breaks before each step, the steps one tab in; a call's or a literal's arguments go one a
# line, one tab past the line that opened them, the closing bracket on a line of its own, or,
# when the last argument is a lambda, its body goes below the line and the bracket on a line of
# its own. A line inside brackets (a literal's elements) breaks at its commas, one element a
# line. A string literal is never broken: a line too long because of one (the literal alone
# would not fit one tab in) stays as it is, as does a line whose code fits and whose comment
# does not.

# a line of the layout: its indentation in tabs and its text
type Piece:
	indent i64
	text str

# the lines with each line of code past lineWidth broken once at its outermost place
fn breakLongLines(lines str[], markup bool):
	out = []
	sc = LineScanner(markup)
	for raw in lines:
		kind = sc.enterLine(raw)
		t = raw.trimmed()
		if kind == lineText or t == "":
			out.push(raw.copy())
			continue
		indent = indentOf(raw)
		# a test's header opening its source is one line, which the lexer reads as one
		if kind == lineRaw or sc.keepsText() or t.startsWith("#") or opensTestSource(t):
			out.push(raw.copy())
		else:
			for piece in breakLine(t, indent, not sc.freeLine()):
				out.push("\t".repeat(piece.indent) + piece.text)
		sc.leaveLine(t, indent)
	out

# the pieces a line of code (inside brackets opened above, or free) is broken into at its
# outermost place, or the line itself
fn breakLine(t str, indent i64, inBrackets bool):
	code = codeOf(t)
	whole = [Piece(indent, text = t.copy())]
	if 4 * indent + code.len <= lineWidth or tooLongLiteral(code, indent): return whole
	kinds = byteKinds(code)
	pieces = bodyBelow(code, kinds, indent)
	if pieces.isEmpty and inBrackets: pieces = oneALine(code, 0, indent)
	if pieces.isEmpty: pieces = beforeChoice(code, kinds, indent)
	if pieces.isEmpty: pieces = afterOperator(code, kinds, indent)
	if pieces.isEmpty: pieces = beforeSteps(code, kinds, indent)
	if pieces.isEmpty: pieces = insideBrackets(code, kinds, indent)
	if pieces.isEmpty: return whole
	# the comment stays with the first line
	comment = t[code.len..]
	if comment != "":
		pieces[0] = Piece(indent, text = pieces[0].text + comment)
	pieces

# whether a string literal of the code would not fit on a line of its own one tab in: the line is
# too long because of it
fn tooLongLiteral(code str, indent i64):
	kinds = byteKinds(code)
	k = 0
	while k < code.len:
		if kinds[k] == byteText and (code[k] == '"' or code[k] == '\''):
			e = literalEnd(code, k)
			if e < 0 or 4 * (indent + 1) + e - k > lineWidth: return true
			k = e
			continue
		k += 1
	false

# the bracket depth at each byte of the code: how many brackets of its code (strings, characters
# and comments apart) stand open before it
fn depths(code str, kinds u8[]):
	out = []
	depth = 0
	for k, kind in kinds:
		b = code[k]
		if kind == byteCode and b in [')', ']', '}']:
			depth -= 1
		out.push(depth)
		if kind == byteCode and b in ['(', '[', '{']:
			depth += 1
	out

# whether byte k is code outside every bracket of the line
fn topCode(kinds u8[], depth i64[], k i64):
	k < kinds.len and kinds[k] == byteCode and depth[k] == 0

# where the code holds pat, at or after `from`, with every byte of the operator in it (the text
# between its spaces) as code outside brackets, or -1
fn topIndexOf(code str, kinds u8[], depth i64[], pat str, from i64):
	at = from
	loop:
		k = code.indexOf(pat, at) ?? -1
		if k < 0: return -1
		if topCode(kinds, depth, k + 1) and topCode(kinds, depth, k + pat.len - 2): return k
		at = k + 1

# the first `:` of the code outside brackets that a space or the end follows (a block's), or -1
fn blockColon(code str, kinds u8[]):
	depth = depths(code, kinds)
	for k in 0..code.len:
		if topCode(kinds, depth, k) and code[k] == ':' and
			(k + 1 == code.len or code[k + 1] == ' '):
			return k
	-1

# the starts of the statements whose one-line body zap fmt moves below them (a lambda argument
# standing on a line of its own among them)
blockHeads = ["if ", "elif ", "else:", "for ", "while ", "loop:", "loop ", "fn ", "pub fn ",
	"{testWord} \""]

# a statement whose body follows its `:` on the line: the head, then the body one tab in; not an
# if written as a value (`if x is v: a else: b`) nor an argument that others follow
fn bodyBelow(code str, kinds u8[], indent i64):
	if not blockHeads.any(code.startsWith(it)) or code.endsWith(","): return []
	colon = blockColon(code, kinds)
	if colon < 0: return []
	body = code[colon + 1..].trimmed()
	if body == "" or
		topIndexOf(body, byteKinds(body), depths(body, byteKinds(body)), " else: ", 0) >= 0:
		return []
	[Piece(indent, text = code[..colon + 1].copy()),
		Piece(indent = indent + 1, text = body.copy())]

# a choice (`a if c else b`) broken before each `else`, the parts one tab in; the lexer goes on
# to such a line
fn beforeChoice(code str, kinds u8[], indent i64):
	depth = depths(code, kinds)
	if topIndexOf(code, kinds, depth, " else ", 0) < 0: return []
	cuts = []
	k = topIndexOf(code, kinds, depth, " else ", 0)
	while k >= 0:
		cuts.push(k + 1)
		k = topIndexOf(code, kinds, depth, " else ", k + 1)
	if cuts.isEmpty: return []
	out = [Piece(indent, text = code[..cuts[0]].trimmedEnd().copy())]
	for i, c in cuts:
		end = cuts[i + 1] if i + 1 < cuts.len else code.len
		out.push(Piece(indent = indent + 1, text = code[c..end].trimmed().copy()))
	out

# the binary operators a line breaks after (written between spaces; the lexer goes on to the next
# line after each)
breakOperators = ["??", "or", "and", "==", "!=", "<", ">", "<=", ">=", "+", "-", "*", "/", "%", "@"]

# a condition or a sum broken after the last of its loosest operators outside brackets that lets
# the line fit (the first when none does), the rest one tab in
fn afterOperator(code str, kinds u8[], indent i64):
	depth = depths(code, kinds)
	ends = []   # where each occurrence of a loosest operator ends
	level = -1
	for op in breakOperators:
		if operatorLevel(op) < level: continue
		k = topIndexOf(code, kinds, depth, " {op} ", 0)
		while k >= 0:
			if operatorLevel(op) > level:
				ends = []
				level = operatorLevel(op)
			ends.push(k + op.len + 1)
			k = topIndexOf(code, kinds, depth, " {op} ", k + 1)
	if ends.isEmpty: return []
	ends.sort()
	end = ends[0]
	for e in ends:
		if 4 * indent + e <= lineWidth: end = e
	rest = code[end..].trimmed()
	if rest == "": return []
	head = code[..end].copy()
	[Piece(indent, text = head), Piece(indent = indent + 1, text = rest.copy())]

# whether the `.` at k starts a step of a chain of calls: `.name(` after a value (the line's
# start counts: a step going on from the line above)
fn stepAt(code str, kinds u8[], k i64):
	if k > 0:
		b = code[k - 1]
		if not b.isWordByte() and b not in [')', ']', '"', '\''] and not b.isDigit(): return false
	e = k + 1
	if e >= code.len or not code[e].isWordStart() or code[e] >= 'A' and code[e] <= 'Z':   # a variant (.Input(...)) is not a step
		return false
	while e < code.len and code[e].isWordByte():
		e += 1
	e < code.len and code[e] == '(' and kinds[e] == byteCode

# the index after the step whose `.` is at k: its call and the indexes following it
fn stepEnd(code str, k i64):
	e = k + 1
	while e < code.len and code[e].isWordByte():
		e += 1
	e = closingOf(code, e)
	while e > 0 and e < code.len and code[e] == '[':
		e = closingOf(code, e)
	code.len if e < 0 else e

# a chain of two or more calls, each step right after the one before, broken before each step,
# the steps one tab in
fn beforeSteps(code str, kinds u8[], indent i64):
	depth = depths(code, kinds)
	steps = []
	k = 0
	while k < code.len:
		if topCode(kinds, depth, k) and code[k] == '.' and stepAt(code, kinds, k):
			steps.push(k)
			k = stepEnd(code, k)
		elif steps.len >= 2:
			break
		else:
			steps = []
			k += 1
	if steps.len < 2: return []
	out = []
	if steps[0] > 0:
		out.push(Piece(indent, text = code[..steps[0]].copy()))
	for i, k in steps:
		end = steps[i + 1] if i + 1 < steps.len else code.len
		out.push(Piece(indent = indent + 1, text = code[k..end].copy()))
	out

# the values the code holds from byte `from` on, separated by commas outside brackets, one a
# line at the indentation (each with its comma, the last with the one it had); none when the
# code holds one value or ends inside a bracket it opens
fn oneALine(code str, from i64, indent i64):
	inner = code[from..]
	if bracketDelta(inner) != 0: return []
	parts = topLevelParts(inner)
	trailing = parts.len > 1 and parts[len - 1] == ""
	if trailing: parts.pop()
	if parts.len < 2 and not trailing: return []
	out = []
	for i, p in parts:
		out.push(Piece(indent, text = "{p}," if i + 1 < parts.len or trailing else p.copy()))
	out

# the arguments of the longest call or literal outside other brackets one a line, one tab past
# the line that opened them, the closing bracket on a line of its own; the last argument a
# lambda: the line keeps its head, its body goes one tab in and the bracket on a line of its own.
# A line that opens a bracket it does not close (a literal going on below) keeps the opener and
# puts what follows it one a line.
fn insideBrackets(code str, kinds u8[], indent i64):
	depth = depths(code, kinds)
	open = -1
	close = -1
	unclosed = -1
	for k in 0..code.len:
		b = code[k]
		if kinds[k] == byteCode and b in ['(', '[', '{']:
			e = closingOf(code, k)
			if e < 0:
				unclosed = k
			elif depth[k] == 0 and e - k > close - open:
				open = k
				close = e - 1
	if unclosed >= 0:
		values = oneALine(code, unclosed + 1, indent + 1)
		if values.isEmpty: return []
		values.insert(0, Piece(indent, text = code[..unclosed + 1].copy()))
		return values
	if open < 0 or close - open < 2: return []
	parts = topLevelParts(code[open + 1..close])
	if parts[len - 1] == "": parts.pop()   # a trailing comma
	if parts.isEmpty: return []
	head = code[..open + 1]
	tail = code[close..]
	last = parts[len - 1]
	if code[open] == '(' and lambdaText(last):
		colon = blockColon(last, byteKinds(last))
		if colon >= 0 and colon + 1 < last.len:
			before = parts[..len - 1].map("{it}, ").join("")
			body = last[colon + 1..].trimmed()
			return [Piece(indent, text = head + before + last[..colon + 1]),
				Piece(indent = indent + 1, text = body.copy()), Piece(indent, text = tail.copy())]
	out = [Piece(indent, text = head.copy())]
	for i, p in parts:
		out.push(Piece(indent = indent + 1, text = "{p}," if i + 1 < parts.len else p.copy()))
	out.push(Piece(indent, text = tail.copy()))
	out

# whether an argument's text is a lambda: `x: ...`, `(a, b): ...`
fn lambdaText(s str):
	name, _ = lambdaHead(s, 0)
	if name != "": return true
	if not s.startsWith("("): return false
	close = closingOf(s, 0)
	close > 0 and s[close..].startsWith(":")
