const a = 1;
var b: u32 = 2;
pub const c: [4]u8 align(4) = undefined;
extern "c" var errno: c_int;
export var counter: usize = 0;
pub extern threadlocal var shared: i32;
var placed: u8 linksection(".data") = 0;

test "addition" {}
test a {}
test {}

comptime {}
