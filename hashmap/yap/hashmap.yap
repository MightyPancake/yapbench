/*
 * Hash table insert/lookup throughput, integer-keyed. Uses modules/hashmap
 * (generic hashmap(K, V), vendored Robin Hood open addressing) instead of
 * hand-rolling a table -- this benchmark is the reason that module was
 * built in the first place (problems.md #8).
 *
 * n keys (0..n-1) are inserted with pseudo-random splitmix64-derived
 * values, then looked up -- successful lookups over the inserted range,
 * unsuccessful lookups over n..2n-1 -- into a single deterministic
 * checksum. The checksum depends only on put/get/has semantics (not on
 * bucket order or the specific hash function used), so it matches the
 * hand-rolled linear-probing table in the C/Nim/Zig siblings exactly even
 * though their hash function (a splitmix64-based probe) differs from this
 * module's own internal Robin Hood hashing.
 */
import io
import hashmap

u64 fn splitmix64(u64 x) {
    x = x + 0x9E3779B97F4A7C15;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EB;
    x = x ^ (x >> 31);
    ret x;
}

// io module has no u64 print helper (only print_i32, which would truncate
// our checksum -- checksums here exceed i32 range even for small n), same
// approach as the other benchmarks' print_u64.
none fn print_u64(u64 v) {
    if (v == 0) {
        io->print_char(48);
        ret;
    }
    i32[24] digits;
    i32 n = 0;
    while (v > 0) {
        u64 d = v % 10;
        digits[n] = d.(i32) + 48;
        v = v / 10;
        n = n + 1;
    }
    i32 i = n - 1;
    while (i >= 0) {
        io->print_char(digits[i]);
        i = i - 1;
    }
}

i32 fn main(byte@[] args) {
    byte@ n_str = args[1];
    i32 n = 0;
    i32 k = 0;
    while (n_str[k] != 0) {
        n = n * 10 + n_str[k].(i32) - 48;
        k = k + 1;
    }

    if (n <= 0) {
        print_u64(0);
        io->putchar(10);
        ret 0;
    }

    _ h = hashmap->new:(i64, u64);

    i32 i = 0;
    while (i < n) {
        h:put(i.(i64), splitmix64((i + 1).(u64)));
        i = i + 1;
    }

    u64 sum = 0;
    i = 0;
    while (i < n) {
        u64 val = h:get(i.(i64));
        sum = sum + val * (i + 1).(u64);
        i = i + 1;
    }

    u64 miss_count = 0;
    i = n;
    while (i < 2 * n) {
        if (!h:has(i.(i64))) {
            miss_count = miss_count + 1;
        }
        i = i + 1;
    }

    sum = sum + miss_count * 1000000007;
    h:free();

    print_u64(sum);
    io->putchar(10);
    ret 0;
}
