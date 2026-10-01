#!/bin/sh

set -e

cd "$(dirname "$0")/.."

out=$(mktemp -d)

bison -d -o "$out/parser.cpp" parser.y

flex -o "$out/lexer.cpp" lexer.l

g++ -I"$out" -o "$out/zig" "$out/parser.cpp" "$out/lexer.cpp"

failed=0

# Run the compiler on a file and compare what it prints with the expected output.
check() {
    if ! "$out/zig" $3 "$1" 2>&1 | diff -u "$2" -; then
        failed=$((failed + 1))
    fi
}

# Lexer tests, from the main folder: the list of tokens
for f in ../tests/*/*.zig; do
    check "$f" "${f%.zig}.expected" --tokens
done

# Parser tests: the parse tree, or the syntax errors
for f in tests/*/*.zig; do
    check "$f" "${f%.zig}.tree"
done

if [ "$failed" -ne 0 ]; then
    echo "FAILED: $failed"
    exit 1
fi

echo "OK"
