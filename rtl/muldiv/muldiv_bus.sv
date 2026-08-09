// out-of-order complete, in-order issue; stalls at ID for raw and waw

interface muldiv_in_if;
    logic        clk;
    logic        ready;
    logic [63:0] op1;
    logic [63:0] op2;
    logic [4:0]  rd;
    logic [1:0]  f3_2;
    logic        is_wd_op;
    logic        mark_spec;  // speculative; aka an old trap/csr_w is pending resolution

    logic mul_ready;
    logic div_ready;

    modport master (
        output ready, op1, op2, rd, f3_2, is_wd_op, clk, mark_spec,
        input  mul_ready, div_ready
    );

    modport mul_slave (
        input  ready, op1, op2, rd, f3_2, is_wd_op, clk, mark_spec,
        output mul_ready
    );

    modport div_slave (
        input  ready, op1, op2, rd, f3_2, is_wd_op, clk, mark_spec,
        output div_ready
    );
endinterface


interface muldiv_out_if;
    logic        commit_ready;
    logic [63:0] result;
    logic [4:0]  rd;
    logic        flush_spec;  // if mem stage flushes, ONLY flush spec res
    logic        mark_safe;  // if mem stage doesn't flush
    logic        stall;

    modport master (
        output commit_ready, result, rd,
        input flush_spec, mark_safe, stall
    );

    modport slave (
        input  commit_ready, result, rd,
        output flush_spec, mark_safe, stall
    );
endinterface


/*
For a 3 stage mul, you can't cram the 3 is_spec bits into a global flg because of edge cases:

mul, mem, mul -> (spec, bubble, non_spec)  // if mem takes > 1 cycle
*/
