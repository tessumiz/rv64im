OUTPUT_ARCH("riscv")
ENTRY(_start)


SECTIONS
{
    . = 0x80000000;
    .text : { *(.text) }
    
    . = 0x80010000;
    .data : { *(.data) }
    .bss : { *(.bss) }
    _end = .;
}