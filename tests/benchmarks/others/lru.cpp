// lru: an LRU cache of `size` entries through n operations of the programming-language-benchmarks
// suite: each step puts a key of one LCG and gets a key of another; prints the hits and the misses.
// A hash map from key to slot, the slots in a doubly linked list from the oldest to the newest.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <unordered_map>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

namespace {

constexpr uint32_t NONE = 0xffffffffu;

// the next number of an LCG: 31 bits
uint32_t lcg(uint32_t &seed) {
    seed = (seed * 1103515245u + 12345u) & 0x7fffffffu;
    return seed;
}

class Cache {
public:
    explicit Cache(uint32_t size) : size_(size), key_(size), value_(size), prev_(size), next_(size) {
        slot_.reserve(size);
    }

    void put(uint32_t key, uint32_t value) {
        auto it = slot_.find(key);
        if (it != slot_.end()) {
            uint32_t s = it->second;
            value_[s] = value;
            moveToEnd(s);
            return;
        }
        uint32_t s;
        if (len_ == size_) {
            s = head_;
            slot_.erase(key_[s]);
            unlink(s);
        } else {
            s = len_++;
        }
        key_[s] = key;
        value_[s] = value;
        slot_[key] = s;
        append(s);
    }

    bool get(uint32_t key) {
        auto it = slot_.find(key);
        if (it == slot_.end()) return false;
        moveToEnd(it->second);
        return true;
    }

private:
    void unlink(uint32_t s) {
        uint32_t p = prev_[s], n = next_[s];
        if (p == NONE) head_ = n; else next_[p] = n;
        if (n == NONE) tail_ = p; else prev_[n] = p;
    }

    void append(uint32_t s) {
        prev_[s] = tail_;
        next_[s] = NONE;
        if (tail_ == NONE) head_ = s; else next_[tail_] = s;
        tail_ = s;
    }

    void moveToEnd(uint32_t s) {
        if (s == tail_) return;
        unlink(s);
        append(s);
    }

    uint32_t size_, len_ = 0, head_ = NONE, tail_ = NONE;
    std::vector<uint32_t> key_, value_, prev_, next_;
    std::unordered_map<uint32_t, uint32_t> slot_;
};

}  // namespace

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    uint32_t size = argc > 1 ? std::atoi(argv[1]) : 100;
    long n = argc > 2 ? std::atol(argv[2]) : 10000;
    uint32_t modular = size * 10;
    Cache cache(size);
    uint32_t seed0 = 0, seed1 = 1;
    long hit = 0, missed = 0;
    for (long i = 0; i < n; i++) {
        uint32_t k0 = lcg(seed0) % modular;
        cache.put(k0, k0);
        uint32_t k1 = lcg(seed1) % modular;
        if (cache.get(k1)) hit++; else missed++;
    }
    std::printf("%ld\n%ld\n", hit, missed);
    return 0;
}
