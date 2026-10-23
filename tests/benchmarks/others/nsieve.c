/* nsieve: primes up to 2^k * 10000 for k = n, n - 1, n - 2, by a sieve of one bit per number. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

static long long primes_up_to(long long m) {
    size_t words = (size_t)(m / 64 + 1);
    uint64_t *candidates = malloc(words * sizeof(uint64_t));
    memset(candidates, 0xff, words * sizeof(uint64_t));
    long long count = 0;
    for (long long i = 2; i <= m; i++) {
        if (candidates[i >> 6] & ((uint64_t)1 << (i & 63))) {
            count++;
            for (long long j = i * i; j <= m; j += i)
                candidates[j >> 6] &= ~((uint64_t)1 << (j & 63));
        }
    }
    free(candidates);
    return count;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    long long n = argc > 1 ? atoll(argv[1]) : 2;
    for (long long k = 0; k < 3; k++) {
        long long m = (1LL << (n - k)) * 10000;
        printf("Primes up to %8lld %8lld\n", m, primes_up_to(m));
    }
    return 0;
}
