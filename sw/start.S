.section .text.start
.globl _start
.type _start, @function

_start:
    la sp, __stack_top
    call main

loop:
    j loop