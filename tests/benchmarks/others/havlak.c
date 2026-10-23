/* havlak: Havlak's loop finder (Google's "Loop Recognition in C++/Java/Go/Scala" benchmark) over a synthetic
   control-flow graph of nested and sequential loops, run n times; prints the loops found. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

typedef struct {
    int nodes, edges, cap;
    int *from, *to;
} Graph;

static void connect(Graph *g, int a, int b) {
    if (g->edges == g->cap) {
        g->cap = g->cap ? g->cap * 2 : 1024;
        g->from = realloc(g->from, g->cap * sizeof(int));
        g->to = realloc(g->to, g->cap * sizeof(int));
    }
    g->from[g->edges] = a;
    g->to[g->edges++] = b;
    if (a >= g->nodes) g->nodes = a + 1;
    if (b >= g->nodes) g->nodes = b + 1;
}

static int straight(Graph *g, int start, int n) {
    for (int i = 0; i < n; i++) connect(g, start + i, start + i + 1);
    return start + n;
}

static int diamond(Graph *g, int start) {
    connect(g, start, start + 1);
    connect(g, start, start + 2);
    connect(g, start + 1, start + 3);
    connect(g, start + 2, start + 3);
    return start + 3;
}

/* a loop whose body holds a diamond, a second loop (a diamond with a back edge) and a diamond */
static int baseLoop(Graph *g, int from) {
    int header = straight(g, from, 1);
    int d1 = diamond(g, header);
    int d11 = straight(g, d1, 1);
    int d2 = diamond(g, d11);
    int footer = straight(g, d2, 1);
    connect(g, d2, d11);
    connect(g, d1, header);
    connect(g, footer, from);
    return straight(g, footer, 1);
}

static void build(Graph *g) {
    int n = 2;
    connect(g, 0, 2);
    for (int tree = 0; tree < 10; tree++) {
        n++;
        connect(g, 2, n);
        for (int i = 0; i < 100; i++) {
            int top = n;
            n = straight(g, n, 1);
            for (int j = 0; j < 25; j++) n = baseLoop(g, n);
            int bottom = straight(g, n, 1);
            connect(g, n, top);
            n = bottom;
        }
        connect(g, n, 1);
    }
}

typedef struct {
    int loops, irreducible, self, blocks, maxDepth;
    long long depthSum;
} Stats;

/* the neighbours of every node as a compressed list: start[v]..start[v+1] into other[], in edge order */
static void adjacency(const Graph *g, const int *key, const int *other, int **start, int **list) {
    int *s = calloc(g->nodes + 2, sizeof(int));
    int *l = malloc((g->edges + 1) * sizeof(int));
    for (int e = 0; e < g->edges; e++) s[key[e] + 1]++;
    for (int v = 0; v < g->nodes; v++) s[v + 1] += s[v];
    int *fill = malloc((g->nodes + 1) * sizeof(int));
    memcpy(fill, s, (g->nodes + 1) * sizeof(int));
    for (int e = 0; e < g->edges; e++) l[fill[key[e]]++] = other[e];
    free(fill);
    *start = s;
    *list = l;
}

static int find(int *uf, int x) {
    int root = x;
    while (uf[root] != root) root = uf[root];
    while (uf[x] != root) {
        int next = uf[x];
        uf[x] = root;
        x = next;
    }
    return root;
}

static Stats findLoops(const Graph *g, const int *outStart, const int *outTo, const int *inStart, const int *inFrom) {
    int size = g->nodes;
    int *number = malloc(size * sizeof(int));
    int *order = malloc(size * sizeof(int));
    int *last = malloc(size * sizeof(int));
    int *cursor = malloc(size * sizeof(int));
    int *stack = malloc(size * sizeof(int));
    for (int v = 0; v < size; v++) number[v] = -1;
    /* depth-first numbering from the start node, last[w] the highest number below w */
    int count = 0, sp = 0;
    number[0] = count;
    order[count++] = 0;
    cursor[0] = outStart[0];
    stack[sp++] = 0;
    while (sp > 0) {
        int v = stack[sp - 1];
        if (cursor[v] < outStart[v + 1]) {
            int t = outTo[cursor[v]++];
            if (number[t] < 0) {
                number[t] = count;
                order[count++] = t;
                cursor[t] = outStart[t];
                stack[sp++] = t;
            }
        } else {
            last[number[v]] = count - 1;
            sp--;
        }
    }
    /* the predecessors of each numbered node, back edges (from a descendant) apart from the others */
    int *backStart = malloc((count + 1) * sizeof(int));
    int *backList = malloc((g->edges + 1) * sizeof(int));
    int *plainStart = malloc((count + 1) * sizeof(int));
    int *plainList = malloc((g->edges + 1) * sizeof(int));
    int nb = 0, np = 0;
    for (int w = 0; w < count; w++) {
        backStart[w] = nb;
        plainStart[w] = np;
        int node = order[w];
        for (int e = inStart[node]; e < inStart[node + 1]; e++) {
            int v = number[inFrom[e]];
            if (v < 0) continue;
            if (w <= v && v <= last[w]) backList[nb++] = v;
            else plainList[np++] = v;
        }
    }
    backStart[count] = nb;
    plainStart[count] = np;
    /* predecessors added later, as lists chained through extraNext */
    int *extraHead = malloc(count * sizeof(int));
    for (int w = 0; w < count; w++) extraHead[w] = -1;
    int *extraNext = NULL, *extraVal = NULL, extraLen = 0, extraCap = 0;

    int *uf = malloc(count * sizeof(int));
    int *mark = malloc(count * sizeof(int));
    int *loopOf = malloc(count * sizeof(int));
    int *pool = malloc(count * sizeof(int));
    int *parent = malloc(count * sizeof(int));
    int *depth = malloc(count * sizeof(int));
    int *blocks = calloc(count, sizeof(int));
    unsigned char *kind = malloc(count); /* 1 reducible, 2 irreducible, 3 self */
    for (int w = 0; w < count; w++) {
        uf[w] = w;
        mark[w] = -1;
        loopOf[w] = -1;
    }
    Stats stats = {0, 0, 0, 0, 0, 0};
    for (int w = count - 1; w >= 0; w--) {
        int poolLen = 0;
        int isSelf = 0, irreducible = 0;
        for (int e = backStart[w]; e < backStart[w + 1]; e++) {
            int v = backList[e];
            if (v == w) {
                isSelf = 1;
                continue;
            }
            int r = find(uf, v);
            if (mark[r] != w) {
                mark[r] = w;
                pool[poolLen++] = r;
            }
        }
#define VISIT(y)                                                                               do {                                                                                           int yd = find(uf, (y));                                                                    if (!(w <= yd && yd <= last[w])) {                                                             irreducible = 1;                                                                           if (extraLen == extraCap) {                                                                    extraCap = extraCap ? extraCap * 2 : 64;                                                   extraNext = realloc(extraNext, extraCap * sizeof(int));                                    extraVal = realloc(extraVal, extraCap * sizeof(int));                                  }                                                                                          extraVal[extraLen] = yd;                                                                   extraNext[extraLen] = extraHead[w];                                                        extraHead[w] = extraLen++;                                                             } else if (yd != w && mark[yd] != w) {                                                         mark[yd] = w;                                                                              pool[poolLen++] = yd;                                                                  }                                                                                      } while (0)
        for (int i = 0; i < poolLen; i++) {
            int x = pool[i];
            for (int e = plainStart[x]; e < plainStart[x + 1]; e++) VISIT(plainList[e]);
            for (int e = extraHead[x]; e >= 0; e = extraNext[e]) VISIT(extraVal[e]);
        }
        if (poolLen == 0 && !isSelf) continue;
        int loop = stats.loops++;
        kind[loop] = irreducible ? 2 : poolLen == 0 ? 3 : 1;
        parent[loop] = -1;
        loopOf[w] = loop;
        for (int i = 0; i < poolLen; i++) {
            int node = pool[i];
            uf[node] = w;
            if (loopOf[node] >= 0) parent[loopOf[node]] = loop;
            else blocks[loop]++;
        }
    }
    for (int l = stats.loops - 1; l >= 0; l--) {
        depth[l] = parent[l] < 0 ? 1 : depth[parent[l]] + 1;
        if (depth[l] > stats.maxDepth) stats.maxDepth = depth[l];
        stats.depthSum += depth[l];
        stats.blocks += blocks[l];
        if (kind[l] == 2) stats.irreducible++;
        if (kind[l] == 3) stats.self++;
    }
    free(number); free(order); free(last); free(cursor); free(stack);
    free(backStart); free(backList); free(plainStart); free(plainList);
    free(extraHead); free(extraNext); free(extraVal);
    free(uf); free(mark); free(loopOf); free(pool); free(parent); free(depth); free(blocks); free(kind);
    return stats;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    int runs = argc > 1 ? atoi(argv[1]) : 1;
    Graph g = {0, 0, 0, NULL, NULL};
    build(&g);
    int *outStart, *outTo, *inStart, *inFrom;
    adjacency(&g, g.from, g.to, &outStart, &outTo);
    adjacency(&g, g.to, g.from, &inStart, &inFrom);
    long long found = 0;
    Stats stats = {0};
    for (int r = 0; r < runs; r++) {
        stats = findLoops(&g, outStart, outTo, inStart, inFrom);
        found += stats.loops;
    }
    printf("%d nodes, %d edges\n", g.nodes, g.edges);
    printf("%lld loops found in %d runs\n", found, runs);
    printf("loops %d, irreducible %d, self %d, blocks %d, max depth %d, depth sum %lld\n", stats.loops,
           stats.irreducible, stats.self, stats.blocks, stats.maxDepth, stats.depthSum);
    return 0;
}
