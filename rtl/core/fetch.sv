// to be purged after demo

module fetch import defs_pkg::*, mem_pkg::*; (
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

    // temp
    gen_mem_if.master ram_bus,

    output if_id_t out,
    output logic   icache_stall
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
        icache_bus.req.r_en   = !stall || icache_bus.rsp.busy;
        icache_bus.req.w_en   =  0; 
        icache_bus.req.w_mask = '0;
        icache_bus.req.w_data = '0;

        icache_bus.req.set_idx = pc[11:6];
        icache_bus.req.tag.ppn = pc[55:12];  // hardwired; solely for the demo

        ram_bus.r_en = icache_bus.mem_req.fill_req;
        ram_bus.addr = { icache_bus.req.tag.ppn, icache_bus.req.set_idx, 6'b0 };

        icache_bus.mem_rsp.fill_en   = ram_bus.ready && ram_bus.r_en;
        icache_bus.mem_rsp.fill_data = ram_bus.r_data;
        icache_bus.mem_rsp.evict_complete = 1'b1;


        // zicsr might have errors, add this later...

        // nxt_pc =
        //     take_mtvec  ? mtvec_targ  :
        //     take_mepc   ? mepc_targ   :
        //     take_stvec  ? stvec_targ  :
        //     take_sepc   ? sepc_targ   :
        //     take_csr_br ? csr_br_targ :
        //     take_br     ? br_targ     :
        //     pc + 4;

        nxt_pc = rst ? 64'h8000_0000 : (take_br ? br_targ : pc + 4);

        out.pc = pc;
        out.ins = icache_bus.rsp.r_data[ pc[5:2] * 32 +: 32 ];
        out.exc.valid = 0;  // No errors for now...
    end

    set_cache u_icache (
        .clk   (clk),
        .rst   (rst),
        .flush (0),  // icache doesn't need to flush
        .bus   (icache_bus)
    );

    assign icache_stall = !icache_bus.rsp.ready || icache_bus.rsp.busy;

    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk (clk),
        .en  (rst || !(stall || icache_stall)), 
        .clr (0),
        .d   (nxt_pc),
        .q   (pc)
    );
endmodule
