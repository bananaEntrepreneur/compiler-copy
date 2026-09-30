const b = #;
const bad_str = "unterminated
const bad_char = 'ab';
const empty_char = '';
const no_close = 'x;
const bad_quoted = @"unclosed
const str_tab = "a	b";
const char_tab = '	';
const x = 1; // comment	tab
const ml_tab =
    \\a	b
;
const at_eof = "runs into EOF