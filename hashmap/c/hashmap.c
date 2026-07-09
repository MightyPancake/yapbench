#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

/*
 * Hash table insert/lookup throughput, integer-keyed. Hand-rolled open
 * addressing (linear probing) hash table, translated identically across
 * all 4 languages -- fixed capacity (no growth) sized upfront from n at a
 * <=50% load factor, so this measures probe-chain throughput rather than
 * resize behavior. Reuses the splitmix64 generator (public domain, Vigna)
 * from the histogram/lcs benchmarks, here as the hash function itself
 * rather than for data generation. Keys are 0..n-1 (guaranteed unique, so
 * no growth or delete logic is needed); -1 is the "empty slot" sentinel
 * since real keys here are always non-negative.
 *
 * The checksum only depends on put/get/has semantics (not on bucket
 * iteration order or the specific hash function used), so it stays
 * comparable against yap's sibling benchmark even though that one uses
 * modules/hashmap's vendored Robin Hood hashing instead of this file's
 * plain linear probing -- that module's existence is the whole reason
 * this benchmark could be added at all (problems.md #8).
 */
typedef struct {
    int64_t *keys;
    uint64_t *values;
    int32_t cap;
    int32_t mask;
} Map;

static uint64_t splitmix64(uint64_t x) {
    x += 0x9E3779B97F4A7C15ULL;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
    x = x ^ (x >> 31);
    return x;
}

static int32_t next_cap(int32_t n) {
    int32_t cap = 16;
    while (cap < 2 * n) cap *= 2;
    return cap;
}

static void map_init(Map *m, int32_t n) {
    m->cap = next_cap(n);
    m->mask = m->cap - 1;
    m->keys = malloc((size_t)m->cap * sizeof(int64_t));
    m->values = malloc((size_t)m->cap * sizeof(uint64_t));
    for (int32_t i = 0; i < m->cap; i++) m->keys[i] = -1;
}

static void map_insert(Map *m, int64_t key, uint64_t value) {
    int32_t idx = (int32_t)(splitmix64((uint64_t)key) & (uint64_t)m->mask);
    while (m->keys[idx] != -1) {
        if (m->keys[idx] == key) {
            m->values[idx] = value;
            return;
        }
        idx = (idx + 1) & m->mask;
    }
    m->keys[idx] = key;
    m->values[idx] = value;
}

static int map_lookup(Map *m, int64_t key, uint64_t *out) {
    int32_t idx = (int32_t)(splitmix64((uint64_t)key) & (uint64_t)m->mask);
    while (m->keys[idx] != -1) {
        if (m->keys[idx] == key) {
            *out = m->values[idx];
            return 1;
        }
        idx = (idx + 1) & m->mask;
    }
    return 0;
}

static void map_free(Map *m) {
    free(m->keys);
    free(m->values);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <n>\n", argv[0]);
        return 1;
    }
    int32_t n = (int32_t)strtol(argv[1], NULL, 10);

    if (n <= 0) {
        printf("%" PRIu64 "\n", (uint64_t)0);
        return 0;
    }

    Map m;
    map_init(&m, n);

    for (int32_t i = 0; i < n; i++) {
        map_insert(&m, (int64_t)i, splitmix64((uint64_t)(i + 1)));
    }

    uint64_t sum = 0;
    for (int32_t i = 0; i < n; i++) {
        uint64_t val = 0;
        map_lookup(&m, (int64_t)i, &val);
        sum += val * (uint64_t)(i + 1);
    }

    uint64_t miss_count = 0;
    for (int32_t i = n; i < 2 * n; i++) {
        uint64_t val = 0;
        if (!map_lookup(&m, (int64_t)i, &val)) miss_count++;
    }

    sum += miss_count * 1000000007ULL;
    map_free(&m);

    printf("%" PRIu64 "\n", sum);
    return 0;
}
