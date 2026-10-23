# The standard library's JSON reader: objects, arrays, numbers, strings with escapes, bools and
# null, read into a flat list of entries, a json.Node a place in it.

import json

test "objects, arrays and numbers":
	doc = json.parse("\{ \"name\": \"Ana\", \"age\": 30, \"tags\": [1, 2.5, -3e2], \"ok\": true, \"none\": null }") ?? fail
	expect doc.textOf(doc.root, "name") == "Ana"
	expect (doc.number(doc.root, "age") ?? 0.0) == 30.0
	tags = doc.numbers(doc.root, "tags") ?? []
	expect tags == [1.0, 2.5, -300.0]
	expect doc[doc.get(doc.root, "ok") ?? doc.root].number == 1.0
	nothing = doc.get(doc.root, "none") ?? doc.root
	expect doc[nothing].kind == .Null
	expect doc.get(doc.root, "missing") == none

test "nested containers and escapes":
	doc = json.parse("[\{\"a\": [[], \{}]}, \"x\\\"y\\n\\u0041\"]") ?? fail
	expect doc.count(doc.root) == 2
	first = doc.at(doc.root, 0)
	a = doc.get(first, "a") ?? doc.root
	expect doc.count(a) == 2
	inner = doc.at(a, 1)
	expect doc[inner].kind == .Object
	escaped = doc.at(doc.root, 1)
	expect doc[escaped].text == "x\"y\nA"

test "a \\u escape past ASCII and a surrogate pair are their UTF-8":
	doc = json.parse("[\"caf\\u00e9\", \"\\ud83d\\ude00\"]") ?? fail
	cafe = doc.at(doc.root, 0)
	expect doc[cafe].text == "café"
	smile = doc.at(doc.root, 1)
	expect doc[smile].text == "😀"

test "a text that is not JSON gives why" for text in [
	"",
	"[1, 2",
	"\{\"a\" 1}",
	"[1] 2",
	"tru",
	"[\"\\u12\"]",
	"\{\"a\": [\{}, ]}"
]:
	match json.parse(text):
		error: expect error.startsWith("JSON: ")
		_: expect false

test "a document nested 10,000 deep parses without stopping":
	deep = "{"[".repeat(10_000)}{"]".repeat(10_000)}"
	doc = json.parse(deep) ?? fail
	expect doc.count(doc.root) == 1
