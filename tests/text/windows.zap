# `for part in text.split(sep)`: the parts as windows over the text, none copied; and the trims
# and the last index.
#
# A window (ref str, ref T[]) is two words, pointer and length. Making one inline next to
# another local once wrote a third word over the neighbour (the loop variable here), so the
# list literal's copy read a cleared pointer.
#
# for b in s walks the bytes of a str (each a u8, as s[i] is); for i, b in s gives the index too

test "a separator of several bytes, and continue":
	sep = "--"
	n = 0
	for p in "x--y--z".split(sep):
		if p == "y": continue
		n += p.len
		print(p)
	print(n)
	total = 0
	for w in "10 20 30".split(" "):
		total += i64.parse(w) ?? 0
	print(total)
	prints """
		x
		z
		2
		60
		"""

fn head(s str) ref str:
	s[..1]
words = ["apple", "avocado", "banana"]
mut groups {str: str[]} = {}
for w in words:
	key = head(w)
	ys = groups.remove(key) ?? []
	ys.push(w.copy())
	groups[key.copy()] = ys
for k in groups.keys():
	print("{k}: {groups.get(k) ?? []}")
mut all = []
for w in words:
	key = w[..2]
	xs = [w.copy()]
	all.push(xs)
	print(key)
print(all.len)

test "a window kept in a map's list points into its text":
	main()
	prints """
		b: ["banana"]
		a: ["apple", "avocado"]
		ap
		av
		ba
		3
		"""

test "the bytes of a str":
	text = "héy"
	for b in text:
		print(b)
	n = 0
	for i, b in text:
		n += i + b
	print(n)
	prints """
	    104
	    195
	    169
	    121
	    595
	    """
