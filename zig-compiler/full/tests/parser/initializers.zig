const typed = Point{ .x = 1, .y = 2 };
const anonymous = .{ .x = 1, .y = 2 };
const tuple = .{ 1, "two", '3' };
const array = [_]u8{ 1, 2, 3 };
const empty = Point{};
const color = .red;
const failure = error.NotFound;
const builtin = @as(u32, 5);
const text =
    \\first
    \\second
;
const constants = .{ true, false, null, undefined, 1.5, 0x10 };
