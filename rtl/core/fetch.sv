import defs_pkg::*;
import mem_pkg::*; 

module fetch (
    input logic clk,
    input logic rst,
    input logic stall,
    input logic flush, 

    input logic take_br,
    input logic take_mepc,
    input logic take_mtvec,

    input logic take_stvec,
    input logic take_sepc,

    input logic take_csr_br,

    input logic [63:0] br_targ,
    input logic [63:0] mepc_targ,
    input logic [63:0] mtvec_targ,

    input logic [63:0] sepc_targ,
    input logic [63:0] stvec_targ,

    input logic [63:0] csr_br_targ,

    // temporary
    output logic [55:0]  ram_addr,
    output logic         ram_r_en,
    input  logic [511:0] ram_r_data,
    input  logic         ram_ready,

    output if_id_t out
);

    logic [63:0] pc;
    logic [63:0] nxt_pc;

    set_cache_if #(
        .TAG_T  (icache_tag_t),
        .DATA_T (icache_data_t),
        .SETS   (ICACHE_SETS),
        .WAYS   (ICACHE_WAYS)
    ) icache_bus ();

    always_comb begin
        icache_bus.req.r_en   =  1; 
        icache_bus.req.w_en   =  0; 
        icache_bus.req.w_mask = '0;
        icache_bus.req.w_data = '0;

        icache_bus.req.set_idx = pc[11:6];
        icache_bus.req.tag.ppn = pc[55:12];  // hardwired; solely for the demo

        ram_r_en = icache_bus.mem_req.fill_req;
        ram_addr = { icache_bus.req.tag.ppn, icache_bus.req.set_idx, 6'b0 };

        icache_bus.mem_rsp.fill_en   = ram_ready && ram_r_en;
        icache_bus.mem_rsp.fill_data = ram_r_data;
        icache_bus.mem_rsp.evict_complete = 1'b1;

        nxt_pc =
            take_br     ? br_targ     :
            take_mepc   ? mepc_targ   :
            take_mtvec  ? mtvec_targ  :
            take_stvec  ? stvec_targ  :
            take_sepc   ? sepc_targ   :
            take_csr_br ? csr_br_targ :
            pc + 4;

        out.pc = pc;
        out.ins = icache_bus.rsp.r_data[ pc[5:2] * 32 +: 32 ];
        out.exc.valid = icache_bus.rsp.ready && !flush;
    end

    set_cache u_icache (
        .clk   (clk),
        .rst   (rst),
        .flush (0),  // disabled; enable only once fence instrs are added...
        .bus   (icache_bus)
    );

    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk (clk),
        .en  (!(stall || !icache_bus.rsp.ready)), 
        .clr (rst),
        .d   (nxt_pc),
        .q   (pc)
    );
endmodule
