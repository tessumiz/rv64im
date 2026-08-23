import defs_pkg::uint;


interface imem_if;
    logic [63:0] v_addr;

    logic        r_en;
    logic [31:0] r_data;

    logic        busy, ready;
    logic        access_fault, page_fault;

    modport master (
        output v_addr, r_en,
        input r_data, busy, ready, access_fault, page_fault
    );

    modport slave (
        input v_addr, r_en,
        output r_data, busy, ready, access_fault, page_fault
    );
endinterface


interface dmem_if;
    logic [63:0] v_addr;

    logic        r_en;
    logic [63:0] r_data;

    logic        w_en;
    logic [63:0] w_data;
    logic [7:0]  w_mask;

    logic        busy, ready;
    logic        access_fault, page_fault;

    modport master (
        output v_addr, w_data, w_mask, w_en, r_en,
        input  r_data, busy, ready, access_fault, page_fault
    );

    modport slave (
        input  v_addr, w_data, w_mask, w_en, r_en,
        output r_data, busy, ready, access_fault, page_fault
    );
endinterface



interface set_cache_if #(
    parameter type  TAG_T,
    parameter type  DATA_T,
    parameter uint  SETS,
    parameter uint  WAYS
);
    localparam uint IDX_W      = uint'($clog2(SETS));
    localparam uint W_MASK_LEN = $bits(DATA_T) / 8;
    parameter  uint WAY_LOG_W  = $clog2(bus.WAYS);

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
    logic  busy;
    logic  ready;

    modport master (
        output set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, evict_complete,
        input  r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req, busy
    );

    modport cache (
        input  set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, evict_complete,
        output r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req, busy
    );
endinterface


interface ptw_dram_if;
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


// Removed mmu_ctx_if; it's a struct now
