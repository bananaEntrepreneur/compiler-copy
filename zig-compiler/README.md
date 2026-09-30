zig-0.17-compiler

Компилятор подмножества Zig 0.17: лексический анализатор (`lexer.l`, flex) и синтаксический анализатор (`parser.y`, bison), строящий дерево разбора.

## Сборка

Нужны flex, bison 3.6+ и g++ (на macOS системный bison старый: `brew install bison`).

```sh
bison -d -o parser.cpp parser.y
flex -o lexer.cpp lexer.l
g++ -o zig-compiler parser.cpp lexer.cpp
```

## Запуск

```sh
./zig-compiler file.zig            # дерево разбора
./zig-compiler --dot file.zig      # дерево на языке DOT: ./zig-compiler --dot file.zig | dot -Tpng -o tree.png
./zig-compiler --tokens file.zig   # список лексем (первое задание)
```

Ошибки печатаются в stderr в виде `error: <сообщение> in line: <строка>`. Если есть ошибки, дерево не печатается.

## Тесты

```sh
sh tests/test.sh
```

Для каждого `tests/*/*.zig`: `.expected` — ожидаемые лексемы, `.tree` — ожидаемое дерево или ошибки разбора.

## Грамматика

`parser.y` — грамматика Zig из документации языка, переписанная для LALR(1); нетерминалы названы по ней (`expr` — Expr, `prefix_expr` — PrefixExpr, `primary_expr` — PrimaryExpr...). Приоритеты операторов — по таблице Zig.

Отличия от LALR-неудобных мест грамматики описаны в начале `parser.y`. Один конфликт сдвиг/свёртка ожидается (`%expect 1`): `[*c]` читается как C-указатель.

Не поддерживаются: `asm`, async (`suspend`, `resume`, `nosuspend`, `anyframe`), поля-кортежи (`struct { u8, bool }`), помеченный блок как операнд арифметики (`1 + blk: {...}`) и `if` после `?` или `!` внутри выражения (в типе поля или объявления — можно).
