import defs_pkg::*;

module execute (
    input logic  clk,
    input logic  stall,
    input logic  flush,

    input id_ex_t id_ex,
  
    input fwd_sig_t    fwd_sig,
    input logic [63:0] fwd_mem,
    input logic [63:0] fwd_wb,

    output logic        take_br,
    output logic [63:0] br_targ,

    output ex_mem_t out
);
    logic [63:0] rs1_fwd;
    logic [63:0] rs2_fwd;

    logic [63:0] alu_in1, alu_in2, alu_out;
    logic [3:0]  alu_op;

    ex_mem_t ex_mem;

    always_comb begin
        rs1_fwd = (fwd_sig.mem_fwd_rs1) ? fwd_mem : (fwd_sig.wb_fwd_rs1 ? fwd_wb : id_ex.rs1);
        rs2_fwd = (fwd_sig.mem_fwd_rs2) ? fwd_mem : (fwd_sig.wb_fwd_rs2 ? fwd_wb : id_ex.rs2);

        alu_in1 = id_ex.ctrl.alu_src1_pc  ? id_ex.pc  : rs1_fwd;
        alu_in2 = id_ex.ctrl.alu_src2_imm ? id_ex.imm : rs2_fwd;
    end

    assign alu_op = {id_ex.f7[5], id_ex.f3};  // simple carry-over from functs...

    alu u_alu (
        .a        (alu_in1),
        .b        (alu_in2),
        .alu_op   (alu_op),
        .is_wd_op (id_ex.ctrl.is_wd_op),
        .alu_out  (alu_out)
    );

    assign br_targ = alu_out & ~1;

    bcu u_bcu (
        .rs1     (rs1_fwd),
        .rs2     (rs2_fwd),
        .is_br   (id_ex.ctrl.br),
        .is_jmp  (id_ex.ctrl.jmp),
        .f3      (id_ex.f3),
        .take_br (take_br)
    );

    assign ex_mem.ex_res = id_ex.ctrl.jmp ? (id_ex.pc + 4) : alu_out;;
    assign ex_mem.rs2    = rs2_fwd;
    assign ex_mem.rd     = id_ex.rd;
    assign ex_mem.f3     = id_ex.f3;
    assign ex_mem.ctrl   = id_ex.ctrl;

    pipe_reg #(.T(ex_mem_t))
    u_ex_mem (
        .clk (clk),
        .en  (~stall),
        .clr (flush),
        .d   (ex_mem),
        .q   (out)
    );

endmodule