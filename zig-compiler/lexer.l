%option noyywrap yylineno

%x MLSTR STR CHR QIDENT

%{
#include <iostream>
#include <sstream>
#include <string>
#include <cstdlib>

#include "parser.hpp"

static std::string ml;
static std::string literal;
static int literal_line;

static unsigned long long int_value(const char* text, int base);
static double float_value(const char* text);
static const char* literal_type_from_condition(int condition);
static bool validate_int_size(const char* text);
void report(int line, const std::string& message);

bool print_tokens = false; // --tokens: print every lexeme, as in the first exercise
int error_count = 0;

    /* Every rule hands its own token to the parser. With --tokens it is also printed. */

#define TOKEN(token, output) do {                        \
        if (print_tokens) std::cout << output << '\n';   \
        return token;                                    \
    } while (0)

    /* The same, and the printed text becomes the token's semantic value: */
    /* the parser puts it in the tree as a leaf.                           */

#define VALUE(token, output) do {                        \
        std::ostringstream out;                          \
        out << output;                                   \
        if (print_tokens) std::cout << out.str() << '\n'; \
        yylval.text = new std::string(out.str());        \
        return token;                                    \
    } while (0)
%}

    /* Only DEC numbers can not start with zero */

DEC 0|[1-9](_?[0-9])*
HEX [0-9a-fA-F](_?[0-9a-fA-F])*
BIN [01](_?[01])*
OCT [0-7](_?[0-7])*

%%

    /* Comment. Match any comment. Anyway, they will be deleted by parser. */

"//"[^\r\n]* { if (print_tokens) std::cout << "Comment: " << yytext << '\n'; }

    /* Character literal */

' { literal.clear(); literal_line = yylineno; BEGIN(CHR); }

<CHR>[^\\'\n] { literal += yytext; }

<CHR>' {
    BEGIN(INITIAL);

    if (literal.size() == 1) {
        VALUE(CHAR_LITERAL, "Char literal: " << literal);
    }

    report(literal_line, "character literal must hold exactly one character");
}

    /* String literal */

\" { literal.clear(); literal_line = yylineno; BEGIN(STR); }

<STR,QIDENT>[^\\"\n]+ { literal += yytext; }

<STR>\" { BEGIN(INITIAL); VALUE(STRING_LITERAL, "String literal: " << literal); }

    /* Quoted identifier. Backslash and escape sequences can be used - it will be just an id. */

@\" { literal.clear(); literal_line = yylineno; BEGIN(QIDENT); }

<QIDENT>\" { BEGIN(INITIAL); VALUE(IDENTIFIER, "Quoted identifier: " << literal); }

    /* Escape sequences */

<CHR,STR,QIDENT>\\n { literal += '\n'; }
<CHR,STR,QIDENT>\\r { literal += '\r'; }
<CHR,STR,QIDENT>\\t { literal += '\t'; }
<CHR,STR,QIDENT>\\\\ { literal += '\\'; }
<CHR,STR,QIDENT>\\' { literal += '\''; }
<CHR,STR,QIDENT>\\\" { literal += '"'; }
<CHR,STR,QIDENT>\\x[0-9a-fA-F]{2} { literal += (char)strtol(yytext + 2, nullptr, 16); }

    /* Other escape */

<CHR,STR,QIDENT>\\.? { report(yylineno, std::string("invalid escape sequence: ") + yytext); }

    /* No closing delimiter before the line or the file ends. Report which type of literal was left open. */

<CHR,STR,QIDENT>\n { report(literal_line, std::string("unterminated ") + literal_type_from_condition(YY_START)); BEGIN(INITIAL); }

<CHR,STR,QIDENT><<EOF>> { report(literal_line, std::string("unterminated ") + literal_type_from_condition(YY_START)); BEGIN(INITIAL); }

    /* Multiline string. Extra \n between last line and ';' don't count. */

\\\\ { ml.clear(); BEGIN(MLSTR); }

<MLSTR>[^\r\n]+ { ml += yytext; }

<MLSTR>\r?\n[ \t]*\\\\ { ml += '\n'; } // Может быть несколько пустых строчек между многострочными строчками

<MLSTR>\r?\n { BEGIN(INITIAL); VALUE(MULTILINE_STRING_LITERAL, "Multiline string literal: " << ml); }

<MLSTR><<EOF>> { BEGIN(INITIAL); VALUE(MULTILINE_STRING_LITERAL, "Multiline string literal: " << ml); }

    /* Numbers */
    /* Hex float may contain either a fractional part, or an exponential part, or both simultaneously. */
    /* Examples:  0x1.1p+1, 0x1.1, 0x11p+10, 0x1.1p10 */
0x{HEX}(\.{HEX}([pP][+-]?{DEC})?|[pP][+-]?{DEC}) { VALUE(FLOAT_LITERAL, "Hex float literal: " << float_value(yytext)); }

0x{HEX} { VALUE(INTEGER_LITERAL, "Hex integer literal: " << int_value(yytext + 2, 16)); }

0b{BIN} { VALUE(INTEGER_LITERAL, "Binary integer literal: " << int_value(yytext + 2, 2)); }

0o{OCT} { VALUE(INTEGER_LITERAL, "Octal integer literal: " << int_value(yytext + 2, 8)); }

    /* DEC float may contain either a fractional part, or an exponential part, or both simultaneously. */
    /* Examples:  1.1e+1, 1.1, 11e+10, 1.1E10 */
{DEC}(\.{DEC}([eE][+-]?{DEC})?|[eE][+-]?{DEC}) { VALUE(FLOAT_LITERAL, "Float literal: " << float_value(yytext)); }

{DEC} { VALUE(INTEGER_LITERAL, "Integer literal: " << int_value(yytext, 10)); }

    /* Keywords */

"addrspace" { TOKEN(KW_ADDRSPACE, "Keyword: " << yytext); }
"align" { TOKEN(KW_ALIGN, "Keyword: " << yytext); }
"allowzero" { TOKEN(KW_ALLOWZERO, "Keyword: " << yytext); }
"and" { TOKEN(KW_AND, "Keyword: " << yytext); }
"anyframe" { TOKEN(KW_ANYFRAME, "Keyword: " << yytext); }
"anytype" { TOKEN(KW_ANYTYPE, "Keyword: " << yytext); }
"asm" { TOKEN(KW_ASM, "Keyword: " << yytext); }
"break" { TOKEN(KW_BREAK, "Keyword: " << yytext); }
"callconv" { TOKEN(KW_CALLCONV, "Keyword: " << yytext); }
"catch" { TOKEN(KW_CATCH, "Keyword: " << yytext); }
"comptime" { TOKEN(KW_COMPTIME, "Keyword: " << yytext); }
"const" { TOKEN(KW_CONST, "Keyword: " << yytext); }
"continue" { TOKEN(KW_CONTINUE, "Keyword: " << yytext); }
"defer" { TOKEN(KW_DEFER, "Keyword: " << yytext); }
"else" { TOKEN(KW_ELSE, "Keyword: " << yytext); }
"enum" { TOKEN(KW_ENUM, "Keyword: " << yytext); }
"errdefer" { TOKEN(KW_ERRDEFER, "Keyword: " << yytext); }
"error" { TOKEN(KW_ERROR, "Keyword: " << yytext); }
"export" { TOKEN(KW_EXPORT, "Keyword: " << yytext); }
"extern" { TOKEN(KW_EXTERN, "Keyword: " << yytext); }
"fn" { TOKEN(KW_FN, "Keyword: " << yytext); }
"for" { TOKEN(KW_FOR, "Keyword: " << yytext); }
"if" { TOKEN(KW_IF, "Keyword: " << yytext); }
"inline" { TOKEN(KW_INLINE, "Keyword: " << yytext); }
"linksection" { TOKEN(KW_LINKSECTION, "Keyword: " << yytext); }
"noalias" { TOKEN(KW_NOALIAS, "Keyword: " << yytext); }
"noinline" { TOKEN(KW_NOINLINE, "Keyword: " << yytext); }
"nosuspend" { TOKEN(KW_NOSUSPEND, "Keyword: " << yytext); }
"opaque" { TOKEN(KW_OPAQUE, "Keyword: " << yytext); }
"or" { TOKEN(KW_OR, "Keyword: " << yytext); }
"orelse" { TOKEN(KW_ORELSE, "Keyword: " << yytext); }
"packed" { TOKEN(KW_PACKED, "Keyword: " << yytext); }
"pub" { TOKEN(KW_PUB, "Keyword: " << yytext); }
"resume" { TOKEN(KW_RESUME, "Keyword: " << yytext); }
"return" { TOKEN(KW_RETURN, "Keyword: " << yytext); }
"struct" { TOKEN(KW_STRUCT, "Keyword: " << yytext); }
"suspend" { TOKEN(KW_SUSPEND, "Keyword: " << yytext); }
"switch" { TOKEN(KW_SWITCH, "Keyword: " << yytext); }
"test" { TOKEN(KW_TEST, "Keyword: " << yytext); }
"threadlocal" { TOKEN(KW_THREADLOCAL, "Keyword: " << yytext); }
"try" { TOKEN(KW_TRY, "Keyword: " << yytext); }
"union" { TOKEN(KW_UNION, "Keyword: " << yytext); }
"unreachable" { TOKEN(KW_UNREACHABLE, "Keyword: " << yytext); }
"var" { TOKEN(KW_VAR, "Keyword: " << yytext); }
"volatile" { TOKEN(KW_VOLATILE, "Keyword: " << yytext); }
"while" { TOKEN(KW_WHILE, "Keyword: " << yytext); }
"null" { VALUE(KW_NULL, "Null literal: " << yytext); }
"undefined" { VALUE(KW_UNDEFINED, "Constant: " << yytext); }

    /* Constants */

"true" { VALUE(KW_TRUE, "Boolean literal(true): " << 1); }
"false" { VALUE(KW_FALSE, "Boolean literal(false): " << 0); }

    /* Integer types. Number in [0,65535], no leading zero. */

u[0-9]+ { if (validate_int_size(yytext)) VALUE(PRIMITIVE_TYPE, "Unsigned integer type: " << yytext); }
i[0-9]+ { if (validate_int_size(yytext)) VALUE(PRIMITIVE_TYPE, "Signed integer type: " << yytext); }

    /* Float types */

f16 { VALUE(PRIMITIVE_TYPE, "Float type: " << yytext); }
f32 { VALUE(PRIMITIVE_TYPE, "Float type: " << yytext); }
f64 { VALUE(PRIMITIVE_TYPE, "Float type: " << yytext); }
f80 { VALUE(PRIMITIVE_TYPE, "Float type: " << yytext); }
f128 { VALUE(PRIMITIVE_TYPE, "Float type: " << yytext); }

    /* Other primitive types */

"bool" { VALUE(PRIMITIVE_TYPE, "Bool type: " << yytext); }
"void" { VALUE(PRIMITIVE_TYPE, "Void type: " << yytext); }
"noreturn" { VALUE(PRIMITIVE_TYPE, "Noreturn type: " << yytext); }
"type" { VALUE(PRIMITIVE_TYPE, "Type: " << yytext); }
"anyerror" { VALUE(PRIMITIVE_TYPE, "Anyerror type: " << yytext); }
"anyopaque" { VALUE(PRIMITIVE_TYPE, "Anyopaque type: " << yytext); }
"comptime_int" { VALUE(PRIMITIVE_TYPE, "Comptime int type: " << yytext); }
"comptime_float" { VALUE(PRIMITIVE_TYPE, "Comptime float type: " << yytext); }

    /* Pointer-sized types */

"usize" { VALUE(PRIMITIVE_TYPE, "Usize type: " << yytext); }
"isize" { VALUE(PRIMITIVE_TYPE, "Isize type: " << yytext); }

    /* C-compatible types */

"c_char" { VALUE(PRIMITIVE_TYPE, "C char type: " << yytext); }
"c_short" { VALUE(PRIMITIVE_TYPE, "C short type: " << yytext); }
"c_ushort" { VALUE(PRIMITIVE_TYPE, "C ushort type: " << yytext); }
"c_int" { VALUE(PRIMITIVE_TYPE, "C int type: " << yytext); }
"c_uint" { VALUE(PRIMITIVE_TYPE, "C uint type: " << yytext); }
"c_long" { VALUE(PRIMITIVE_TYPE, "C long type: " << yytext); }
"c_ulong" { VALUE(PRIMITIVE_TYPE, "C ulong type: " << yytext); }
"c_longlong" { VALUE(PRIMITIVE_TYPE, "C longlong type: " << yytext); }
"c_ulonglong" { VALUE(PRIMITIVE_TYPE, "C ulonglong type: " << yytext); }
"c_longdouble" { VALUE(PRIMITIVE_TYPE, "C longdouble type: " << yytext); }

    /* Identifiers */

[A-Za-z_][A-Za-z0-9_]* { VALUE(IDENTIFIER, "Identifier: " << yytext); }

    /* Builtin identifiers. Lexer allows any identifier, but later only implecated functions will be allowed  */

@[a-zA-Z_][a-zA-Z0-9_]* { VALUE(BUILTIN, "Builtin identifier: " << yytext); }

    /* Punctuators */

"[" { TOKEN(LBRACKET, "Punctuator: " << yytext); }
"]" { TOKEN(RBRACKET, "Punctuator: " << yytext); }
"{" { TOKEN(LBRACE, "Punctuator: " << yytext); }
"}" { TOKEN(RBRACE, "Punctuator: " << yytext); }
"(" { TOKEN(LPAREN, "Punctuator: " << yytext); }
")" { TOKEN(RPAREN, "Punctuator: " << yytext); }

    /* Separators */

"," { TOKEN(COMMA, "Separator: " << yytext); }
":" { TOKEN(COLON, "Separator: " << yytext); }
";" { TOKEN(SEMICOLON, "Semicolon: " << yytext); }

    /* Operators (array) */

"++" { TOKEN(PLUS_PLUS, "Operator (array concat): " << yytext); }
"**" { TOKEN(ASTERISK_ASTERISK, "Operator (array repeat): " << yytext); }

    /* Operators (arithmetic) */

"+" { TOKEN(PLUS, "Operator (arithmetic): " << yytext); }
"-" { TOKEN(MINUS, "Operator (arithmetic): " << yytext); }
"*" { TOKEN(ASTERISK, "Operator (arithmetic): " << yytext); }
"/" { TOKEN(SLASH, "Operator (arithmetic): " << yytext); }
"%" { TOKEN(PERCENT, "Operator (arithmetic): " << yytext); }

    /* Wrapping (%) and saturating (|) operators */

"+%" { TOKEN(PLUS_PERCENT, "Operator (wrapping): " << yytext); }
"-%" { TOKEN(MINUS_PERCENT, "Operator (wrapping): " << yytext); }
"*%" { TOKEN(ASTERISK_PERCENT, "Operator (wrapping): " << yytext); }
"+|" { TOKEN(PLUS_PIPE, "Operator (saturating): " << yytext); }
"-|" { TOKEN(MINUS_PIPE, "Operator (saturating): " << yytext); }
"*|" { TOKEN(ASTERISK_PIPE, "Operator (saturating): " << yytext); }
"<<|" { TOKEN(SHL_PIPE, "Operator (saturating): " << yytext); }

    /* Operators (comparison) */

"==" { TOKEN(EQUAL_EQUAL, "Operator (comparison): " << yytext); }
"!=" { TOKEN(BANG_EQUAL, "Operator (comparison): " << yytext); }
"<=" { TOKEN(LESS_EQUAL, "Operator (comparison): " << yytext); }
">=" { TOKEN(GREATER_EQUAL, "Operator (comparison): " << yytext); }
"<" { TOKEN(LESS, "Operator (comparison): " << yytext); }
">" { TOKEN(GREATER, "Operator (comparison): " << yytext); }

    /* Operators (logical) */

"!" { TOKEN(BANG, "Operator (logical): " << yytext); }

    /* Operators (bitwise) */

"<<" { TOKEN(SHL, "Operator (bitwise): " << yytext); }
">>" { TOKEN(SHR, "Operator (bitwise): " << yytext); }
"&" { TOKEN(AMPERSAND, "Operator (bitwise): " << yytext); }
"|" { TOKEN(PIPE, "Operator (bitwise): " << yytext); }
"^" { TOKEN(CARET, "Operator (bitwise): " << yytext); }
"~" { TOKEN(TILDE, "Operator (bitwise): " << yytext); }

    /* Operators (assignment) */

"<<=" { TOKEN(SHL_EQUAL, "Operator (assignment): " << yytext); }
">>=" { TOKEN(SHR_EQUAL, "Operator (assignment): " << yytext); }
"+=" { TOKEN(PLUS_EQUAL, "Operator (assignment): " << yytext); }
"-=" { TOKEN(MINUS_EQUAL, "Operator (assignment): " << yytext); }
"*=" { TOKEN(ASTERISK_EQUAL, "Operator (assignment): " << yytext); }
"/=" { TOKEN(SLASH_EQUAL, "Operator (assignment): " << yytext); }
"%=" { TOKEN(PERCENT_EQUAL, "Operator (assignment): " << yytext); }
"&=" { TOKEN(AMPERSAND_EQUAL, "Operator (assignment): " << yytext); }
"|=" { TOKEN(PIPE_EQUAL, "Operator (assignment): " << yytext); }
"^=" { TOKEN(CARET_EQUAL, "Operator (assignment): " << yytext); }
"+%=" { TOKEN(PLUS_PERCENT_EQUAL, "Operator (assignment): " << yytext); }
"-%=" { TOKEN(MINUS_PERCENT_EQUAL, "Operator (assignment): " << yytext); }
"*%=" { TOKEN(ASTERISK_PERCENT_EQUAL, "Operator (assignment): " << yytext); }
"+|=" { TOKEN(PLUS_PIPE_EQUAL, "Operator (assignment): " << yytext); }
"-|=" { TOKEN(MINUS_PIPE_EQUAL, "Operator (assignment): " << yytext); }
"*|=" { TOKEN(ASTERISK_PIPE_EQUAL, "Operator (assignment): " << yytext); }
"<<|=" { TOKEN(SHL_PIPE_EQUAL, "Operator (assignment): " << yytext); }
"=" { TOKEN(EQUAL, "Operator (assignment): " << yytext); }

    /* Operators (other) */

".*" { TOKEN(DOT_ASTERISK, "Operator (struct deref): " << yytext); }
".?" { TOKEN(DOT_QUESTION, "Operator (optional unwrap): " << yytext); }
"..." { TOKEN(ELLIPSIS3, "Operator (range): " << yytext); }
".." { TOKEN(ELLIPSIS2, "Operator (range): " << yytext); }
"=>" { TOKEN(EQUAL_ARROW, "Operator (switch prong): " << yytext); }
"||" { TOKEN(PIPE_PIPE, "Operator (error set merge): " << yytext); }
"." { TOKEN(DOT, "Operator (member): " << yytext); }
"?" { TOKEN(QUESTION, "Operator (optional): " << yytext); }

[ \t\r\n]+ { /* ignored */ }

    /* Errors */

<*>. { report(yylineno, std::string("unexpected character: ") + yytext); }

%%

/*! Print an error in the format "error: <message> in line: <line>". */
void report(int line, const std::string& message) {
    std::cerr << "error: " << message << " in line: " << line << '\n';
    ++error_count;
}

/*! Get type of literal that lexer reads in a start condition.
 *  \param[in] condition number of start condition.
 *  \return the type of literal, or an empty string for a condition that reads no literal.
 */
static const char* literal_type_from_condition(int condition) {
    switch (condition) {
        case CHR:    return "character literal";
        case STR:    return "string literal";
        case QIDENT: return "quoted identifier";
    }

    return "";
}

/*! Validate integer size. A bit count above 65535
 *  or with a leading zero is reported as an error.
 *  \param[in] text type name, such as u8 or i32.
 *  \return whether the name is a valid integer type.
 */
static bool validate_int_size(const char* text) {
    std::string name = text;

    if (name.size() >= 3 && name[1] == '0') {
        report(yylineno, "primitive integer type '" + name + "' has leading zero");
        return false;
    }

    if (name.size() > 6 || strtoul(text + 1, nullptr, 10) > 65535) {
        report(yylineno, "primitive integer type '" + name + "' exceeds maximum bit width of 65535");
        return false;
    }

    return true;
}

static std::string strip_underscores(const char* text) {
    std::string digits;

    for (; *text; ++text) {
        if (*text != '_') digits += *text;
    }

    return digits;
}

/*! Parse an integer literal into its value.
 *  \param[in] text literal with skipped base prefix.
 *  \param[in] base 2, 8, 10 or 16.
 *  \return the value, saturated at ULLONG_MAX.
 */
static unsigned long long int_value(const char* text, int base) {
    std::string digits = strip_underscores(text);

    unsigned long long value = strtoull(digits.c_str(), nullptr, base);

    return value;
}

/*! Parse a floating-point literal into its value.
 *  Handles both decimal and hexadecimal forms.
 *  \param[in] text full literal text, prefix included.
 *  \return the value.
 */
static double float_value(const char* text) {
    std::string digits = strip_underscores(text);

    double value = strtod(digits.c_str(), nullptr);

    return value;
}
