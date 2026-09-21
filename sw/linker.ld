OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x80000000;
    .text : { *(.text) }

    . = 0x80010000;
    .data : { *(.data) }
    .bss : { *(.bss) }

    . = 0x8001FFF8;
    .tohost : { *(.tohost) }

    _end = .;
}