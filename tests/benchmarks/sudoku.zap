# sudoku: attractivechaos/plb2's solver (an improvement of Guenter Stertenbrink's suexco.c) over its
# twenty hard 9x9 grids, n times over; prints every solution of each grid and a blank line.
# A grid is an exact cover: 729 choices (a number in a cell) against 324 constraints, each choice
# in four of them and each constraint in nine choices; the backtracking takes the constraint with the
# fewest choices left.
import problems

type Cover:
	rows u16[324, 9]
	cols u16[729, 4]

# rows[c, i]: the i-th choice of constraint c; cols[r, j]: the j-th constraint of choice r
fn matrix():
	cols u16[729, 4]
	r = 0
	for i in 0..9:
		for j in 0..9:
			for k in 0..9:
				cols[r, 0] = 9 * i + j
				cols[r, 1] = (i / 3 * 3 + j / 3) * 9 + k + 81
				cols[r, 2] = 9 * i + k + 162
				cols[r, 3] = 9 * j + k + 243
				r += 1
	rows u16[324, 9]
	filled i64[324]
	for r in 0..729:
		for c in cols[r]:
			rows[c, filled[c]] = r
			filled[c] += 1
	Cover(rows, cols)

# sr[r]: how many times choice r is forbidden by the chosen ones; sc[c]: the choices left of
# constraint c, plus 128 once the constraint is used
type Board:
	sr i8[729]
	sc u8[324]

	# chooses r; the fewest choices left of a constraint touched, shifted left 16 bits, with that constraint
	fn choose(m Cover, r i64):
		least = 10
		leastC = 0
		for c in m.cols[r]:
			sc[c] |= 128
		for c in m.cols[r]:
			for rr in m.rows[c]:
				sr[rr] += 1
				if sr[rr] != 1: continue
				for cc in m.cols[rr]:
					sc[cc] -= 1
					if sc[cc] < least:
						least = sc[cc]
						leastC = cc
		least << 16 | leastC

	# takes choice r back
	fn unchoose(m Cover, r i64):
		for c in m.cols[r]:
			sc[c] &= 127
		for c in m.cols[r]:
			for rr in m.rows[c]:
				sr[rr] -= 1
				if sr[rr] != 0: continue
				for cc in m.cols[rr]:
					sc[cc] += 1

	# the constraint of fewest choices left, from `least` (the best so far) on; its index in the low bits
	fn pickConstraint(least i64, first i64):
		best = least
		bestC = first
		if best > 1:
			for c in 0..324:
				if sc[c] < best:
					best = sc[c]
					bestC = c
					if best <= 1: break
		best << 16 | bestC

# appends every solution of the grid, a line each
fn solve(m Cover, grid ref str, mut out u8[]):
	board = Board(sr = zeros(729), sc = fill(324, 9))
	text = []
	hints = 0
	for ch in grid.bytes():
		at = text.len
		text.push(ch)
		if ch >= '1' and ch <= '9':
			board.choose(m, at * 9 + i64(ch - '1'))
			hints += 1
	cr i64[81] = fill(81, -1)
	cc i64[81] = fill(81, -1)
	forward = true
	cand = 10 << 16
	i = 0
	loop:
		while i >= 0 and i < 81 - hints:
			if forward:
				pick = board.pickConstraint(cand >> 16, cand & 65_535)
				cc[i] = pick & 65_535
				least = pick >> 16
				if least == 0 or least == 10:
					cr[i] = -1
					i -= 1
					forward = false
			c = cc[i]
			if not forward and cr[i] >= 0:
				board.unchoose(m, m.rows[c, cr[i]])
			r2 = cr[i] + 1
			while r2 < 9 and board.sr[m.rows[c, r2]] != 0:
				r2 += 1
			if r2 < 9:
				cand = board.choose(m, m.rows[c, r2])
				cr[i] = r2
				i += 1
				forward = true
			else:
				cr[i] = -1
				i -= 1
				forward = false
		if i < 0: break
		for j in 0..i:
			r = i64(m.rows[cc[j], cr[j]])
			text[r / 9] = '1' + u8(r % 9)
		out.extend(text)
		out.push('\n')
		i -= 1
		forward = false

hard20 = [
	"..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9",
	".......12........3..23..4....18....5.6..7.8.......9.....85.....9...4.5..47...6...",
	".2..5.7..4..1....68....3...2....8..3.4..2.5.....6...1...2.9.....9......57.4...9..",
	"........3..1..56...9..4..7......9.5.7.......8.5.4.2....8..2..9...35..1..6........",
	"12.3....435....1....4........54..2..6...7.........8.9...31..5.......9.7.....6...8",
	"1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1",
	".......39.....1..5..3.5.8....8.9...6.7...2...1..4.......9.8..5..2....6..4..7.....",
	"12.3.....4.....3....3.5......42..5......8...9.6...5.7...15..2......9..6......7..8",
	"..3..6.8....1..2......7...4..9..8.6..3..4...1.7.2.....3....5.....5...6..98.....5.",
	"1.......9..67...2..8....4......75.3...5..2....6.3......9....8..6...4...1..25...6.",
	"..9...4...7.3...2.8...6...71..8....6....1..7.....56...3....5..1.4.....9...2...7..",
	"....9..5..1.....3...23..7....45...7.8.....2.......64...9..1.....8..6......54....7",
	"4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........",
	"7.8...3.....2.1...5.........4.....263...8.......1...9..9.6....4....7.5...........",
	"3.7.4...........918........4.....7.....16.......25..........38..9....5...2.6.....",
	"........8..3...4...9..2..6.....79.......612...6.5.2.7...8...5...1.....2.4.5.....3",
	".......1.4.........2...........5.4.7..8...3....1.9....3..4..2...5.1........8.6...",
	".......12....35......6...7.7.....3.....4..8..1...........12.....8.....4..5....6..",
	"1.......2.9.4...5...6...7...5.3.4.......6........58.4...2...6...3...9.8.7.......1",
	".....1.2.3...4.5.....6....7..2.....1.8..9..3.4.....8..5....2....9..3.4....67....."]

n = arg(0, 1)
m = matrix()
mut out = []
loop n:
	for grid in hard20:
		m.solve(grid, out)
		out.push('\n')
stdout.writeBytes(out)

test "every hard grid gets its solution, and the C, Rust and Python programs print the same bytes":
	main()
	prints problems.expectedOf("sudoku")
	expect problems.agree("sudoku")
