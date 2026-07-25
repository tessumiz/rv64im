import riscv_pkg::*;

module decoder (
    input  logic [31:0] ins,
    
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [2:0]  f3,
    output logic        f7_5,
    
    output logic        alu_src1_pc,
    output logic        alu_src2_imm,
    output logic        is_word_op,
    output logic        br,
    output logic        jal,
    output logic        jalr,
    output logic        mem_r,
    output logic        mem_w,
    output logic        wb,
    
    output logic [4:0]  isbuj
);
    logic [4:0] op;

    always_comb begin
        op   = ins[6:2];
        
        rs1  = ins[19:15];
        rs2  = ins[24:20];
        rd   = ins[11:7];
        f3   = ins[14:12];
        f7_5 = ins[30];

        alu_src1_pc  = (op == OP_AU);
        alu_src2_imm = (op == OP_IMM) || (op == OP_IMMW) || (op == OP_LD) || 
                       (op == OP_ST)  || (op == OP_LUI)  || (op == OP_AU);
                       
        is_word_op   = (op == OP_REGW) || (op == OP_IMMW);

        br           = (op == OP_BR);
        jal          = (op == OP_JAL);
        jalr         = (op == OP_JALR);

        mem_r        = (op == OP_LD);
        mem_w        = (op == OP_ST);

        wb           = (op == OP_LD)   || (op == OP_IMM)  || (op == OP_IMMW) || 
                       (op == OP_REG)  || (op == OP_REGW) || (op == OP_LUI)  || 
                       (op == OP_AU)   || (op == OP_JAL)  || (op == OP_JALR);

        isbuj[0]     = (op == OP_IMM) || (op == OP_IMMW) || (op == OP_LD) || (op == OP_JALR);
        isbuj[1]     = (op == OP_ST);
        isbuj[2]     = (op == OP_BR);
        isbuj[3]     = (op == OP_LUI) || (op == OP_AU);
        isbuj[4]     = (op == OP_JAL);
    end
endmodule