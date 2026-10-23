# Tokens of a program in Zap, C, C++, Rust or Python, counted by one tokenizer for all: every
# identifier or keyword, number, string or character literal and operator is one token; comments
# and whitespace are none. Zap's test blocks are not part of the program.

import fs

# the operators of more than one character that are one token; any other symbol is a token alone
operators = [
	"<<=", ">>=", "...", "..=", "->", "=>", "::", "==", "!=", "<=", ">=", "&&", "||", "++", "--",
	"+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>", "..", "??"
]

# the tokens of the source file at path (by its extension: zap, c, cpp, rs, py)
pub fn tokenCount(path str) i64:
	ext = extensionOf(path)
	source = fs.readFile(path) ?? ""
	countTokens(withoutZapTests(source) if ext == "zap" else source, ext)

# the source without its test blocks (`test` at the margin, the indented lines after it and the
# closing bracket of a header laid over several lines)
fn withoutZapTests(source str):
	kept = []
	inTest = false
	for line in source.lines():
		if line.startsWith("test "):
			inTest = true
		elif inTest and line.trimmed() != "" and not line.startsWith(" ") and
			not line.startsWith("\t") and not line.startsWith("]") and not line.startsWith(")"):
			inTest = false
		if not inTest:
			kept.push(line.copy())
	kept.join("\n")

fn countTokens(text str, ext str):
	s = text.bytes()
	hashComments = ext == "zap" or ext == "py"
	count = 0
	i = 0
	while i < s.len:
		c = s[i]
		next = s[i + 1] if i + 1 < s.len else 0
		if c in [' ', '\t', '\n', '\r']:
			i += 1
		elif hashComments and c == '#' or not hashComments and c == '/' and next == '/':
			while i < s.len and s[i] != '\n':
				i += 1
		elif not hashComments and c == '/' and next == '*':
			i += 2
			while i < s.len and not (s[i] == '*' and i + 1 < s.len and s[i + 1] == '/'):
				i += 1
			i += 2
		else:
			i = tokenEnd(text, s, i, ext)
			count += 1
	count

fn isIdentChar(c u8):
	c == '_' or c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c >= '0' and c <= '9'

fn isDigit(c u8):
	c >= '0' and c <= '9'

# the index after the token that starts at i
fn tokenEnd(text str, s u8[], i i64, ext str):
	c = s[i]
	if c == '"' or c == '\'' and ext == "py":
		if ext == "py" and i + 2 < s.len and s[i + 1] == c and s[i + 2] == c:
			return tripleQuotedEnd(s, i)
		return stringEnd(s, i, ext == "zap")
	if c == '\'': return quoteEnd(s, i)
	if isDigit(c): return numberEnd(s, i)
	if isIdentChar(c):
		j = i
		while j < s.len and isIdentChar(s[j]):
			j += 1
		return j
	for n in [3, 2]:
		if i + n <= text.len and text[i..i + n] in operators: return i + n
	i + 1

# the index after the string that opens at start; Zap's `{` opens an interpolation, which may
# hold strings of its own
fn stringEnd(s u8[], start i64, zap bool) i64:
	quote = s[start]
	i = start + 1
	while i < s.len and s[i] != quote:
		if s[i] == '\\':
			i += 2
		elif zap and quote == '"' and s[i] == '{':
			i = interpolationEnd(s, i + 1)
		else:
			i += 1
	i + 1

fn interpolationEnd(s u8[], start i64) i64:
	i = start
	while i < s.len and s[i] != '}':
		i = stringEnd(s, i, true) if s[i] == '"' else i + 1
	i + 1

fn tripleQuotedEnd(s u8[], start i64):
	quote = s[start]
	i = start + 3
	while i + 2 < s.len and not (s[i] == quote and s[i + 1] == quote and s[i + 2] == quote):
		i += 1
	i + 3

# a quote that is a character literal ('x', '\n') or, in Rust, a lifetime ('a)
fn quoteEnd(s u8[], i i64):
	if i + 1 < s.len and s[i + 1] == '\\' or i + 2 < s.len and s[i + 2] == '\'':
		return stringEnd(s, i, false)
	j = i + 1
	while j < s.len and isIdentChar(s[j]):
		j += 1
	j

# a number: its digits, suffix, fraction (a `.` before a digit) and exponent
fn numberEnd(s u8[], i i64):
	hex = s[i] == '0' and i + 1 < s.len and (s[i + 1] == 'x' or s[i + 1] == 'X')
	j = i
	while j < s.len:
		d = s[j]
		signed = (d == '+' or d == '-') and not hex and (s[j - 1] == 'e' or s[j - 1] == 'E')
		if isIdentChar(d):
			j += 1
		elif (d == '.' or signed) and j + 1 < s.len and isDigit(s[j + 1]):
			j += 1
		else:
			break
	j
