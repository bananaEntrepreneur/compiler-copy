const A = ?u8;
const B = *const u8;
const C = *align(4) volatile u32;
const D = **u8;
const E = []const u8;
const F = [:0]const u8;
const G = [*]u8;
const H = [*:0]u8;
const I = [*c]u8;
const J = [4]u8;
const K = [4:0]u8;
const L = anyerror!void;
const M = error{A}!?*u8;
const N = fn (a: u32) callconv(.c) void;
const O = struct {
    field: if (true) u8 else u16,
    optional: ?if (true) u8 else u16,
};
