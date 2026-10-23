# havlak: Havlak's loop finder (Google's "Loop Recognition in C++/Java/Go/Scala" benchmark) over a synthetic
# control-flow graph of nested and sequential loops, run n times; prints the loops found
import sys


class Graph:
    def __init__(self):
        self.nodes = 0
        self.src = []
        self.dst = []

    def connect(self, a, b):
        self.src.append(a)
        self.dst.append(b)
        self.nodes = max(self.nodes, a + 1, b + 1)

    def straight(self, start, n):
        for i in range(n):
            self.connect(start + i, start + i + 1)
        return start + n

    def diamond(self, start):
        self.connect(start, start + 1)
        self.connect(start, start + 2)
        self.connect(start + 1, start + 3)
        self.connect(start + 2, start + 3)
        return start + 3

    # a loop whose body holds a diamond, a second loop (a diamond with a back edge) and a diamond
    def base_loop(self, start):
        header = self.straight(start, 1)
        d1 = self.diamond(header)
        d11 = self.straight(d1, 1)
        d2 = self.diamond(d11)
        footer = self.straight(d2, 1)
        self.connect(d2, d11)
        self.connect(d1, header)
        self.connect(footer, start)
        return self.straight(footer, 1)

    def build(self):
        n = 2
        self.connect(0, 2)
        for _ in range(10):
            n += 1
            self.connect(2, n)
            for _ in range(100):
                top = n
                n = self.straight(n, 1)
                for _ in range(25):
                    n = self.base_loop(n)
                bottom = self.straight(n, 1)
                self.connect(n, top)
                n = bottom
            self.connect(n, 1)


def adjacency(nodes, key, other):
    # the neighbours of every node as a list per node, in edge order
    lists = [[] for _ in range(nodes)]
    for k, o in zip(key, other):
        lists[k].append(o)
    return lists


def find(uf, x):
    root = x
    while uf[root] != root:
        root = uf[root]
    while uf[x] != root:
        uf[x], x = root, uf[x]
    return root


def find_loops(nodes, out, inn):
    number = [-1] * nodes
    order = []
    last = [0] * nodes
    # depth-first numbering from the start node, last[w] the highest number below w
    number[0] = 0
    order.append(0)
    cursor = [0] * nodes
    stack = [0]
    while stack:
        v = stack[-1]
        succ = out[v]
        if cursor[v] < len(succ):
            t = succ[cursor[v]]
            cursor[v] += 1
            if number[t] < 0:
                number[t] = len(order)
                order.append(t)
                stack.append(t)
        else:
            last[number[v]] = len(order) - 1
            stack.pop()
    count = len(order)
    # the predecessors of each numbered node, back edges (from a descendant) apart from the others;
    # predecessors added later go to the end of the second list
    back = []
    plain = []
    for w in range(count):
        b = []
        p = []
        lw = last[w]
        for pred in inn[order[w]]:
            v = number[pred]
            if v < 0:
                continue
            if w <= v <= lw:
                b.append(v)
            else:
                p.append(v)
        back.append(b)
        plain.append(p)

    uf = list(range(count))
    mark = [-1] * count
    loop_of = [-1] * count
    parent = []
    blocks = []
    kind = []   # 1 reducible, 2 irreducible, 3 self
    for w in range(count - 1, -1, -1):
        pool = []
        is_self = False
        irreducible = False
        for v in back[w]:
            if v == w:
                is_self = True
                continue
            r = find(uf, v)
            if mark[r] != w:
                mark[r] = w
                pool.append(r)
        lw = last[w]
        i = 0
        while i < len(pool):
            x = pool[i]
            i += 1
            for y in plain[x]:
                yd = find(uf, y)
                if not (w <= yd <= lw):
                    irreducible = True
                    plain[w].append(yd)
                elif yd != w and mark[yd] != w:
                    mark[yd] = w
                    pool.append(yd)
        if not pool and not is_self:
            continue
        loop = len(kind)
        kind.append(2 if irreducible else 3 if not pool else 1)
        parent.append(-1)
        blocks.append(0)
        loop_of[w] = loop
        for node in pool:
            uf[node] = w
            if loop_of[node] >= 0:
                parent[loop_of[node]] = loop
            else:
                blocks[loop] += 1
    loops = len(kind)
    depth = [0] * loops
    max_depth = 0
    depth_sum = 0
    for l in range(loops - 1, -1, -1):
        depth[l] = 1 if parent[l] < 0 else depth[parent[l]] + 1
        max_depth = max(max_depth, depth[l])
        depth_sum += depth[l]
    return loops, kind.count(2), kind.count(3), sum(blocks), max_depth, depth_sum


runs = int(sys.argv[1]) if len(sys.argv) > 1 else 1
g = Graph()
g.build()
out = adjacency(g.nodes, g.src, g.dst)
inn = adjacency(g.nodes, g.dst, g.src)
found = 0
stats = None
for _ in range(runs):
    stats = find_loops(g.nodes, out, inn)
    found += stats[0]
text = "%d nodes, %d edges\n%d loops found in %d runs\n" % (g.nodes, len(g.src), found, runs)
text += "loops %d, irreducible %d, self %d, blocks %d, max depth %d, depth sum %d\n" % stats
sys.stdout.buffer.write(text.encode())   # bytes: no CRLF translation, the runner compares bytes
