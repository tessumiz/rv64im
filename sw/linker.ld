ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > RAM

    . = ALIGN(8);

    .data :
    {
        __data_start = .;
        *(.data*)
        __data_end = .;
    } > RAM

    . = ALIGN(8);

    .bss :
    {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);  /* riscv mandatees this for sp */

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}