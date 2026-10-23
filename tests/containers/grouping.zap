mut words = ["apple", "avocado", "banana", "blueberry", "cherry"]
mut counts {str: i64} = {}
for w in words:
	counts[w[..1].copy()] = (counts.get(w[..1]) ?? 0) + 1
# the last pass over words: each word moves out of the list into its group
mut groups {str: str[]} = {}
for i in 0..words.len:
	key = words[i][0..1].copy()
	ys = groups.remove(key) ?? []
	ys.push(move words[i])
	groups[key] = ys
for k in groups.keys():
	print("{k}: {groups.get(k) ?? []}")
print(counts)

test "words moved out of their list into groups keep their text":
	main()
	prints r"""
	    b: ["banana", "blueberry"]
	    c: ["cherry"]
	    a: ["apple", "avocado"]
	    {"a": 2, "b": 2, "c": 1}
	    """
