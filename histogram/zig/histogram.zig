const std = @import("std");

// splitmix64 (public domain, Vigna), same generator as the lcs benchmark,
// reduced mod 256 here for a full-byte-range (not small-alphabet)
// distribution.
fn splitmix64(x_in: u64) u64 {
    var x = x_in;
    x +%= 0x9E3779B97F4A7C15;
    x = (x ^ (x >> 30)) *% 0xBF58476D1CE4E5B9;
    x = (x ^ (x >> 27)) *% 0x94D049BB133111EB;
    x = x ^ (x >> 31);
    return x;
}

fn fill(buf: []u8, n: i32) void {
    var i: i32 = 0;
    while (i < n) : (i += 1) {
        const idx: u64 = @intCast(i + 1);
        buf[@intCast(i)] = @intCast(splitmix64(idx) % 256);
    }
}

fn histogram(buf: []const u8, counts: []u64) void {
    for (counts) |*c| c.* = 0;
    for (buf) |b| {
        counts[b] += 1;
    }
}

fn checksum(counts: []const u64) u64 {
    var sum: u64 = 0;
    for (counts, 0..) |c, b| {
        sum +%= c *% @as(u64, @intCast(b + 1));
    }
    return sum;
}

pub fn main(init: std.process.Init) !void {
    var it = init.minimal.args.iterate();
    _ = it.skip(); // program name

    const n_str = it.next() orelse {
        std.debug.print("Usage: histogram <n>\n", .{});
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
    const buffer = try allocator.alloc(u8, @intCast(n));
    defer allocator.free(buffer);

    var counts: [256]u64 = undefined;

    fill(buffer, n);
    histogram(buffer, &counts);
    const result = checksum(&counts);

    try stdout.interface.print("{d}\n", .{result});
    try stdout.interface.flush();
}
