#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT_DIR"

echo "=== [1/3] Compiling RTL and C++ Testbench ==="

rm -rf "$ROOT_DIR/sw/build"

mkdir -p "$ROOT_DIR/sw/build"
mkdir -p "$ROOT_DIR/sw/logs"

verilator -Wall \
    --cc \
    --exe \
    --build \
    --coverage \
    --trace-fst \
    -f "$ROOT_DIR/cache_tb.f" \
    "$ROOT_DIR/sw/tb/tb.cpp" \
    -CFLAGS "-std=c++17 -I$ROOT_DIR/sw/tb/include -I$ROOT_DIR/sw/tb" \
    --top-module tb_cache_top \
    --Mdir "$ROOT_DIR/sw/build" \
    -Wno-fatal

echo
echo "=== [2/3] Running 10-Million Cycle Simulation ==="

"$ROOT_DIR/sw/build/Vtb_cache_top"

echo
echo "=== [3/3] Generating SystemVerilog Coverage Report ==="

if [ -f "$ROOT_DIR/sw/logs/coverage.dat" ]; then
    mkdir -p "$ROOT_DIR/sw/logs/annotated_src"

    verilator_coverage \
        --annotate "$ROOT_DIR/sw/logs/annotated_src" \
        "$ROOT_DIR/sw/logs/coverage.dat"
else
    echo "WARNING: coverage.dat was not generated."
fi

echo
echo "=== DONE ==="