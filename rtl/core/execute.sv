import defs_pkg::*;

module execute (
    input id_ex_t id_ex,

    input fwd_sig_t    fwd_sig,
    input logic [63:0] fwd_mem,
    input logic [63:0] fwd_wb,

    output logic        take_br,
    output logic [63:0] br_targ,

    output logic [63:0] rs1_fwd,
    output logic [63:0] rs2_fwd,
    output ex_mem_t out
);
    logic [63:0] alu_in1, alu_in2, alu_out;
    logic [3:0]  alu_op;

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

    always_comb begin
        out.pc     = id_ex.pc;
        out.ex_res = id_ex.ctrl.jmp ? (id_ex.pc + 4) : alu_out;
        out.rs2    = rs2_fwd;
        out.rd     = id_ex.rd;
        out.f3     = id_ex.f3;
        out.ctrl   = id_ex.ctrl;
    end

endmodule
