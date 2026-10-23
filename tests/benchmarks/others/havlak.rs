// havlak: Havlak's loop finder (Google's "Loop Recognition in C++/Java/Go/Scala" benchmark) over a synthetic
// control-flow graph of nested and sequential loops, run n times; prints the loops found.
use std::io::Write;

#[derive(Default)]
struct Graph {
    nodes: usize,
    from: Vec<usize>,
    to: Vec<usize>,
}

impl Graph {
    fn connect(&mut self, a: usize, b: usize) {
        self.from.push(a);
        self.to.push(b);
        self.nodes = self.nodes.max(a + 1).max(b + 1);
    }

    fn straight(&mut self, start: usize, n: usize) -> usize {
        for i in 0..n {
            self.connect(start + i, start + i + 1);
        }
        start + n
    }

    fn diamond(&mut self, start: usize) -> usize {
        self.connect(start, start + 1);
        self.connect(start, start + 2);
        self.connect(start + 1, start + 3);
        self.connect(start + 2, start + 3);
        start + 3
    }

    // a loop whose body holds a diamond, a second loop (a diamond with a back edge) and a diamond
    fn base_loop(&mut self, start: usize) -> usize {
        let header = self.straight(start, 1);
        let d1 = self.diamond(header);
        let d11 = self.straight(d1, 1);
        let d2 = self.diamond(d11);
        let footer = self.straight(d2, 1);
        self.connect(d2, d11);
        self.connect(d1, header);
        self.connect(footer, start);
        self.straight(footer, 1)
    }

    fn build(&mut self) {
        let mut n = 2;
        self.connect(0, 2);
        for _ in 0..10 {
            n += 1;
            self.connect(2, n);
            for _ in 0..100 {
                let top = n;
                n = self.straight(n, 1);
                for _ in 0..25 {
                    n = self.base_loop(n);
                }
                let bottom = self.straight(n, 1);
                self.connect(n, top);
                n = bottom;
            }
            self.connect(n, 1);
        }
    }
}

#[derive(Default)]
struct Stats {
    loops: usize,
    irreducible: usize,
    selfs: usize,
    blocks: usize,
    max_depth: usize,
    depth_sum: u64,
}

// the neighbours of every node as a compressed list: start[v]..start[v+1] into list, in edge order
struct Adjacency {
    start: Vec<usize>,
    list: Vec<usize>,
}

impl Adjacency {
    fn new(nodes: usize, key: &[usize], other: &[usize]) -> Adjacency {
        let mut start = vec![0usize; nodes + 2];
        for &k in key {
            start[k + 1] += 1;
        }
        for v in 0..nodes {
            start[v + 1] += start[v];
        }
        let mut fill = start.clone();
        let mut list = vec![0usize; key.len()];
        for e in 0..key.len() {
            list[fill[key[e]]] = other[e];
            fill[key[e]] += 1;
        }
        Adjacency { start, list }
    }
}

fn find(uf: &mut [usize], mut x: usize) -> usize {
    let mut root = x;
    while uf[root] != root {
        root = uf[root];
    }
    while uf[x] != root {
        let next = uf[x];
        uf[x] = root;
        x = next;
    }
    root
}

const NONE: usize = usize::MAX;

fn find_loops(nodes: usize, out: &Adjacency, inn: &Adjacency) -> Stats {
    let mut number = vec![NONE; nodes];
    let mut order = vec![0usize; nodes];
    let mut last = vec![0usize; nodes];
    let mut cursor = vec![0usize; nodes];
    let mut stack: Vec<usize> = Vec::with_capacity(nodes);
    // depth-first numbering from the start node, last[w] the highest number below w
    let mut count = 0;
    number[0] = count;
    order[count] = 0;
    count += 1;
    cursor[0] = out.start[0];
    stack.push(0);
    while let Some(&v) = stack.last() {
        if cursor[v] < out.start[v + 1] {
            let t = out.list[cursor[v]];
            cursor[v] += 1;
            if number[t] == NONE {
                number[t] = count;
                order[count] = t;
                count += 1;
                cursor[t] = out.start[t];
                stack.push(t);
            }
        } else {
            last[number[v]] = count - 1;
            stack.pop();
        }
    }
    // the predecessors of each numbered node, back edges (from a descendant) apart from the others
    let mut back_start = vec![0usize; count + 1];
    let mut back_list: Vec<usize> = Vec::new();
    let mut plain_start = vec![0usize; count + 1];
    let mut plain_list: Vec<usize> = Vec::new();
    for w in 0..count {
        back_start[w] = back_list.len();
        plain_start[w] = plain_list.len();
        let node = order[w];
        for e in inn.start[node]..inn.start[node + 1] {
            let v = number[inn.list[e]];
            if v == NONE {
                continue;
            }
            if w <= v && v <= last[w] {
                back_list.push(v);
            } else {
                plain_list.push(v);
            }
        }
    }
    back_start[count] = back_list.len();
    plain_start[count] = plain_list.len();
    // predecessors added later, as lists chained through extra_next
    let mut extra_head = vec![NONE; count];
    let mut extra_next: Vec<usize> = Vec::new();
    let mut extra_val: Vec<usize> = Vec::new();

    let mut uf: Vec<usize> = (0..count).collect();
    let mut mark = vec![NONE; count];
    let mut loop_of = vec![NONE; count];
    let mut pool: Vec<usize> = Vec::with_capacity(count);
    let mut parent: Vec<usize> = Vec::new();
    let mut blocks: Vec<usize> = Vec::new();
    let mut kind: Vec<u8> = Vec::new(); // 1 reducible, 2 irreducible, 3 self
    let mut stats = Stats::default();
    for w in (0..count).rev() {
        pool.clear();
        let mut is_self = false;
        let mut irreducible = false;
        for e in back_start[w]..back_start[w + 1] {
            let v = back_list[e];
            if v == w {
                is_self = true;
                continue;
            }
            let r = find(&mut uf, v);
            if mark[r] != w {
                mark[r] = w;
                pool.push(r);
            }
        }
        macro_rules! visit {
            ($y:expr) => {
                let yd = find(&mut uf, $y);
                if !(w <= yd && yd <= last[w]) {
                    irreducible = true;
                    extra_val.push(yd);
                    extra_next.push(extra_head[w]);
                    extra_head[w] = extra_val.len() - 1;
                } else if yd != w && mark[yd] != w {
                    mark[yd] = w;
                    pool.push(yd);
                }
            };
        }
        let mut i = 0;
        while i < pool.len() {
            let x = pool[i];
            i += 1;
            for e in plain_start[x]..plain_start[x + 1] {
                visit!(plain_list[e]);
            }
            let mut e = extra_head[x];
            while e != NONE {
                visit!(extra_val[e]);
                e = extra_next[e];
            }
        }
        if pool.is_empty() && !is_self {
            continue;
        }
        let lp = stats.loops;
        stats.loops += 1;
        kind.push(if irreducible { 2 } else if pool.is_empty() { 3 } else { 1 });
        parent.push(NONE);
        blocks.push(0);
        loop_of[w] = lp;
        for &node in &pool {
            uf[node] = w;
            if loop_of[node] != NONE {
                parent[loop_of[node]] = lp;
            } else {
                blocks[lp] += 1;
            }
        }
    }
    let mut depth = vec![0usize; stats.loops];
    for l in (0..stats.loops).rev() {
        depth[l] = if parent[l] == NONE { 1 } else { depth[parent[l]] + 1 };
        stats.max_depth = stats.max_depth.max(depth[l]);
        stats.depth_sum += depth[l] as u64;
        stats.blocks += blocks[l];
        if kind[l] == 2 {
            stats.irreducible += 1;
        }
        if kind[l] == 3 {
            stats.selfs += 1;
        }
    }
    stats
}

fn main() {
    let runs: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(1);
    let mut g = Graph::default();
    g.build();
    let out = Adjacency::new(g.nodes, &g.from, &g.to);
    let inn = Adjacency::new(g.nodes, &g.to, &g.from);
    let mut found = 0usize;
    let mut stats = Stats::default();
    for _ in 0..runs {
        stats = find_loops(g.nodes, &out, &inn);
        found += stats.loops;
    }
    let mut o = std::io::stdout().lock();
    writeln!(o, "{} nodes, {} edges", g.nodes, g.from.len()).unwrap();
    writeln!(o, "{} loops found in {} runs", found, runs).unwrap();
    writeln!(
        o,
        "loops {}, irreducible {}, self {}, blocks {}, max depth {}, depth sum {}",
        stats.loops, stats.irreducible, stats.selfs, stats.blocks, stats.max_depth, stats.depth_sum
    )
    .unwrap();
}
