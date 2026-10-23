# dijkstra: shortest paths from the top left cell of an n by n grid whose edges between
# neighbours cost 1 to 9, over a binary heap of (distance, cell) packed in one integer; prints the
# far corner's distance, the sum of all and how many entries the heap took.
import sys
from heapq import heappop, heappush

MASK = (1 << 64) - 1
n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
state = 1
right = [0] * (n * n)
down = [0] * (n * n)
for i in range(n * n):
    state = (state * 6364136223846793005 + 1442695040888963407) & MASK
    right[i] = 1 + (state >> 33) % 9
    state = (state * 6364136223846793005 + 1442695040888963407) & MASK
    down[i] = 1 + (state >> 33) % 9
INF = 1 << 40
dist = [INF] * (n * n)
dist[0] = 0
heap = [0]
pushes = 1
while heap:
    top = heappop(heap)
    d = top >> 32
    cell = top & 0xFFFFFFFF
    if d > dist[cell]:
        continue
    y, x = divmod(cell, n)
    if x > 0:
        nd = d + right[cell - 1]
        if nd < dist[cell - 1]:
            dist[cell - 1] = nd
            heappush(heap, nd << 32 | cell - 1)
            pushes += 1
    if x + 1 < n:
        nd = d + right[cell]
        if nd < dist[cell + 1]:
            dist[cell + 1] = nd
            heappush(heap, nd << 32 | cell + 1)
            pushes += 1
    if y > 0:
        nd = d + down[cell - n]
        if nd < dist[cell - n]:
            dist[cell - n] = nd
            heappush(heap, nd << 32 | cell - n)
            pushes += 1
    if y + 1 < n:
        nd = d + down[cell]
        if nd < dist[cell + n]:
            dist[cell + n] = nd
            heappush(heap, nd << 32 | cell + n)
            pushes += 1
sys.stdout.buffer.write(b"corner %d, sum %d, pushes %d\n" % (dist[n * n - 1], sum(dist), pushes))
