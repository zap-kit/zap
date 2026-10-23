# `lo..x + 1` compares the counter with x itself: the same steps, none when x + 1 wraps
#
# A step past loops (spec/loops.zap states it): a slice's elements, a pipeline's numbers.
#
# x in lo..hi, a condition expect checks.

fn count(lo i64, x i64):
	n = 0
	for i in lo..=x:
		n += i & 1
	n

big = 9_223_372_036_854_775_807
print("{count(1, 10)} {count(5, 4)} {count(5, 5)} {count(big - 3, big)} {count(-3, -1)}")
mut s = 0
m = arg(0, 7)
for i in 0..=m:
	for j in i..=m step 3:
		s += j
print(s)

test "an inclusive range runs to its end, none when the end is below the start":
	main()
	prints """
		5 0 1 0 2
		66
		"""

fn digitKind(b u8):
	match b:
		'0'..='9': "digit"
		'a'..='z': "letter"
		_: "other"

test "lo..=hi includes hi, in loops, pipelines and patterns":
	parts = []
	for i in 1..=3:
		parts.push("{i}")
	expect parts.join(" ") == "1 2 3"
	expect (1..=3).sum() == 6
	expect digitKind == {'7': "digit", 'q': "letter", '#': "other"}

test "a step picks a slice's elements, a pipeline steps":
	xs = [0, 1, 2, 3, 4, 5]
	expect xs[.. step 2] == [0, 2, 4]
	expect xs[1..4 step 2] == [1, 3]
	expect (0..10 step 3).sum() == 18

test "x in lo..hi is lo <= x and x < hi":
	n = 5
	last = n - 1
	expect 3 in 0..n and last in 0..=4 and not (n in 0..n)
	expect 0.5 in 0.0..1.0
