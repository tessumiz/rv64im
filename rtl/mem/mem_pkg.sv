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
        logic [25:0] ppn2;
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
    } sv39_pte_t;


    typedef enum { CACHE_IDLE, TAG_CMP, EVICT, REQ_FILL, R_FILL, SUBWORD_W_FILL, WRITE } set_cache_fsm_t;

    typedef enum { PTW_IDLE, PTW_WALK, PTW_READ, PTW_WRITE } ptw_fsm_t;
    typedef enum { PTW_LVL2, PTW_LVL1, PTW_LVL0 } ptw_lvl_t;

endpackage
