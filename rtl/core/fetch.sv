import defs_pkg::if_id_t;


module fetch (
    input logic clk,
    input logic rst,
    input logic stall,
    input logic flush,

    input logic        take_br,
    input logic [63:0] br_targ,
    input logic        take_trap_br,
    input logic [63:0] trap_targ,

    imem_if.master imem_bus,

    output if_id_t out
);

    logic [63:0] pc;
    logic [63:0] nxt_pc;

    assign imem_bus.addr = pc;
    assign imem_bus.r_en = !flush;

    assign nxt_pc = take_trap_br ? trap_targ : (take_br ? br_targ : pc + 4);

    if_id_t if_id;
    assign  if_id.pc  = pc;  // ########################################!!!!!!!!!!!!
    assign  if_id.ins = imem_bus.data;

    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk  (clk),
        .en   (~stall || take_br || take_trap_br),
        .clr  (rst),
        .d    (nxt_pc),
        .q    (pc)
    );

    assign out = if_id;
endmodule
