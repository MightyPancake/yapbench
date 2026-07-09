const std = @import("std");

// splitmix64 (public domain, Vigna), same generator as the lcs/histogram
// benchmarks -- reused here as the hash function itself, not just for data
// generation.
fn splitmix64(x_in: u64) u64 {
    var x = x_in;
    x +%= 0x9E3779B97F4A7C15;
    x = (x ^ (x >> 30)) *% 0xBF58476D1CE4E5B9;
    x = (x ^ (x >> 27)) *% 0x94D049BB133111EB;
    x = x ^ (x >> 31);
    return x;
}

// Hand-rolled open addressing (linear probing) hash table, fixed capacity
// (no growth) sized upfront from n at a <=50% load factor -- see hashmap.c
// for the full rationale, identical across all 4 languages.
const Map = struct {
    keys: []i64,
    values: []u64,
    mask: i32,
};

fn nextCap(n: i32) i32 {
    var cap: i32 = 16;
    while (cap < 2 * n) : (cap *= 2) {}
    return cap;
}

fn mapInit(allocator: std.mem.Allocator, n: i32) !Map {
    const cap = nextCap(n);
    const keys = try allocator.alloc(i64, @intCast(cap));
    const values = try allocator.alloc(u64, @intCast(cap));
    for (keys) |*k| k.* = -1;
    return Map{ .keys = keys, .values = values, .mask = cap - 1 };
}

fn mapInsert(m: *Map, key: i64, value: u64) void {
    var idx: i32 = @intCast(splitmix64(@intCast(key)) & @as(u64, @intCast(m.mask)));
    while (m.keys[@intCast(idx)] != -1) {
        if (m.keys[@intCast(idx)] == key) {
            m.values[@intCast(idx)] = value;
            return;
        }
        idx = (idx + 1) & m.mask;
    }
    m.keys[@intCast(idx)] = key;
    m.values[@intCast(idx)] = value;
}

fn mapLookup(m: *Map, key: i64, out: *u64) bool {
    var idx: i32 = @intCast(splitmix64(@intCast(key)) & @as(u64, @intCast(m.mask)));
    while (m.keys[@intCast(idx)] != -1) {
        if (m.keys[@intCast(idx)] == key) {
            out.* = m.values[@intCast(idx)];
            return true;
        }
        idx = (idx + 1) & m.mask;
    }
    return false;
}

fn mapFree(allocator: std.mem.Allocator, m: *Map) void {
    allocator.free(m.keys);
    allocator.free(m.values);
}

pub fn main(init: std.process.Init) !void {
    var it = init.minimal.args.iterate();
    _ = it.skip(); // program name

    const n_str = it.next() orelse {
        std.debug.print("Usage: hashmap <n>\n", .{});
        std.process.exit(1);
    };

    const n = try std.fmt.parseInt(i32, n_str, 10);

    var buf: [32]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buf);

    if (n <= 0) {
        try stdout.interface.print("{d}\n", .{@as(u64, 0)});
        try stdout.interface.flush();
        return;
    }

    const allocator = std.heap.page_allocator;
    var m = try mapInit(allocator, n);

    var i: i32 = 0;
    while (i < n) : (i += 1) {
        mapInsert(&m, @intCast(i), splitmix64(@intCast(i + 1)));
    }

    var sum: u64 = 0;
    i = 0;
    while (i < n) : (i += 1) {
        var val: u64 = 0;
        _ = mapLookup(&m, @intCast(i), &val);
        sum +%= val *% @as(u64, @intCast(i + 1));
    }

    var miss_count: u64 = 0;
    i = n;
    while (i < 2 * n) : (i += 1) {
        var val: u64 = 0;
        if (!mapLookup(&m, @intCast(i), &val)) miss_count += 1;
    }

    sum +%= miss_count *% 1000000007;
    mapFree(allocator, &m);

    try stdout.interface.print("{d}\n", .{sum});
    try stdout.interface.flush();
}
