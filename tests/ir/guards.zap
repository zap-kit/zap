# A counted loop's checks made once by a guard before it (spec 14.3): the copy without them runs
# when the guard holds, the loop as written otherwise, so the results are the turn-by-turn ones and
# a check that fails stops where it would. The references call a function each turn, which keeps
# the loop as written.

most = 9_223_372_036_854_775_807

fn at(v i64[], i i64):
	v[i]

fn windows(v i64[], from i64, n i64):
	s = 0
	i = from
	while i < n:
		s = s * 3 + v[i + 2] - v[i]
		i += 1
	s

fn windowsByCalls(v i64[], from i64, n i64):
	s = 0
	i = from
	while i < n:
		s = s * 3 + at(v, i + 2) - at(v, i)
		i += 1
	s

fn behind(v i64[], from i64, n i64):
	s = 0
	i = from
	while i < n:
		s = s * 3 + v[i - 1]
		i += 1
	s

fn behindByCalls(v i64[], from i64, n i64):
	s = 0
	i = from
	while i < n:
		s = s * 3 + at(v, i - 1)
		i += 1
	s

fn quads(v i64[], from i64, n i64):
	s = 0
	j = from
	while j < n:
		s = s * 5 + v[j] - v[j + 3]
		j += 4
	s

fn quadsByCalls(v i64[], from i64, n i64):
	s = 0
	j = from
	while j < n:
		s = s * 5 + at(v, j) - at(v, j + 3)
		j += 4
	s

fn positives(v i64[], from i64):
	c = from
	i = 0
	while i < v.len:
		if v[i] > 0: c += 1
		i += 1
	c

test "a guarded loop gives the turn-by-turn results for every start and count":
	v = (0..23).map(it * 7 % 11 - 4)
	for from in 0..4:
		for n in -1..22:
			if n <= from or n + 2 <= v.len:
				expect windows(v, from, n) == windowsByCalls(v, from, n)
	for from in 1..4:
		for n in -1..25:
			if n <= from or n <= v.len + 1:
				expect behind(v, from, n) == behindByCalls(v, from, n)
	for from in 0..5:
		for n in -1..21:
			if n <= from or (n - 1 - from) / 4 * 4 + from + 3 < v.len:
				expect quads(v, from, n) == quadsByCalls(v, from, n)
	expect positives(v, 0) == v.count(it > 0)
	expect positives(v, most - 50) == most - 50 + v.count(it > 0)

test "an index past the end still stops" stops IndexOutOfBounds:
	v = [1, 2, 3, 4]
	print(windows(v, 0, args.len + 3))

test "an index below zero still stops" stops IndexOutOfBounds:
	v = [1, 2, 3, 4]
	print(behind(v, -args.len, 3))

test "a step past the end in the last turn still stops" stops IndexOutOfBounds:
	v = (0..10).map(it)
	print(quads(v, 0, v.len - args.len))

test "a counter past its end still stops" stops IntegerOverflow:
	v = [1, 2, 3, 4]
	print(positives(v, most - 2 - args.len))
