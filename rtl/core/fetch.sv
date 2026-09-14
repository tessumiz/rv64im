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
        icache_bus.req.r_en   =  1;  // this anyways gets latched by set_cache
        icache_bus.req.w_en   =  0;
        icache_bus.req.w_mask = '0;
        icache_bus.req.w_data = '0;

        icache_bus.req.set_idx = pc[11:6];
        icache_bus.req.tag.ppn = pc[55:12];

        ram_bus.r_en = icache_bus.mem_req.fill_req;

        ram_bus.addr = {
            icache_bus.req.tag.ppn,
            icache_bus.req.set_idx,
            6'b0
        };

        // zicsr might have errors, add this later...

        // nxt_pc =
        //     take_mtvec  ? mtvec_targ  :
        //     take_mepc   ? mepc_targ   :
        //     take_stvec  ? stvec_targ   :
        //     take_sepc   ? sepc_targ   :
        //     take_csr_br ? csr_br_targ :
        //     take_br     ? br_targ     :
        //     pc + 4;

        nxt_pc = rst ? 64'h8000_0000 : (take_br ? br_targ : pc + 4);
    end


    always_comb begin
        icache_bus.mem_rsp.fill_en = ram_bus.ready && ram_bus.r_en;
        icache_bus.mem_rsp.fill_data = ram_bus.r_data;
        icache_bus.mem_rsp.evict_complete = 1;
    end


    logic [31:0] pending_ins;
    logic        ready_pending;

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            ready_pending <= 0;
        end
        else if (icache_bus.rsp.ready && stall) begin
            pending_ins <= icache_bus.rsp.r_data[pc[5:2] * 32 +: 32];
            ready_pending <= 1;
        end
        else if (!stall) begin
            ready_pending <= 0;
        end
    end


    always_comb begin
        out.pc = pc;
        out.ins = ready_pending ? pending_ins : icache_bus.rsp.r_data[pc[5:2] * 32 +: 32];
        out.exc.valid = 1'b0;
        out.valid = 1;
    end


    set_cache u_icache (
        .clk   (clk),
        .rst   (rst),
        .flush (0),  // icache doesn't need to flush
        .bus   (icache_bus),
        .abort (flush)
    );


    assign icache_stall = !(ready_pending || icache_bus.rsp.ready);


    gen_reg #(.T(logic [63:0]))
    u_pc (
        .clk (clk),
        .en  (rst || flush || !(stall || icache_stall)),
        .clr (0),
        .d   (nxt_pc),
        .q   (pc)
    );


// logic [63:0] dbg_pc             /* verilator public_flat */;
// logic [63:0] dbg_nxt_pc         /* verilator public_flat */;
logic [31:0] dbg_ins            /* verilator public_flat */;

// logic        dbg_stall          /* verilator public_flat */;
// logic        dbg_flush          /* verilator public_flat */;

// logic        dbg_take_br        /* verilator public_flat */;
// logic [63:0] dbg_br_targ        /* verilator public_flat */;

// logic        dbg_icache_stall   /* verilator public_flat */;
// logic        dbg_ready_pending  /* verilator public_flat */;

// logic        dbg_rsp_ready      /* verilator public_flat */;
// logic        dbg_ram_r_en       /* verilator public_flat */;
// logic        dbg_ram_ready      /* verilator public_flat */;

// logic        dbg_pc_en          /* verilator public_flat */;

// assign dbg_pc            = pc;
// assign dbg_nxt_pc        = nxt_pc;
assign dbg_ins           = out.ins;

// assign dbg_stall         = stall;
// assign dbg_flush         = flush;

// assign dbg_take_br       = take_br;
// assign dbg_br_targ       = br_targ;

// assign dbg_icache_stall  = icache_stall;
// assign dbg_ready_pending = ready_pending;

// assign dbg_rsp_ready     = icache_bus.rsp.ready;
// assign dbg_ram_r_en      = ram_bus.r_en;
// assign dbg_ram_ready     = ram_bus.ready;

// assign dbg_pc_en = rst || !(stall || icache_stall);
endmodule
