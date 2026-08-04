import defs_pkg::*;

interface csr_rw_if;
    logic        r_en;
    logic [11:0] r_addr;
    logic [63:0] r_data;
    logic        r_exc;

    logic        w_en;
    logic [11:0] w_addr;
    logic [63:0] w_data;

    modport r_master (
        output r_addr, r_en,
        input  r_data, r_exc
    );

    modport w_master (
        output w_en, w_addr, w_data
    );

    modport slave (
        input  r_addr, w_en, w_addr, w_data,
        output r_data, r_exc
    );
endinterface


interface csr_trap_if;
    logic [63:0] pc;
    logic [63:0] cause;
    logic [63:0] mtvec;
    logic [63:0] mepc;

    logic is_exc;
    logic is_mret;

    irq_t irq;

    modport master (
        output is_exc, is_mret, cause, pc, irq,
        input  mtvec, mepc
    );

    modport slave (
        input  is_exc, is_mret, cause, pc, irq,
        output mtvec, mepc
    );
endinterface
