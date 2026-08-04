// out-of-order complete, in-order issue; stalls at ID for raw and waw

interface imuldiv_in_if;
    logic        clk;
    logic        valid;
    logic [63:0] op1;
    logic [63:0] op2;
    logic [4:0]  rd;
    logic [1:0]  f3_2;
    logic        is_wd_op;
    logic        pending_mem_flg;

    logic imul_ready;
    logic idiv_ready;

    modport master (
        output valid, op1, op2, rd, f3_2, is_wd_op, clk, pending_mem_flg,
        input  imul_ready, idiv_ready
    );

    modport imul_slave (
        input  valid, op1, op2, rd, f3_2, is_wd_op, clk, pending_mem_flg,
        output imul_ready
    );

    modport idiv_slave (
        input  valid, op1, op2, rd, f3_2, is_wd_op, clk, pending_mem_flg,
        output idiv_ready
    );
endinterface


interface imuldiv_out_if;
    logic        valid;
    logic [63:0] result;
    logic [4:0]  rd;
    logic        clr_pending_mem_flg;
    logic        stall;
    logic        flush;

    modport master (
        output valid, result, rd, flush,
        input clr_pending_mem_flg, stall
    );

    modport slave (
        input  valid, result, rd, flush,
        output clr_pending_mem_flg, stall
    );
endinterface
