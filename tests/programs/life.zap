# Game-of-life step on a small grid of lists of bools, with neighbors counting and printing.
fn countNeighbors(g bool[,], r i64, c i64):
	n = 0
	for dr in -1..2:
		for dc in -1..2:
			if dr == 0 and dc == 0: continue
			rr = r + dr
			cc = c + dc
			if rr >= 0 and rr < g.len and cc >= 0 and cc < g[0].len and g[rr][cc]:
				n += 1
	n
fn step(g bool[,]):
	out = []
	for r in 0..g.len:
		row = []
		for c in 0..g[0].len:
			n = countNeighbors(g, r, c)
			alive = g[r][c]
			row.push((alive and (n == 2 or n == 3)) or (not alive and n == 3))
		out.push(row)
	out
fn show(g bool[,]):
	for row in g:
		line = ""
		for cell in row:
			if cell:
				line += "#"
			else:
				line += "."
		print(line)
mut g = [
	[false, true, false],
	[false, true, false],
	[false, true, false],
]
show(g)
print("--")
g = step(g)
show(g)

test "a step of the game of life counts each cell's neighbours":
	main()
	prints """
	    .#.
	    .#.
	    .#.
	    --
	    ...
	    ###
	    ...
	    """
