fn empty() void {}

pub fn add(comptime T: type, x: T, y: T) T {
    return x + y;
}

fn read(noalias buffer: []u8, value: anytype) !usize {
    return buffer.len;
}

extern "c" fn printf(format: [*:0]const u8, ...) c_int;

export fn callback(code: i32) callconv(.c) void {}

inline fn fail() error{Oops}!void {
    return error.Oops;
}

const Handler = *const fn (u32, ?*anyopaque) bool;
