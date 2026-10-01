/* Grammar rules of Zig 0.17 for the lexer in lexer.l. No semantic actions yet.
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
 */

%{
int yylex();
void yyerror(const char* message);
%}

%token END 0 "end of file"

%token IDENTIFIER "identifier"
%token BUILTIN "builtin function"
%token PRIMITIVE_TYPE "primitive type"
%token INTEGER_LITERAL "integer literal"
%token FLOAT_LITERAL "float literal"
%token CHAR_LITERAL "character literal"
%token STRING_LITERAL "string literal"
%token MULTILINE_STRING_LITERAL "multiline string literal"
%token KW_TRUE "'true'" KW_FALSE "'false'" KW_NULL "'null'" KW_UNDEFINED "'undefined'"

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

%%

source_file
    : container_members
    ;

    /* ---------------- Members of a file, struct, enum, union or opaque ---------------- */

    /* Declarations, fields, then declarations again: Zig allows no declaration between fields */

container_members
    : declarations
    | declarations fields
    ;

declarations
    : %empty
    | declarations declaration
    ;

nonempty_declarations
    : declaration
    | nonempty_declarations declaration
    ;

fields
    : field
    | field COMMA
    | field COMMA fields
    | field COMMA nonempty_declarations
    ;

    /* A struct or union field has a type; an enum field has only a name and maybe a value */

field
    : name value_opt
    | name COLON decl_type align_opt value_opt
    | KW_COMPTIME name COLON decl_type align_opt value_opt
    ;

value_opt
    : %empty
    | EQUAL full_expr
    ;

declaration
    : pub_opt fn_modifiers fn_proto block
    | pub_opt fn_modifiers fn_proto SEMICOLON
    | pub_opt var_modifiers var_declaration
    | KW_COMPTIME block
    | KW_TEST STRING_LITERAL block
    | KW_TEST IDENTIFIER block
    | KW_TEST block
    ;

pub_opt
    : %empty
    | KW_PUB
    ;

linkage
    : %empty
    | KW_EXPORT
    | KW_EXTERN
    | KW_EXTERN STRING_LITERAL
    ;

fn_modifiers
    : linkage
    | KW_INLINE
    | KW_NOINLINE
    ;

var_modifiers
    : linkage
    | linkage KW_THREADLOCAL
    ;

var_declaration
    : KW_CONST IDENTIFIER type_opt align_opt addrspace_opt linksection_opt value_opt SEMICOLON
    | KW_VAR IDENTIFIER type_opt align_opt addrspace_opt linksection_opt value_opt SEMICOLON
    ;

type_opt
    : %empty
    | COLON decl_type
    ;

align_opt
    : %empty
    | KW_ALIGN LPAREN expr RPAREN
    ;

addrspace_opt
    : %empty
    | KW_ADDRSPACE LPAREN expr RPAREN
    ;

linksection_opt
    : %empty
    | KW_LINKSECTION LPAREN expr RPAREN
    ;

    /* The type of a declaration, a field, a parameter or a returned value */
    /* may also be chosen by if or switch                                  */

decl_type
    : type_expr
    | if_type_expr
    | switch_expr
    | QUESTION if_type_expr
    ;

if_type_expr
    : if_prefix decl_type %prec LOWER_THAN_ELSE
    | if_prefix decl_type KW_ELSE payload_opt decl_type
    ;

    /* ---------------- Functions ---------------- */

fn_proto
    : KW_FN IDENTIFIER LPAREN parameters RPAREN align_opt addrspace_opt linksection_opt callconv_opt return_type
    ;

callconv_opt
    : %empty
    | KW_CALLCONV LPAREN expr RPAREN
    ;

    /* '!T' returns T or an error of a set the compiler infers */

return_type
    : decl_type
    | BANG decl_type
    ;

parameters
    : %empty
    | parameter_list
    | parameter_list COMMA
    ;

parameter_list
    : parameter
    | parameter_list COMMA parameter
    ;

parameter
    : param_modifier name COLON param_type
    | param_modifier param_type
    | ELLIPSIS3
    ;

param_modifier
    : %empty
    | KW_COMPTIME
    | KW_NOALIAS
    ;

param_type
    : decl_type
    | KW_ANYTYPE
    ;

    /* ---------------- Statements ---------------- */

block
    : LBRACE statements RBRACE
    ;

statements
    : %empty
    | statements statement
    ;

statement
    : var_declaration
    | KW_COMPTIME var_declaration
    | KW_COMPTIME block_expr
    | KW_COMPTIME body_expr SEMICOLON
    | KW_DEFER block_expr
    | KW_DEFER body_expr SEMICOLON
    | KW_ERRDEFER payload_opt block_expr
    | KW_ERRDEFER payload_opt body_expr SEMICOLON
    | if_statement
    | loop_statement
    | IDENTIFIER COLON loop_statement
    | switch_expr
    | IDENTIFIER COLON switch_expr
    | block_expr
    | jump SEMICOLON
    | destructure SEMICOLON
    | plain_assign SEMICOLON
    ;

block_expr
    : block
    | IDENTIFIER COLON block
    ;

    /* The body of if, while, for or defer that is not a block: ';' or 'else' comes after it */

body_expr
    : plain_assign
    | jump
    | if_expr
    | loop_expr
    | switch_expr
    | IDENTIFIER COLON loop_expr
    | IDENTIFIER COLON switch_expr
    | KW_COMPTIME branch
    ;

if_statement
    : if_prefix block_expr %prec LOWER_THAN_ELSE
    | if_prefix block_expr KW_ELSE payload_opt statement
    | if_prefix body_expr SEMICOLON
    | if_prefix body_expr KW_ELSE payload_opt statement
    ;

if_prefix
    : KW_IF LPAREN full_expr RPAREN capture_opt
    ;

loop_statement
    : for_statement
    | while_statement
    | KW_INLINE for_statement
    | KW_INLINE while_statement
    ;

for_statement
    : for_prefix block_expr %prec LOWER_THAN_ELSE
    | for_prefix block_expr KW_ELSE statement
    | for_prefix body_expr SEMICOLON
    | for_prefix body_expr KW_ELSE statement
    ;

while_statement
    : while_prefix block_expr %prec LOWER_THAN_ELSE
    | while_prefix block_expr KW_ELSE payload_opt statement
    | while_prefix body_expr SEMICOLON
    | while_prefix body_expr KW_ELSE payload_opt statement
    ;

for_prefix
    : KW_FOR LPAREN for_inputs comma_opt RPAREN capture
    ;

for_inputs
    : for_input
    | for_inputs COMMA for_input
    ;

for_input
    : expr
    | expr ELLIPSIS2
    | expr ELLIPSIS2 expr
    ;

while_prefix
    : KW_WHILE LPAREN full_expr RPAREN capture_opt continue_opt
    ;

continue_opt
    : %empty
    | COLON LPAREN assign_expr RPAREN
    ;

    /* 'const a, var b: T, c.d = f();' */

destructure
    : destructure_targets EQUAL full_expr
    ;

destructure_targets
    : var_proto COMMA var_proto
    | var_proto COMMA expr
    | plain_expr COMMA var_proto
    | plain_expr COMMA expr
    | destructure_targets COMMA var_proto
    | destructure_targets COMMA expr
    ;

var_proto
    : KW_CONST IDENTIFIER type_opt
    | KW_VAR IDENTIFIER type_opt
    ;

    /* ---------------- Expressions ---------------- */

    /* An assignment is a statement, not an expression */

plain_assign
    : plain_expr
    | plain_expr assign_op full_expr
    ;

assign_expr
    : expr
    | expr assign_op full_expr
    ;

full_expr
    : expr
    | labeled_expr
    ;

labeled_expr
    : IDENTIFIER COLON block
    | IDENTIFIER COLON loop_expr
    | IDENTIFIER COLON switch_expr
    ;

expr
    : expr KW_OR expr
    | expr KW_OR labeled_expr
    | expr KW_AND expr
    | expr KW_AND labeled_expr
    | expr compare_op expr %prec EQUAL_EQUAL
    | expr bitwise_op expr %prec AMPERSAND
    | expr KW_CATCH payload_opt expr
    | expr KW_CATCH payload_opt labeled_expr
    | expr KW_ORELSE expr
    | expr KW_ORELSE labeled_expr
    | expr bit_shift_op expr %prec SHL
    | expr addition_op expr %prec PLUS
    | expr multiply_op expr %prec ASTERISK
    | prefix_expr
    ;

    /* The same as expr, but not starting with if, while, for, switch, a block, return, */
    /* break, continue or comptime: at the start of a statement these are statements.  */

plain_expr
    : plain_expr KW_OR expr
    | plain_expr KW_OR labeled_expr
    | plain_expr KW_AND expr
    | plain_expr KW_AND labeled_expr
    | plain_expr compare_op expr %prec EQUAL_EQUAL
    | plain_expr bitwise_op expr %prec AMPERSAND
    | plain_expr KW_CATCH payload_opt expr
    | plain_expr KW_CATCH payload_opt labeled_expr
    | plain_expr KW_ORELSE expr
    | plain_expr KW_ORELSE labeled_expr
    | plain_expr bit_shift_op expr %prec SHL
    | plain_expr addition_op expr %prec PLUS
    | plain_expr multiply_op expr %prec ASTERISK
    | prefix_op prefix_expr
    | curly_expr
    ;

assign_op
    : EQUAL
    | PLUS_EQUAL
    | MINUS_EQUAL
    | ASTERISK_EQUAL
    | SLASH_EQUAL
    | PERCENT_EQUAL
    | AMPERSAND_EQUAL
    | PIPE_EQUAL
    | CARET_EQUAL
    | SHL_EQUAL
    | SHR_EQUAL
    | PLUS_PERCENT_EQUAL
    | MINUS_PERCENT_EQUAL
    | ASTERISK_PERCENT_EQUAL
    | PLUS_PIPE_EQUAL
    | MINUS_PIPE_EQUAL
    | ASTERISK_PIPE_EQUAL
    | SHL_PIPE_EQUAL
    ;

compare_op
    : EQUAL_EQUAL
    | BANG_EQUAL
    | LESS
    | GREATER
    | LESS_EQUAL
    | GREATER_EQUAL
    ;

bitwise_op
    : AMPERSAND
    | CARET
    | PIPE
    ;

bit_shift_op
    : SHL
    | SHR
    | SHL_PIPE
    ;

addition_op
    : PLUS
    | MINUS
    | PLUS_PLUS
    | PLUS_PERCENT
    | MINUS_PERCENT
    | PLUS_PIPE
    | MINUS_PIPE
    ;

multiply_op
    : ASTERISK
    | SLASH
    | PERCENT
    | ASTERISK_ASTERISK
    | ASTERISK_PERCENT
    | ASTERISK_PIPE
    | PIPE_PIPE
    ;

prefix_expr
    : prefix_op prefix_expr
    | primary_expr
    ;

prefix_op
    : BANG
    | MINUS
    | TILDE
    | MINUS_PERCENT
    | AMPERSAND
    | KW_TRY
    ;

primary_expr
    : curly_expr
    | block
    | if_expr
    | loop_expr
    | switch_expr
    | jump
    | KW_COMPTIME branch
    ;

jump
    : KW_RETURN
    | KW_RETURN branch
    | KW_BREAK break_label
    | KW_BREAK break_label branch
    | KW_CONTINUE break_label
    | KW_CONTINUE break_label branch
    ;

    /* What an if/else, a loop or a jump ends with */

branch
    : expr %prec LOWER_THAN_ELSE
    | labeled_expr
    ;

break_label
    : %empty %prec KW_BREAK
    | COLON IDENTIFIER
    ;

if_expr
    : if_prefix branch %prec LOWER_THAN_ELSE
    | if_prefix branch KW_ELSE payload_opt branch
    ;

loop_expr
    : for_expr
    | while_expr
    | KW_INLINE for_expr
    | KW_INLINE while_expr
    ;

for_expr
    : for_prefix branch %prec LOWER_THAN_ELSE
    | for_prefix branch KW_ELSE branch
    ;

while_expr
    : while_prefix branch %prec LOWER_THAN_ELSE
    | while_prefix branch KW_ELSE payload_opt branch
    ;

switch_expr
    : KW_SWITCH LPAREN full_expr RPAREN LBRACE switch_prongs RBRACE
    ;

switch_prongs
    : %empty
    | prong_list comma_opt
    ;

prong_list
    : switch_prong
    | prong_list COMMA switch_prong
    ;

switch_prong
    : switch_case EQUAL_ARROW capture_opt prong_body
    | KW_INLINE switch_case EQUAL_ARROW capture_opt prong_body
    ;

switch_case
    : KW_ELSE
    | switch_items
    | switch_items COMMA
    ;

switch_items
    : switch_item
    | switch_items COMMA switch_item
    ;

switch_item
    : plain_expr
    | plain_expr ELLIPSIS3 expr
    ;

prong_body
    : full_expr
    | expr assign_op full_expr
    ;

    /* 'T{...}' - a value of type T */

curly_expr
    : type_expr
    | type_expr init_list
    ;

    /* Type operators bind looser than 'A!B': '?A!B' is '?(A!B)'. A function type takes */
    /* all that follows as its return type: 'fn () A!B' returns 'A!B'.                  */

type_expr
    : error_union_expr
    | KW_FN LPAREN parameters RPAREN align_opt addrspace_opt linksection_opt callconv_opt return_type
    | QUESTION type_expr
    | ASTERISK pointer_modifiers type_expr
    | ASTERISK_ASTERISK pointer_modifiers type_expr
    | LBRACKET RBRACKET pointer_modifiers type_expr
    | LBRACKET COLON expr RBRACKET pointer_modifiers type_expr
    | LBRACKET ASTERISK RBRACKET pointer_modifiers type_expr
    | LBRACKET ASTERISK COLON expr RBRACKET pointer_modifiers type_expr
    | LBRACKET ASTERISK IDENTIFIER RBRACKET pointer_modifiers type_expr    /* the identifier must be c */
    | LBRACKET expr RBRACKET type_expr
    | LBRACKET expr COLON expr RBRACKET type_expr
    ;

pointer_modifiers
    : %empty
    | pointer_modifiers KW_CONST
    | pointer_modifiers KW_VOLATILE
    | pointer_modifiers KW_ALLOWZERO
    | pointer_modifiers KW_ALIGN LPAREN expr RPAREN
    | pointer_modifiers KW_ADDRSPACE LPAREN expr RPAREN
    ;

error_union_expr
    : suffix_expr
    | suffix_expr BANG type_expr
    ;

suffix_expr
    : primary_type_expr
    | suffix_expr LBRACKET expr RBRACKET
    | suffix_expr LBRACKET expr ELLIPSIS2 RBRACKET
    | suffix_expr LBRACKET expr ELLIPSIS2 expr RBRACKET
    | suffix_expr LBRACKET expr ELLIPSIS2 expr COLON expr RBRACKET
    | suffix_expr DOT name
    | suffix_expr DOT_ASTERISK
    | suffix_expr DOT_QUESTION
    | suffix_expr LPAREN arguments RPAREN
    ;

arguments
    : %empty
    | argument_list comma_opt
    ;

argument_list
    : full_expr
    | argument_list COMMA full_expr
    ;

primary_type_expr
    : INTEGER_LITERAL
    | FLOAT_LITERAL
    | CHAR_LITERAL
    | STRING_LITERAL
    | MULTILINE_STRING_LITERAL
    | KW_TRUE
    | KW_FALSE
    | KW_NULL
    | KW_UNDEFINED
    | KW_UNREACHABLE
    | IDENTIFIER %prec IDENTIFIER_OPERAND
    | PRIMITIVE_TYPE
    | BUILTIN LPAREN arguments RPAREN
    | LPAREN full_expr RPAREN
    | DOT name
    | DOT init_list
    | KW_ERROR DOT name
    | KW_ERROR LBRACE error_names RBRACE
    | container_decl
    ;

    /* A field or declaration name. Fields may be named like primitives: 'type', 'bool', 'null' */

name
    : IDENTIFIER
    | PRIMITIVE_TYPE
    | KW_TRUE
    | KW_FALSE
    | KW_NULL
    | KW_UNDEFINED
    ;

error_names
    : %empty
    | error_name_list comma_opt
    ;

error_name_list
    : IDENTIFIER
    | error_name_list COMMA IDENTIFIER
    ;

container_decl
    : container_kind LBRACE container_members RBRACE
    | KW_EXTERN container_kind LBRACE container_members RBRACE
    | KW_PACKED container_kind LBRACE container_members RBRACE
    ;

container_kind
    : KW_STRUCT
    | KW_STRUCT LPAREN expr RPAREN
    | KW_OPAQUE
    | KW_ENUM
    | KW_ENUM LPAREN expr RPAREN
    | KW_UNION
    | KW_UNION LPAREN KW_ENUM RPAREN
    | KW_UNION LPAREN KW_ENUM LPAREN expr RPAREN RPAREN
    | KW_UNION LPAREN expr RPAREN
    ;

init_list
    : LBRACE RBRACE
    | LBRACE field_inits comma_opt RBRACE
    | LBRACE init_elements comma_opt RBRACE
    ;

field_inits
    : field_init
    | field_inits COMMA field_init
    ;

field_init
    : DOT name EQUAL full_expr
    ;

init_elements
    : full_expr
    | init_elements COMMA full_expr
    ;

    /* |x|, |*x|, |x, i| after if, while, for and switch prongs */

capture_opt
    : %empty
    | capture
    ;

capture
    : PIPE captures comma_opt PIPE
    ;

captures
    : capture_item
    | captures COMMA capture_item
    ;

capture_item
    : IDENTIFIER
    | ASTERISK IDENTIFIER
    ;

    /* |err| after catch, else and errdefer */

payload_opt
    : %empty
    | PIPE IDENTIFIER PIPE
    ;

comma_opt
    : %empty
    | COMMA
    ;

%%
