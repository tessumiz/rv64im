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

    typedef enum { IDLE, TAG_CMP, REQ_FILL, R_FILL, SUBWORD_W_FILL, WRITE } set_cache_fsm_t;
endpackage
