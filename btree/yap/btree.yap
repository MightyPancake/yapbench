/*
 * Binary tree benchmark for YAP.
 * Usage: ./btree <n>
 * Builds a balanced binary tree of n nodes (heap-allocated via stdlib->malloc),
 * computes a deterministic checksum via in-order traversal, then post-order frees.
 */
import io
import stdlib

struct Node {
    i32 value,
    Node@ left,
    Node@ right,
}

u64 fn checksum(Node@ root) {
    if (root == null.(Node@)) {
        u64 zero = 0;
        ret zero;
    }
    u64 sum = checksum(root.left);
    u64 weight = (root.value + 1).(u64);
    sum = sum + weight * 2654435761;
    sum = sum + checksum(root.right);
    ret sum;
}

Node@ fn build(i32 lo, i32 hi) {
    if (lo > hi) {
        ret null.(Node@);
    }
    i32 mid = lo + (hi - lo) / 2;
    none@ raw = stdlib->malloc(24);  // sizeof(Node) = 4 + 8 + 8 = 20, round to 24
    Node@ n = raw.(Node@);
    n.value = mid;
    n.left = build(lo, mid - 1);
    n.right = build(mid + 1, hi);
    ret n;
}

none fn free_tree(Node@ root) {
    if (root == null.(Node@)) {
        ret;
    }
    free_tree(root.left);
    free_tree(root.right);
    none@ raw = root.(none@);
    stdlib->free(raw);
    ret;
}

// io module has no u64 print helper, so provide our own (same digit-buffer
// approach as the other benchmarks).
none fn print_u64(u64 v) {
    if (v == 0) {
        io->print_char(48);
        ret;
    }
    i32[24] digits;
    i32 n = 0;
    while (v > 0) {
        u64 d = v % 10;
        digits:[n] = d.(i32) + 48;
        v = v / 10;
        n = n + 1;
    }
    i32 i = n - 1;
    while (i >= 0) {
        io->print_char(digits:[i]);
        i = i - 1;
    }
}

i32 fn main(byte@[] args) {
    byte@ n_str = args:[1];
    i32 n = 0;
    i32 k = 0;
    while (n_str:[k] != 0) {
        n = n * 10 + n_str:[k].(i32) - 48;
        k = k + 1;
    }

    if (n <= 0) {
        io->print_i32(0);
        io->putchar(10);
        ret 0;
    }

    Node@ root = build(1, n);
    u64 ck = checksum(root);
    free_tree(root);

    print_u64(ck);
    io->putchar(10);
    ret 0;
}
