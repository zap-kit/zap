// havlak: Havlak's loop finder (Google's "Loop Recognition in C++/Java/Go/Scala" benchmark) over a synthetic
// control-flow graph of nested and sequential loops, run n times; prints the loops found.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

struct Graph {
    int nodes = 0;
    std::vector<int> from, to;

    void connect(int a, int b) {
        from.push_back(a);
        to.push_back(b);
        nodes = std::max({nodes, a + 1, b + 1});
    }

    int straight(int start, int n) {
        for (int i = 0; i < n; i++) connect(start + i, start + i + 1);
        return start + n;
    }

    int diamond(int start) {
        connect(start, start + 1);
        connect(start, start + 2);
        connect(start + 1, start + 3);
        connect(start + 2, start + 3);
        return start + 3;
    }

    // a loop whose body holds a diamond, a second loop (a diamond with a back edge) and a diamond
    int baseLoop(int start) {
        int header = straight(start, 1);
        int d1 = diamond(header);
        int d11 = straight(d1, 1);
        int d2 = diamond(d11);
        int footer = straight(d2, 1);
        connect(d2, d11);
        connect(d1, header);
        connect(footer, start);
        return straight(footer, 1);
    }

    void build() {
        int n = 2;
        connect(0, 2);
        for (int tree = 0; tree < 10; tree++) {
            n++;
            connect(2, n);
            for (int i = 0; i < 100; i++) {
                int top = n;
                n = straight(n, 1);
                for (int j = 0; j < 25; j++) n = baseLoop(n);
                int bottom = straight(n, 1);
                connect(n, top);
                n = bottom;
            }
            connect(n, 1);
        }
    }
};

struct Stats {
    int loops = 0, irreducible = 0, self = 0, blocks = 0, maxDepth = 0;
    long long depthSum = 0;
};

// the neighbours of every node as a compressed list: start[v]..start[v+1] into list, in edge order
struct Adjacency {
    std::vector<int> start, list;

    Adjacency(const Graph &g, const std::vector<int> &key, const std::vector<int> &other)
        : start(g.nodes + 2), list(key.size()) {
        for (int k : key) start[k + 1]++;
        for (int v = 0; v < g.nodes; v++) start[v + 1] += start[v];
        std::vector<int> fill(start.begin(), start.begin() + g.nodes + 1);
        for (size_t e = 0; e < key.size(); e++) list[fill[key[e]]++] = other[e];
    }
};

static int find(std::vector<int> &uf, int x) {
    int root = x;
    while (uf[root] != root) root = uf[root];
    while (uf[x] != root) {
        int next = uf[x];
        uf[x] = root;
        x = next;
    }
    return root;
}

static Stats findLoops(const Graph &g, const Adjacency &out, const Adjacency &in) {
    int size = g.nodes;
    std::vector<int> number(size, -1), order(size), last(size), cursor(size), stack;
    stack.reserve(size);
    // depth-first numbering from the start node, last[w] the highest number below w
    int count = 0;
    number[0] = count;
    order[count++] = 0;
    cursor[0] = out.start[0];
    stack.push_back(0);
    while (!stack.empty()) {
        int v = stack.back();
        if (cursor[v] < out.start[v + 1]) {
            int t = out.list[cursor[v]++];
            if (number[t] < 0) {
                number[t] = count;
                order[count++] = t;
                cursor[t] = out.start[t];
                stack.push_back(t);
            }
        } else {
            last[number[v]] = count - 1;
            stack.pop_back();
        }
    }
    // the predecessors of each numbered node, back edges (from a descendant) apart from the others
    std::vector<int> backStart(count + 1), backList, plainStart(count + 1), plainList;
    for (int w = 0; w < count; w++) {
        backStart[w] = static_cast<int>(backList.size());
        plainStart[w] = static_cast<int>(plainList.size());
        int node = order[w];
        for (int e = in.start[node]; e < in.start[node + 1]; e++) {
            int v = number[in.list[e]];
            if (v < 0) continue;
            if (w <= v && v <= last[w]) backList.push_back(v);
            else plainList.push_back(v);
        }
    }
    backStart[count] = static_cast<int>(backList.size());
    plainStart[count] = static_cast<int>(plainList.size());
    // predecessors added later, as lists chained through extraNext
    std::vector<int> extraHead(count, -1), extraNext, extraVal;

    std::vector<int> uf(count), mark(count, -1), loopOf(count, -1), pool, parent, blocks;
    std::vector<uint8_t> kind; // 1 reducible, 2 irreducible, 3 self
    pool.reserve(count);
    for (int w = 0; w < count; w++) uf[w] = w;
    Stats stats;
    for (int w = count - 1; w >= 0; w--) {
        pool.clear();
        bool isSelf = false, irreducible = false;
        for (int e = backStart[w]; e < backStart[w + 1]; e++) {
            int v = backList[e];
            if (v == w) {
                isSelf = true;
                continue;
            }
            int r = find(uf, v);
            if (mark[r] != w) {
                mark[r] = w;
                pool.push_back(r);
            }
        }
        auto visit = [&](int y) {
            int yd = find(uf, y);
            if (!(w <= yd && yd <= last[w])) {
                irreducible = true;
                extraVal.push_back(yd);
                extraNext.push_back(extraHead[w]);
                extraHead[w] = static_cast<int>(extraVal.size()) - 1;
            } else if (yd != w && mark[yd] != w) {
                mark[yd] = w;
                pool.push_back(yd);
            }
        };
        for (size_t i = 0; i < pool.size(); i++) {
            int x = pool[i];
            for (int e = plainStart[x]; e < plainStart[x + 1]; e++) visit(plainList[e]);
            for (int e = extraHead[x]; e >= 0; e = extraNext[e]) visit(extraVal[e]);
        }
        if (pool.empty() && !isSelf) continue;
        int loop = stats.loops++;
        kind.push_back(irreducible ? 2 : pool.empty() ? 3 : 1);
        parent.push_back(-1);
        blocks.push_back(0);
        loopOf[w] = loop;
        for (int node : pool) {
            uf[node] = w;
            if (loopOf[node] >= 0) parent[loopOf[node]] = loop;
            else blocks[loop]++;
        }
    }
    std::vector<int> depth(stats.loops);
    for (int l = stats.loops - 1; l >= 0; l--) {
        depth[l] = parent[l] < 0 ? 1 : depth[parent[l]] + 1;
        stats.maxDepth = std::max(stats.maxDepth, depth[l]);
        stats.depthSum += depth[l];
        stats.blocks += blocks[l];
        if (kind[l] == 2) stats.irreducible++;
        if (kind[l] == 3) stats.self++;
    }
    return stats;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    int runs = argc > 1 ? atoi(argv[1]) : 1;
    Graph g;
    g.build();
    Adjacency out(g, g.from, g.to), in(g, g.to, g.from);
    long long found = 0;
    Stats stats;
    for (int r = 0; r < runs; r++) {
        stats = findLoops(g, out, in);
        found += stats.loops;
    }
    printf("%d nodes, %zu edges\n", g.nodes, g.from.size());
    printf("%lld loops found in %d runs\n", found, runs);
    printf("loops %d, irreducible %d, self %d, blocks %d, max depth %d, depth sum %lld\n", stats.loops,
           stats.irreducible, stats.self, stats.blocks, stats.maxDepth, stats.depthSum);
    return 0;
}
