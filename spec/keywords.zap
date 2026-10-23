# 2.2 Reserved words
#
# The reserved words are kept by the language: none names a variable, a function or a type, except
# `self`, which is a method's receiver and a name elsewhere (*Methods*). `zap doc keywords` prints
# them after this section, and the contextual words, from the compiler's own lists. A reserved
# word written as a name is an error; the tests are one for each error it gives.

test "it is reserved" refuses ItIsNoName:
	it = 1

# A contextual word is a word of the language only where the language reads it (an import, a
# test, after `extern`, alone where a body would be, inside an index's brackets, on the right of
# `??`, a range's step, a scope's first line), and a name everywhere else.

test "contextual words are names elsewhere":
	from = 1
	test = 2
	refuses = 3
	expect = 4
	prints = 5
	loaded = 6
	bound = 7
	pass = 8
	len = 9
	error = 10
	use = 11
	arena = 12
	stops = 13
	print(from + test + refuses + stops + expect + prints + loaded)
	print(bound + pass + len + error + use + arena)
	xs = [1, 2, 3]
	print(xs[len - 1])   # inside the brackets, still the list's length
	if xs.len > 9: pass
	prints """
		34
		57
		3
		"""
