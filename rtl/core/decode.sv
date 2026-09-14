module decode import defs_pkg::*, zicsr_pkg::*; (
    input logic clk,

    wb_if.slave wb_bus,
    csr_rw_if.r_master csr_bus,

    input logic [1:0] priv,
    input if_id_t     if_id,

    output id_ex_t out
);

    exc_t  decoder_exc;
    ctrl_t decoder_ctrl;

    logic [4:0]  rs1_a, rs2_a, rd;
    logic [2:0]  f3;
    logic [6:0]  f7;
    logic [63:0] reg_rs1, reg_rs2;
    logic [63:0] imm_val;

    decoder u_decoder (
        .ins   (if_id.ins),
        .priv  (priv),

        .rs1_a (rs1_a),
        .rs2_a (rs2_a),
        .rd    (rd),
        .f3    (f3),
        .f7    (f7),
        .ctrl  (decoder_ctrl),
        .exc   (decoder_exc)
    );

    regfile u_reg (
        .clk     (clk),
        .rs1_a   (rs1_a),
        .rs2_a   (rs2_a),
        .rd      (wb_bus.rd),
        .wb_data (wb_bus.data),
        .wb_en   (wb_bus.valid),

        .rs1     (reg_rs1),
        .rs2     (reg_rs2)
    );

    immgen u_immgen (
        .ins (if_id.ins),
        .imm (imm_val)
    );

    logic illegal_csr_w, is_csr;

    always_comb begin
        automatic ctrl_t ctrl_tmp = decoder_ctrl;

        // unverified; so neutered...
        ctrl_tmp.is_csr = 0;
        ctrl_tmp.is_zimm = 0;

        is_csr = ctrl_tmp.is_csr;

        csr_bus.r_en   = is_csr;
        csr_bus.r_addr = imm_val[11:0];

        illegal_csr_w = is_csr && (
            ((imm_val[11:10] == CSR_ADDR_RO) && ctrl_tmp.csr_we) ||
            (priv < imm_val[9:8])
        );

        out.rs1_a = rs1_a;
        out.rs2_a = rs2_a;
        out.rd    = rd;
        out.f3    = f3;
        out.f7    = f7;
        out.rs1   = reg_rs1;
        out.imm   = imm_val;

        out.pc  = if_id.pc;
        out.rs2 = ctrl_tmp.is_csr ? csr_bus.r_data : reg_rs2;

        out.exc.valid = 0;
        out.exc.cause = (is_csr && (csr_bus.r_exc || illegal_csr_w)) ? EXC_ILLEGAL_INSTR :
                        (decoder_exc.valid ? decoder_exc.cause : 0);

        out.exc.is_mret = 0;
        out.exc.is_sret = 0;
        out.exc.tval    = {32'b0, if_id.ins};

        out.ctrl = ctrl_tmp;
    end

endmodule
