#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p sw/build
mkdir -p sw/logs

echo "Building Verilator model..."
verilator -Wall --cc --exe --build sw/tb.cpp -f files.f -Wno-fatal --quiet-exit

for test_file in $(find sw/tests -type f -name "*.S"); do
    
    test_suite=$(basename $(dirname "$test_file"))
    test_name=$(basename "$test_file" .S)
    
    log_file="sw/logs/${test_suite}_${test_name}.log"
    
    if ! riscv64-unknown-elf-gcc \
        -I sw/tests/include \
        -I riscv-tests/isa/macros/scalar \
        -I riscv-tests/env/p \
        -I riscv-tests/env \
        -march=rv64g -mabi=lp64 -mcmodel=medany \
        -nostdlib -nostartfiles \
        -T sw/linker.ld \
        "$test_file" -o "sw/build/${test_name}.elf" > "$log_file" 2>&1; then
        
        echo -e "${RED}[GCC FAIL]${NC} [$test_suite] $test_name"
        cat "$log_file"
        continue
    fi
    
    riscv64-unknown-elf-objcopy -O binary "sw/build/${test_name}.elf" "sw/build/test.bin"
    
    ./obj_dir/Vdefs_pkg > "$log_file" 2>&1
    
    result=$(tail -n 1 "$log_file")
    
    if [[ "$result" == *"PASS"* ]]; then
        echo -e "${GREEN}[PASS]${NC} [${test_suite}] $test_name"
    else
        echo -e "${RED}[FAIL]${NC} [${test_suite}] $test_name"
        echo "       -> See log: $log_file"
    fi
done