# Borrowed values where owned ones go, through the intermediate form: a field or element stored
# or returned gets a copy of its own; presence tests of optionals; find of a str element; a
# return inside a match whose arms all return; extend with elements that own memory.
type Tok:
	text str
	line i64

type Parser:
	toks Tok[]
	at i64
	dll str

fn adv(mut p Parser):
	p.at += 1
	p.toks[p.at - 1].copy()

fn setDll(mut p Parser):
	p.dll = p.adv().text

fn textOf(p Parser) ref str:
	p.toks[0].text

fn where(m {str: i64}, key str):
	match m.get(key):
		at: return at
		none: return -1

fn hasNo(m {str: i64}, key str):
	m.get(key) == none

fn firstLong(words str[]):
	match words.find(.len > 2):
		w: w.copy()
		none: "-"

fn joined(mut out str[], more str[]):
	out.extend(more.copy())
	out.len

fn churn(n i64):
	before = liveBlocks()
	k = 0
	for i in 0..n:
		p = Parser(toks = [Tok(text = "t{i}", line = i)], at = 0, dll = "")
		p.setDll()
		k += p.dll.len + p.textOf().len
		out = ["a"]
		k += joined(out, ["b", "c{i}"])
	k > 0 and liveBlocks() == before

test "borrows copied, presence tests, find, extend":
	p = Parser(toks = [Tok(text = "x", line = 1)], at = 0, dll = "")
	p.setDll()
	m = {"a": 1}
	out = ["a"]
	expect p.dll == "x"
	expect p.textOf() == "x"
	expect where == {(m, "a"): 1, (m, "b"): -1}
	expect hasNo == {(m, "b"): true, (m, "a"): false}
	expect firstLong(["ab", "cde"]) == "cde"
	expect joined(out, ["b", "c"]) == 3
	expect churn(30)
