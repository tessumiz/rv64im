package mem_pkg;

    typedef struct packed {
        logic [11:0] asid;
        logic [63:0] vpn;
        logic [63:0] ppn;

        logic        g;
        logic        u;
        logic        r, w, x;
        logic        d;
    } tlb_entry_t;


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


    typedef struct packed {
        logic [8:0]  vpn4, vpn3, vpn2;
        logic [15:0] asid;
        logic [1:0]  mode;  // satp_mode[1:0] (since codes are 8-10 for sv39-57)
    } pwc_tag_t;

    typedef struct packed {
        logic        valid;
        pwc_tag_t    tag;
        logic [43:0] lvl1_root;
    } pwc_data_t;


    typedef enum { CACHE_IDLE, CACHE_TAG_CMP, CACHE_EVICT, CACHE_REQ_FILL,
                   CACHE_R_FILL, CACHE_SUBWORD_W_FILL, CACHE_WRITE } set_cache_fsm_t;

    typedef enum { PTW_IDLE, PTW_CHECK_PWC, PTW_READ, PTW_CHECK_PTE, PTW_WRITE } ptw_fsm_t;
    typedef enum { PTW_LVL4, PTW_LVL3, PTW_LVL2, PTW_LVL1, PTW_LVL0 } ptw_lvl_t;

endpackage
