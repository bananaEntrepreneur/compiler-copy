const a = 1;
const b = #;
const c = $x;
const d = `2`;
const ok_str = "fine";
const ok_char = 'a';
const ok_quoted = @"good";
const bad_str = "unterminated
const bad_char = 'ab';
const no_close = 'x;
const bad_quoted = @"unclosed
// don't touch apostrophes in comments
const in_str = "it's fine";
const at_eof = "runs into EOF