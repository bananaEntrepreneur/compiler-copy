const precedence = a or b and c == d | e << f + g * h;
const left = a - b - c;
const prefix = -a * !b.c;
const suffix = a.b[0].*.?(1, 2);
const error_union = try a catch |err| b orelse c;
const grouping = (a + b) * c;
const comparison = a + b < c;
const branch = if (a) b else c + 1;
const unwrap = a orelse return;
const handled = a catch |err| switch (err) {
    else => 0,
};
const tail = a orelse blk: {
    break :blk 1;
};
