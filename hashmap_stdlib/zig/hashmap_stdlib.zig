const std = @import("std");

// Hash table insert/lookup throughput, integer-keyed -- "idiomatic
// generic-container" tier (see ../../hashmap/ for the hand-rolled
// fixed-capacity tier this pairs with). Uses std.AutoHashMap(K, V)
// out of the box, no ensureTotalCapacity call -- the plain first-cut
// usage any Zig tutorial shows, matching yap's modules/hashmap sibling
// (../../hashmap_stdlib/yap/), which has no capacity-hint API at all.
fn splitmix64(x_in: u64) u64 {
    var x = x_in;
    x +%= 0x9E3779B97F4A7C15;
    x = (x ^ (x >> 30)) *% 0xBF58476D1CE4E5B9;
    x = (x ^ (x >> 27)) *% 0x94D049BB133111EB;
    x = x ^ (x >> 31);
    return x;
}

pub fn main(init: std.process.Init) !void {
    var it = init.minimal.args.iterate();
    _ = it.skip(); // program name

    const n_str = it.next() orelse {
        std.debug.print("Usage: hashmap_stdlib <n>\n", .{});
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
    var map = std.AutoHashMap(i64, u64).init(allocator);
    defer map.deinit();

    var i: i32 = 0;
    while (i < n) : (i += 1) {
        try map.put(@intCast(i), splitmix64(@intCast(i + 1)));
    }

    var sum: u64 = 0;
    i = 0;
    while (i < n) : (i += 1) {
        if (map.get(@intCast(i))) |val| {
            sum +%= val *% @as(u64, @intCast(i + 1));
        }
    }

    var miss_count: u64 = 0;
    i = n;
    while (i < 2 * n) : (i += 1) {
        if (map.get(@intCast(i)) == null) miss_count += 1;
    }

    sum +%= miss_count *% 1000000007;

    try stdout.interface.print("{d}\n", .{sum});
    try stdout.interface.flush();
}
