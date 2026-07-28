import defs_pkg::*;

module decode (
    input  logic   clk,
    input  logic   stall,
    input  logic   flush,

    wb_if.slave    wb_bus,

    input  if_id_t if_id,
    output id_ex_t out
);

    id_ex_t id_ex;

    decoder u_decoder (
        .ins   (if_id.ins),

        .rs1_a (id_ex.rs1_a),
        .rs2_a (id_ex.rs2_a),
        .rd    (id_ex.rd),
        .f3    (id_ex.f3),
        .f7    (id_ex.f7),
        .ctrl  (id_ex.ctrl)
    );

    regfile u_reg (
        .clk     (clk),
        .rs1_a   (id_ex.rs1_a),
        .rs2_a   (id_ex.rs2_a),
        .rd      (wb_bus.rd),       
        .wb_data (wb_bus.data),     
        .wb_en   (wb_bus.en),       

        .rs1     (id_ex.rs1),
        .rs2     (id_ex.rs2)
    );

    immgen u_immgen (
        .ins (if_id.ins),
        .imm (id_ex.imm)
    );

    assign id_ex.pc = if_id.pc;

    pipe_reg #(.T(id_ex_t))
    u_id_ex (
        .clk (clk),
        .en  (~stall),
        .clr (flush),
        .d   (id_ex),
        .q   (out)
    );

endmodule