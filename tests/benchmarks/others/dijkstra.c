/* dijkstra: shortest paths from the top left cell of an n by n grid whose edges between
 * neighbours cost 1 to 9, over a binary heap of (distance, cell) packed in one u64; prints the
 * far corner's distance, the sum of all and how many entries the heap took. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

typedef struct {
    uint64_t *items;
    size_t len, cap, pushes;
} Heap;

static uint64_t state = 1;

/* the next number, 31 bits */
static uint64_t next(void) {
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return state >> 33;
}

static void push(Heap *h, uint64_t v) {
    if (h->len == h->cap) {
        h->cap = h->cap ? h->cap * 2 : 1024;
        h->items = realloc(h->items, h->cap * sizeof(uint64_t));
    }
    h->pushes++;
    size_t i = h->len++;
    while (i > 0 && h->items[(i - 1) / 2] > v) {
        h->items[i] = h->items[(i - 1) / 2];
        i = (i - 1) / 2;
    }
    h->items[i] = v;
}

static uint64_t pop(Heap *h) {
    uint64_t top = h->items[0];
    uint64_t last = h->items[--h->len];
    size_t i = 0;
    for (;;) {
        size_t c = 2 * i + 1;
        if (c >= h->len)
            break;
        if (c + 1 < h->len && h->items[c + 1] < h->items[c])
            c++;
        if (last <= h->items[c])
            break;
        h->items[i] = h->items[c];
        i = c;
    }
    h->items[i] = last;
    return top;
}

static void relax(Heap *h, uint32_t *dist, uint64_t d, size_t cell, uint8_t cost) {
    uint64_t nd = d + cost;
    if (nd < dist[cell]) {
        dist[cell] = (uint32_t)nd;
        push(h, nd << 32 | cell);
    }
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    size_t n = argc > 1 ? (size_t)atoll(argv[1]) : 100;
    /* the cost of the edge from a cell to its right and to its lower neighbour */
    uint8_t *right = malloc(n * n), *down = malloc(n * n);
    uint32_t *dist = malloc(n * n * sizeof(uint32_t));
    for (size_t i = 0; i < n * n; i++) {
        right[i] = (uint8_t)(1 + next() % 9);
        down[i] = (uint8_t)(1 + next() % 9);
        dist[i] = UINT32_MAX;
    }
    Heap h = {0};
    dist[0] = 0;
    push(&h, 0);
    while (h.len > 0) {
        uint64_t top = pop(&h);
        uint64_t d = top >> 32;
        size_t cell = (uint32_t)top;
        if (d > dist[cell])
            continue;
        size_t x = cell % n, y = cell / n;
        if (x > 0)
            relax(&h, dist, d, cell - 1, right[cell - 1]);
        if (x + 1 < n)
            relax(&h, dist, d, cell + 1, right[cell]);
        if (y > 0)
            relax(&h, dist, d, cell - n, down[cell - n]);
        if (y + 1 < n)
            relax(&h, dist, d, cell + n, down[cell]);
    }
    uint64_t sum = 0;
    for (size_t i = 0; i < n * n; i++)
        sum += dist[i];
    printf("corner %u, sum %llu, pushes %zu\n", dist[n * n - 1], (unsigned long long)sum, h.pushes);
    free(h.items);
    free(dist);
    free(down);
    free(right);
    return 0;
}
