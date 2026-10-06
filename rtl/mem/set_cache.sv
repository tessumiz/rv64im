module set_cache import mem_pkg::*, defs_pkg::uint; (
    input  logic clk,
    input  logic rst,
    input  logic flush,  // triggers dirty wb fsm
    input  logic abort_sig,  // cpp name coll with 'abort' (verilator)

    set_cache_if.cache bus
);

    localparam type DATA_T = cache_data_t;
    localparam type TAG_T  = type(bus.req.tag);
    localparam uint SETS   = bus.SETS;
    localparam uint WAYS   = bus.WAYS;

    localparam uint WAY_LOG_W = bus.WAY_LOG_W;
    typedef logic  [WAY_LOG_W-1:0] way_idx_t;


    typedef struct packed {
        logic valid;
        logic dirty;
    } meta_t;


    // bram

    /* tag and data are split now; less routing, and most imp allows native w_mask byte-en.
       Judge the ROI later (during the perf-asic phase...)
    */
    TAG_T  [WAYS-1:0] tag_mem  [SETS-1:0];
    DATA_T [WAYS-1:0] data_mem [SETS-1:0];
    meta_t [WAYS-1:0] meta [SETS-1:0] /* verilator public */;

    TAG_T  [WAYS-1:0] curr_tag;
    DATA_T [WAYS-1:0] curr_data;
    meta_t [WAYS-1:0] curr_meta;
    logic  [WAYS-1:0] cmp_out;

    DATA_T      hit_data;
    way_idx_t   hit_way;
    logic       hit, miss;

    /* turned into a one-hot fsm for fpga and binary for asic by tools */
    set_cache_fsm_t state;


    // latching req sigs
    logic  req_r_en, req_w_en;
    TAG_T  req_tag;
    logic  [63:0] req_w_data;
    logic  [7:0]  req_w_mask;
    logic  [$clog2(SETS)-1:0] req_set_idx;
    logic  [2:0] req_blk_offset;


    // sigs for writes to cache
    logic     norm_w;  // ≤ 8B
    logic     burst_w;
    logic     write;

    DATA_T    w_data;
    way_idx_t w_way;
    logic [63:0] w_wmask;

    DATA_T    r_filled_data;


    // for prioritizing invalid victims in plru
    logic [bus.WAYS-1:0] cmp_in_valid;


    /* Fix; to cut the critical path as well as to remove a caching ff + a fwd-ing mux,
    plru update was changed to happen only when the ready signal is set. Previously:

    victim_way = (state == CACHE_TAG_CMP) ? curr_victim_way : victim_way_ff;
    */
    way_idx_t victim_way;


    // worth it, or pay the 1 cycle of latency which gets amortized? what if I add an L2 cache?
    logic [63:0] beat_8_read_fwd;


    // set_idx of the set being cleared (and NOT flushed, as it lags by 1 cycle)
    logic [$clog2(SETS):0] curr_clr_addr;

    // flush dirty wb routine
    logic     clr_done,  set_flushed, begin_flush_wb;
    way_idx_t curr_flush_way;
    logic     curr_way_dirty;

    /* NOTE: the flush routine reuses clr's signals as of now */

    always_comb begin
        clr_done    = (curr_clr_addr  == SETS);
        set_flushed = (curr_flush_way == WAYS - 1'b1);

        begin_flush_wb = 0;
        for (uint i = 0; i < WAYS; i++)
            begin_flush_wb |= curr_meta[i].dirty;

        curr_way_dirty = curr_meta[curr_flush_way].dirty;
    end


    // master fsm
    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= CACHE_CLR;
            curr_clr_addr <= '0;
            curr_meta     <= '0;  // flush fsm must start with |dirty = 0
        end

        else begin
            unique case (state)
                CACHE_IDLE : begin
                    /* irq amidst a dcu cache is still undecided, if I would break it down into
                       an abort followed by a flush signal; flush in this case must at least be
                       held for 2 cycles then. Let's see... */
                    if (flush) begin
                        state         <= CACHE_FLUSH;
                        curr_clr_addr <= 1;
                        curr_meta     <= meta[0];
                        curr_tag      <= tag_mem[0];
                        curr_data     <= data_mem[0];
                    end

                    else if (bus.req.r_en || bus.req.w_en) begin
                        state  <= CACHE_INIT_READ;

                        req_r_en    <= bus.req.r_en;
                        req_w_en    <= bus.req.w_en;
                        req_w_data  <= bus.req.w_data;
                        req_w_mask  <= bus.req.w_mask;
                        req_set_idx <= bus.req.set_idx;

                        curr_tag  <= tag_mem  [bus.req.set_idx];

                        // OR-ed with (state == CACHE_READ_AFTER_R_FILL && busrt_done) later down
                        curr_data <= data_mem [bus.req.set_idx];
                        curr_meta <= meta     [bus.req.set_idx];
                    end
                end

                CACHE_CLR : begin
                    if (clr_done)
                        state <= CACHE_IDLE;

                    else begin
                        curr_clr_addr <= curr_clr_addr + 1;
                        meta[curr_clr_addr[$clog2(SETS)-1:0]] <= '0;
                    end
                end

                CACHE_FLUSH : begin
                    if (begin_flush_wb) begin
                        state <= CACHE_FLUSH_DIRTY_SET;
                        curr_flush_way <= 0;
                    end

                    else if (clr_done)
                        state <= CACHE_IDLE;

                    else begin
                        curr_tag   <= tag_mem  [curr_clr_addr];
                        curr_data  <= data_mem [curr_clr_addr];
                        curr_meta  <= meta     [curr_clr_addr];

                        curr_clr_addr <= curr_clr_addr + 1;
                    end
                end

                CACHE_FLUSH_DIRTY_SET : begin
                    if (curr_way_dirty) begin
                        if (bus.miu_rsp.burst_done) begin
                            if (set_flushed) begin
                                state     <= CACHE_FLUSH;
                                curr_meta <= '0;
                            end
                            else
                                curr_flush_way <= curr_flush_way + 1;
                            
                            meta[curr_clr_addr-1][curr_flush_way].dirty <= 0;
                        end
                    end

                    else begin
                        if (set_flushed) begin
                            state     <= CACHE_FLUSH;
                            curr_meta <= '0;
                        end
                        else
                            curr_flush_way <= curr_flush_way + 1;
                    end
                end


                /* crit path broken down, since tag_cmp is massive... */
                CACHE_INIT_READ : begin
                    state   <= CACHE_TAG_CMP;
                    req_tag <= bus.req.tag;
                    req_blk_offset <= bus.req.blk_offset;
                end

                CACHE_TAG_CMP : begin
                    if (bus.miu_req.w_en) begin
                        assert (miss) else 
                                $error("Eviction taken during hit; subword fill unrequired for hits");

                        state <= CACHE_EVICT;
                    end

                    else begin
                        if (req_w_en && hit)
                            meta[req_set_idx][hit_way].dirty <= 1;

                        state <= hit ? CACHE_IDLE : CACHE_REQ_FILL;
                    end
                end


                /* BIG GOTCHA; abort during evict renders the particular main memory stale with
                   torn, incomplete write; the local cache line would still be marked as dirty */
                CACHE_EVICT : begin
                    // handle RAM errors later; for now, assume evict always succeeds
                    if (bus.miu_rsp.burst_done) begin
                        state <= CACHE_REQ_FILL;

                        meta[req_set_idx][victim_way].valid <= 0;
                    end
                end

                CACHE_REQ_FILL : begin
                    if (bus.miu_rsp.ready)
                        state <= req_r_en ? CACHE_R_FILL : CACHE_W_FILL;
                end

                // burst fsm will be handled by miu
                CACHE_W_FILL : begin
                    if (bus.miu_rsp.burst_done) begin
                        state <= CACHE_NORM_WRITE;

                        /*
                        poor ROI; trying to squeeze perf out of a special case where
                        an abort_sig precisely occurs after a burst fill is done, trying
                        to mark the fetched data as valid instead of discarding it
                        */
                        // meta[req_set_idx][victim_way] <= '{ valid: 1, dirty: 0 };
                    end
                end

                CACHE_R_FILL : begin
                    if (bus.miu_rsp.burst_done) begin
                        state <= CACHE_READ_AFTER_R_FILL;

                        curr_data <= data_mem[req_set_idx];
                        beat_8_read_fwd <= bus.miu_rsp.r_data;

                        meta[req_set_idx][victim_way] <= '{ valid: 1, dirty: 0 };
                    end
                end

                CACHE_NORM_WRITE : begin
                    state <= CACHE_IDLE;
                    meta[req_set_idx][w_way] <= '{ valid: 1, dirty: 1 };
                end

                CACHE_READ_AFTER_R_FILL : begin
                    state <= CACHE_IDLE;
                end

                default: ;
            endcase

            if (abort_sig) begin
                state <= CACHE_IDLE;
                if (state == CACHE_REQ_FILL || state == CACHE_W_FILL || state == CACHE_R_FILL)
                    meta[req_set_idx][victim_way].valid <= 0;
            end
        end
    end


    always_comb begin
        hit_way  = 0;
        hit_data = 0;
        cmp_out  = 0;

        for (uint i = 0; i < WAYS; i++) begin
            cmp_out[i]      = (curr_meta[i].valid && curr_tag[i] == req_tag);
            cmp_in_valid[i] =  curr_meta[i].valid;
        end

        /*
        Fix; an if-stmt might synthesize a priority encoder favouring the last HIGH
        I've explicitly made an AND-OR one-hot mux
        */
        for (uint i = 0; i < WAYS; i++) begin
            hit_way  |= ( i[WAY_LOG_W-1:0] & {WAY_LOG_W{cmp_out[i]}} );
            hit_data |= ( curr_data[i] & {$bits(DATA_T){cmp_out[i]}} );
        end

        bus.rsp.hit = |cmp_out;
        hit         = bus.rsp.hit;
        miss        = !hit;
    end


    // WRITE

    // LRU

    tree_plru #(
        .SETS      (SETS),
        .WAYS      (WAYS),
        .WAY_LOG_W (WAY_LOG_W)
    )
    u_tree_plru (
        .clk          (clk),
        .rst          (rst),

        .set_idx      (req_set_idx),
        .ctrl         ({hit, bus.miu_req.r_en, bus.rsp.ready}),

        .hit_way      (hit_way),
        .cmp_in_valid (cmp_in_valid),

        .victim_way   (victim_way)
    );


    TAG_T  victim_tag;
    DATA_T victim_data;
    meta_t victim_meta;

    TAG_T  flush_tag;  // flush dirty wb fsm
    DATA_T flush_data;

    logic  victim_present;
    assign victim_present = victim_meta.valid && victim_meta.dirty;

    logic [511:0] w_sel_data;

    logic [7:0] burst_mask;
    assign      burst_mask = bus.miu_rsp.burst_mask;



    always_comb begin
        victim_tag  = curr_tag[victim_way];
        victim_data = curr_data[victim_way];
        victim_meta = curr_meta[victim_way];
        
        flush_tag   = curr_tag[curr_flush_way];
        flush_data  = curr_data[curr_flush_way];

        // Fix; deferred subword fill r_en till evict wb completes...
        // abort_sig gating is unnecessary; miu handles that
        bus.miu_req.r_en = (
            (state == CACHE_TAG_CMP && miss && !victim_present) ||
            (state == CACHE_REQ_FILL)
        );

        bus.miu_req.w_en = (
            (state == CACHE_TAG_CMP && miss && victim_present) ||
            (state == CACHE_EVICT) ||
            (state == CACHE_FLUSH_DIRTY_SET && curr_way_dirty)
        );

        bus.miu_req.addr =
            (state == CACHE_FLUSH_DIRTY_SET) ?
              { flush_tag.ppn,  6'(curr_clr_addr - 1'b1), 6'b0 }
            : (state == CACHE_TAG_CMP && miss && victim_present) ?  // another candidate for our mealy-to-moore refactor
              { victim_tag.ppn, req_set_idx, 6'b0 }
            : { req_tag.ppn, req_set_idx, 6'b0 };


        w_sel_data = (state == CACHE_FLUSH_DIRTY_SET) ? flush_data : victim_data;

        bus.miu_req.w_data = '0;

        for (int i = 0; i < 8; i++)
            bus.miu_req.w_data |= w_sel_data[i*64 +: 64] & {64{burst_mask[i]}};


        /*
        miu fsm handles this; let the cache immediately go to IDLE
        evicts precede fills, and the fill valid bit is set only at the last burst cycle,
        hence correctness issues are absent. If abort_sig arrives amidst an eviction, let the
        miu handle it appropriately; either errors out (currently), or some other behaviour
        */
        bus.miu_req.abort = abort_sig;
    end

    always_comb begin
        // change these into moore machines later; degrading asic quality for reducing latency of
        // an already latent operation is terrible ROI
        norm_w =
            (state == CACHE_TAG_CMP && req_w_en && hit) ||
            (state == CACHE_NORM_WRITE);

        burst_w =
            (state == CACHE_REQ_FILL && bus.miu_rsp.ready) ||
            (state == CACHE_R_FILL || state == CACHE_W_FILL);


        write  = !abort_sig && (norm_w || burst_w);
        w_way  = (req_w_en && hit) ? hit_way : victim_way;


        if (norm_w) begin
            w_data  = 512'(req_w_data) << (req_blk_offset * 64);
            w_wmask = 64'(req_w_mask)  << (req_blk_offset * 8);
        end
        else begin
            w_data  = {8{bus.miu_rsp.r_data}};

            w_wmask = {
                {8{burst_mask[7]}},
                {8{burst_mask[6]}},
                {8{burst_mask[5]}},
                {8{burst_mask[4]}},
                {8{burst_mask[3]}},
                {8{burst_mask[2]}},
                {8{burst_mask[1]}},
                {8{burst_mask[0]}}
            };
        end

    end

    always_comb begin
        // fill_data must remain stable till ready fires
        bus.rsp.ready = (state == CACHE_TAG_CMP && hit) ||
                        (state == CACHE_READ_AFTER_R_FILL) ||
                        (state == CACHE_NORM_WRITE);

        bus.rsp.busy  = (state != CACHE_IDLE) && !bus.rsp.ready;  // readys leads CACHE_IDLE, hence why gated here

        r_filled_data  = { beat_8_read_fwd, curr_data[victim_way][447:0] };

        bus.rsp.r_data = hit ? hit_data[req_blk_offset * 64 +: 64] 
                             : r_filled_data[req_blk_offset * 64 +: 64];
    end

    always_ff @(posedge clk) begin
        if (!rst && write) begin
            tag_mem [req_set_idx][w_way] <= req_tag;

            for (uint i = 0; i < 64; i++) begin
                if (w_wmask[i])
                    data_mem[req_set_idx][w_way][8*i +: 8] <= w_data[8*i +: 8];
            end
        end
    end

endmodule
