fn statements(items: []const u8) !void {
    var i: usize = 0;
    i += 1;
    const x, var y = pair();
    {
        defer i -= 1;
        errdefer |err| log(err);
    }

    if (i == 0) {
        return;
    } else if (items.len > 1) {
        i = 2;
    } else unreachable;

    if (find(items)) |index| use(index) else |err| return err;

    while (i < 10) : (i += 1) {
        continue;
    }

    outer: for (items, 0..) |item, index| {
        if (item == 0) break :outer;
        inline for (0..3) |_| use(index);
    }

    const value = blk: {
        break :blk x + y;
    };

    switch (value) {
        0, 1 => {},
        2...9 => |n| use(n),
        else => i = 0,
    }

    comptime assert(true);
}
