import defs_pkg::*;

module decoder (
    input  logic [31:0] ins,

    output logic [4:0]  rs1_a,
    output logic [4:0]  rs2_a,
    output logic [4:0]  rd,
    output logic [2:0]  f3,
    output logic [6:0]  f7,
    output logic        has_rs1,
    output logic        has_rs2,

    output ctrl_t       ctrl,
    output logic        exc,
    output logic [63:0] mcause
);

    logic [4:0]  op;
    logic [11:0] sys_imm;

    logic csr_r;
    logic csr_w;


    always_comb begin
        op      = ins[6:2];
        rd      = ins[11:7];
        f3      = ins[14:12];
        rs1_a   = ins[19:15];
        rs2_a   = ins[24:20];
        f7      = ins[31:25];
        sys_imm = ins[31:20];

        has_rs1 =  0;
        has_rs2 =  0;
        ctrl    = '0;
        exc     =  0;
        mcause  =  0;


        case (op)
            OP_LUI: begin
                ctrl.alu_src2_imm = 1;
                ctrl.wb           = 1;
            end

            OP_AU: begin
                ctrl.alu_src1_pc  = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.wb           = 1;
            end

            OP_JAL: begin
                ctrl.jmp          = 1;
                ctrl.alu_src1_pc  = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.wb           = 1;
            end

            OP_JALR: begin
                has_rs1           = 1;
                ctrl.jmp          = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.wb           = 1;
            end

            OP_BR: begin
                has_rs1           = 1;
                has_rs2           = 1;
                ctrl.br           = 1;
                ctrl.alu_src1_pc  = 1;
                ctrl.alu_src2_imm = 1;
            end

            OP_LD: begin
                has_rs1           = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.mem_r        = 1;
                ctrl.wb           = 1;
            end

            OP_ST: begin
                has_rs1           = 1;
                has_rs2           = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.mem_w        = 1;
            end

            OP_IMM,
            OP_IMMW: begin
                has_rs1           = 1;
                ctrl.alu_src2_imm = 1;
                ctrl.is_wd_op     = (op == OP_IMMW);
                ctrl.wb           = 1;
            end

            OP_REG,
            OP_REGW: begin
                has_rs1       = 1;
                has_rs2       = 1;
                ctrl.is_wd_op = (op == OP_REGW);
                ctrl.wb       = 1;

                if (op == OP_REG) begin
                    ctrl.is_imul = (f7 == F7_1) && !f3[2];
                    ctrl.is_idiv = (f7 == F7_1) &&  f3[2];
                end
            end

            OP_SYS: begin
                if (f3 != PRIV) begin
                    ctrl.is_csr = 1;
                    has_rs1 = !f3[2];

                end else begin
                    exc = 1;

                    case (sys_imm)
                        ECALL: mcause = 11;
                        EBRK : mcause = 3;

                        MRET : begin
                            exc    = 0;
                            mcause = 0;
                            ctrl.is_mret = 1;
                        end

                        default: mcause = 2;
                    endcase
                end
            end

            default: begin
                exc = 1;
                mcause = 2;
            end
        endcase
    end

endmodule
