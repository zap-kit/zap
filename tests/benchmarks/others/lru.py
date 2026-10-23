# lru: an LRU cache of `size` entries through n operations of the programming-language-benchmarks
# suite: each step puts a key of one LCG and gets a key of another; prints the hits and the misses.
# The language's ordered map, the oldest entry first.
import sys
from collections import OrderedDict

size = int(sys.argv[1]) if len(sys.argv) > 1 else 100
n = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
modular = size * 10
cache = OrderedDict()
seed0, seed1 = 0, 1
hit = missed = 0
for _ in range(n):
    seed0 = (seed0 * 1103515245 + 12345) & 0x7FFFFFFF
    k0 = seed0 % modular
    if k0 in cache:
        cache.move_to_end(k0)
    elif len(cache) == size:
        cache.popitem(last=False)
    cache[k0] = k0
    seed1 = (seed1 * 1103515245 + 12345) & 0x7FFFFFFF
    k1 = seed1 % modular
    if k1 in cache:
        cache.move_to_end(k1)
        hit += 1
    else:
        missed += 1
sys.stdout.buffer.write(b"%d\n%d\n" % (hit, missed))
