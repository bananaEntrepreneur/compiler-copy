/* Basic grammar rules of Zig 0.17 for the lexer in lexer.l. No semantic actions yet.
 *
 * The nonterminals are named after the grammar in the Zig language reference:
 * expr is Expr, prefix_expr is PrefixExpr, suffix_expr is SuffixExpr...
 *
 * if, switch and jumps are not operands of binary operators: they are values
 * (of a variable, an assignment, an argument, a return). So a statement that
 * starts with if or switch is always the if or switch statement.
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

    /* Binary operators, from the lowest precedence to the highest, as in the Zig reference */

%left KW_OR
%left KW_AND
%nonassoc EQUAL_EQUAL BANG_EQUAL LESS GREATER LESS_EQUAL GREATER_EQUAL
%left AMPERSAND CARET PIPE KW_ORELSE KW_CATCH
%left SHL SHR
%left PLUS MINUS PLUS_PLUS
%left ASTERISK SLASH PERCENT ASTERISK_ASTERISK

%%

source_file
    : container_members
    ;

    /* ---------------- Members of a file, struct, enum or union ---------------- */

container_members
    : members
    | members field
    ;

members
    : %empty
    | members declaration
    | members field COMMA
    ;

    /* A struct or union field has a type; an enum field has only a name and maybe a value */

field
    : IDENTIFIER
    | IDENTIFIER EQUAL value
    | IDENTIFIER COLON type_expr
    | IDENTIFIER COLON type_expr EQUAL value
    ;

declaration
    : pub_opt var_declaration
    | pub_opt fn_proto block
    | KW_TEST STRING_LITERAL block
    ;

pub_opt
    : %empty
    | KW_PUB
    ;

var_declaration
    : var_kind IDENTIFIER EQUAL value SEMICOLON
    | var_kind IDENTIFIER COLON type_expr EQUAL value SEMICOLON
    ;

var_kind
    : KW_CONST
    | KW_VAR
    ;

    /* ---------------- Functions ---------------- */

fn_proto
    : KW_FN IDENTIFIER LPAREN parameters RPAREN return_type
    ;

    /* '!T' returns T or an error of a set the compiler infers */

return_type
    : type_expr
    | BANG type_expr
    ;

parameters
    : %empty
    | parameter_list comma_opt
    ;

parameter_list
    : parameter
    | parameter_list COMMA parameter
    ;

parameter
    : IDENTIFIER COLON param_type
    | KW_COMPTIME IDENTIFIER COLON param_type
    ;

param_type
    : type_expr
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
    | block
    | if_statement
    | while_statement
    | for_statement
    | switch_expr
    | KW_DEFER body
    | KW_ERRDEFER payload_opt body
    | assign_expr SEMICOLON
    ;

    /* The body of a loop or defer */

body
    : block
    | assign_expr SEMICOLON
    ;

if_statement
    : if_prefix block
    | if_prefix block KW_ELSE payload_opt statement
    | if_prefix assign_expr SEMICOLON
    | if_prefix assign_expr KW_ELSE payload_opt statement
    ;

if_prefix
    : KW_IF LPAREN expr RPAREN capture_opt
    ;

while_statement
    : KW_WHILE LPAREN expr RPAREN capture_opt continue_opt body
    ;

continue_opt
    : %empty
    | COLON LPAREN assign_expr RPAREN
    ;

for_statement
    : KW_FOR LPAREN for_inputs comma_opt RPAREN capture body
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

    /* ---------------- Values ---------------- */

    /* An assignment is a statement, not an expression */

assign_expr
    : simple_value
    | expr assign_op value
    ;

value
    : simple_value
    | if_expr
    | switch_expr
    ;

    /* A value that may start a statement */

simple_value
    : expr
    | jump
    | expr KW_ORELSE jump
    | expr KW_CATCH payload_opt jump
    ;

jump
    : KW_RETURN
    | KW_RETURN value
    | KW_BREAK
    | KW_BREAK value
    | KW_CONTINUE
    ;

if_expr
    : if_prefix value KW_ELSE payload_opt value
    ;

switch_expr
    : KW_SWITCH LPAREN expr RPAREN LBRACE switch_prongs RBRACE
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
    ;

switch_case
    : KW_ELSE
    | switch_items
    ;

switch_items
    : switch_item
    | switch_items COMMA switch_item
    ;

switch_item
    : expr
    | expr ELLIPSIS3 expr
    ;

prong_body
    : value
    | block
    | expr assign_op value
    ;

    /* ---------------- Expressions ---------------- */

expr
    : expr KW_OR expr
    | expr KW_AND expr
    | expr compare_op expr %prec EQUAL_EQUAL
    | expr bitwise_op expr %prec AMPERSAND
    | expr KW_CATCH payload_opt expr
    | expr KW_ORELSE expr
    | expr bit_shift_op expr %prec SHL
    | expr addition_op expr %prec PLUS
    | expr multiply_op expr %prec ASTERISK
    | prefix_expr
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
    ;

addition_op
    : PLUS
    | MINUS
    | PLUS_PLUS
    ;

multiply_op
    : ASTERISK
    | SLASH
    | PERCENT
    | ASTERISK_ASTERISK
    ;

prefix_expr
    : prefix_op prefix_expr
    | curly_expr
    ;

prefix_op
    : BANG
    | MINUS
    | TILDE
    | AMPERSAND
    | KW_TRY
    ;

    /* 'T{...}' - a value of type T */

curly_expr
    : type_expr
    | type_expr init_list
    ;

    /* ---------------- Types ---------------- */

    /* Type operators bind looser than 'A!B': '?A!B' is '?(A!B)' */

type_expr
    : error_union_expr
    | QUESTION type_expr
    | ASTERISK const_opt type_expr
    | LBRACKET RBRACKET const_opt type_expr
    | LBRACKET ASTERISK RBRACKET const_opt type_expr
    | LBRACKET expr RBRACKET type_expr
    ;

const_opt
    : %empty
    | KW_CONST
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
    | suffix_expr DOT IDENTIFIER
    | suffix_expr DOT_ASTERISK
    | suffix_expr DOT_QUESTION
    | suffix_expr LPAREN arguments RPAREN
    ;

arguments
    : %empty
    | argument_list comma_opt
    ;

argument_list
    : value
    | argument_list COMMA value
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
    | IDENTIFIER
    | PRIMITIVE_TYPE
    | BUILTIN LPAREN arguments RPAREN
    | LPAREN value RPAREN
    | DOT IDENTIFIER
    | DOT init_list
    | KW_ERROR DOT IDENTIFIER
    | KW_ERROR LBRACE error_names RBRACE
    | container_decl
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
    : KW_STRUCT LBRACE container_members RBRACE
    | KW_ENUM LBRACE container_members RBRACE
    | KW_ENUM LPAREN type_expr RPAREN LBRACE container_members RBRACE
    | KW_UNION LBRACE container_members RBRACE
    | KW_UNION LPAREN KW_ENUM RPAREN LBRACE container_members RBRACE
    ;

    /* '.{ .x = 1, .y = 2 }' or '.{ 1, 2 }' */

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
    : DOT IDENTIFIER EQUAL value
    ;

init_elements
    : value
    | init_elements COMMA value
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
