// plain single-line comment
//
/// doc comment
//! top-level doc comment
//// four slashes is a normal comment in Zig
///// five slashes too
// comment with "double quotes" inside
// comment with 'apostrophes' and don't
// comment with a \\ backslash pair
const after = "// not a comment";
const doc = "/// also not a comment";
const x = 1; // trailing comment after code
// last line, no trailing newline