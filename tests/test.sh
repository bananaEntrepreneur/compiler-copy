#!/bin/sh

set -e

cd "$(dirname "$0")/.."

out=$(mktemp -d)

flex -o "$out/lexer.cpp" lexer.l

g++ -o "$out/lexer" "$out/lexer.cpp"

failed=0

for f in tests/*/*.zig; do
    if ! "$out/lexer" "$f" 2>&1 | diff -u "${f%.zig}.expected" -; then
        failed=$((failed + 1))
    fi
done

if [ "$failed" -ne 0 ]; then
    echo "FAILED: $failed"
    exit 1
fi

echo "OK"
