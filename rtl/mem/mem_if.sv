interface imem_if;
    logic [63:0] v_addr;
    logic [31:0] data;

    logic        r_en;
    logic        busy;

    logic        access_fault;
    logic        page_fault;

    modport master (
        output v_addr, r_en,
        input data, busy, access_fault, page_fault
    );

    modport slave (
        input v_addr, r_en,
        output data, busy, access_fault, page_fault
    );
endinterface


interface dmem_if;
    logic [63:0] p_addr;

    logic        r_en;
    logic [63:0] r_data;

    logic        w_en;
    logic [63:0] w_data;
    logic [1:0]  f3_2;  // for the lsu

    logic        busy;

    logic        access_fault;
    logic        page_fault;

    modport master (
        output p_addr, f3_2, w_data, w_en, r_en,
        input  r_data, busy, access_fault, page_fault
    );

    modport slave (
        input  p_addr, f3_2, w_data, w_en, r_en,
        output r_data, busy, access_fault, page_fault
    );
endinterface


// set assoc cache
interface set_cache_if #(
    parameter type TAG_T,
    parameter type DATA_T,
    parameter int  SETS
);
    localparam int IDX_W  = $clog2(SETS);
    localparam int W_MASK_LEN = $bits(DATA_T) / 8;

    logic  [IDX_W-1:0] set_idx;
    TAG_T  tag;

    logic  r_en;
    DATA_T r_data;

    logic  w_en;
    DATA_T w_data;

    // byte-mask
    logic [W_MASK_LEN-1:0] w_mask;

    logic  evict_wb;
    TAG_T  evict_tag;
    DATA_T evicted_data;
    logic  evict_complete;

    logic  fill_en;
    DATA_T fill_data;  // at req_master's set_idx
    logic  fill_req;

    logic  hit;
    logic  ready;

    modport req (
        output set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, evict_complete,
        input  r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req
    );

    modport slave(
        input  set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, evict_complete,
        output r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req
    );
endinterface


// ptw
interface dram_if;
    logic [55:0] addr;

    logic        r_en;
    logic [63:0] r_data;

    logic        w_en;
    logic [63:0] w_data;

    logic        busy;
    logic        ready;
    logic        access_fault;

    modport master (
        output addr, r_en, w_en, w_data,
        input  busy, ready, r_data, access_fault
    );

    modport slave (
        input  addr, r_en, w_en, w_data,
        output busy, ready, r_data, access_fault
    );
endinterface



interface mmu_ctx_if;
    logic [43:0] root_ppn;
    logic [3:0]  mode;
    logic        SUM;
    logic        MXR;
    logic [1:0]  priv;
    logic [15:0] asid;

    modport csr_master (
        output asid, mode, SUM, MXR
    );

    modport tlb_view (
        input asid, mode, SUM, MXR, priv
    );

    modport ptw_view (
        input root_ppn, asid, mode, SUM, MXR, priv
    );

endinterface
