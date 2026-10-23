// dijkstra: shortest paths from the top left cell of an n by n grid whose edges between
// neighbours cost 1 to 9, over a binary heap of (distance, cell) packed in one u64; prints the
// far corner's distance, the sum of all and how many entries the heap took.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <queue>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

static uint64_t state = 1;

// the next number, 31 bits
static uint64_t next() {
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return state >> 33;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    size_t n = argc > 1 ? (size_t)atoll(argv[1]) : 100;
    // the cost of the edge from a cell to its right and to its lower neighbour
    std::vector<uint8_t> right(n * n), down(n * n);
    for (size_t i = 0; i < n * n; i++) {
        right[i] = (uint8_t)(1 + next() % 9);
        down[i] = (uint8_t)(1 + next() % 9);
    }
    std::vector<uint32_t> dist(n * n, UINT32_MAX);
    std::priority_queue<uint64_t, std::vector<uint64_t>, std::greater<uint64_t>> heap;
    size_t pushes = 0;
    auto relax = [&](uint64_t d, size_t cell, uint8_t cost) {
        uint64_t nd = d + cost;
        if (nd < dist[cell]) {
            dist[cell] = (uint32_t)nd;
            heap.push(nd << 32 | cell);
            pushes++;
        }
    };
    dist[0] = 0;
    heap.push(0);
    pushes++;
    while (!heap.empty()) {
        uint64_t top = heap.top();
        heap.pop();
        uint64_t d = top >> 32;
        size_t cell = (uint32_t)top;
        if (d > dist[cell])
            continue;
        size_t x = cell % n, y = cell / n;
        if (x > 0)
            relax(d, cell - 1, right[cell - 1]);
        if (x + 1 < n)
            relax(d, cell + 1, right[cell]);
        if (y > 0)
            relax(d, cell - n, down[cell - n]);
        if (y + 1 < n)
            relax(d, cell + n, down[cell]);
    }
    uint64_t sum = 0;
    for (uint32_t v : dist)
        sum += v;
    printf("corner %u, sum %llu, pushes %zu\n", dist[n * n - 1], (unsigned long long)sum, pushes);
    return 0;
}
