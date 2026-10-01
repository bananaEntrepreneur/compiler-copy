/* Parser of Zig 0.17 for the lexer in lexer.l.
 *
 * The grammar follows the one in the Zig language reference, rewritten for
 * LALR(1). The nonterminals are named after it: expr is Expr, prefix_expr is
 * PrefixExpr, primary_expr is PrimaryExpr, suffix_expr is SuffixExpr...
 *
 * Two places need a different shape than in the reference:
 *
 * 1. At the start of a statement, 'if', 'while', 'for', 'switch' and '{' begin
 *    a statement that needs no ';' after a block. So an expression statement
 *    is a plain_expr: the same as expr, but it cannot start with such a
 *    construct (nor with return, break, continue or comptime, which are
 *    statements of their own there). Switch case items are plain_expr too:
 *    'inline' before a case is the prong's, not an inline loop's.
 *
 * 2. 'label: {...}' needs two tokens to be told from an identifier followed
 *    by ':' (as in 'a[0..n :0]'). So labeled blocks, loops and switches are
 *    allowed where a whole expression stands (full_expr: values, arguments,
 *    prong bodies, statements), in the branches of if/else, loops and jumps,
 *    after comptime, orelse, catch, and, or; not as other operands.
 *
 * Not supported: asm, async (suspend, resume, nosuspend, anyframe), tuple-like
 * struct fields ('struct { u8, bool }') and 'if' right after '?' or '!' inside
 * an expression (in the type of a field or a declaration it is allowed).
 *
 * The result is the parse tree: printed as an indented list, or with --dot in
 * the DOT language of Graphviz.
 */

%code requires {
#include <string>

struct Node;
}

%code {
#include <cstdio>
#include <iostream>
#include <vector>

/*! A node of the parse tree: what the construct is, and its parts in source order. */
struct Node {
    std::string label;
    std::vector<Node*> children;

    explicit Node(const std::string& label) : label(label) {}

    ~Node() {
        for (Node* child : children) {
            delete child;
        }
    }
};

int yylex();
void yyerror(const char* message);
void report(int line, const std::string& message); // lexer.l
extern int yylineno;

static Node* tree; // the source file, set once it is parsed

static Node* node(const std::string& label, std::initializer_list<Node*> children = {});
static Node* leaf(std::string* text);
static Node* add(Node* parent, Node* child);
static Node* prepend(Node* parent, Node* child);
static Node* rename(Node* list, const std::string& label);
static Node* concat(Node* list, Node* tail);
static Node* labeled(std::string* label, Node* construct);
static Node* modify(Node* declaration, Node* pub, Node* modifiers);
static Node* binary(const char* op, Node* left, Node* right);
static Node* pointer(const std::string& label, Node* modifiers, Node* element);
}

%define parse.error detailed

%union {
    std::string* text; /* text of the token, as the lexer prints it */
    Node* node;
    const char* op;
}

%destructor { delete $$; } <text> <node>

%token END 0 "end of file"

%token <text> IDENTIFIER "identifier"
%token <text> BUILTIN "builtin function"
%token <text> PRIMITIVE_TYPE "primitive type"
%token <text> INTEGER_LITERAL "integer literal"
%token <text> FLOAT_LITERAL "float literal"
%token <text> CHAR_LITERAL "character literal"
%token <text> STRING_LITERAL "string literal"
%token <text> MULTILINE_STRING_LITERAL "multiline string literal"
%token <text> KW_TRUE "'true'" KW_FALSE "'false'" KW_NULL "'null'" KW_UNDEFINED "'undefined'"

%token KW_ADDRSPACE "'addrspace'" KW_ALIGN "'align'" KW_ALLOWZERO "'allowzero'" KW_AND "'and'"
%token KW_ANYFRAME "'anyframe'" KW_ANYTYPE "'anytype'" KW_ASM "'asm'" KW_BREAK "'break'"
%token KW_CALLCONV "'callconv'" KW_CATCH "'catch'" KW_COMPTIME "'comptime'" KW_CONST "'const'"
%token KW_CONTINUE "'continue'" KW_DEFER "'defer'" KW_ELSE "'else'" KW_ENUM "'enum'"
%token KW_ERRDEFER "'errdefer'" KW_ERROR "'error'" KW_EXPORT "'export'" KW_EXTERN "'extern'"
%token KW_FN "'fn'" KW_FOR "'for'" KW_IF "'if'" KW_INLINE "'inline'" KW_LINKSECTION "'linksection'"
%token KW_NOALIAS "'noalias'" KW_NOINLINE "'noinline'" KW_NOSUSPEND "'nosuspend'"
%token KW_OPAQUE "'opaque'" KW_OR "'or'" KW_ORELSE "'orelse'" KW_PACKED "'packed'" KW_PUB "'pub'"
%token KW_RESUME "'resume'" KW_RETURN "'return'" KW_STRUCT "'struct'" KW_SUSPEND "'suspend'"
%token KW_SWITCH "'switch'" KW_TEST "'test'" KW_THREADLOCAL "'threadlocal'" KW_TRY "'try'"
%token KW_UNION "'union'" KW_UNREACHABLE "'unreachable'" KW_VAR "'var'" KW_VOLATILE "'volatile'"
%token KW_WHILE "'while'"

%token LBRACKET "'['" RBRACKET "']'" LBRACE "'{'" RBRACE "'}'" LPAREN "'('" RPAREN "')'"
%token COMMA "','" COLON "':'" SEMICOLON "';'"
%token PLUS_PLUS "'++'" ASTERISK_ASTERISK "'**'"
%token PLUS "'+'" MINUS "'-'" ASTERISK "'*'" SLASH "'/'" PERCENT "'%'"
%token PLUS_PERCENT "'+%'" MINUS_PERCENT "'-%'" ASTERISK_PERCENT "'*%'"
%token PLUS_PIPE "'+|'" MINUS_PIPE "'-|'" ASTERISK_PIPE "'*|'" SHL_PIPE "'<<|'"
%token EQUAL_EQUAL "'=='" BANG_EQUAL "'!='" LESS_EQUAL "'<='" GREATER_EQUAL "'>='" LESS "'<'" GREATER "'>'"
%token BANG "'!'" SHL "'<<'" SHR "'>>'" AMPERSAND "'&'" PIPE "'|'" CARET "'^'" TILDE "'~'"
%token SHL_EQUAL "'<<='" SHR_EQUAL "'>>='" PLUS_EQUAL "'+='" MINUS_EQUAL "'-='" ASTERISK_EQUAL "'*='"
%token SLASH_EQUAL "'/='" PERCENT_EQUAL "'%='" AMPERSAND_EQUAL "'&='" PIPE_EQUAL "'|='" CARET_EQUAL "'^='"
%token PLUS_PERCENT_EQUAL "'+%='" MINUS_PERCENT_EQUAL "'-%='" ASTERISK_PERCENT_EQUAL "'*%='"
%token PLUS_PIPE_EQUAL "'+|='" MINUS_PIPE_EQUAL "'-|='" ASTERISK_PIPE_EQUAL "'*|='" SHL_PIPE_EQUAL "'<<|='"
%token EQUAL "'='"
%token DOT_ASTERISK "'.*'" DOT_QUESTION "'.?'" ELLIPSIS3 "'...'" ELLIPSIS2 "'..'" EQUAL_ARROW "'=>'"
%token PIPE_PIPE "'||'" DOT "'.'" QUESTION "'?'"

    /* if/while/for, return, break, continue and comptime end with an expression, which */
    /* takes all that follows: 'return a + b' returns 'a + b'. So they bind loosest.    */
    /* 'else' belongs to the nearest if/while/for.                                      */

%precedence LOWER_THAN_ELSE KW_RETURN KW_BREAK KW_CONTINUE
%precedence KW_ELSE

    /* A ':' right after break or continue starts the label: 'break :blk'. And a name */
    /* followed by ':' where a labeled block may start is its label: 'orelse blk: {'. */

%precedence IDENTIFIER_OPERAND
%precedence COLON

    /* Binary operators, from the lowest precedence to the highest, as in the Zig reference */

%left KW_OR
%left KW_AND
%nonassoc EQUAL_EQUAL BANG_EQUAL LESS GREATER LESS_EQUAL GREATER_EQUAL
%left AMPERSAND CARET PIPE KW_ORELSE KW_CATCH
%left SHL SHR SHL_PIPE
%left PLUS MINUS PLUS_PLUS PLUS_PERCENT MINUS_PERCENT PLUS_PIPE MINUS_PIPE
%left ASTERISK SLASH PERCENT ASTERISK_ASTERISK ASTERISK_PERCENT ASTERISK_PIPE PIPE_PIPE

    /* '[*c]' is a C pointer, not an array whose length is the pointer type '*c': */
    /* shift the identifier, as Zig tries the pointer form first.                  */

%expect 1

%type <node> container_members declarations nonempty_declarations fields field value_opt
%type <node> declaration pub_opt linkage fn_modifiers var_modifiers var_declaration var_proto
%type <node> fn_proto type_opt align_opt addrspace_opt linksection_opt callconv_opt
%type <node> return_type decl_type if_type_expr
%type <node> parameters parameter_list parameter param_modifier param_type
%type <node> block statements statement block_expr body_expr destructure destructure_targets
%type <node> if_statement if_prefix loop_statement for_statement while_statement
%type <node> for_prefix for_inputs for_input while_prefix continue_opt
%type <node> full_expr labeled_expr branch assign_expr plain_assign plain_expr
%type <node> expr prefix_expr primary_expr jump break_label if_expr loop_expr for_expr while_expr
%type <node> switch_expr switch_prongs prong_list switch_prong switch_case switch_items
%type <node> switch_item prong_body curly_expr type_expr pointer_modifiers error_union_expr
%type <node> suffix_expr arguments argument_list primary_type_expr name error_names
%type <node> error_name_list container_decl container_kind init_list field_inits field_init
%type <node> init_elements capture_opt capture captures capture_item payload_opt
%type <op> assign_op compare_op bitwise_op bit_shift_op addition_op multiply_op prefix_op

%%

source_file
    : container_members                                   { tree = rename($1, "Source file"); }
    ;

    /* ---------------- Members of a file, struct, enum, union or opaque ---------------- */

    /* Declarations, fields, then declarations again: Zig allows no declaration between fields */

container_members
    : declarations
    | declarations fields                                 { $$ = concat($1, $2); }
    ;

declarations
    : %empty                                              { $$ = new Node("Members"); }
    | declarations declaration                            { $$ = add($1, $2); }
    ;

nonempty_declarations
    : declaration                                         { $$ = node("Members", {$1}); }
    | nonempty_declarations declaration                   { $$ = add($1, $2); }
    ;

fields
    : field                                               { $$ = node("Members", {$1}); }
    | field COMMA                                         { $$ = node("Members", {$1}); }
    | field COMMA fields                                  { $$ = prepend($3, $1); }
    | field COMMA nonempty_declarations                   { $$ = prepend($3, $1); }
    ;

    /* A struct or union field has a type; an enum field has only a name and maybe a value */

field
    : name value_opt                                      { $$ = node("Field", {$1, $2}); }
    | name COLON decl_type align_opt value_opt            { $$ = node("Field", {$1, node("Type", {$3}), $4, $5}); }
    | KW_COMPTIME name COLON decl_type align_opt value_opt
                                                          { $$ = node("Field", {new Node("Keyword: comptime"), $2, node("Type", {$4}), $5, $6}); }
    ;

value_opt
    : %empty                                              { $$ = nullptr; }
    | EQUAL full_expr                                     { $$ = node("Value", {$2}); }
    ;

declaration
    : pub_opt fn_modifiers fn_proto block                 { $$ = add(modify($3, $1, $2), $4); }
    | pub_opt fn_modifiers fn_proto SEMICOLON             { $$ = modify($3, $1, $2); }
    | pub_opt var_modifiers var_declaration               { $$ = modify($3, $1, $2); }
    | KW_COMPTIME block                                   { $$ = node("Comptime", {$2}); }
    | KW_TEST STRING_LITERAL block                        { $$ = node("Test declaration", {leaf($2), $3}); }
    | KW_TEST IDENTIFIER block                            { $$ = node("Test declaration", {leaf($2), $3}); }
    | KW_TEST block                                       { $$ = node("Test declaration", {$2}); }
    ;

pub_opt
    : %empty                                              { $$ = nullptr; }
    | KW_PUB                                              { $$ = new Node("Keyword: pub"); }
    ;

    /* Modifiers come as a list node; the declaration takes its children */

linkage
    : %empty                                              { $$ = new Node("Modifiers"); }
    | KW_EXPORT                                           { $$ = node("Modifiers", {new Node("Keyword: export")}); }
    | KW_EXTERN                                           { $$ = node("Modifiers", {new Node("Keyword: extern")}); }
    | KW_EXTERN STRING_LITERAL                            { $$ = node("Modifiers", {node("Keyword: extern", {leaf($2)})}); }
    ;

fn_modifiers
    : linkage
    | KW_INLINE                                           { $$ = node("Modifiers", {new Node("Keyword: inline")}); }
    | KW_NOINLINE                                         { $$ = node("Modifiers", {new Node("Keyword: noinline")}); }
    ;

var_modifiers
    : linkage
    | linkage KW_THREADLOCAL                              { $$ = add($1, new Node("Keyword: threadlocal")); }
    ;

var_declaration
    : KW_CONST IDENTIFIER type_opt align_opt addrspace_opt linksection_opt value_opt SEMICOLON
                                                          { $$ = node("Variable declaration: const", {leaf($2), $3, $4, $5, $6, $7}); }
    | KW_VAR IDENTIFIER type_opt align_opt addrspace_opt linksection_opt value_opt SEMICOLON
                                                          { $$ = node("Variable declaration: var", {leaf($2), $3, $4, $5, $6, $7}); }
    ;

type_opt
    : %empty                                              { $$ = nullptr; }
    | COLON decl_type                                     { $$ = node("Type", {$2}); }
    ;

align_opt
    : %empty                                              { $$ = nullptr; }
    | KW_ALIGN LPAREN expr RPAREN                         { $$ = node("Align", {$3}); }
    ;

addrspace_opt
    : %empty                                              { $$ = nullptr; }
    | KW_ADDRSPACE LPAREN expr RPAREN                     { $$ = node("Address space", {$3}); }
    ;

linksection_opt
    : %empty                                              { $$ = nullptr; }
    | KW_LINKSECTION LPAREN expr RPAREN                   { $$ = node("Link section", {$3}); }
    ;

    /* The type of a declaration, a field, a parameter or a returned value */
    /* may also be chosen by if or switch                                  */

decl_type
    : type_expr
    | if_type_expr
    | switch_expr
    | QUESTION if_type_expr                               { $$ = node("Optional type", {$2}); }
    ;

if_type_expr
    : if_prefix decl_type %prec LOWER_THAN_ELSE           { $$ = add($1, $2); }
    | if_prefix decl_type KW_ELSE payload_opt decl_type   { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    ;

    /* ---------------- Functions ---------------- */

fn_proto
    : KW_FN IDENTIFIER LPAREN parameters RPAREN align_opt addrspace_opt linksection_opt callconv_opt return_type
                                                          { $$ = node("Function declaration", {leaf($2), $4, $6, $7, $8, $9, $10}); }
    ;

callconv_opt
    : %empty                                              { $$ = nullptr; }
    | KW_CALLCONV LPAREN expr RPAREN                      { $$ = node("Calling convention", {$3}); }
    ;

    /* '!T' returns T or an error of a set the compiler infers */

return_type
    : decl_type                                           { $$ = node("Return type", {$1}); }
    | BANG decl_type                                      { $$ = node("Return type", {node("Error union type: inferred error set", {$2})}); }
    ;

parameters
    : %empty                                              { $$ = new Node("Parameters"); }
    | parameter_list
    | parameter_list COMMA
    ;

parameter_list
    : parameter                                           { $$ = node("Parameters", {$1}); }
    | parameter_list COMMA parameter                      { $$ = add($1, $3); }
    ;

parameter
    : param_modifier name COLON param_type                { $$ = node("Parameter", {$1, $2, node("Type", {$4})}); }
    | param_modifier param_type                           { $$ = node("Parameter", {$1, node("Type", {$2})}); }
    | ELLIPSIS3                                           { $$ = new Node("Variadic parameter"); }
    ;

param_modifier
    : %empty                                              { $$ = nullptr; }
    | KW_COMPTIME                                         { $$ = new Node("Keyword: comptime"); }
    | KW_NOALIAS                                          { $$ = new Node("Keyword: noalias"); }
    ;

param_type
    : decl_type
    | KW_ANYTYPE                                          { $$ = new Node("Keyword: anytype"); }
    ;

    /* ---------------- Statements ---------------- */

block
    : LBRACE statements RBRACE                            { $$ = $2; }
    ;

statements
    : %empty                                              { $$ = new Node("Block"); }
    | statements statement                                { $$ = add($1, $2); }
    ;

statement
    : var_declaration
    | KW_COMPTIME var_declaration                         { $$ = node("Comptime", {$2}); }
    | KW_COMPTIME block_expr                              { $$ = node("Comptime", {$2}); }
    | KW_COMPTIME body_expr SEMICOLON                     { $$ = node("Comptime", {$2}); }
    | KW_DEFER block_expr                                 { $$ = node("Defer", {$2}); }
    | KW_DEFER body_expr SEMICOLON                        { $$ = node("Defer", {$2}); }
    | KW_ERRDEFER payload_opt block_expr                  { $$ = node("Errdefer", {$2, $3}); }
    | KW_ERRDEFER payload_opt body_expr SEMICOLON         { $$ = node("Errdefer", {$2, $3}); }
    | if_statement
    | loop_statement
    | IDENTIFIER COLON loop_statement                     { $$ = labeled($1, $3); }
    | switch_expr
    | IDENTIFIER COLON switch_expr                        { $$ = labeled($1, $3); }
    | block_expr
    | jump SEMICOLON
    | destructure SEMICOLON
    | plain_assign SEMICOLON
    ;

block_expr
    : block
    | IDENTIFIER COLON block                              { $$ = labeled($1, $3); }
    ;

    /* The body of if, while, for or defer that is not a block: ';' or 'else' comes after it */

body_expr
    : plain_assign
    | jump
    | if_expr
    | loop_expr
    | switch_expr
    | IDENTIFIER COLON loop_expr                          { $$ = labeled($1, $3); }
    | IDENTIFIER COLON switch_expr                        { $$ = labeled($1, $3); }
    | KW_COMPTIME branch                                  { $$ = node("Comptime", {$2}); }
    ;

if_statement
    : if_prefix block_expr %prec LOWER_THAN_ELSE          { $$ = add($1, $2); }
    | if_prefix block_expr KW_ELSE payload_opt statement  { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    | if_prefix body_expr SEMICOLON                       { $$ = add($1, $2); }
    | if_prefix body_expr KW_ELSE payload_opt statement   { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    ;

if_prefix
    : KW_IF LPAREN full_expr RPAREN capture_opt           { $$ = node("If", {$3, $5}); }
    ;

loop_statement
    : for_statement
    | while_statement
    | KW_INLINE for_statement                             { $$ = prepend($2, new Node("Keyword: inline")); }
    | KW_INLINE while_statement                           { $$ = prepend($2, new Node("Keyword: inline")); }
    ;

for_statement
    : for_prefix block_expr %prec LOWER_THAN_ELSE         { $$ = add($1, $2); }
    | for_prefix block_expr KW_ELSE statement             { $$ = add(add($1, $2), node("Else", {$4})); }
    | for_prefix body_expr SEMICOLON                      { $$ = add($1, $2); }
    | for_prefix body_expr KW_ELSE statement              { $$ = add(add($1, $2), node("Else", {$4})); }
    ;

while_statement
    : while_prefix block_expr %prec LOWER_THAN_ELSE       { $$ = add($1, $2); }
    | while_prefix block_expr KW_ELSE payload_opt statement
                                                          { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    | while_prefix body_expr SEMICOLON                    { $$ = add($1, $2); }
    | while_prefix body_expr KW_ELSE payload_opt statement
                                                          { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    ;

for_prefix
    : KW_FOR LPAREN for_inputs comma_opt RPAREN capture   { $$ = node("For", {$3, $6}); }
    ;

for_inputs
    : for_input                                           { $$ = node("Inputs", {$1}); }
    | for_inputs COMMA for_input                          { $$ = add($1, $3); }
    ;

for_input
    : expr
    | expr ELLIPSIS2                                      { $$ = node("Range", {$1}); }
    | expr ELLIPSIS2 expr                                 { $$ = node("Range", {$1, $3}); }
    ;

while_prefix
    : KW_WHILE LPAREN full_expr RPAREN capture_opt continue_opt
                                                          { $$ = node("While", {$3, $5, $6}); }
    ;

continue_opt
    : %empty                                              { $$ = nullptr; }
    | COLON LPAREN assign_expr RPAREN                     { $$ = node("Continue expression", {$3}); }
    ;

    /* 'const a, var b: T, c.d = f();' */

destructure
    : destructure_targets EQUAL full_expr                 { $$ = add($1, node("Value", {$3})); }
    ;

destructure_targets
    : var_proto COMMA var_proto                           { $$ = node("Destructuring", {$1, $3}); }
    | var_proto COMMA expr                                { $$ = node("Destructuring", {$1, $3}); }
    | plain_expr COMMA var_proto                          { $$ = node("Destructuring", {$1, $3}); }
    | plain_expr COMMA expr                               { $$ = node("Destructuring", {$1, $3}); }
    | destructure_targets COMMA var_proto                 { $$ = add($1, $3); }
    | destructure_targets COMMA expr                      { $$ = add($1, $3); }
    ;

var_proto
    : KW_CONST IDENTIFIER type_opt                        { $$ = node("Variable declaration: const", {leaf($2), $3}); }
    | KW_VAR IDENTIFIER type_opt                          { $$ = node("Variable declaration: var", {leaf($2), $3}); }
    ;

    /* ---------------- Expressions ---------------- */

    /* An assignment is a statement, not an expression */

plain_assign
    : plain_expr
    | plain_expr assign_op full_expr                      { $$ = node(std::string("Assignment: ") + $2, {$1, $3}); }
    ;

assign_expr
    : expr
    | expr assign_op full_expr                            { $$ = node(std::string("Assignment: ") + $2, {$1, $3}); }
    ;

full_expr
    : expr
    | labeled_expr
    ;

labeled_expr
    : IDENTIFIER COLON block                              { $$ = labeled($1, $3); }
    | IDENTIFIER COLON loop_expr                          { $$ = labeled($1, $3); }
    | IDENTIFIER COLON switch_expr                        { $$ = labeled($1, $3); }
    ;

expr
    : expr KW_OR expr                                     { $$ = binary("or", $1, $3); }
    | expr KW_OR labeled_expr                             { $$ = binary("or", $1, $3); }
    | expr KW_AND expr                                    { $$ = binary("and", $1, $3); }
    | expr KW_AND labeled_expr                            { $$ = binary("and", $1, $3); }
    | expr compare_op expr %prec EQUAL_EQUAL              { $$ = binary($2, $1, $3); }
    | expr bitwise_op expr %prec AMPERSAND                { $$ = binary($2, $1, $3); }
    | expr KW_CATCH payload_opt expr                      { $$ = node("Binary operator: catch", {$1, $3, $4}); }
    | expr KW_CATCH payload_opt labeled_expr              { $$ = node("Binary operator: catch", {$1, $3, $4}); }
    | expr KW_ORELSE expr                                 { $$ = binary("orelse", $1, $3); }
    | expr KW_ORELSE labeled_expr                         { $$ = binary("orelse", $1, $3); }
    | expr bit_shift_op expr %prec SHL                    { $$ = binary($2, $1, $3); }
    | expr addition_op expr %prec PLUS                    { $$ = binary($2, $1, $3); }
    | expr multiply_op expr %prec ASTERISK                { $$ = binary($2, $1, $3); }
    | prefix_expr
    ;

    /* The same as expr, but not starting with if, while, for, switch, a block, return, */
    /* break, continue or comptime: at the start of a statement these are statements.  */

plain_expr
    : plain_expr KW_OR expr                               { $$ = binary("or", $1, $3); }
    | plain_expr KW_OR labeled_expr                       { $$ = binary("or", $1, $3); }
    | plain_expr KW_AND expr                              { $$ = binary("and", $1, $3); }
    | plain_expr KW_AND labeled_expr                      { $$ = binary("and", $1, $3); }
    | plain_expr compare_op expr %prec EQUAL_EQUAL        { $$ = binary($2, $1, $3); }
    | plain_expr bitwise_op expr %prec AMPERSAND          { $$ = binary($2, $1, $3); }
    | plain_expr KW_CATCH payload_opt expr                { $$ = node("Binary operator: catch", {$1, $3, $4}); }
    | plain_expr KW_CATCH payload_opt labeled_expr        { $$ = node("Binary operator: catch", {$1, $3, $4}); }
    | plain_expr KW_ORELSE expr                           { $$ = binary("orelse", $1, $3); }
    | plain_expr KW_ORELSE labeled_expr                   { $$ = binary("orelse", $1, $3); }
    | plain_expr bit_shift_op expr %prec SHL              { $$ = binary($2, $1, $3); }
    | plain_expr addition_op expr %prec PLUS              { $$ = binary($2, $1, $3); }
    | plain_expr multiply_op expr %prec ASTERISK          { $$ = binary($2, $1, $3); }
    | prefix_op prefix_expr                               { $$ = node(std::string("Unary operator: ") + $1, {$2}); }
    | curly_expr
    ;

assign_op
    : EQUAL                                               { $$ = "="; }
    | PLUS_EQUAL                                          { $$ = "+="; }
    | MINUS_EQUAL                                         { $$ = "-="; }
    | ASTERISK_EQUAL                                      { $$ = "*="; }
    | SLASH_EQUAL                                         { $$ = "/="; }
    | PERCENT_EQUAL                                       { $$ = "%="; }
    | AMPERSAND_EQUAL                                     { $$ = "&="; }
    | PIPE_EQUAL                                          { $$ = "|="; }
    | CARET_EQUAL                                         { $$ = "^="; }
    | SHL_EQUAL                                           { $$ = "<<="; }
    | SHR_EQUAL                                           { $$ = ">>="; }
    | PLUS_PERCENT_EQUAL                                  { $$ = "+%="; }
    | MINUS_PERCENT_EQUAL                                 { $$ = "-%="; }
    | ASTERISK_PERCENT_EQUAL                              { $$ = "*%="; }
    | PLUS_PIPE_EQUAL                                     { $$ = "+|="; }
    | MINUS_PIPE_EQUAL                                    { $$ = "-|="; }
    | ASTERISK_PIPE_EQUAL                                 { $$ = "*|="; }
    | SHL_PIPE_EQUAL                                      { $$ = "<<|="; }
    ;

compare_op
    : EQUAL_EQUAL                                         { $$ = "=="; }
    | BANG_EQUAL                                          { $$ = "!="; }
    | LESS                                                { $$ = "<"; }
    | GREATER                                             { $$ = ">"; }
    | LESS_EQUAL                                          { $$ = "<="; }
    | GREATER_EQUAL                                       { $$ = ">="; }
    ;

bitwise_op
    : AMPERSAND                                           { $$ = "&"; }
    | CARET                                               { $$ = "^"; }
    | PIPE                                                { $$ = "|"; }
    ;

bit_shift_op
    : SHL                                                 { $$ = "<<"; }
    | SHR                                                 { $$ = ">>"; }
    | SHL_PIPE                                            { $$ = "<<|"; }
    ;

addition_op
    : PLUS                                                { $$ = "+"; }
    | MINUS                                               { $$ = "-"; }
    | PLUS_PLUS                                           { $$ = "++"; }
    | PLUS_PERCENT                                        { $$ = "+%"; }
    | MINUS_PERCENT                                       { $$ = "-%"; }
    | PLUS_PIPE                                           { $$ = "+|"; }
    | MINUS_PIPE                                          { $$ = "-|"; }
    ;

multiply_op
    : ASTERISK                                            { $$ = "*"; }
    | SLASH                                               { $$ = "/"; }
    | PERCENT                                             { $$ = "%"; }
    | ASTERISK_ASTERISK                                   { $$ = "**"; }
    | ASTERISK_PERCENT                                    { $$ = "*%"; }
    | ASTERISK_PIPE                                       { $$ = "*|"; }
    | PIPE_PIPE                                           { $$ = "||"; }
    ;

prefix_expr
    : prefix_op prefix_expr                               { $$ = node(std::string("Unary operator: ") + $1, {$2}); }
    | primary_expr
    ;

prefix_op
    : BANG                                                { $$ = "!"; }
    | MINUS                                               { $$ = "-"; }
    | TILDE                                               { $$ = "~"; }
    | MINUS_PERCENT                                       { $$ = "-%"; }
    | AMPERSAND                                           { $$ = "&"; }
    | KW_TRY                                              { $$ = "try"; }
    ;

primary_expr
    : curly_expr
    | block
    | if_expr
    | loop_expr
    | switch_expr
    | jump
    | KW_COMPTIME branch                                  { $$ = node("Comptime", {$2}); }
    ;

jump
    : KW_RETURN                                           { $$ = new Node("Return"); }
    | KW_RETURN branch                                    { $$ = node("Return", {$2}); }
    | KW_BREAK break_label                                { $$ = node("Break", {$2}); }
    | KW_BREAK break_label branch                         { $$ = node("Break", {$2, $3}); }
    | KW_CONTINUE break_label                             { $$ = node("Continue", {$2}); }
    | KW_CONTINUE break_label branch                      { $$ = node("Continue", {$2, $3}); }
    ;

    /* What an if/else, a loop or a jump ends with */

branch
    : expr %prec LOWER_THAN_ELSE
    | labeled_expr
    ;

break_label
    : %empty %prec KW_BREAK                               { $$ = nullptr; }
    | COLON IDENTIFIER                                    { $$ = node("Label", {leaf($2)}); }
    ;

if_expr
    : if_prefix branch %prec LOWER_THAN_ELSE              { $$ = add($1, $2); }
    | if_prefix branch KW_ELSE payload_opt branch         { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    ;

loop_expr
    : for_expr
    | while_expr
    | KW_INLINE for_expr                                  { $$ = prepend($2, new Node("Keyword: inline")); }
    | KW_INLINE while_expr                                { $$ = prepend($2, new Node("Keyword: inline")); }
    ;

for_expr
    : for_prefix branch %prec LOWER_THAN_ELSE             { $$ = add($1, $2); }
    | for_prefix branch KW_ELSE branch                    { $$ = add(add($1, $2), node("Else", {$4})); }
    ;

while_expr
    : while_prefix branch %prec LOWER_THAN_ELSE           { $$ = add($1, $2); }
    | while_prefix branch KW_ELSE payload_opt branch      { $$ = add(add($1, $2), node("Else", {$4, $5})); }
    ;

switch_expr
    : KW_SWITCH LPAREN full_expr RPAREN LBRACE switch_prongs RBRACE
                                                          { $$ = prepend($6, $3); }
    ;

switch_prongs
    : %empty                                              { $$ = new Node("Switch"); }
    | prong_list comma_opt
    ;

prong_list
    : switch_prong                                        { $$ = node("Switch", {$1}); }
    | prong_list COMMA switch_prong                       { $$ = add($1, $3); }
    ;

switch_prong
    : switch_case EQUAL_ARROW capture_opt prong_body      { $$ = node("Prong", {$1, $3, $4}); }
    | KW_INLINE switch_case EQUAL_ARROW capture_opt prong_body
                                                          { $$ = node("Prong", {new Node("Keyword: inline"), $2, $4, $5}); }
    ;

switch_case
    : KW_ELSE                                             { $$ = node("Cases", {new Node("Keyword: else")}); }
    | switch_items
    | switch_items COMMA
    ;

switch_items
    : switch_item                                         { $$ = node("Cases", {$1}); }
    | switch_items COMMA switch_item                      { $$ = add($1, $3); }
    ;

switch_item
    : plain_expr
    | plain_expr ELLIPSIS3 expr                           { $$ = node("Range", {$1, $3}); }
    ;

prong_body
    : full_expr
    | expr assign_op full_expr                            { $$ = node(std::string("Assignment: ") + $2, {$1, $3}); }
    ;

    /* 'T{...}' - a value of type T */

curly_expr
    : type_expr
    | type_expr init_list                                 { $$ = prepend($2, node("Type", {$1})); }
    ;

    /* Type operators bind looser than 'A!B': '?A!B' is '?(A!B)'. A function type takes */
    /* all that follows as its return type: 'fn () A!B' returns 'A!B'.                  */

type_expr
    : error_union_expr
    | KW_FN LPAREN parameters RPAREN align_opt addrspace_opt linksection_opt callconv_opt return_type
                                                          { $$ = node("Function type", {$3, $5, $6, $7, $8, $9}); }
    | QUESTION type_expr                                  { $$ = node("Optional type", {$2}); }
    | ASTERISK pointer_modifiers type_expr                { $$ = pointer("Pointer type: *", $2, $3); }
    | ASTERISK_ASTERISK pointer_modifiers type_expr       { $$ = node("Pointer type: *", {pointer("Pointer type: *", $2, $3)}); }
    | LBRACKET RBRACKET pointer_modifiers type_expr       { $$ = pointer("Slice type", $3, $4); }
    | LBRACKET COLON expr RBRACKET pointer_modifiers type_expr
                                                          { $$ = prepend(pointer("Slice type", $5, $6), node("Sentinel", {$3})); }
    | LBRACKET ASTERISK RBRACKET pointer_modifiers type_expr
                                                          { $$ = pointer("Pointer type: [*]", $4, $5); }
    | LBRACKET ASTERISK COLON expr RBRACKET pointer_modifiers type_expr
                                                          { $$ = prepend(pointer("Pointer type: [*]", $6, $7), node("Sentinel", {$4})); }
    | LBRACKET ASTERISK IDENTIFIER RBRACKET pointer_modifiers type_expr
                                                          {
                                                              if (*$3 != "Identifier: c") {
                                                                  delete $3; delete $5; delete $6;
                                                                  yyerror("syntax error, expected 'c' in '[*c]'");
                                                                  YYERROR;
                                                              }

                                                              delete $3;
                                                              $$ = pointer("Pointer type: [*c]", $5, $6);
                                                          }
    | LBRACKET expr RBRACKET type_expr                    { $$ = node("Array type", {node("Length", {$2}), $4}); }
    | LBRACKET expr COLON expr RBRACKET type_expr         { $$ = node("Array type", {node("Length", {$2}), node("Sentinel", {$4}), $6}); }
    ;

pointer_modifiers
    : %empty                                              { $$ = new Node("Modifiers"); }
    | pointer_modifiers KW_CONST                          { $$ = add($1, new Node("Keyword: const")); }
    | pointer_modifiers KW_VOLATILE                       { $$ = add($1, new Node("Keyword: volatile")); }
    | pointer_modifiers KW_ALLOWZERO                      { $$ = add($1, new Node("Keyword: allowzero")); }
    | pointer_modifiers KW_ALIGN LPAREN expr RPAREN       { $$ = add($1, node("Align", {$4})); }
    | pointer_modifiers KW_ADDRSPACE LPAREN expr RPAREN   { $$ = add($1, node("Address space", {$4})); }
    ;

error_union_expr
    : suffix_expr
    | suffix_expr BANG type_expr                          { $$ = node("Error union type", {$1, $3}); }
    ;

suffix_expr
    : primary_type_expr
    | suffix_expr LBRACKET expr RBRACKET                  { $$ = node("Index", {$1, $3}); }
    | suffix_expr LBRACKET expr ELLIPSIS2 RBRACKET        { $$ = node("Slice", {$1, $3}); }
    | suffix_expr LBRACKET expr ELLIPSIS2 expr RBRACKET   { $$ = node("Slice", {$1, $3, $5}); }
    | suffix_expr LBRACKET expr ELLIPSIS2 expr COLON expr RBRACKET
                                                          { $$ = node("Slice", {$1, $3, $5, node("Sentinel", {$7})}); }
    | suffix_expr DOT name                                { $$ = node("Member access", {$1, $3}); }
    | suffix_expr DOT_ASTERISK                            { $$ = node("Dereference", {$1}); }
    | suffix_expr DOT_QUESTION                            { $$ = node("Optional unwrap", {$1}); }
    | suffix_expr LPAREN arguments RPAREN                 { $$ = prepend(rename($3, "Call"), $1); }
    ;

arguments
    : %empty                                              { $$ = new Node("Arguments"); }
    | argument_list comma_opt
    ;

argument_list
    : full_expr                                           { $$ = node("Arguments", {$1}); }
    | argument_list COMMA full_expr                       { $$ = add($1, $3); }
    ;

primary_type_expr
    : INTEGER_LITERAL                                     { $$ = leaf($1); }
    | FLOAT_LITERAL                                       { $$ = leaf($1); }
    | CHAR_LITERAL                                        { $$ = leaf($1); }
    | STRING_LITERAL                                      { $$ = leaf($1); }
    | MULTILINE_STRING_LITERAL                            { $$ = leaf($1); }
    | KW_TRUE                                             { $$ = leaf($1); }
    | KW_FALSE                                            { $$ = leaf($1); }
    | KW_NULL                                             { $$ = leaf($1); }
    | KW_UNDEFINED                                        { $$ = leaf($1); }
    | KW_UNREACHABLE                                      { $$ = new Node("Unreachable"); }
    | IDENTIFIER %prec IDENTIFIER_OPERAND                 { $$ = leaf($1); }
    | PRIMITIVE_TYPE                                      { $$ = leaf($1); }
    | BUILTIN LPAREN arguments RPAREN                     { $$ = prepend(rename($3, "Builtin call"), leaf($1)); }
    | LPAREN full_expr RPAREN                             { $$ = $2; }
    | DOT name                                            { $$ = node("Enum literal", {$2}); }
    | DOT init_list                                       { $$ = rename($2, "Anonymous initializer"); }
    | KW_ERROR DOT name                                   { $$ = node("Error value", {$3}); }
    | KW_ERROR LBRACE error_names RBRACE                  { $$ = $3; }
    | container_decl
    ;

    /* A field or declaration name. Fields may be named like primitives: 'type', 'bool', 'null' */

name
    : IDENTIFIER                                          { $$ = leaf($1); }
    | PRIMITIVE_TYPE                                      { $$ = leaf($1); }
    | KW_TRUE                                             { $$ = leaf($1); }
    | KW_FALSE                                            { $$ = leaf($1); }
    | KW_NULL                                             { $$ = leaf($1); }
    | KW_UNDEFINED                                        { $$ = leaf($1); }
    ;

error_names
    : %empty                                              { $$ = new Node("Error set"); }
    | error_name_list comma_opt
    ;

error_name_list
    : IDENTIFIER                                          { $$ = node("Error set", {leaf($1)}); }
    | error_name_list COMMA IDENTIFIER                    { $$ = add($1, leaf($3)); }
    ;

container_decl
    : container_kind LBRACE container_members RBRACE      { $$ = concat($1, $3); }
    | KW_EXTERN container_kind LBRACE container_members RBRACE
                                                          { $$ = concat(prepend($2, new Node("Keyword: extern")), $4); }
    | KW_PACKED container_kind LBRACE container_members RBRACE
                                                          { $$ = concat(prepend($2, new Node("Keyword: packed")), $4); }
    ;

container_kind
    : KW_STRUCT                                           { $$ = new Node("Struct"); }
    | KW_STRUCT LPAREN expr RPAREN                        { $$ = node("Struct", {node("Backing type", {$3})}); }
    | KW_OPAQUE                                           { $$ = new Node("Opaque"); }
    | KW_ENUM                                             { $$ = new Node("Enum"); }
    | KW_ENUM LPAREN expr RPAREN                          { $$ = node("Enum", {node("Tag type", {$3})}); }
    | KW_UNION                                            { $$ = new Node("Union"); }
    | KW_UNION LPAREN KW_ENUM RPAREN                      { $$ = node("Union", {new Node("Tag type: enum")}); }
    | KW_UNION LPAREN KW_ENUM LPAREN expr RPAREN RPAREN   { $$ = node("Union", {node("Tag type: enum", {$5})}); }
    | KW_UNION LPAREN expr RPAREN                         { $$ = node("Union", {node("Tag type", {$3})}); }
    ;

init_list
    : LBRACE RBRACE                                       { $$ = new Node("Initializer"); }
    | LBRACE field_inits comma_opt RBRACE                 { $$ = $2; }
    | LBRACE init_elements comma_opt RBRACE               { $$ = $2; }
    ;

field_inits
    : field_init                                          { $$ = node("Initializer", {$1}); }
    | field_inits COMMA field_init                        { $$ = add($1, $3); }
    ;

field_init
    : DOT name EQUAL full_expr                            { $$ = node("Field initializer", {$2, $4}); }
    ;

init_elements
    : full_expr                                           { $$ = node("Initializer", {$1}); }
    | init_elements COMMA full_expr                       { $$ = add($1, $3); }
    ;

    /* |x|, |*x|, |x, i| after if, while, for and switch prongs */

capture_opt
    : %empty                                              { $$ = nullptr; }
    | capture
    ;

capture
    : PIPE captures comma_opt PIPE                        { $$ = $2; }
    ;

captures
    : capture_item                                        { $$ = node("Capture", {$1}); }
    | captures COMMA capture_item                         { $$ = add($1, $3); }
    ;

capture_item
    : IDENTIFIER                                          { $$ = leaf($1); }
    | ASTERISK IDENTIFIER                                 { $$ = node("Pointer capture", {leaf($2)}); }
    ;

    /* |err| after catch, else and errdefer */

payload_opt
    : %empty                                              { $$ = nullptr; }
    | PIPE IDENTIFIER PIPE                                { $$ = node("Capture", {leaf($2)}); }
    ;

comma_opt
    : %empty
    | COMMA
    ;

%%

void yyerror(const char* message) {
    report(yylineno, message);
}

/*! Make a node. Absent optional parts are passed as nullptr and skipped. */
static Node* node(const std::string& label, std::initializer_list<Node*> children) {
    Node* result = new Node(label);

    for (Node* child : children) {
        add(result, child);
    }

    return result;
}

/*! Make a leaf from a token: its label is the text the lexer prints for it. */
static Node* leaf(std::string* text) {
    Node* result = new Node(*text);
    delete text;
    return result;
}

static Node* add(Node* parent, Node* child) {
    if (child) {
        parent->children.push_back(child);
    }

    return parent;
}

static Node* prepend(Node* parent, Node* child) {
    if (child) {
        parent->children.insert(parent->children.begin(), child);
    }

    return parent;
}

static Node* rename(Node* list, const std::string& label) {
    list->label = label;
    return list;
}

/*! Move the children of tail to the end of list. */
static Node* concat(Node* list, Node* tail) {
    list->children.insert(list->children.end(), tail->children.begin(), tail->children.end());
    tail->children.clear();
    delete tail;
    return list;
}

/*! Put the modifiers of a declaration (pub, extern...) first among its children. */
static Node* modify(Node* declaration, Node* pub, Node* modifiers) {
    declaration->children.insert(declaration->children.begin(), modifiers->children.begin(), modifiers->children.end());
    modifiers->children.clear();
    delete modifiers;
    return prepend(declaration, pub);
}

/*! 'label: construct' - the label goes first among the children. */
static Node* labeled(std::string* label, Node* construct) {
    return prepend(construct, node("Label", {leaf(label)}));
}

static Node* binary(const char* op, Node* left, Node* right) {
    return node(std::string("Binary operator: ") + op, {left, right});
}

/*! A pointer or slice type: its modifiers (const, align...), then the element type. */
static Node* pointer(const std::string& label, Node* modifiers, Node* element) {
    return add(concat(new Node(label), modifiers), element);
}

/*! Show control characters of strings and chars as escapes, to keep one node per line. */
static std::string escape(const std::string& text) {
    std::string result;

    for (char c : text) {
        switch (c) {
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default:   result += c;
        }
    }

    return result;
}

static void print_tree(const Node* node, int depth) {
    std::cout << std::string(2 * depth, ' ') << escape(node->label) << '\n';

    for (const Node* child : node->children) {
        print_tree(child, depth + 1);
    }
}

/*! Print a node and its subtree as DOT statements.
 *  \return the number of the node, used in the edges.
 */
static int print_dot(const Node* node, int& count) {
    int id = count++;
    std::string label;

    for (char c : escape(node->label)) {
        if (c == '"' || c == '\\') label += '\\';
        label += c;
    }

    std::cout << "    node" << id << " [label=\"" << label << "\"];\n";

    for (const Node* child : node->children) {
        int child_id = print_dot(child, count);
        std::cout << "    node" << id << " -> node" << child_id << ";\n";
    }

    return id;
}

int main(int argc, char* argv[]) {
    extern FILE* yyin;
    extern bool print_tokens;
    extern int error_count;

    std::string mode = argc == 3 ? argv[1] : "";

    if ((argc != 2 && argc != 3) || (argc == 3 && mode != "--tokens" && mode != "--dot")) {
        std::cerr << "Usage: " << argv[0] << " [--tokens | --dot] <source file>\n";
        return 1;
    }

    yyin = fopen(argv[argc - 1], "r");

    if (!yyin) {
        std::cout << "File was not found!\n";
        return 1;
    }

    if (mode == "--tokens") {
        print_tokens = true;

        for (yylval.text = nullptr; yylex() != 0; yylval.text = nullptr) {
            delete yylval.text;
        }
    } else if (yyparse() == 0 && error_count == 0) {
        if (mode == "--dot") {
            int count = 0;
            std::cout << "digraph G {\n";
            print_dot(tree, count);
            std::cout << "}\n";
        } else {
            print_tree(tree, 0);
        }
    }

    delete tree;
    fclose(yyin);
    return error_count == 0 ? 0 : 1;
}
