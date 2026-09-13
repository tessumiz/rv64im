// to be purged after demo

import defs_pkg::*;
import mem_pkg::*;
import zicsr_pkg::*;


module mem_stage (
    input  logic        clk,
    input  logic        rst,
    input  ex_mem_t     ex_mem,

    csr_trap_if.master  trap_bus,

    gen_mem_if.master   ram_bus,
    gen_mem_if.master   mmio_bus,

    output logic        mem_stall,
    output logic        wb,
    output logic [4:0]  wb_rd,
    output logic [63:0] fwd_data,

    output logic [63:0] csr_br_targ,

    output logic        trap_flush,
    output logic        csr_flush,
    output mem_wb_t     out
);

    logic [63:0] addr;
    logic [63:0] r_data;
    logic [63:0] raw_r_data;
    logic [63:0] lsu_w_data_fmt;
    logic [7:0]  lsu_w_mask;
    
    logic        is_misaligned;
    logic [63:0] mem_cause;
    
    logic  is_exc, is_mret, is_sret, is_irq;
    logic  safe, is_mem_op, is_mmio;
    logic [2:0] word_idx;

    set_cache_if #(
        .TAG_T  (dcache_tag_t),
        .DATA_T (dcache_data_t),
        .SETS   (DCACHE_SETS),
        .WAYS   (DCACHE_WAYS)
    ) dcache_bus ();

    lsu u_lsu (
        .is_mem_op     (is_mem_op),
        .f3            (ex_mem.f3),
        .addr          (addr),

        .r_data_raw    (raw_r_data),
        .w_data_raw    (ex_mem.rs2),
        .w_mask        (lsu_w_mask),

        .r_data_fmt    (r_data),
        .w_data_fmt    (lsu_w_data_fmt),

        .is_misaligned (is_misaligned)
    );


    always_comb begin
        addr = ex_mem.ex_res;
        word_idx = addr[5:3]; 

        mem_cause = ex_mem.exc.valid ? ex_mem.exc.cause :
                    64'(ex_mem.ctrl.mem_w ? EXC_STORE_MISALIGNED : EXC_LOAD_MISALIGNED);

        is_exc  = 0; 
        is_mret = 0;
        is_sret = 0;
        is_irq  = 0;

        // is_exc  = (ex_mem.exc.valid || is_misaligned);
        // is_mret = ex_mem.exc.is_mret;
        // is_sret = ex_mem.exc.is_sret;
        // is_irq  = trap_bus.irq_pending;

        safe = !(is_exc || is_mret || is_sret || is_irq);
        is_mem_op = (ex_mem.ctrl.mem_r || ex_mem.ctrl.mem_w) && safe;

        // hardcoded PMA; synths to a redn-OR tree for addr[63:26]
        is_mmio = (addr >= 64'h0400_0000);

        dcache_bus.req.set_idx = addr[11:6];
        dcache_bus.req.tag.ppn = addr[55:12];  // hardcoded for demo

        if (is_mmio) begin
            dcache_bus.req.r_en   =  0;
            dcache_bus.req.w_en   =  0;
            dcache_bus.req.w_mask = '0;
            dcache_bus.req.w_data = '0;

            // well not all of these have to be gated with is_mmio, but doesn't matter for now...
            mmio_bus.addr   = addr;
            mmio_bus.r_en   = is_mem_op && ex_mem.ctrl.mem_r;
            mmio_bus.w_en   = is_mem_op && ex_mem.ctrl.mem_w;
            mmio_bus.w_data = lsu_w_data_fmt;
            mmio_bus.w_mask = lsu_w_mask;
            
            raw_r_data  = mmio_bus.r_data;
            mem_stall   = is_mem_op && !mmio_bus.ready;
        end
        else begin
            dcache_bus.req.r_en   = is_mem_op && ex_mem.ctrl.mem_r;
            dcache_bus.req.w_en   = is_mem_op && ex_mem.ctrl.mem_w;
            dcache_bus.req.w_mask = 64'(lsu_w_mask) << (word_idx * 8);
            dcache_bus.req.w_data = 512'(lsu_w_data_fmt) << (word_idx * 64);
            
            mmio_bus.addr   = '0;
            mmio_bus.r_en   =  0;
            mmio_bus.w_en   =  0;
            mmio_bus.w_data = '0;
            mmio_bus.w_mask = '0;
            
            raw_r_data  = dcache_bus.rsp.r_data[word_idx * 64 +: 64];
            mem_stall   = is_mem_op && !dcache_bus.rsp.ready;
        end


        ram_bus.addr = dcache_bus.mem_req.evict_wb ? 
                   { dcache_bus.mem_req.evict_tag.ppn, dcache_bus.req.set_idx, 6'b0 } :
                   { dcache_bus.req.tag.ppn, dcache_bus.req.set_idx, 6'b0 };

        ram_bus.r_en   = dcache_bus.mem_req.fill_req;
        ram_bus.w_en   = dcache_bus.mem_req.evict_wb;
        ram_bus.w_data = dcache_bus.mem_req.evicted_data;

        dcache_bus.mem_rsp.fill_en = ram_bus.ready && ram_bus.r_en;
        dcache_bus.mem_rsp.fill_data = ram_bus.r_data;
        dcache_bus.mem_rsp.evict_complete = ram_bus.ready && ram_bus.w_en;


        trap_bus.take_exc  = is_exc;
        trap_bus.take_mret = is_mret;
        trap_bus.take_sret = is_sret;
        trap_bus.take_irq  = is_irq && !(is_exc || is_mret);
        trap_bus.cause     = is_exc ? mem_cause : 0;
        trap_bus.pc        = ex_mem.pc;
        trap_bus.tval      = ex_mem.exc.tval;

        trap_flush  = !safe;
        csr_flush   = ex_mem.ctrl.is_csr && safe;
        csr_br_targ = ex_mem.pc + 4;


        out.pc           = ex_mem.pc;
        out.data         = ex_mem.ctrl.mem_r ? r_data : ex_mem.ex_res;
        out.rd           = ex_mem.rd;
        out.csr_new_data = ex_mem.rs2;
        out.csr_addr     = ex_mem.csr_w_addr;
        out.ctrl         = ex_mem.ctrl;
        // out.ctrl.valid   = valid && safe;  bubble detection is unnecessary in wb...
        out.ctrl.is_csr  = ex_mem.ctrl.is_csr && safe;

        wb       = ex_mem.ctrl.wb && safe;
        wb_rd    = ex_mem.rd;
        fwd_data = out.data;
    end

    set_cache u_dcache (
        .clk   (clk),
        .rst   (rst),
        .flush (0),  // never flushes (demo purposes)
        .bus   (dcache_bus)
    );

endmodule
