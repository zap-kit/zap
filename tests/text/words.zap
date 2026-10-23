# Text processing: word frequency, anagram groups, palindromes, Caesar cipher, Levenshtein.
#
# wrapLines (spec/strings.zap states the str type and its methods).

import fs

fn normalize(w str):
	out = ""
	for ch in w.lower().chars():
		c = ch.charCode()
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			out += ch
	out

fn sortedLetters(w str):
	w.chars().sorted().join("")

fn isPalindrome(s str):
	n = normalize(s)
	n == n.chars().reversed().join("")

fn caesar(s str, shift i64):
	out = ""
	for ch in s.chars():
		c = ch.charCode()
		if c >= 97 and c <= 122:
			out += str.fromCode((c - 97 + shift) % 26 + 97)
		elif c >= 65 and c <= 90:
			out += str.fromCode((c - 65 + shift) % 26 + 65)
		else:
			out += ch
	out

fn levenshtein(a str, b str):
	ac = a.chars()
	bc = b.chars()
	prev = []
	for j in 0..=(bc.len):
		prev.push(j)
	for i in 1..=(ac.len):
		cur = [i]
		for j in 1..=(bc.len):
			cost = 1
			if ac[i - 1] == bc[j - 1]:
				cost = 0
			cur.push((prev[j] + 1).min(cur[j - 1] + 1).min(prev[j - 1] + cost))
		prev = cur
	prev[bc.len]

text = "the quick brown fox jumps over the lazy dog. The dog barks; the fox runs. A man, a plan, a canal: Panama!"
mut freq {str: i64} = {}
mut order = []
for raw in text.split(" "):
	w = normalize(raw)
	if w == "": continue
	freq.add(w, 1)
	if (freq.get(w) ?? 0) == 1:
		order.push(w)
mut pairs = []
for w in order.sorted():
	if freq.get(w) is n:
		if n > 1:
			pairs.push("{w}={n}")
print("repeated: {pairs.join(", ")}")
print("distinct words: {order.len}")

mut words = ["listen", "silent", "enlist", "google", "gogole", "cat", "act", "tac", "dog"]
mut groups {str: str[]} = {}
mut keys = []
for i in 0..words.len:
	k = sortedLetters(words[i])
	gs = groups.remove(k) ?? []
	if gs.isEmpty:
		keys.push(k.copy())
	gs.push(move words[i])
	groups[k] = gs
for k in keys:
	if groups.get(k) is g:
		print("{k}: {g.join(" ")}")

for s in ["A man, a plan, a canal: Panama!", "racecar", "hello", "No lemon, no melon"]:
	print("\"{s}\" palindrome: {isPalindrome(s)}")
secret = caesar("Hello, World! xyz", 3)
print(secret)
print(caesar(secret, 23))
for pair in [
	["kitten", "sitting"],
	["flaw", "lawn"],
	["intention", "execution"],
	["", "abc"],
	["same", "same"]
]:
	print("levenshtein({pair[0]}, {pair[1]}) = {levenshtein(pair[0], pair[1])}")
print(
	"{"the quick brown fox".upper()} | {"  padded  ".trimmed()} | {"ab".repeat(3)} | ----x | {"abcdef"[2..5]}"
)

test "word frequency, anagrams, palindromes, Caesar and Levenshtein give their known answers":
	main()
	prints fs.readFile("tests/text/words.expected") ?? ""

test "wrapLines: the words in lines of at most the width, a longer word alone":
	print("the quick  brown fox\tjumps over the lazy dog".wrapLines(10))
	print("a unbreakableword b".wrapLines(5))
	print("".wrapLines(10).len)
	prints """
		the quick
		brown fox
		jumps over
		the lazy
		dog
		a
		unbreakableword
		b
		0
		"""
