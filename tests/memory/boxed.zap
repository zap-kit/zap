# a map or a box is one word: storing over one in a field, an element or a variable drops it
type Held:
	m {i64: i64}
	b Box<i64>

fn keepMap(move m {i64: i64}):
	m.len

test "a map or a box stored over":
	s = Held(m = {}, b = Box(1))
	s.m = {1: 2}
	s.m = {}
	s.b = Box(2)
	xs {i64: i64}[] = [{}]
	xs[0] = {3: 4}
	m = {5: 6}
	m = {}
	moved = {7: 8}
	print(keepMap(moved))
	moved = {9: 10}
	print(s.m.len + xs[0].len + m.len + moved.len + s.b)
	prints """
		1
		4
		"""
