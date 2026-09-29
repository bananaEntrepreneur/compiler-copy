const empty = "";
const simple = "hello world";
const escapes = "nl:\n tab:\t cr:\r quote:\" apos:\' backslash:\\ hex:\x41 uni:\u{1F4A9}";
const ends_with_escaped_quote = "trailing \"";
const escaped_backslash = "ends with a backslash \\";
const slashes = "// not a comment";
const doc_slashes = "/// not a doc comment";
const ml_marker = "a \\ backslash pair inside a string";
const two = "first" ++ "second";

const indented =
    \\first line
    \\second line
;

const unindented =
\\no indent here
\\still going
;

const with_blank =
    \\before
    \\
    \\after
;

const ml_contents =
    \\has "quotes" and // slashes and \n literal backslash-n
;

const after_ml = "back to normal";
