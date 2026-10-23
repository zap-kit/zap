# havlak: Havlak's loop finder (Google's "Loop Recognition in C++/Java/Go/Scala" benchmark) over a
# synthetic control-flow graph of nested and sequential loops, run n times; prints the loops found.
import problems

type Graph:
	nodes i32
	from i32[]
	to i32[]

	fn connect(a i32, b i32):
		from.push(a)
		to.push(b)
		nodes = nodes.max(a + 1).max(b + 1)

	mut fn straight(start i32, n i32):
		for i in 0..n:
			connect(start + i, start + i + 1)
		start + n

	mut fn diamond(start i32):
		connect(start, start + 1)
		connect(start, start + 2)
		connect(start + 1, start + 3)
		connect(start + 2, start + 3)
		start + 3

	# a loop whose body holds a diamond, a second loop (a diamond with a back edge) and a diamond
	mut fn baseLoop(start i32) i32:
		header = straight(start, 1)
		d1 = diamond(header)
		d11 = straight(d1, 1)
		d2 = diamond(d11)
		footer = straight(d2, 1)
		connect(d2, d11)
		connect(d1, header)
		connect(footer, start)
		straight(footer, 1)

	mut fn build():
		n = 2
		connect(0, 2)
		loop 10:
			n += 1
			connect(2, n)
			loop 100:
				top = n
				n = straight(n, 1)
				loop 25:
					n = baseLoop(n)
				bottom = straight(n, 1)
				connect(n, top)
				n = bottom
			connect(n, 1)

# the neighbours of every node as a compressed list: start[v]..start[v+1] into list, in edge order
type Adjacency:
	start i32[]
	list i32[]

fn adjacency(nodes i32, key i32[], other i32[]):
	start i32[] = zeros(nodes + 2)
	for k in key:
		start[k + 1] += 1
	for v in 0..nodes:
		start[v + 1] += start[v]
	fill = start.copy()
	list i32[] = zeros(key.len)
	for e in 0..key.len:
		list[fill[key[e]]] = other[e]
		fill[key[e]] += 1
	Adjacency(start, list)

# the depth-first numbering from the start node: order[w] the node numbered w, last[w] the highest
# number below w
type Numbering:
	number i32[]
	order i32[]
	last i32[]

fn numbering(out Adjacency, nodes i32):
	number i32[] = fill(nodes, -1)
	order i32[] = []
	order.reserve(nodes)
	last i32[] = zeros(nodes)
	cursor = out.start.copy()
	stack i32[] = [0]
	stack.reserve(nodes)
	number[0] = 0
	order.push(0)
	while not stack.isEmpty:
		v = stack[len - 1]
		if cursor[v] < out.start[v + 1]:
			t = out.list[cursor[v]]
			cursor[v] += 1
			if number[t] < 0:
				number[t] = i32(order.len)
				order.push(t)
				stack.push(t)
		else:
			last[number[v]] = i32(order.len) - 1
			stack.pop()
	Numbering(number, order, last)

# the predecessors of each numbered node, back edges (from a descendant) apart from the others
type Preds:
	backStart i32[]
	backList i32[]
	plainStart i32[]
	plainList i32[]

fn predecessors(num Numbering, inn Adjacency):
	count = num.order.len
	backStart i32[] = []
	backList i32[] = []
	plainStart i32[] = []
	plainList i32[] = []
	backStart.reserve(count + 1)
	plainStart.reserve(count + 1)
	backList.reserve(inn.list.len)
	plainList.reserve(inn.list.len)
	for w in 0..num.order.len:
		backStart.push(i32(backList.len))
		plainStart.push(i32(plainList.len))
		node = num.order[w]
		for e in inn.start[node]..inn.start[node + 1]:
			v = num.number[inn.list[e]]
			if v < 0: continue
			if w <= v and v <= num.last[w]: backList.push(v)
			else: plainList.push(v)
	backStart.push(i32(backList.len))
	plainStart.push(i32(plainList.len))
	Preds(backStart, backList, plainStart, plainList)

type Stats:
	loops i64
	irreducible i64
	selfLoops i64
	blocks i64
	maxDepth i64
	depthSum i64

# the loop finder's state: union-find over the numbers (uf), the nodes already in the pool of the
# loop being collapsed (mark), the loop each header heads, and the loops found. Predecessors added
# while collapsing are chained through extraNext.
type Finder:
	num Numbering
	preds Preds
	uf i32[]
	mark i32[]
	loopOf i32[]
	pool i32[]
	extraHead i32[]
	extraNext i32[]
	extraVal i32[]
	irreducible bool
	parent i32[]
	blocks i32[]
	kind u8[]   # 1 reducible, 2 irreducible, 3 self

	fn find(x i32):
		root = x
		while uf[root] != root:
			root = uf[root]
		at = x
		while uf[at] != root:
			next = uf[at]
			uf[at] = root
			at = next
		root

	# a predecessor y of a node of the pool of w: one inside w's subtree joins the pool, one outside
	# makes the loop irreducible and a predecessor of w
	fn visit(w i32, y i32):
		yd = find(y)
		if w <= yd and yd <= num.last[w]:
			if yd != w and mark[yd] != w:
				mark[yd] = w
				pool.push(yd)
		else:
			irreducible = true
			extraVal.push(yd)
			extraNext.push(extraHead[w])
			extraHead[w] = i32(extraVal.len) - 1

	# the loop headed by w, if any: the pool of the nodes that reach a back edge to w without passing w
	fn collapse(w i32):
		pool.clear()
		irreducible = false
		isSelf = false
		for e in preds.backStart[w]..preds.backStart[w + 1]:
			v = preds.backList[e]
			if v == w:
				isSelf = true
				continue
			r = find(v)
			if mark[r] != w:
				mark[r] = w
				pool.push(r)
		i = 0
		while i < pool.len:
			x = pool[i]
			i += 1
			for e in preds.plainStart[x]..preds.plainStart[x + 1]:
				visit(w, preds.plainList[e])
			e = extraHead[x]
			while e >= 0:
				visit(w, extraVal[e])
				e = extraNext[e]
		if pool.isEmpty and not isSelf: return
		id = i32(kind.len)
		kind.push(2 if irreducible else 3 if pool.isEmpty else 1)
		parent.push(-1)
		blocks.push(0)
		loopOf[w] = id
		for node in pool:
			uf[node] = w
			if loopOf[node] >= 0: parent[loopOf[node]] = id
			else: blocks[id] += 1

	# the loops counted, and their nesting: parents are found after their children
	fn stats():
		s = Stats(
			loops = kind.len,
			irreducible = 0,
			selfLoops = 0,
			blocks = 0,
			maxDepth = 0,
			depthSum = 0
		)
		depth = zeros(kind.len)
		for l in kind.len - 1..-1 step -1:
			depth[l] = 1 if parent[l] < 0 else depth[parent[l]] + 1
			s.maxDepth = s.maxDepth.max(depth[l])
			s.depthSum += depth[l]
			s.blocks += blocks[l]
			if kind[l] == 2: s.irreducible += 1
			if kind[l] == 3: s.selfLoops += 1
		s

fn findLoops(nodes i32, out Adjacency, inn Adjacency):
	num = out.numbering(nodes)
	count = num.order.len
	preds = num.predecessors(inn)
	finder = Finder(
		num,
		preds,
		uf = (0..count).map(i32(it)),
		mark = fill(count, -1),
		loopOf = fill(count, -1),
		pool = [],
		extraHead = fill(count, -1),
		extraNext = [],
		extraVal = [],
		irreducible = false,
		parent = [],
		blocks = [],
		kind = [])
	finder.pool.reserve(count)
	finder.parent.reserve(count)
	finder.blocks.reserve(count)
	finder.kind.reserve(count)
	for w in count - 1..-1 step -1:
		finder.collapse(i32(w))
	finder.stats()

runs = arg(0, 1)
mut g = Graph(nodes = 0, from = [], to = [])
g.build()
out = adjacency(g.nodes, g.from, g.to)
inn = adjacency(g.nodes, g.to, g.from)
mut found = 0
mut last = Stats(loops = 0, irreducible = 0, selfLoops = 0, blocks = 0, maxDepth = 0, depthSum = 0)
loop runs:
	last = findLoops(g.nodes, out, inn)
	found += last.loops
print("{g.nodes} nodes, {g.from.len} edges")
print("{found} loops found in {runs} runs")
print("loops {last.loops}, irreducible {last.irreducible}, self {last.selfLoops}, blocks {last.blocks}, max depth {last.maxDepth}, depth sum {last.depthSum}")

test "Havlak's loop finder finds every loop of the synthetic graph":
	main()
	prints """
		252013 nodes, 378021 edges
		76000 loops found in 1 runs
		loops 76000, irreducible 0, self 0, blocks 176000, max depth 3, depth sum 201000
		"""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("havlak")
