# dijkstra: shortest paths from the top left cell of an n by n grid whose edges between
# neighbours cost 1 to 9, over a heap of (distance, cell) packed in one u64; prints the
# far corner's distance, the sum of all and how many entries the heap took.
import problems

# the cost of the edge from a cell to its right and to its lower neighbour
type Costs:
	right u8
	down u8

type Generator:
	state u64

	# the next number, 31 bits
	fn next():
		state = state * 6_364_136_223_846_793_005 + 1_442_695_040_888_963_407
		state >> 33

# a cell reached at distance d: a shorter way to it goes into the heap (1 pushed, else 0)
fn reach(mut dist u32[], mut queue Heap<u64>, cell i64, d u64):
	if d >= dist[cell]: return 0
	dist[cell] = u32(d)
	queue.push(d << 32 | u64(cell))
	1

n = arg(0, 100)
mut random = Generator(state = 1)
costs = (0..n * n).map(_: Costs(1 + random.next() % 9, 1 + random.next() % 9))
mut dist u32[] = fill(n * n, 4_294_967_295)
mut queue = Heap<u64>()
mut pushes = reach(dist, queue, 0, 0)
while queue.pop() is top:
	d = top >> 32
	cell = i64(top & 4_294_967_295)
	if d > dist[cell]: continue
	x, y = cell % n, cell / n
	if x > 0:
		pushes += reach(dist, queue, cell - 1, d + costs[cell - 1].right)
	if x + 1 < n:
		pushes += reach(dist, queue, cell + 1, d + costs[cell].right)
	if y > 0:
		pushes += reach(dist, queue, cell - n, d + costs[cell - n].down)
	if y + 1 < n:
		pushes += reach(dist, queue, cell + n, d + costs[cell].down)
print("corner {dist[n * n - 1]}, sum {dist.sum(u64(it))}, pushes {pushes}")

test "the shortest paths over a grid of costs give the known distances":
	main()
	prints """
		corner 526, sum 2928503, pushes 12400
		"""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("dijkstra")
