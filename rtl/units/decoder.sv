import defs_pkg::*;
import zicsr_pkg::*;


module decoder (
    input  logic [31:0] ins,
    input  logic [1:0]  priv,

    output logic [4:0]  rs1_a,
    output logic [4:0]  rs2_a,
    output logic [4:0]  rd,
    output logic [2:0]  f3,
    output logic [6:0]  f7,

    output ctrl_t       ctrl,
    output exc_t        exc
);

    logic [4:0]  op;
    logic [11:0] sys_imm;

    logic has_rs1, has_rs2;
    logic csr_w_op;


    always_comb begin
        op      = ins[6:2];
        f3      = ins[14:12];
        f7      = ins[31:25];
        sys_imm = ins[31:20];

        rd      = ctrl.wb ? ins[11:7]  : 0;
        rs1_a   = has_rs1 ? ins[19:15] : 0;
        rs2_a   = has_rs2 ? ins[24:20] : 0;

        has_rs1 =  0;
        has_rs2 =  0;

        ctrl = '0;
        ctrl.valid = 1;

        exc = '0;
        csr_w_op = 0;


        case (op)
            OP_LUI: begin
                ctrl.alu_src2_imm = 1;
                ctrl.wb           = 1;
                ctrl.is_lui       = 1;
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
                    ctrl.is_csr  = 1;
                    ctrl.is_zimm = f3[2];
                    has_rs1 = !f3[2];

                    csr_w_op    = (f3[1:0] == CSR_RW);
                    ctrl.csr_we = (csr_w_op || (!csr_w_op && rs1_a != 0));

                end else begin
                    exc.valid = 1;

                    case (sys_imm)
                        ECALL: begin
                            unique case (priv)
                                PRIV_U:  exc.cause = EXC_ECALL_U;
                                PRIV_S:  exc.cause = EXC_ECALL_S;
                                PRIV_M:  exc.cause = EXC_ECALL_M;
                            endcase
                        end

                        MRET : begin
                            exc.valid   = (priv < PRIV_M);
                            exc.is_mret = (priv == PRIV_M);
                        end

                        SRET : begin
                            // M mode is allowed to exec sret, acc to specs...
                            exc.valid   = (priv < PRIV_S);
                            exc.is_sret = (priv >= PRIV_S);
                        end

                        default: exc.cause = EXC_ILLEGAL_INSTR;
                    endcase
                end
            end

            default: begin
                exc.valid = 1;
                exc.cause = EXC_ILLEGAL_INSTR;
            end
        endcase
    end

endmodule
