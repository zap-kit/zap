# BFS shortest path on a grid read from a list of strings; uses a 2D visited list and a queue.
type Pos:
	r i64
	c i64
grid = [
	"S.#.....",
	".##.###.",
	"....#...",
	".##...#E",
]
rows = grid.len
cols = grid[0].len
mut dist = []
loop rows:
	row = []
	loop cols:
		row.push(-1)
	dist.push(row)
mut queue = []
queue.push(Pos(r = 0, c = 0))
dist[0][0] = 0
mut head = 0
mut answer = -1
dr = [1, -1, 0, 0]
dc = [0, 0, 1, -1]
while head < queue.len:
	p = queue[head]
	head += 1
	if grid[p.r][p.c..p.c + 1] == "E":
		answer = dist[p.r][p.c]
		break
	for k in 0..4:
		nr = p.r + dr[k]
		nc = p.c + dc[k]
		if nr < 0 or nc < 0 or nr >= rows or nc >= cols: continue
		if grid[nr][nc..nc + 1] == "#" or dist[nr][nc] != -1: continue
		dist[nr][nc] = dist[p.r][p.c] + 1
		queue.push(Pos(r = nr, c = nc))
print("shortest path: {answer}")

test "a breadth-first search finds the maze's shortest path":
	main()
	prints """
	    shortest path: 12
	    """
