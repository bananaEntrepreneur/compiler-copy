# Как работает парсер

`parser.y` — синтаксический анализатор (парсер) подмножества Zig 0.17 для GNU Bison. Пока в нём только **правила грамматики**: нет семантических действий, нет дерева разбора, и с лексером `lexer.l` он ещё не соединён.

Проверить, что грамматика корректна:

```sh
bison -o /dev/null parser.y
```

Bison не должен выдать ни одного предупреждения. Цифры по грамматике:

| | |
|---|---|
| правил | 205 |
| нетерминалов | 68 |
| состояний автомата | 362 |
| конфликтов | 0 |

## 1. Что делает парсер

Лексер разбивает текст программы на **лексемы (токены)**: `const`, `x`, `=`, `1`, `;`. Парсер проверяет, что последовательность токенов составлена по правилам языка. Например, после `const x` идёт `=` или `:`, а выражение `a + b` не может кончиться на `+`.

Bison по файлу `parser.y` генерирует на C/C++ функцию `yyparse()`.

```
текст ──► лексер (yylex) ──► токены ──► парсер (yyparse) ──► «программа корректна» или syntax error
```

`yyparse()` в цикле вызывает `yylex()`, получает следующий токен и решает, что с ним делать. При ошибке вызывается `yyerror("syntax error")`. Обе функции объявлены в начале `parser.y`, а определять их будем при объединении с лексером.

### LALR(1): сдвиг и свёртка

Bison строит **LALR(1)-парсер**. Это конечный автомат со стеком, который на каждом шаге смотрит ровно на **один** следующий токен и выполняет одно из действий:

- **сдвиг (shift)** — положить токен в стек и прочитать следующий;
- **свёртка (reduce)** — снять с вершины стека правую часть какого-то правила и положить вместо неё левую часть. Например, `expr '+' expr` → `expr`;
- **принять (accept)** — весь файл свёрнут в стартовый символ `source_file`;
- **ошибка** — для этого токена в этом состоянии нет действия.

Свёртки идут «снизу вверх»: из токенов собираются выражения, из выражений операторы, из операторов функции, из функций файл.

### Конфликты

Если в каком-то состоянии автомат не может однозначно выбрать действие, Bison сообщает о **конфликте**. Конфликт сдвиг/свёртка — это выбор между сдвигом и свёрткой, конфликт свёртка/свёртка — выбор между двумя свёртками. Конфликт означает, что грамматика неоднозначна или требует просмотра больше чем на один токен вперёд.

Грамматика Zig в документации записана в форме PEG, где первая подходящая альтернатива побеждает. В LALR(1) её нельзя перенести один в один, поэтому её пришлось перестроить (раздел 5). В итоге конфликтов нет совсем.

## 2. Устройство файла `parser.y`

Файл Bison состоит из трёх частей, разделённых `%%`:

```
/* комментарий о грамматике */

%{ ... %}            пролог: код на C, копируется в начало парсера
%token ...           объявления токенов
%left ... %nonassoc  приоритеты операторов

%%
правила грамматики
%%
                     эпилог: здесь будет код на C (пока пусто)
```

### 2.1. Пролог

```c
%{
int yylex();
void yyerror(const char* message);
%}
```

Здесь только объявления функций, которые нужны сгенерированному парсеру: `yylex` даёт следующий токен, `yyerror` сообщает об ошибке.

### 2.2. Токены

Каждый токен объявлен с именем и строкой-псевдонимом:

```
%token KW_CONST "'const'"
%token IDENTIFIER "identifier"
```

- **Имя** (`KW_CONST`) — то, что будет возвращать лексер: `return KW_CONST;`.
- **Псевдоним** (`"'const'"`) — так токен называется в сообщениях об ошибках Bison.
- `END 0 "end of file"` — токен конца файла. Лексер возвращает 0, когда текст кончился.

| Группа | Токены |
|---|---|
| Имена | `IDENTIFIER` — идентификатор, `BUILTIN` — `@import` и другие встроенные функции, `PRIMITIVE_TYPE` — `u8`, `i32`, `bool`, `void`, `type`… |
| Литералы | `INTEGER_LITERAL`, `FLOAT_LITERAL`, `CHAR_LITERAL`, `STRING_LITERAL`, `MULTILINE_STRING_LITERAL`, а также `KW_TRUE`, `KW_FALSE`, `KW_NULL`, `KW_UNDEFINED` |
| Ключевые слова | `KW_CONST`, `KW_VAR`, `KW_FN`, `KW_IF`, `KW_WHILE`… — по одному на каждое слово Zig |
| Скобки и разделители | `LPAREN` `(`, `RBRACE` `}`, `LBRACKET` `[`, `COMMA`, `COLON`, `SEMICOLON`… |
| Операторы | `PLUS` `+`, `PLUS_EQUAL` `+=`, `EQUAL_EQUAL` `==`, `DOT_ASTERISK` `.*`, `ELLIPSIS2` `..`, `EQUAL_ARROW` `=>`… |

Объявлены **все** токены, которые знает лексер, даже если в основной грамматике они не используются: `asm`, `+%`, `align` и другие. Тогда при объединении лексер сможет вернуть любой из них, а парсер сообщит понятную ошибку, например `unexpected 'align'`.

### 2.3. Приоритеты операторов

```
%left KW_OR                                                      ← самый низкий
%left KW_AND
%nonassoc EQUAL_EQUAL BANG_EQUAL LESS GREATER LESS_EQUAL GREATER_EQUAL
%left AMPERSAND CARET PIPE KW_ORELSE KW_CATCH
%left SHL SHR
%left PLUS MINUS PLUS_PLUS
%left ASTERISK SLASH PERCENT ASTERISK_ASTERISK                   ← самый высокий
```

Порядок взят из таблицы приоритетов в документации Zig: чем ниже строка, тем сильнее связывает оператор.

- `%left` — левоассоциативный оператор: `a - b - c` = `(a - b) - c`.
- `%nonassoc` — неассоциативный: цепочку `a == b == c` Zig запрещает, и парсер выдаст на ней ошибку.

Сама грамматика выражений неоднозначна: `expr: expr addition_op expr | expr multiply_op expr | …`. Приоритеты разрешают её конфликты. Пусть в стеке лежит `expr + expr`, а следующий токен `*`:

- **свёртка** дала бы `(a + b) * c`;
- **сдвиг** даёт `a + (b * c)`.

Bison сравнивает приоритет правила с приоритетом токена `*`. Приоритет правила — это приоритет, указанный через `%prec PLUS`. У `*` приоритет выше, поэтому выбирается сдвиг.

Операторы собраны в нетерминалы `addition_op`, `multiply_op` и другие, чтобы не писать отдельное правило на каждый. Поэтому приоритет правилу задаётся явно через `%prec`:

```
expr
    : expr addition_op expr %prec PLUS
    | expr multiply_op expr %prec ASTERISK
    ...
```

## 3. Грамматика по разделам

Нетерминалы названы по грамматике из документации Zig: `expr` — это Expr, `prefix_expr` — PrefixExpr, `suffix_expr` — SuffixExpr и т. д. Ниже разделы в том же порядке, что и в файле.

### 3.1. Файл и контейнеры

Файл Zig — это неявная структура, поэтому файл и тело `struct`/`enum`/`union` описываются одним нетерминалом `container_members`.

```
source_file
    : container_members
    ;

container_members
    : members
    | members field          ← последнее поле может быть без запятой
    ;

members
    : %empty
    | members declaration
    | members field COMMA
    ;
```

`%empty` — пустая альтернатива: файл или структура могут быть пустыми. Списки записаны **леворекурсивно** (`members: members declaration`). Для LALR это лучше всего: стек не растёт с длиной списка.

Поле структуры или объединения имеет тип, поле перечисления — только имя и, возможно, значение:

```
field
    : IDENTIFIER                              red
    | IDENTIFIER EQUAL value                  green = 2
    | IDENTIFIER COLON type_expr              x: i32
    | IDENTIFIER COLON type_expr EQUAL value  y: i32 = 0
    ;
```

### 3.2. Объявления

```
declaration
    : pub_opt var_declaration       pub const x = 1;
    | pub_opt fn_proto block        fn main() void { ... }
    | KW_TEST STRING_LITERAL block  test "name" { ... }
    ;

var_declaration
    : var_kind IDENTIFIER EQUAL value SEMICOLON                   const x = 1;
    | var_kind IDENTIFIER COLON type_expr EQUAL value SEMICOLON   var i: usize = 0;
    ;
```

Значение после `=` обязательно: Zig не разрешает объявить переменную без инициализации. Если значение пока неизвестно, пишут `= undefined`.

Суффикс `_opt` означает необязательную часть: `pub_opt` — это `%empty` или `pub`. Так же устроены `capture_opt`, `payload_opt`, `comma_opt` и другие.

### 3.3. Функции

```
fn_proto
    : KW_FN IDENTIFIER LPAREN parameters RPAREN return_type
    ;

return_type
    : type_expr          fn f() u8
    | BANG type_expr     fn f() !void   — ошибка или void, набор ошибок выводит компилятор
    ;

parameter
    : IDENTIFIER COLON param_type               a: u8
    | KW_COMPTIME IDENTIFIER COLON param_type   comptime T: type
    ;

param_type
    : type_expr
    | KW_ANYTYPE                                x: anytype
    ;
```

`parameters` — это пустой список или список через запятую с необязательной запятой в конце (`comma_opt`). По тому же образцу описаны аргументы вызова, элементы инициализатора, ветви `switch` и имена ошибок.

### 3.4. Операторы (statements)

```
block
    : LBRACE statements RBRACE
    ;

statement
    : var_declaration                 const x = 1;
    | block                           { ... }
    | if_statement
    | while_statement
    | for_statement
    | switch_expr                     switch (x) { ... }   — без ';'
    | KW_DEFER body                   defer file.close();
    | KW_ERRDEFER payload_opt body    errdefer |err| log(err);
    | assign_expr SEMICOLON           x += 1;   f();   return x;
    ;
```

Тело цикла или `defer` — это блок либо одно выражение с `;`:

```
body
    : block
    | assign_expr SEMICOLON
    ;
```

**if** повторяет правило `IfStatement` из грамматики Zig. После блока `;` не нужна, после выражения нужна, а ветка `else` — любой оператор. Поэтому `else if` — это просто `else`, за которым идёт оператор `if`.

```
if_statement
    : if_prefix block                                      if (a) { ... }
    | if_prefix block KW_ELSE payload_opt statement        if (a) { ... } else { ... }
    | if_prefix assign_expr SEMICOLON                      if (a) x = 1;
    | if_prefix assign_expr KW_ELSE payload_opt statement  if (a) x = 1 else x = 2;
    ;

if_prefix
    : KW_IF LPAREN expr RPAREN capture_opt                 if (opt) |value|
    ;
```

Классической проблемы «висящего else» здесь нет. Тело `if` — блок или выражение, но не другой оператор `if`, так что `else` всегда относится к ближайшему `if`, и приоритеты для этого не нужны.

**while** и **for**:

```
while_statement
    : KW_WHILE LPAREN expr RPAREN capture_opt continue_opt body
    ;                                  while (i <= 16) : (i += 1) { ... }

for_statement
    : KW_FOR LPAREN for_inputs comma_opt RPAREN capture body
    ;                                  for (items, 0..) |item, i| { ... }

for_input
    : expr          items
    | expr ELLIPSIS2        0..
    | expr ELLIPSIS2 expr   0..10
    ;
```

### 3.5. Значения: присваивание, `if`, `switch`, переходы

Это главная часть грамматики. Её устройство объясняется в разделе 5.

```
assign_expr          — то, что стоит в операторе перед ';'
    : simple_value
    | expr assign_op value       x = 1,  i += 1
    ;

value                — значение переменной, аргумента, поля, return
    : simple_value
    | if_expr                    if (a) b else c
    | switch_expr                switch (x) { ... }
    ;

simple_value         — значение, с которого может начинаться оператор
    : expr
    | jump                               return x
    | expr KW_ORELSE jump                opt orelse return null
    | expr KW_CATCH payload_opt jump     f() catch |err| return err
    ;

jump
    : KW_RETURN | KW_RETURN value
    | KW_BREAK  | KW_BREAK value
    | KW_CONTINUE
    ;

if_expr
    : if_prefix value KW_ELSE payload_opt value   — у if-выражения else обязателен
    ;
```

`switch`:

```
switch_expr
    : KW_SWITCH LPAREN expr RPAREN LBRACE switch_prongs RBRACE
    ;

switch_prong                       ветвь
    : switch_case EQUAL_ARROW capture_opt prong_body
    ;

switch_case
    : KW_ELSE                      else => ...
    | switch_items                 1, 2, 4...6 => ...
    ;

prong_body
    : value                        => 1   => return x   => unreachable
    | block                        => { ... }
    | expr assign_op value         => i = 3
    ;
```

### 3.6. Выражения

Выражение разбирается по уровням. Каждый следующий уровень связывает сильнее предыдущего:

```
expr                бинарные операторы:  a + b * c,  x orelse y,  a and b
 └ prefix_expr      префиксные:          -x  !ok  ~bits  &value  try f()
    └ curly_expr    инициализатор типа:  Point{ .x = 1 }
       └ type_expr  операторы типов:     ?T  *T  []T  [*]T  [N]T
          └ error_union_expr             E!T
             └ suffix_expr               постфиксные:  a[i]  a[1..n]  a.b  p.*  opt.?  f(x)
                └ primary_type_expr      основа: литерал, имя, (value), @f(...), .{...}, struct {...}
```

Так в одной грамматике оказываются и выражения, и типы. В Zig это одно и то же: тип — тоже значение, и его можно передать в функцию (`@as(u8, x)`, `ArrayList(u8)`).

Постфиксные операции записаны леворекурсивно, поэтому `std.log.info("x", .{})` разбирается так:

```
suffix_expr  →  suffix_expr ( arguments )
                 └ suffix_expr . info
                    └ suffix_expr . log
                       └ primary_type_expr: std
```

`primary_type_expr` — неделимые выражения:

| Правило | Пример |
|---|---|
| литералы | `42`, `1.5`, `'a'`, `"text"`, `true`, `null`, `undefined`, `unreachable` |
| имена | `x`, `u8` |
| `BUILTIN LPAREN arguments RPAREN` | `@import("std")` |
| `LPAREN value RPAREN` | `(a + b)`, `(if (c) 1 else 2)` |
| `DOT IDENTIFIER` | `.red` — значение перечисления |
| `DOT init_list` | `.{ 1, 2 }`, `.{ .x = 1 }` — анонимный инициализатор |
| `KW_ERROR DOT IDENTIFIER` | `error.OutOfMemory` |
| `KW_ERROR LBRACE error_names RBRACE` | `error{ A, B }` |
| `container_decl` | `struct { ... }`, `enum(u8) { ... }`, `union(enum) { ... }` |

### 3.7. Инициализаторы и захваты

```
init_list
    : LBRACE RBRACE                              {}
    | LBRACE field_inits comma_opt RBRACE        { .x = 1, .y = 2 }
    | LBRACE init_elements comma_opt RBRACE      { 1, 2, 3 }
    ;

capture       |x|   |*x|   |item, i|     — после if, while, for и ветви switch
payload_opt   |err|                      — после catch, else и errdefer
```

## 4. Пример разбора

Строка `const x = a + b * c;`. Лексер выдаёт токены:

```
'const'  identifier  '='  identifier  '+'  identifier  '*'  identifier  ';'  end of file
```

Ниже шаги, которые делает парсер. Это трассировка Bison: сгенерирован с флагом `-t`, запущен с `yydebug = 1`. Цепочки однотипных свёрток сокращены.

| Шаг | Следующий токен | Действие |
|---|---|---|
| 1 | `const` | свёртка `members: %empty` — файл начинается с пустого списка |
| 2 | `const` | свёртка `pub_opt: %empty` — `pub` нет |
| 3 | `const` | сдвиг `const`, свёртка `var_kind: 'const'` |
| 4 | `x`, `=` | сдвиг `x`, сдвиг `=` |
| 5 | `a` | сдвиг `a` |
| 6 | `+` | свёртки `a` → `primary_type_expr` → `suffix_expr` → `error_union_expr` → `type_expr` → `curly_expr` → `prefix_expr` → `expr` |
| 7 | `+` | сдвиг `+`, свёртка `addition_op: '+'` |
| 8 | `b`, `*` | сдвиг `b`, те же свёртки до `expr` |
| 9 | `*` | **выбор:** свернуть `expr + expr` или сдвинуть `*`? Приоритет `*` выше, чем у правила с `%prec PLUS`, поэтому **сдвиг** `*` и свёртка `multiply_op` |
| 10 | `c`, `;` | сдвиг `c`, свёртки до `expr` |
| 11 | `;` | свёртка `expr: expr multiply_op expr` (это `b * c`), потом `expr: expr addition_op expr` (это `a + (b * c)`) |
| 12 | `;` | свёртки `simple_value: expr` и `value: simple_value` |
| 13 | `;` | сдвиг `;`, свёртки `var_declaration`, `declaration`, `members`, `container_members`, `source_file` |
| 14 | конец файла | принять |

Получившееся дерево вывода:

```
source_file
└ container_members
  └ members
    ├ members (пусто)
    └ declaration
      ├ pub_opt (пусто)
      └ var_declaration
        ├ var_kind: const
        ├ x
        ├ =
        ├ value → simple_value → expr
        │   ├ expr … a
        │   ├ addition_op: +
        │   └ expr
        │       ├ expr … b
        │       ├ multiply_op: *
        │       └ expr … c
        └ ;
```

## 5. Почему `if` и `switch` — значения, а не операнды

В полной грамматике Zig `if`, `switch`, `while`, `for`, блоки и переходы — обычные выражения. Их можно поставить куда угодно, даже так: `1 + if (a) 2 else 3`. Для LALR(1) с одним токеном просмотра это порождает конфликты.

1. **Начало оператора.** Встретив `if` или `switch` в начале оператора, парсер должен сразу решить: это оператор, после блока которого `;` не нужна, или начало выражения, после которого нужна `;`. Одного токена для этого мало.
2. **Висящий else и операторы после `if`.** В `if (a) b else c + d` неясно, относится ли `+ d` к ветке `else` или ко всему `if`.

В основной грамматике это решено разделением на уровни:

- `expr` — только «обычные» выражения с операторами. Оно **никогда не начинается** с `if`, `switch`, `return`, `break`, `continue` или `{`.
- `if_expr`, `switch_expr` и `jump` бывают только **целым значением**: справа от `=`, аргументом, элементом `.{...}`, значением поля, после `return` и `=>`, в скобках `( )`.
- Переходы разрешены ещё после `orelse` и `catch`, потому что это частый приём в Zig: `opt orelse return null`.

Отсюда следуют две вещи:

- В начале оператора токены `if` и `switch` однозначно начинают оператор `if` или `switch`. Выражение с них начаться не может, и конфликта нет.
- `if`-выражение не бывает операндом `+`, поэтому вопрос «к чему относится `+ d`» не возникает: всё после `else` — значение ветки.

Цена этого решения — запись `1 + if (a) 2 else 3` не поддерживается. Её можно переписать в скобках: `1 + (if (a) 2 else 3)`.

## 6. Как отвергаются ошибочные программы

| Программа | Почему ошибка |
|---|---|
| `a = b = c;` | присваивание — это `expr assign_op value`, а `value` не может содержать `=`. После `b` токен `=` неожидан |
| `a == b == c;` | сравнения объявлены `%nonassoc`, цепочка из двух запрещена |
| `if (a) b; else c;` | `if (a) b;` — уже законченный оператор, а новый оператор не может начинаться с `else` |
| `const x = 1 }` | `var_declaration` требует `;` перед `}` |
| `const x;` | после имени ожидаются `=` или `:` |
| `x + if (a) b else c;` | после `+` ожидается `expr`, а `expr` не начинается с `if` (см. раздел 5) |
| `fn f() void { ` | файл кончился, а блок не закрыт: после операторов ожидается `}` |

Сейчас Bison выдаёт только `syntax error`. Чтобы в сообщении было, какой токен встретился и какой ожидался (`unexpected '=', expecting ';'`), достаточно добавить `%define parse.error detailed` (Bison 3.6+). Строки-псевдонимы токенов уже подготовлены для этого.

## 7. Что не входит в основную грамматику

- метки блоков и циклов: `blk: { break :blk 1; }`;
- `while`/`for` как выражения, `else` у циклов, `inline` у циклов и ветвей `switch`;
- `if`/`switch` как операнды операторов (`1 + if ...`), `switch` после `catch` (`catch |e| switch (e) {...}`);
- вложенный `if` без фигурных скобок как тело другого `if` или цикла (`if (a) if (b) x;`);
- `comptime`-блоки и выражения (поддержан только `comptime` у параметра);
- `extern`, `export`, `inline` и `noinline` у функций, `threadlocal`;
- `align`, `addrspace`, `linksection`, `callconv`, `noalias`;
- `packed` и `extern` структуры, `opaque`;
- модификаторы указателей кроме `const` (`volatile`, `allowzero`, `align`), сентинелы (`[:0]u8`), `[*c]`;
- типы функций (`fn (u8) void`);
- деструктуризация: `const a, const b = f();`;
- операторы с переполнением и насыщением (`+%`, `-%`, `*%`, `+|`, `<<|` и их присваивания), `||` для наборов ошибок;
- имена полей, совпадающие с ключевыми словами и типами (`.type`, `.bool`);
- `test` без строки-имени;
- `asm`, async (`suspend`, `resume`, `nosuspend`, `anyframe`).

Есть одно послабление: в отличие от Zig, объявления между полями структуры не запрещены.

## 8. Объединение с лексером

Когда придёт время соединить парсер с `lexer.l`, понадобится:

1. Сгенерировать заголовок с номерами токенов: `bison -d -o parser.cpp parser.y`. Получится `parser.hpp`.
2. В лексере подключить `parser.hpp` и вместо печати лексемы возвращать токен: `return KW_CONST;`, `return IDENTIFIER;` и т. д. Имена токенов — те, что объявлены через `%token`.
3. Убрать `main` из лексера и написать его в эпилоге парсера: открыть файл, присвоить его `yyin`, вызвать `yyparse()`.
4. Определить `yyerror` так же, как лексер сообщает об ошибках (с номером строки `yylineno`).
5. Для дерева разбора добавить `%union` с типом значения, `%type` для нетерминалов и действия `{ $$ = ... }` к правилам.

Сборка после объединения:

```sh
bison -d -o parser.cpp parser.y
flex -o lexer.cpp lexer.l
g++ -o zig-compiler parser.cpp lexer.cpp
```
