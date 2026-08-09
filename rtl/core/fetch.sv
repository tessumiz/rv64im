import defs_pkg::*;


module fetch (
    input logic clk,
    input logic rst,
    input logic stall,
    input logic flush,

    input logic take_br,
    input logic take_mepc,
    input logic take_mtvec,

    input logic take_stvec,
    input logic take_sepc,

    input logic take_csr_br,

    input logic [63:0] br_targ,
    input logic [63:0] mepc_targ,
    input logic [63:0] mtvec_targ,

    input logic [63:0] sepc_targ,
    input logic [63:0] stvec_targ,

    input logic [63:0] csr_br_targ,

    imem_if.master imem_bus,

    output if_id_t out
);

    logic [63:0] pc;
    logic [63:0] nxt_pc;

    always_comb begin
        imem_bus.addr = pc;
        imem_bus.r_en = !flush;

        nxt_pc =
            take_br     ? br_targ     :
            take_mepc   ? mepc_targ   :
            take_mtvec  ? mtvec_targ  :
            take_stvec  ? stvec_targ  :
            take_sepc   ? sepc_targ   :
            take_csr_br ? csr_br_targ :
            pc + 4;

        out.pc  = pc;  // ########################################!!!!!!!!!!!!
        out.ins = imem_bus.data;
        out.exc.valid = 1;  // later... 
    end

    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk (clk),
        .en  (~stall),
        .clr (rst),
        .d   (nxt_pc),
        .q   (pc)
    );
endmodule
