import defs_pkg::if_id_t;


module fetch (
    input logic clk,
    input logic stall,
    input logic flush,

    input logic        take_br,
    input logic [63:0] br_targ,
    
    imem_if.master imem_bus,

    output if_id_t out
);

    logic [63:0] pc;
    logic [63:0] next_pc;

    assign imem_bus.addr = pc;
    assign imem_bus.r_en = !(stall || flush);

    assign next_pc = take_br ? br_targ : pc + 4;

    if_id_t if_id;  // if_id_in
    assign if_id.pc  = pc;
    assign if_id.ins = imem_bus.data;

    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk  (clk),
        .en   (~stall),
        .clr  (0),
        .d    (next_pc),
        .q    (pc)
    );

    gen_reg #(.T(if_id_t))
    u_if_id (
        .clk   (clk),
        .en    (~stall),
        .clr   (flush),
        .d     (if_id),
        .q     (out)
    );
endmodule