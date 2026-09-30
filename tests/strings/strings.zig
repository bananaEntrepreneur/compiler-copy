const empty = "";
const simple = "hello world";
const escapes = "nl:\n tab:\t cr:\r quote:\" apos:\' backslash:\\ hex:\x41 uni:\u{42}";
const ends_with_escaped_quote = "trailing \"";
const escaped_backslash = "ends with a backslash \\";
const ml_marker = "a \\ backslash pair inside a string";

const indented =
    \\first line
    \\second line
;

const with_blank =
    \\before
    \\
    \\after
;

const ml_contents =
    \\has "quotes" and // slashes and \n literal backslash-n
;
