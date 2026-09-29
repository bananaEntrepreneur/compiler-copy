%option noyywrap yylineno

%x MLSTR STR CHR QIDENT

%{
#include <iostream>
#include <string>
#include <cstdlib>

    /* Like the Zig compiler, the rules below only cut the source into tokens, */
    /* as std.zig.Tokenizer does. Whether a literal is valid, and its value,   */
    /* is decided by ports of std.zig.number_literal, std.zig.string_literal   */
    /* and the checks AstGen makes. A token with an error is not printed.      */

static std::string ml;       // multiline string literal being collected
static int ml_line;
static bool ml_error;        // an error was already reported for it

static std::string literal;  // source text of a quoted literal, quotes included
static int literal_line;
static bool literal_error;   // an error was already reported for it

static void report(int line, const std::string& message);
static std::string char_escape(unsigned long c);
static bool is_invalid_byte(unsigned char c);

static void literal_begin(const char* quote);
static void literal_fail(const std::string& message);
static void literal_end(int state);
static const char* literal_kind(int state);

static void multiline_line(const char* text);
static void comment(const char* text, int length);
static void number(const char* text);
static void integer_type(const char* text);
%}

    /* The bytes a std.zig.Tokenizer literal state rejects: controls except '\n' */

INVALID [\0\x01-\x09\x0b-\x1f\x7f]

    /* A number token, as the tokenizer reads it: a digit, then letters, digits, */
    /* '_', a sign right after e/E/p/P, and one '.' that is not after a sign.    */
    /* What the token means is decided by number().                              */

NUMTAIL ([_a-zA-Z0-9]|[eEpP][+-])*
NUMBER [0-9][_a-zA-Z0-9]*([eEpP][+-]{NUMTAIL}|\.([_a-zA-Z0-9]|[eEpP][+-]){NUMTAIL})?

%%

    /* Comment. Match any comment. Anyway, they will be deleted by parser. */

"//"[^\n]* { comment(yytext, yyleng); }

    /* Character literal, string literal and quoted identifier: collect the */
    /* source text up to the closing quote and parse it there.              */

' { literal_begin("'"); BEGIN(CHR); }

\" { literal_begin("\""); BEGIN(STR); }

    /* Quoted identifier. Backslash and escape sequences can be used - it will be just an id. */

@\" { literal_begin("\""); BEGIN(QIDENT); }

<CHR>[^\\'\n\0\x01-\x09\x0b-\x1f\x7f]+ { literal += yytext; }

<STR,QIDENT>[^\\"\n\0\x01-\x09\x0b-\x1f\x7f]+ { literal += yytext; }

    /* A backslash keeps the next byte, so \' and \" do not close the literal. */
    /* A backslash before a newline or an invalid byte is left to their rules. */

<CHR,STR,QIDENT>\\[^\n\0\x01-\x09\x0b-\x1f\x7f] { literal += yytext; }

<CHR,STR,QIDENT>\\ { literal += yytext; }

<CHR,STR,QIDENT>{INVALID} {
    literal_fail(std::string(literal_kind(YY_START)) + " contains invalid byte: '" + char_escape((unsigned char)yytext[0]) + "'");
}

<CHR>' { literal += yytext; literal_end(CHR); BEGIN(INITIAL); }

<STR,QIDENT>\" { literal += yytext; literal_end(YY_START); BEGIN(INITIAL); }

    /* No closing delimiter before the line or the file ends */

<CHR,STR,QIDENT>\n { literal_fail(std::string("unterminated ") + literal_kind(YY_START)); BEGIN(INITIAL); }

<CHR,STR,QIDENT><<EOF>> { literal_fail(std::string("unterminated ") + literal_kind(YY_START)); BEGIN(INITIAL); }

    /* Multiline string. Extra \n between last line and ';' don't count. */

\\\\ { ml.clear(); ml_line = yylineno; ml_error = false; BEGIN(MLSTR); }

<MLSTR>[^\r\n]+ { multiline_line(yytext); }

<MLSTR>\r?\n[ \t]*\\\\ { ml += '\n'; } // Может быть несколько пустых строчек между многострочными строчками

    /* A '\r' is only allowed right before '\n' */

<MLSTR>\r { multiline_line(yytext); }

<MLSTR>\r?\n {
    if (!ml_error) {
        std::cout << "Multiline string literal: " << ml << '\n';
    }

    BEGIN(INITIAL);
}

<MLSTR><<EOF>> {
    if (!ml_error) {
        std::cout << "Multiline string literal: " << ml << '\n';
    }

    BEGIN(INITIAL);
}

    /* Numbers: one token as std.zig.Tokenizer cuts it, then checked by number() */

{NUMBER} { number(yytext); }

    /* Keywords */

"addrspace" { std::cout << "Keyword: " << yytext << '\n'; }
"align" { std::cout << "Keyword: " << yytext << '\n'; }
"allowzero" { std::cout << "Keyword: " << yytext << '\n'; }
"and" { std::cout << "Keyword: " << yytext << '\n'; }
"anyframe" { std::cout << "Keyword: " << yytext << '\n'; }
"anytype" { std::cout << "Keyword: " << yytext << '\n'; }
"asm" { std::cout << "Keyword: " << yytext << '\n'; }
"break" { std::cout << "Keyword: " << yytext << '\n'; }
"callconv" { std::cout << "Keyword: " << yytext << '\n'; }
"catch" { std::cout << "Keyword: " << yytext << '\n'; }
"comptime" { std::cout << "Keyword: " << yytext << '\n'; }
"const" { std::cout << "Keyword: " << yytext << '\n'; }
"continue" { std::cout << "Keyword: " << yytext << '\n'; }
"defer" { std::cout << "Keyword: " << yytext << '\n'; }
"else" { std::cout << "Keyword: " << yytext << '\n'; }
"enum" { std::cout << "Keyword: " << yytext << '\n'; }
"errdefer" { std::cout << "Keyword: " << yytext << '\n'; }
"error" { std::cout << "Keyword: " << yytext << '\n'; }
"export" { std::cout << "Keyword: " << yytext << '\n'; }
"extern" { std::cout << "Keyword: " << yytext << '\n'; }
"fn" { std::cout << "Keyword: " << yytext << '\n'; }
"for" { std::cout << "Keyword: " << yytext << '\n'; }
"if" { std::cout << "Keyword: " << yytext << '\n'; }
"inline" { std::cout << "Keyword: " << yytext << '\n'; }
"linksection" { std::cout << "Keyword: " << yytext << '\n'; }
"noalias" { std::cout << "Keyword: " << yytext << '\n'; }
"noinline" { std::cout << "Keyword: " << yytext << '\n'; }
"nosuspend" { std::cout << "Keyword: " << yytext << '\n'; }
"opaque" { std::cout << "Keyword: " << yytext << '\n'; }
"or" { std::cout << "Keyword: " << yytext << '\n'; }
"orelse" { std::cout << "Keyword: " << yytext << '\n'; }
"packed" { std::cout << "Keyword: " << yytext << '\n'; }
"pub" { std::cout << "Keyword: " << yytext << '\n'; }
"resume" { std::cout << "Keyword: " << yytext << '\n'; }
"return" { std::cout << "Keyword: " << yytext << '\n'; }
"struct" { std::cout << "Keyword: " << yytext << '\n'; }
"suspend" { std::cout << "Keyword: " << yytext << '\n'; }
"switch" { std::cout << "Keyword: " << yytext << '\n'; }
"test" { std::cout << "Keyword: " << yytext << '\n'; }
"threadlocal" { std::cout << "Keyword: " << yytext << '\n'; }
"try" { std::cout << "Keyword: " << yytext << '\n'; }
"union" { std::cout << "Keyword: " << yytext << '\n'; }
"unreachable" { std::cout << "Keyword: " << yytext << '\n'; }
"var" { std::cout << "Keyword: " << yytext << '\n'; }
"volatile" { std::cout << "Keyword: " << yytext << '\n'; }
"while" { std::cout << "Keyword: " << yytext << '\n'; }
"null" { std::cout << "Null literal: " << yytext << '\n'; }
"undefined" { std::cout << "Constant: " << yytext << '\n'; }

    /* Constants */

"true" { std::cout << "Boolean literal(true): " << 1 << '\n'; }
"false" { std::cout << "Boolean literal(false): " << 0 << '\n'; }


    /* Integer types. Checked by integer_type(), as AstGen does: bit count up to 65535, no leading zero. */

[iu][0-9]+ { integer_type(yytext); }

    /* Float types */

f16 { std::cout << "Float type: " << yytext << '\n'; }
f32 { std::cout << "Float type: " << yytext << '\n'; }
f64 { std::cout << "Float type: " << yytext << '\n'; }
f80 { std::cout << "Float type: " << yytext << '\n'; }
f128 { std::cout << "Float type: " << yytext << '\n'; }

    /* Other primitive types */

"bool" { std::cout << "Bool type: " << yytext << '\n'; }
"void" { std::cout << "Void type: " << yytext << '\n'; }
"noreturn" { std::cout << "Noreturn type: " << yytext << '\n'; }
"type" { std::cout << "Type: " << yytext << '\n'; }
"anyerror" { std::cout << "Anyerror type: " << yytext << '\n'; }
"anyopaque" { std::cout << "Anyopaque type: " << yytext << '\n'; }
"comptime_int" { std::cout << "Comptime int type: " << yytext << '\n'; }
"comptime_float" { std::cout << "Comptime float type: " << yytext << '\n'; }

    /* Pointer-sized types */

"usize" { std::cout << "Usize type: " << yytext << '\n'; }
"isize" { std::cout << "Isize type: " << yytext << '\n'; }

    /* C-compatible types */

"c_char" { std::cout << "C char type: " << yytext << '\n'; }
"c_short" { std::cout << "C short type: " << yytext << '\n'; }
"c_ushort" { std::cout << "C ushort type: " << yytext << '\n'; }
"c_int" { std::cout << "C int type: " << yytext << '\n'; }
"c_uint" { std::cout << "C uint type: " << yytext << '\n'; }
"c_long" { std::cout << "C long type: " << yytext << '\n'; }
"c_ulong" { std::cout << "C ulong type: " << yytext << '\n'; }
"c_longlong" { std::cout << "C longlong type: " << yytext << '\n'; }
"c_ulonglong" { std::cout << "C ulonglong type: " << yytext << '\n'; }
"c_longdouble" { std::cout << "C longdouble type: " << yytext << '\n'; }

    /* Identifiers */

[A-Za-z_][A-Za-z0-9_]* { std::cout << "Identifier: " << yytext << '\n'; }

    /* Builtin identifiers. Lexer allows any identifier, but later only implecated functions will be allowed  */

@[a-zA-Z_][a-zA-Z0-9_]* { std::cout << "Builtin identifier: " << yytext << '\n'; }

    /* Punctuators */

"[" { std::cout << "Punctuator: " << yytext << '\n'; }
"]" { std::cout << "Punctuator: " << yytext << '\n'; }
"{" { std::cout << "Punctuator: " << yytext << '\n'; }
"}" { std::cout << "Punctuator: " << yytext << '\n'; }
"(" { std::cout << "Punctuator: " << yytext << '\n'; }
")" { std::cout << "Punctuator: " << yytext << '\n'; }

    /* Separators */

"," { std::cout << "Separator: " << yytext << '\n'; }
":" { std::cout << "Separator: " << yytext << '\n'; }
";" { std::cout << "Semicolon: " << yytext << '\n'; }

    /* Operators (array) */

"++" { std::cout << "Operator (array concat): " << yytext << '\n'; }
"**" { std::cout << "Operator (array repeat): " << yytext << '\n'; }

    /* Operators (arithmetic) */

"+" { std::cout << "Operator (arithmetic): " << yytext << '\n'; }
"-" { std::cout << "Operator (arithmetic): " << yytext << '\n'; }
"*" { std::cout << "Operator (arithmetic): " << yytext << '\n'; }
"/" { std::cout << "Operator (arithmetic): " << yytext << '\n'; }
"%" { std::cout << "Operator (arithmetic): " << yytext << '\n'; }

    /* Wrapping (%) and saturating (|) operators */

"+%" { std::cout << "Operator (wrapping): " << yytext << '\n'; }
"-%" { std::cout << "Operator (wrapping): " << yytext << '\n'; }
"*%" { std::cout << "Operator (wrapping): " << yytext << '\n'; }
"+|" { std::cout << "Operator (saturating): " << yytext << '\n'; }
"-|" { std::cout << "Operator (saturating): " << yytext << '\n'; }
"*|" { std::cout << "Operator (saturating): " << yytext << '\n'; }
"<<|" { std::cout << "Operator (saturating): " << yytext << '\n'; }

    /* Operators (comparison) */

"==" { std::cout << "Operator (comparison): " << yytext << '\n'; }
"!=" { std::cout << "Operator (comparison): " << yytext << '\n'; }
"<=" { std::cout << "Operator (comparison): " << yytext << '\n'; }
">=" { std::cout << "Operator (comparison): " << yytext << '\n'; }
"<" { std::cout << "Operator (comparison): " << yytext << '\n'; }
">" { std::cout << "Operator (comparison): " << yytext << '\n'; }

    /* Operators (logical) */

"!" { std::cout << "Operator (logical): " << yytext << '\n'; }

    /* Operators (bitwise) */

"<<" { std::cout << "Operator (bitwise): " << yytext << '\n'; }
">>" { std::cout << "Operator (bitwise): " << yytext << '\n'; }
"&" { std::cout << "Operator (bitwise): " << yytext << '\n'; }
"|" { std::cout << "Operator (bitwise): " << yytext << '\n'; }
"^" { std::cout << "Operator (bitwise): " << yytext << '\n'; }
"~" { std::cout << "Operator (bitwise): " << yytext << '\n'; }

    /* Operators (assignment) */

"<<=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
">>=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"+=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"-=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"*=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"/=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"%=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"&=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"|=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"^=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"+%=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"-%=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"*%=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"+|=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"-|=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"*|=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"<<|=" { std::cout << "Operator (assignment): " << yytext << '\n'; }
"=" { std::cout << "Operator (assignment): " << yytext << '\n'; }

    /* Operators (other) */

".*" { std::cout << "Operator (struct deref): " << yytext << '\n'; }
".?" { std::cout << "Operator (optional unwrap): " << yytext << '\n'; }
"..." { std::cout << "Operator (range): " << yytext << '\n'; }
".." { std::cout << "Operator (range): " << yytext << '\n'; }
"=>" { std::cout << "Operator (switch prong): " << yytext << '\n'; }
"->" { std::cout << "Operator (arrow): " << yytext << '\n'; }
"||" { std::cout << "Operator (error set merge): " << yytext << '\n'; }
"." { std::cout << "Operator (member): " << yytext << '\n'; }
"?" { std::cout << "Operator (optional): " << yytext << '\n'; }

[ \t\r\n]+ { /* ignored */ }

    /* Errors */

. { report(yylineno, "unexpected character: '" + char_escape((unsigned char)yytext[0]) + "'"); }

%%

/*! Print an error in the format "error: <message> in line: <line>".
 *  \param[in] line    source line of the token.
 *  \param[in] message what is wrong, worded as the Zig compiler words it.
 */
static void report(int line, const std::string& message) {
    std::cerr << "error: " << message << " in line: " << line << '\n';
}

/*! Port of std.zig.charEscape: show a byte or code point as Zig source.
 *  \param[in] c byte or code point.
 *  \return c itself when printable ASCII, else an escape such as \t or \x01.
 */
static std::string char_escape(unsigned long c) {
    static const char* hex = "0123456789abcdef";

    switch (c) {
        case '\n': return "\\n";
        case '\r': return "\\r";
        case '\t': return "\\t";
        case '\\': return "\\\\";
        case '\'': return "\\'";
    }

    if (c >= ' ' && c <= '~') {
        return std::string(1, (char)c);
    }

    if (c <= 0xFF) {
        return std::string("\\x") + hex[c >> 4] + hex[c & 0xF];
    }

    std::string digits;

    for (; c != 0; c >>= 4) {
        digits.insert(digits.begin(), hex[c & 0xF]);
    }

    return "\\u{" + digits + "}";
}

/*! Whether std.zig.Tokenizer rejects a byte inside a literal or comment:
 *  NUL and control characters other than '\n'.
 */
static bool is_invalid_byte(unsigned char c) {
    return (c < 0x20 && c != '\n') || c == 0x7F;
}

/*! Name the literal a start condition is scanning, for error messages.
 *  \param[in] state current start condition, normally YY_START.
 *  \return name of the literal kind; string literal for anything but
 *          CHR and QIDENT.
 */
static const char* literal_kind(int state) {
    switch (state) {
        case CHR:    return "character literal";
        case QIDENT: return "quoted identifier";
        default:     return "string literal";
    }
}

/* ---- Quoted literals: port of std.zig.string_literal ---- */

static std::string found(const char* expected, char c) {
    return std::string(expected) + ", found '" + c + "'";
}

static int hex_digit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static const char* const bad_code_point = "unicode escape does not correspond to a valid unicode scalar value";

/*! Port of std.zig.string_literal.parseEscapeSequence.
 *  \param[in]     s      literal text, quotes included, so the closing
 *                        quote always follows the escape.
 *  \param[in,out] offset index of the backslash; moved past the escape.
 *  \param[out]    value  code point of the escape (a byte for \xNN).
 *  \return error message, empty on success.
 */
static std::string parse_escape(const std::string& s, size_t& offset, unsigned long& value) {
    offset += 2;
    char c = s[offset - 1];

    switch (c) {
        case 'n':  value = '\n'; return "";
        case 'r':  value = '\r'; return "";
        case 't':  value = '\t'; return "";
        case '\\': case '\'': case '"': value = (unsigned char)c; return "";

        case 'x':
            value = 0;

            for (size_t i = offset; i < offset + 2; ++i) {
                if (hex_digit(s[i]) < 0) {
                    return found("expected hex digit", s[i]);
                }

                value = value * 16 + hex_digit(s[i]);
            }

            offset += 2;
            return "";

        case 'u': {
            size_t i = offset;

            if (s[i] != '{') {
                return found("expected '{'", s[i]);
            }

            if (s[++i] == '}') {
                return "empty unicode escape sequence";
            }

            for (value = 0; s[i] != '}'; ++i) {
                if (hex_digit(s[i]) < 0) {
                    return found("expected hex digit or '}'", s[i]);
                }

                value = value * 16 + hex_digit(s[i]);

                if (value > 0x10FFFF) {
                    return bad_code_point;
                }
            }

            offset = i + 1;
            return "";
        }
    }

    return std::string("invalid escape character: '") + c + "'";
}

/*! Append a code point encoded as UTF-8 (surrogates too, as WTF-8).
 *  \param[in,out] out destination.
 *  \param[in]     cp  code point, at most U+10FFFF.
 */
static void append_utf8(std::string& out, unsigned long cp) {
    if (cp < 0x80) {
        out += (char)cp;
    } else if (cp < 0x800) {
        out += (char)(0xC0 | (cp >> 6));
        out += (char)(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += (char)(0xE0 | (cp >> 12));
        out += (char)(0x80 | ((cp >> 6) & 0x3F));
        out += (char)(0x80 | (cp & 0x3F));
    } else {
        out += (char)(0xF0 | (cp >> 18));
        out += (char)(0x80 | ((cp >> 12) & 0x3F));
        out += (char)(0x80 | ((cp >> 6) & 0x3F));
        out += (char)(0x80 | (cp & 0x3F));
    }
}

static bool is_surrogate(unsigned long cp) {
    return cp >= 0xD800 && cp <= 0xDFFF;
}

/*! Port of std.zig.string_literal.parseWrite.
 *  \param[in]  s   string literal text, quotes included.
 *  \param[out] out the bytes of the string.
 *  \return error message, empty on success.
 */
static std::string parse_string(const std::string& s, std::string& out) {
    for (size_t i = 1; s[i] != '"';) {
        if (s[i] != '\\') {
            out += s[i++];
            continue;
        }

        bool unicode = s[i + 1] == 'u';
        unsigned long value;
        std::string error = parse_escape(s, i, value);

        if (!error.empty()) {
            return error;
        }

        if (!unicode) {
            out += (char)value;
        } else if (is_surrogate(value)) {
            return bad_code_point; // utf8Encode refuses surrogates
        } else {
            append_utf8(out, value);
        }
    }

    return "";
}

/*! Port of std.unicode.utf8Decode for one sequence of the given length:
 *  rejects bad continuation bytes, overlong forms, surrogates and values
 *  above U+10FFFF.
 *  \return the code point, or -1 when the bytes are not valid UTF-8.
 */
static long utf8_decode(const std::string& b) {
    static const unsigned long min[] = { 0, 0, 0x80, 0x800, 0x10000 };
    static const unsigned char lead_bits[] = { 0, 0x7F, 0x1F, 0x0F, 0x07 };
    size_t n = b.size();
    unsigned long cp = (unsigned char)b[0] & lead_bits[n];

    for (size_t i = 1; i < n; ++i) {
        if (((unsigned char)b[i] & 0xC0) != 0x80) {
            return -1;
        }

        cp = (cp << 6) | ((unsigned char)b[i] & 0x3F);
    }

    if (n > 1 && (cp < min[n] || cp > 0x10FFFF || is_surrogate(cp))) {
        return -1;
    }

    return (long)cp;
}

/*! Port of std.zig.string_literal.parseCharLiteral: one escape or one
 *  UTF-8 encoded code point.
 *  \param[in]  s     character literal text, quotes included.
 *  \param[out] value its code point.
 *  \return error message, empty on success.
 */
static std::string parse_char(const std::string& s, unsigned long& value) {
    if (s.size() < 3) {
        return "empty character literal";
    }

    if (s[1] == '\\') {
        size_t offset = 1;
        std::string error = parse_escape(s, offset, value);

        if (error.empty() && offset + 1 != s.size()) {
            return found("expected single quote (')", s[offset]);
        }

        return error;
    }

    std::string inner = s.substr(1, s.size() - 2);
    unsigned char lead = inner[0];
    size_t n = lead < 0x80 ? 1 : (lead & 0xE0) == 0xC0 ? 2 : (lead & 0xF0) == 0xE0 ? 3 : (lead & 0xF8) == 0xF0 ? 4 : 0;

    if (n == 0) {
        return bad_code_point;
    }

    if (inner.size() > n) {
        return found("expected single quote (')", inner[n]);
    }

    long cp = inner.size() == n ? utf8_decode(inner) : -1;

    if (cp < 0) {
        return bad_code_point;
    }

    value = (unsigned long)cp;
    return "";
}

static void literal_begin(const char* quote) {
    literal = quote;
    literal_line = yylineno;
    literal_error = false;
}

/*! Report an error for the current literal. Like the compiler, only the
 *  first error of a literal is reported, and the literal is not printed.
 */
static void literal_fail(const std::string& message) {
    if (!literal_error) {
        report(literal_line, message);
        literal_error = true;
    }
}

/*! Parse a closed literal and print it, as AstGen would read it.
 *  \param[in] state the start condition that scanned it: CHR, STR or QIDENT.
 */
static void literal_end(int state) {
    if (literal_error) {
        return;
    }

    std::string error;

    if (state == CHR) {
        unsigned long value;
        error = parse_char(literal, value);

        if (error.empty()) {
            // A surrogate is a valid character value, but has no UTF-8 form
            std::string text;

            if (is_surrogate(value)) {
                text = char_escape(value);
            } else {
                append_utf8(text, value);
            }

            std::cout << "Char literal: " << text << '\n';
        }
    } else {
        std::string text;
        error = parse_string(literal, text);

        if (!error.empty()) {
            // reported below
        } else if (state == STR) {
            std::cout << "String literal: " << text << '\n';
        } else if (text.empty()) {
            error = "identifier cannot be empty";
        } else if (text.find('\0') != std::string::npos) {
            error = "identifier cannot contain null bytes";
        } else {
            std::cout << "Quoted identifier: " << text << '\n';
        }
    }

    if (!error.empty()) {
        literal_fail(error);
    }
}

/* ---- Multiline strings and comments ---- */

/*! Add one line of a multiline string literal, rejecting the bytes the
 *  tokenizer rejects (a '\r' reaches here only when no '\n' follows it).
 */
static void multiline_line(const char* text) {
    for (const char* p = text; *p; ++p) {
        if (is_invalid_byte((unsigned char)*p) && !ml_error) {
            report(yylineno, "string literal contains invalid byte: '" + char_escape((unsigned char)*p) + "'");
            ml_error = true;
        }
    }

    ml += text;
}

/*! Print a comment, or report the first byte the tokenizer rejects in it.
 *  A '\r' is allowed only as part of a "\r\n" line end.
 */
static void comment(const char* text, int length) {
    if (length > 2 && text[length - 1] == '\r') {
        --length;
    }

    for (int i = 2; i < length; ++i) {
        if (is_invalid_byte((unsigned char)text[i])) {
            report(yylineno, "comment contains invalid byte: '" + char_escape((unsigned char)text[i]) + "'");
            return;
        }
    }

    std::cout << "Comment: " << std::string(text, length) << '\n';
}

/* ---- Numbers: port of std.zig.number_literal and AstGen checks ---- */

/*! Port of std.zig.number_literal.parseNumberLiteral, with the messages
 *  of AstGen.failWithNumberError.
 *  \param[in]  s     the number token.
 *  \param[out] base  2, 8, 10 or 16.
 *  \param[out] is_float whether it is a float literal.
 *  \return error message, empty on success.
 */
static std::string parse_number(const std::string& s, int& base, bool& is_float) {
    static const char* base_name[17] = {};
    base_name[2] = "binary"; base_name[8] = "octal"; base_name[10] = "decimal"; base_name[16] = "hex";

    size_t i = 0;
    base = 10;

    if (s.size() >= 2 && s[0] == '0') {
        switch (s[1]) {
            case 'b': base = 2; i = 2; break;
            case 'o': base = 8; i = 2; break;
            case 'x': base = 16; i = 2; break;
            case 'B': case 'O': case 'X': return "base prefix must be lowercase";
            case '.': case 'e': case 'E': break;
            default: return "number '" + s + "' has leading zero";
        }
    }

    if (s.size() == 2 && base != 10) {
        return "expected a digit after base prefix";
    }

    bool underscore = false, period = false, exponent = false, late_period = false;
    char special = 0;
    is_float = false;

    for (; i < s.size(); ++i) {
        char c = s[i];

        if (c == '_') {
            if ((i == 2 && base != 10) || special != 0) return "expected digit before digit separator";
            if (underscore) return "repeated digit separator";
            underscore = true;
            continue;
        }

        if (((c == 'e' || c == 'E') && base == 10) || ((c == 'p' || c == 'P') && base == 16)) {
            if (i == 2 && base == 16) return "expected a digit after base prefix";
            if (exponent) return "duplicate exponent";
            if (underscore) return "expected digit before exponent";
            is_float = true;
            special = c;
            exponent = true;
            continue;
        }

        if (c == '.') {
            // Zig looks only two bytes back, so it misses 1e5.0 and std.fmt.parseFloat
            // later fails on it; report that after the other checks
            if (exponent && s[i - 2] >= '0' && s[i - 2] <= '9') return "unexpected period after exponent";
            late_period = late_period || exponent;
            if (base != 10 && base != 16) return "invalid base for float literal";
            if (period) return "duplicate period";
            if (underscore) return "expected digit before '.'";
            is_float = true;
            period = true;
            special = c;
            continue;
        }

        if (c == '+' || c == '-') {
            // The tokenizer only takes a sign after e/E/p/P, so a rejected
            // sign follows the hex digit e
            if (special != 'p' && special != 'P' && !((special == 'e' || special == 'E') && base == 10)) {
                return std::string("sign '") + c + "' cannot follow digit '" + s[i - 1] + "' in hex base";
            }

            special = c;
            continue;
        }

        int digit = c >= '0' && c <= '9' ? c - '0'
                  : c >= 'a' && c <= 'z' ? c - 'a' + 10
                  : c >= 'A' && c <= 'Z' ? c - 'A' + 10 : 99;

        if (digit >= base) return std::string("invalid digit '") + c + "' for " + base_name[base] + " base";
        if (exponent && digit >= 10) return std::string("invalid digit '") + c + "' in exponent";

        underscore = false;
        special = 0;
    }

    if (underscore) return "trailing digit separator";
    if (special != 0) return std::string("expected digit after '") + s[s.size() - 2] + "'";

    if (late_period) return "unexpected period after exponent";

    // std.fmt.parseFloat needs a digit before the exponent: 0x.p1 has none
    if (is_float && base == 16 && (s[2] == '.' && (s.size() == 3 || s[3] == 'p' || s[3] == 'P'))) {
        return "expected a digit after base prefix";
    }

    return "";
}

static std::string strip_underscores(const char* text) {
    std::string digits;

    for (; *text; ++text) {
        if (*text != '_') {
            digits += *text;
        }
    }

    return digits;
}

/*! Convert integer digits to decimal. Zig comptime_int has no size limit,
 *  so neither has this.
 *  \param[in] digits digits without prefix and underscores.
 *  \param[in] base   2, 8, 10 or 16.
 *  \return the value in decimal.
 */
static std::string to_decimal(const std::string& digits, int base) {
    std::string value = "0"; // decimal digits, most significant first

    for (char c : digits) {
        int carry = hex_digit(c);

        for (size_t i = value.size(); i-- > 0;) {
            int d = (value[i] - '0') * base + carry;
            value[i] = (char)('0' + d % 10);
            carry = d / 10;
        }

        for (; carry != 0; carry /= 10) {
            value.insert(value.begin(), (char)('0' + carry % 10));
        }
    }

    return value;
}

/*! Check a number token and print it, or report why AstGen rejects it. */
static void number(const char* text) {
    static const char* int_label[17] = {};
    int_label[2] = "Binary integer literal"; int_label[8] = "Octal integer literal";
    int_label[10] = "Integer literal"; int_label[16] = "Hex integer literal";

    int base;
    bool is_float;
    std::string error = parse_number(text, base, is_float);

    if (!error.empty()) {
        report(yylineno, error);
        return;
    }

    std::string digits = strip_underscores(text);

    if (is_float) {
        // long double, like Zig's f128, has room for exponents far past double
        long double value = strtold(digits.c_str(), nullptr);
        std::cout << (base == 16 ? "Hex float literal: " : "Float literal: ") << value << '\n';
    } else {
        std::cout << int_label[base] << ": " << to_decimal(digits.substr(base == 10 ? 0 : 2), base) << '\n';
    }
}

/*! Print an integer type name, or report it as AstGen does: a bit count
 *  above 65535 or with a leading zero is an error, not an identifier.
 */
static void integer_type(const char* text) {
    std::string name = text;

    if (name.size() >= 3 && name[1] == '0') {
        report(yylineno, "primitive integer type '" + name + "' has leading zero");
    } else if (name.size() > 6 || strtoul(text + 1, nullptr, 10) > 65535) {
        report(yylineno, "primitive integer type '" + name + "' exceeds maximum bit width of 65535");
    } else {
        std::cout << (name[0] == 'u' ? "Unsigned" : "Signed") << " integer type: " << name << '\n';
    }
}

int main(int argc, char* argv[]) {
    extern FILE* yyin;

    if (argc < 2) {
        std::cerr << "Missing command line argument (source file path)!\n";
        return 1;
    }

    yyin = fopen(argv[1], "r");

    if (!yyin) {
        std::cout << "File was not found!\n";
        return 1;
    }

    yylex();

    fclose(yyin);
    return 0;
}
