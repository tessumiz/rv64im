import defs_pkg::uint;


/*
Use this generic full-duplex intf for internal connections.
Dead code elimination will auto-remove unused signals. Beyond that,
unused signals is just a matter of blurring semantic clarity.
*/
interface gen_mem_if #(
    parameter int ADDR_W,
    parameter int DATA_W,

    // meta or any additional payload
    parameter type REQ_DATA_T = logic,
    parameter type RSP_DATA_T = logic
);
    localparam int MASK_W = DATA_W / 8;

    logic [ADDR_W-1:0] addr;

    logic              r_en;
    logic              w_en;
    logic [MASK_W-1:0] w_mask;

    logic [DATA_W-1:0] r_data;
    logic [DATA_W-1:0] w_data;

    REQ_DATA_T         req_data;
    RSP_DATA_T         rsp_data;

    logic              busy;
    logic              ready;
    logic              access_fault;
    logic              page_fault;

    modport master (
        output addr, r_en, w_en, w_mask, w_data, req_data,
        input  r_data, rsp_data, busy, ready, access_fault, page_fault
    );

    modport slave (
        input  addr, r_en, w_en, w_mask, w_data, req_data,
        output r_data, rsp_data, busy, ready, access_fault, page_fault
    );
endinterface



interface set_cache_if #(
    parameter type  TAG_T,
    parameter type  DATA_T,
    parameter uint  SETS,
    parameter uint  WAYS
);
    localparam uint IDX_W      = uint'($clog2(SETS));
    localparam uint WAY_LOG_W  = uint'($clog2(WAYS));
    localparam uint W_MASK_LEN = $bits(DATA_T) / 8;

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


interface tlb_if #(
    parameter type  TAG_T,
    parameter type  DATA_T,
    parameter uint  SETS,
    parameter uint  WAYS
);
    localparam uint IDX_W      = uint'($clog2(SETS));
    localparam uint WAY_LOG_W  = uint'($clog2(WAYS));

    logic  [IDX_W-1:0] set_idx;
    TAG_T  tag;

    logic  valid;
    DATA_T data;

    DATA_T fetched_page;
    logic  page_fetched;
    logic  page_req;
    logic  fetch_fault;

    logic  evict_page_wb;  // D gets set
    logic  [IDX_W-1:0] evict_set_idx;

    logic  hit;
    logic  busy;
    logic  ready;

    logic  page_fault;

    modport master (
        output set_idx, tag, valid, page_fetched, fetched_page, fetch_fault,
        input  data, hit, ready, page_req, busy, page_fault, evict_page_wb, evict_set_idx
    );

    modport cache (
        input  set_idx, tag, valid, page_fetched, fetched_page, fetch_fault,
        output data, hit, ready, page_req, busy, page_fault, evict_page_wb, evict_set_idx
    );
endinterface


// Removed mmu_ctx_if; it's a struct now
