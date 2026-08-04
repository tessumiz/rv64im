import defs_pkg::*;

module decode (
    input logic clk,

    wb_if.slave wb_bus,
    csr_rw_if.r_master csr_bus,

    input  if_id_t if_id,

    output id_ex_t out
);

    logic        illegal_ins;
    logic [63:0] illegal_cause;

    decoder u_decoder (
        .ins   (if_id.ins),

        .rs1_a (out.rs1_a),
        .rs2_a (out.rs2_a),
        .rd    (out.rd),
        .f3    (out.f3),
        .f7    (out.f7),
        .ctrl  (out.ctrl),

        .exc    (illegal_ins),
        .mcause (illegal_cause)
    );

    logic [63:0] rs2;

    regfile u_reg (
        .clk     (clk),
        .rs1_a   (out.rs1_a),
        .rs2_a   (out.rs2_a),
        .rd      (wb_bus.rd),
        .wb_data (wb_bus.data),
        .wb_en   (wb_bus.valid),

        .rs1     (out.rs1),
        .rs2     (rs2)
    );

    immgen u_immgen (
        .ins (if_id.ins),
        .imm (out.imm)
    );

    logic illegal_csr_w, is_csr;

    always_comb begin
        is_csr = out.ctrl.is_csr;

        csr_bus.r_en   = is_csr;
        csr_bus.r_addr = out.imm[11:0];

        illegal_csr_w = (out.imm[11:10] == CSR_ADDR_RO) && out.ctrl.csr_we;

        out.pc  = if_id.pc;
        out.rs2 = out.ctrl.is_csr ? csr_bus.r_data : rs2;

        out.exc.valid = (is_csr && csr_bus.r_exc) || illegal_ins || illegal_csr_w;
        out.exc.cause = (is_csr && (csr_bus.r_exc || illegal_csr_w)) ? 2 :
                        (illegal_ins ? illegal_cause : 0);
    end

endmodule
