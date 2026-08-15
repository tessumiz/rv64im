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

    typedef enum { CACHE_IDLE, TAG_CMP, EVICT, REQ_FILL, R_FILL, SUBWORD_W_FILL, WRITE } set_cache_fsm_t;

    typedef enum { PTW_IDLE, PTW_WAIT, PTW_WALK } ptw_fsm_t;
    typedef enum { PTW_LVL1, PTW_LVL2, PTW_LVL3 } ptw_lvl_t;

endpackage
