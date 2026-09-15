.section .text.start
.globl _start
.type _start, @function


_start:
    /* push/pop ctx used cuz by default it could be anything;
       either norelax or relax, not a clue about that otherwise */

    .option push
    .option norelax

    la gp, __global_pointer$

    .option pop

    la sp, __stack_top

    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, done

clr_bss:
    sw zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, clr_bss

/* we'll have lma later on */
done:
    call main

loop:
    j loop