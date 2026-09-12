import defs_pkg::uint;
import mem_pkg::*;


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

    typedef struct packed {
        logic [IDX_W-1:0] set_idx;
        TAG_T             tag;
        logic             r_en;
        logic             w_en;
        DATA_T            w_data;
        logic [W_MASK_LEN-1:0] w_mask;
    } req_t;

    typedef struct packed {
        DATA_T r_data;
        logic  hit;
        logic  busy;
        logic  ready;
    } rsp_t;

    typedef struct packed {
        logic  evict_wb;
        TAG_T  evict_tag;
        DATA_T evicted_data;
        logic  fill_req;
    } mem_req_t;

    typedef struct packed {
        logic  fill_en;
        DATA_T fill_data; // at req_master's set_idx
        logic  evict_complete;
    } mem_rsp_t;

    req_t     req;
    rsp_t     rsp;
    mem_req_t mem_req;
    mem_rsp_t mem_rsp;

    modport master (
        output req, mem_rsp,
        input  rsp, mem_req
    );

    modport cache (
        input  req, mem_rsp,
        output rsp, mem_req
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

    typedef struct packed {
        logic             valid;
        logic [IDX_W-1:0] set_idx;
        TAG_T             tag;
        logic             u, r, w, x;
        mmu_ctx_t         mmu_ctx;
    } req_t;

    typedef struct packed {
        logic [43:0] ppn_out;
        logic        hit;
        logic        busy;
        logic        ready;
        logic        page_fault;
    } rsp_t;

    typedef struct packed {
        logic  page_req;

        // whatever changes can be made from the master-to-tlb side; include any which was left out...
        // consider hiding this latency with buffers later...
        logic  evict_page_wb;
        // vpn_t  evict_page_vaddr;  // let the ifu/dcu handle this
    } mem_req_t;

    typedef struct packed {
        logic            page_fetched;
        DATA_T           fetched_page;
        logic            fetched_is_super;
        superpage_mask_t fetched_super_mask;
        logic            fetch_fault;
        logic            evict_done;
    } mem_rsp_t;

    req_t     req;
    rsp_t     rsp;
    mem_req_t mem_req;
    mem_rsp_t mem_rsp;

    modport master (
        output req, mem_rsp,
        input  rsp, mem_req
    );

    modport cache (
        input  req, mem_rsp,
        output rsp, mem_req
    );
endinterface


// Removed mmu_ctx_if; it's a struct now
