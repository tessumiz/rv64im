ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 4M
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM);


/* no lma rn... */
SECTIONS
{
    .text : ALIGN(4) SUBALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
        *(.srodata*)
    } > RAM

    . = ALIGN(8);

    .data : SUBALIGN(8)
    {
        __data_start = .;

        *(.data*)
        *(.sdata*) 

        __global_pointer$ = . + 0x800;

        __data_end = .;
    } > RAM

    . = ALIGN(8);

    .bss : SUBALIGN(8)
    {
        __bss_start = .;

        *(.sbss*)  /* let this be near sdata */
        *(.bss*)
        *(COMMON)

        __bss_end = .;
    } > RAM

    . = ALIGN(16);
}