interface csr_rw_if (
    input logic clk,
    input logic rst
);
    logic [11:0] r_addr;
    logic        w_en;
    logic [11:0] w_addr;
    logic [63:0] w_data;
    logic [63:0] r_data;

    modport master (
        output r_addr, w_en, w_addr, w_data,
        input  r_data
    );

    modport slave (
        input  r_addr, w_en, w_addr, w_data,
        output r_data
    );
endinterface


interface csr_trap_if (
    input logic clk,
    input logic rst
);
    logic        is_trap;
    logic        is_mret;
    logic [63:0] cause;
    logic [63:0] pc;

    logic [63:0] mtvec;
    logic [63:0] mepc;

    modport master (
        output is_trap, is_mret, cause, pc,
        input  mtvec, mepc
    );

    modport slave (
        input  is_trap, is_mret, cause, pc,
        output mtvec, mepc
    );
endinterface
