GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

verilator -Wall --cc --exe --build sw/tb.cpp -f files.f -Wno-fatal


for test_file in sw/tests/riscv/*.S; do
    test_name=$(basename "$test_file" .S)
    
    if ! riscv64-unknown-elf-gcc \
        -I sw/tests/riscv \
        -I riscv-tests/isa/macros/scalar \
        -I riscv-tests/env \
        -march=rv64g -mabi=lp64 -mcmodel=medany \
        -nostdlib -nostartfiles \
        -T sw/linker.ld \
        "$test_file" -o sw/test.elf; then
        echo -e "${RED}[GCC FAIL]${NC} $test_name"
        continue
    fi
    
    riscv64-unknown-elf-objcopy -O binary sw/test.elf sw/test.bin
    
    result=$(./obj_dir/Vdefs_pkg | tail -n 1)
    
    if [[ "$result" == *"PASS"* ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
    else
        echo -e "${RED}[FAIL]${NC} $test_name -> $result"
    fi
done