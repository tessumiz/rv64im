import defs_pkg::*;

module decoder (
    input  logic [31:0] ins,

    output logic [4:0]  rs1_a,
    output logic [4:0]  rs2_a,
    output logic [4:0]  rd,
    output logic [2:0]  f3,
    output logic [6:0]  f7,

    output ctrl_t       ctrl
);
    logic [4:0] op;

    always_comb begin
        op  = ins[6:2];
        rd  = ins[11:7];
        rs1_a = ins[19:15];
        rs2_a = ins[24:20];
        f3  = ins[14:12];
        f7  = ins[31:25];

        ctrl.br   = (op == OP_BR);
        ctrl.jmp  = (op == OP_JAL) || (op == OP_JALR);

        ctrl.alu_src1_pc  = (op == OP_AU)  || ctrl.br || (op == OP_JAL);
        ctrl.alu_src2_imm = (op == OP_IMM) || (op == OP_IMMW) || (op == OP_LD) ||
                            (op == OP_ST)  || (op == OP_LUI)  || (op == OP_AU) ||
                            ctrl.br || ctrl.jmp;

        ctrl.is_word_op   = (op == OP_REGW) || (op == OP_IMMW);

        ctrl.mem_r = (op == OP_LD);
        ctrl.mem_w = (op == OP_ST);
        ctrl.wb    = (op == OP_LD)   || (op == OP_IMM)  || (op == OP_IMMW) ||
                     (op == OP_REG)  || (op == OP_REGW) || (op == OP_LUI)  ||
                     (op == OP_AU)   || (op == OP_JAL)  || (op == OP_JALR);
    end
endmodule
