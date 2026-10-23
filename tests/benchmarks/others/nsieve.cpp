// nsieve: primes up to 2^k * 10000 for k = n, n - 1, n - 2, by a sieve of one bit per number.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

static long long primesUpTo(long long limit) {
    std::vector<uint64_t> candidates(static_cast<size_t>(limit / 64 + 1), ~uint64_t{0});
    long long count = 0;
    for (long long i = 2; i <= limit; i++) {
        if (candidates[i >> 6] & (uint64_t{1} << (i & 63))) {
            count++;
            for (long long j = i * i; j <= limit; j += i)
                candidates[j >> 6] &= ~(uint64_t{1} << (j & 63));
        }
    }
    return count;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    long long n = argc > 1 ? atoll(argv[1]) : 2;
    for (long long k = 0; k < 3; k++) {
        long long limit = (1LL << (n - k)) * 10000;
        printf("Primes up to %8lld %8lld\n", limit, primesUpTo(limit));
    }
    return 0;
}
