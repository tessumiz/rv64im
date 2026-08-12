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
    logic [63:0] v_addr;

    logic        r_en;
    logic [63:0] r_data;

    logic        w_en;
    logic [63:0] w_data;
    logic [1:0]  f3_2;  // for the lsu

    logic        busy;

    logic        access_fault;
    logic        page_fault;

    modport master (
        output v_addr, f3_2, w_data, w_en, r_en,
        input  r_data, busy, access_fault, page_fault
    );

    modport slave (
        input  v_addr, f3_2, w_data, w_en, r_en,
        output r_data, busy, access_fault, page_fault
    );
endinterface


// set assoc
interface set_cache_if #(
    parameter type TAG_T,
    parameter type DATA_T,
    parameter int  SETS
);
    localparam int IDX_W = $clog2(SETS);

    logic  [IDX_W-1:0] set_idx;
    TAG_T  tag;

    logic  r_en;
    DATA_T r_data;

    logic  w_en;
    DATA_T w_data;

    logic [$bits(DATA_T)-1:0]     w_mask;
    logic [$clog2($bits(DATA_T))] w_width;

    logic  evict_wb;
    TAG_T  evict_tag;
    DATA_T evicted_data;

    logic  fill_en;
    DATA_T fill_data;  // at req_master's set_idx
    logic  fill_req;

    logic  hit;
    logic  ready;

    modport req (
        output set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, w_width,
        input  r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req
    );

    modport slave(
        input  set_idx, tag, r_en, w_en, w_data, fill_en, fill_data, w_mask, w_width,
        output r_data, hit, ready, evict_wb, evict_tag, evicted_data, fill_req
    );
endinterface
