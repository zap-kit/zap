# nsieve: primes up to 2^k * 10000 for k = n, n - 1, n - 2, by a sieve of one bit per number
import sys


def primes_up_to(m):
    candidates = bytearray(b"\xff") * (m // 8 + 1)
    count = 0
    for i in range(2, m + 1):
        if candidates[i >> 3] >> (i & 7) & 1:
            count += 1
            for j in range(i * i, m + 1, i):
                candidates[j >> 3] &= ~(1 << (j & 7)) & 0xFF
    return count


n = int(sys.argv[1]) if len(sys.argv) > 1 else 2
out = sys.stdout.buffer   # bytes: no CRLF translation, the runner compares bytes
for k in range(3):
    m = (1 << (n - k)) * 10000
    out.write(("Primes up to %8d %8d\n" % (m, primes_up_to(m))).encode())
