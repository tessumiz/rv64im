// I can't use the structs from the pkg directly here (sv rules)

module tb_cache_top import mem_pkg::*; (
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic abort_sig,

    // pipe req
    input  logic [5:0]  cpu_set_idx,
    input  logic [2:0]  cpu_blk_offset,
    input  logic [43:0] cpu_tag_ppn,
    input  logic        cpu_r_en,
    input  logic        cpu_w_en,
    input  logic [63:0] cpu_w_data,
    input  logic [7:0]  cpu_w_mask,

    // pipe rsp
    output logic [63:0] cpu_r_data,
    output logic        cpu_hit,
    output logic        cpu_busy,
    output logic        cpu_ready,

    // miu req
    output logic        miu_req_r_en,
    output logic        miu_req_w_en,
    output logic        miu_req_abort,
    output logic [21:0] miu_req_addr,
    output logic [63:0] miu_req_w_data,

    // miu rsp
    input  logic        miu_rsp_busy,
    input  logic        miu_rsp_ready,
    input  logic        miu_rsp_access_fault,
    input  logic [7:0]  miu_rsp_burst_mask,
    input  logic        miu_rsp_burst_done,
    input  logic [63:0] miu_rsp_r_data
);

    set_cache_if #(
        .TAG_T (dcache_tag_t),
        .SETS  (DCACHE_SETS),
        .WAYS  (DCACHE_WAYS)
    ) bus();


    assign bus.req = '{
        set_idx:    cpu_set_idx,
        blk_offset: cpu_blk_offset,
        tag:        '{ppn: cpu_tag_ppn},
        r_en:       cpu_r_en,
        w_en:       cpu_w_en,
        w_data:     cpu_w_data,
        w_mask:     cpu_w_mask
    };

    assign bus.miu_rsp = '{
        busy:         miu_rsp_busy,
        ready:        miu_rsp_ready,
        access_fault: miu_rsp_access_fault,
        burst_mask:   miu_rsp_burst_mask,
        burst_done:   miu_rsp_burst_done,
        r_data:       miu_rsp_r_data
    };


    always_comb begin
        cpu_r_data = bus.rsp.r_data;
        cpu_hit    = bus.rsp.hit;
        cpu_busy   = bus.rsp.busy;
        cpu_ready  = bus.rsp.ready;

        miu_req_r_en   = bus.miu_req.r_en;
        miu_req_w_en   = bus.miu_req.w_en;
        miu_req_abort  = bus.miu_req.abort;
        miu_req_addr   = bus.miu_req.addr;
        miu_req_w_data = bus.miu_req.w_data;
    end


    set_cache u_set_cache (
        .clk   (clk),
        .rst   (rst),
        .flush (flush),
        .abort_sig (abort_sig),
        .bus   (bus.cache)
    );

    bind set_cache cache_cov u_cache_cov (
        .clk          (clk),
        .rst          (rst),
        .state        (state),
        .req_r_en     (req_r_en),
        .req_w_en     (req_w_en),
        .req_w_mask   (req_w_mask),
        .hit          (hit),
        .ready        (bus.rsp.ready),
        .abort_sig    (abort_sig),
        .flush        (flush),
        .miu_w_en     (bus.miu_req.w_en)
    );

endmodule
