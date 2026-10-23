/* lru: an LRU cache of `size` entries through n operations of the programming-language-benchmarks
 * suite: each step puts a key of one LCG and gets a key of another; prints the hits and the misses.
 * A hash table from key to slot, the slots in a doubly linked list from the oldest to the newest. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
#include <khash.h>

KHASH_MAP_INIT_INT(slots, uint32_t)

typedef struct {
    uint32_t *key, *value, *prev, *next;
    uint32_t head, tail, len, size;
    khash_t(slots) *slot;
} Cache;

#define NONE 0xffffffffu

/* the next number of an LCG: 31 bits */
static uint32_t lcg(uint32_t *seed) {
    *seed = (*seed * 1103515245u + 12345u) & 0x7fffffffu;
    return *seed;
}

static void unlink_slot(Cache *c, uint32_t s) {
    uint32_t p = c->prev[s], n = c->next[s];
    if (p == NONE) c->head = n; else c->next[p] = n;
    if (n == NONE) c->tail = p; else c->prev[n] = p;
}

static void append(Cache *c, uint32_t s) {
    c->prev[s] = c->tail;
    c->next[s] = NONE;
    if (c->tail == NONE) c->head = s; else c->next[c->tail] = s;
    c->tail = s;
}

static void move_to_end(Cache *c, uint32_t s) {
    if (s == c->tail) return;
    unlink_slot(c, s);
    append(c, s);
}

static void put(Cache *c, uint32_t key, uint32_t value) {
    khiter_t it = kh_get(slots, c->slot, key);
    if (it != kh_end(c->slot)) {
        uint32_t s = kh_value(c->slot, it);
        c->value[s] = value;
        move_to_end(c, s);
        return;
    }
    uint32_t s;
    if (c->len == c->size) {
        s = c->head;
        kh_del(slots, c->slot, kh_get(slots, c->slot, c->key[s]));
        unlink_slot(c, s);
    } else {
        s = c->len++;
    }
    c->key[s] = key;
    c->value[s] = value;
    int absent;
    kh_value(c->slot, kh_put(slots, c->slot, key, &absent)) = s;
    append(c, s);
}

static int get(Cache *c, uint32_t key) {
    khiter_t it = kh_get(slots, c->slot, key);
    if (it == kh_end(c->slot)) return 0;
    move_to_end(c, kh_value(c->slot, it));
    return 1;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    uint32_t size = argc > 1 ? atoi(argv[1]) : 100;
    long n = argc > 2 ? atol(argv[2]) : 10000;
    uint32_t modular = size * 10;
    Cache c = {malloc(size * 4), malloc(size * 4), malloc(size * 4), malloc(size * 4), NONE, NONE, 0, size, kh_init(slots)};
    kh_resize(slots, c.slot, 2 * size);
    uint32_t seed0 = 0, seed1 = 1;
    long hit = 0, missed = 0;
    for (long i = 0; i < n; i++) {
        uint32_t k0 = lcg(&seed0) % modular;
        put(&c, k0, k0);
        uint32_t k1 = lcg(&seed1) % modular;
        if (get(&c, k1)) hit++; else missed++;
    }
    printf("%ld\n%ld\n", hit, missed);
    return 0;
}
