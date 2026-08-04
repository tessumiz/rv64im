import defs_pkg::*;

module decode (
    input logic clk,

    wb_if.slave wb_bus,

    input  if_id_t if_id,
    output logic   has_rs1,
    output logic   has_rs2,
    output logic   has_rd,

    output id_ex_t out
);

    decoder u_decoder (
        .ins   (if_id.ins),

        .rs1_a (out.rs1_a),
        .rs2_a (out.rs2_a),
        .rd    (out.rd),
        .f3    (out.f3),
        .f7    (out.f7),
        .ctrl  (out.ctrl),

        .has_rs1 (has_rs1),
        .has_rs2 (has_rs2),

        .exc    (out.exc.valid),
        .mcause (out.exc.cause)
    );

    regfile u_reg (
        .clk     (clk),
        .rs1_a   (out.rs1_a),
        .rs2_a   (out.rs2_a),
        .rd      (wb_bus.rd),
        .wb_data (wb_bus.data),
        .wb_en   (wb_bus.valid),

        .rs1     (out.rs1),
        .rs2     (out.rs2)
    );

    immgen u_immgen (
        .ins (if_id.ins),
        .imm (out.imm)
    );


    assign out.pc  = if_id.pc;
    assign has_rd   = out.ctrl.wb;

endmodule
