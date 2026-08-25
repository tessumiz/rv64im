package mem_pkg;

    localparam logic [1:0]
        MEM_BYTE  = 2'b00,
        MEM_HWORD = 2'b01,
        MEM_WORD  = 2'b10,
        MEM_DWORD = 2'b11;


    typedef struct packed {
        logic [43:0] root_ppn;
        logic [15:0] asid;
        logic [3:0]  mode;
        logic [1:0]  priv;
        logic        SUM;
        logic        MXR;
    } mmu_ctx_t;


    typedef struct packed {
        logic hit;
        logic fill_req;
        logic ready;
    } plru_ctrl_t;


    // ITLB
    localparam
        // invar
        ITLB_ENTRIES  = 32, // ffs are expensive and take up area + power
        ITLB_WAYS     = 4,  // can affect timing as well as increase synth area

        // var
        ITLB_SETS      = ITLB_ENTRIES / ITLB_WAYS,
        ITLB_BLK_OFF_W = $clog2(ITLB_ENTRIES / ITLB_WAYS);  // block offset


    typedef struct packed {
        logic [44 : ITLB_BLK_OFF_W] vpn_upper;
        logic [15:0] asid;
        logic        g;  // ASID wildcard
    } itlb_tag_t;

    typedef struct packed {
        logic [43:0] ppn;
        logic        u;
        logic        r, x;
        logic        a;
    } itlb_data_t;


    // ICACHE
    localparam
        ICACHE_LINE_SIZE  = 64 * 8,  // Don't change this; else a refactor would be required across files
        ICACHE_WAYS       = 8,
        ICACHE_BLK_OFF_W  = 12,

        ICACHE_OFFSET_W   = $clog2(ICACHE_LINE_SIZE / 8),
        ICACHE_SETS       = 2 ** (ICACHE_BLK_OFF_W - ICACHE_OFFSET_W);


    typedef struct packed {
        logic [43:0] ppn;
    } icache_tag_t;
    
    typedef struct packed {
        logic [ICACHE_LINE_SIZE-1 : 0] data;
    } icache_data_t;

    
    // DTLB
    localparam
        DTLB_ENTRIES = 64,
        DTLB_WAYS    = 8,

        DTLB_BLK_OFF_W = $clog2(DTLB_ENTRIES / DTLB_WAYS);


    typedef struct packed {
        logic [44 : DTLB_BLK_OFF_W] vpn_upper;
        logic [15:0] asid;
        logic        g;  // ASID wildcard
    } dtlb_tag_t;

    typedef struct packed {
        logic [43:0] ppn;
        logic        u;
        logic        r, w, x;
        logic        a, d;
    } dtlb_data_t;


    // DCACHE (NOTE: I'm not unifying I/D data structs; future proofing for some obscure reason)
    localparam
        DCACHE_LINE_SIZE = 64 * 8,  // Don't change this
        DCACHE_BLK_OFF_W = 12,
        DCACHE_WAYS  = 8,

        DCACHE_OFFSET_W   = $clog2(DCACHE_LINE_SIZE / 8),
        DCACHE_SETS       = 2 ** (DCACHE_BLK_OFF_W - DCACHE_OFFSET_W);


    typedef struct packed {
        logic [43:0] ppn;
    } dcache_tag_t;
    
    typedef struct packed {
        logic [DCACHE_LINE_SIZE-1 : 0] data;
    } dcache_data_t;



    // PTW
    typedef struct packed {
        logic [9:0]  reserved;
        logic [7:0]  ppn4;
        logic [8:0]  ppn3;
        logic [8:0]  ppn2;
        logic [8:0]  ppn1;
        logic [8:0]  ppn0;
        logic [1:0]  rsw;
        logic        d;
        logic        a;
        logic        g;
        logic        u;
        logic        x;
        logic        w;
        logic        r;
        logic        v;
    } pte_t;

    typedef struct packed {
        logic [8:0] vpn4, vpn3, vpn2, vpn1, vpn0;
    } vpn_t;


    // PWC
    typedef struct packed {
        logic [8:0]  vpn4, vpn3, vpn2;
        logic        g;
        logic [15:0] asid;
        logic [1:0]  mode;  // satp_mode[1:0] (since codes are 8-10 for sv39-57)
    } pwc_tag_t;

    typedef struct packed {
        logic        valid;
        pwc_tag_t    tag;
        logic [43:0] lvl1_root;
    } pwc_data_t;


    // FSMs
    typedef enum logic [3:0] {
        CACHE_CLR, CACHE_IDLE, CACHE_READ, CACHE_TAG_CMP, CACHE_EVICT,
        CACHE_WRITE, CACHE_REQ_FILL, CACHE_R_FILL, CACHE_SUBWORD_W_FILL
    } set_cache_fsm_t;

    typedef enum logic [2:0] {
        TLB_IDLE, TLB_READ_AND_TAG_CMP, TLB_FAULT_CHECK, TLB_FETCH_PAGE, TLB_WRITE_PAGE, TLB_EVICT
    } set_tlb_fsm_t;

    typedef enum logic [2:0] {
        PTW_IDLE, PTW_CHECK_PWC, PTW_READ, PTW_CHECK_PTE, PTW_WRITE
    } ptw_fsm_t;

    typedef enum logic [2:0] {
        PTW_LVL4, PTW_LVL3, PTW_LVL2, PTW_LVL1, PTW_LVL0
    } ptw_lvl_t;

endpackage
