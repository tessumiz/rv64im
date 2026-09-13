import mem_pkg::*;
import defs_pkg::uint;


module set_cache (
    input  logic clk,
    input  logic rst,
    input  logic flush,  // triggers dirty wb fsm

    set_cache_if.cache bus
);

    localparam type DATA_T = bus.DATA_T;
    localparam type TAG_T  = bus.TAG_T;
    localparam uint SETS   = bus.SETS;
    localparam uint WAYS   = bus.WAYS;

    localparam uint WAY_LOG_W = bus.WAY_LOG_W;
    typedef logic  [WAY_LOG_W-1:0] way_idx_t;


    typedef struct packed {
        TAG_T  tag;
        DATA_T data;
    } line_t;

    typedef struct packed {
        logic valid;
        logic dirty;
    } meta_t;


    // bram
    line_t mem  [SETS-1:0][WAYS-1:0];
    meta_t meta [SETS-1:0][WAYS-1:0];

    line_t [WAYS-1:0] curr_line;
    meta_t [WAYS-1:0] curr_meta;
    logic  [WAYS-1:0] cmp_out;

    line_t      hit_line;
    way_idx_t   hit_way;
    logic       hit, miss;

    /* turned into a one-hot fsm for fpga and binary for asic by tools */
    set_cache_fsm_t state;

    logic  is_subword_w;
    assign is_subword_w = !(&bus.req.w_mask);


    // latching req sigs
    logic req_r_en, req_w_en;


    // sigs for writes to cache
    logic       norm_w;
    logic       write;
    way_idx_t   w_way;
    DATA_T      w_data;
    logic       w_dirty;
    logic [bus.W_MASK_LEN-1:0] w_wmask;


    // for prioritizing invalid victims in plru
    logic [bus.WAYS-1:0] cmp_in_valid;


    /*
    A separate clr_in_prog ff was removed; CACHE_CLR was added to state.
    This saves an ff at the expense of more comb logic (minor)
    */

    // set_idx of the set being cleared (and NOT flushed, as it lags by 1 cycle)
    logic [$clog2(SETS):0] curr_clr_addr;

    // flush dirty wb routine
    logic     is_flush;  // ff; assuming flush is a pulse
    logic     clr_done,  flush_set_done, begin_flush_wb;
    way_idx_t curr_flush_way;
    logic     curr_way_dirty;

    always_comb begin
        clr_done       = (curr_clr_addr  == SETS);
        flush_set_done = (curr_flush_way == WAYS - 1);

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
            is_flush      <=  0;
        end

        else if (state == CACHE_CLR) begin
            if (is_flush && begin_flush_wb) begin
                state <= CACHE_FLUSH_DIRTY_SET;
                curr_flush_way <= 0;
            end
            else if (clr_done) begin
                is_flush <= 0;
                state    <= CACHE_IDLE;
            end
            else begin
                curr_line <= mem [curr_clr_addr[$clog2(SETS)-1:0]];
                curr_meta <= meta[curr_clr_addr[$clog2(SETS)-1:0]];

                curr_clr_addr <= curr_clr_addr + 1;
                meta[curr_clr_addr[$clog2(SETS)-1:0]] <= '0; 
            end
        end

        else begin
            if (write) begin
                meta[bus.req.set_idx][w_way].valid <= 1;
                meta[bus.req.set_idx][w_way].dirty <= w_dirty;
            end

            unique case (state)
                CACHE_IDLE : begin
                    if (flush) begin
                        state         <= CACHE_CLR;
                        curr_clr_addr <= '0;
                        curr_meta     <= '0;
                        is_flush      <=  1;
                    end
                    else if (bus.req.r_en || bus.req.w_en) begin
                        state  <= CACHE_READ;

                        req_r_en <= bus.req.r_en;
                        req_w_en <= bus.req.w_en;

                        curr_line <= mem [bus.req.set_idx];
                        curr_meta <= meta[bus.req.set_idx];
                    end
                end

                /* crit path broken down, since tag_cmp is massive... */
                CACHE_READ : begin
                    state <= CACHE_TAG_CMP;
                end

                CACHE_TAG_CMP : begin
                    if (bus.mem_req.evict_wb)
                        state <= CACHE_EVICT;
                    else if (req_r_en)
                        state <= hit ? CACHE_IDLE : CACHE_REQ_FILL;
                    else
                        state <= (is_subword_w && miss) ? CACHE_REQ_FILL : CACHE_WRITE;
                end

                CACHE_EVICT : begin
                    // handle RAM errors later; for now, assume evict always succeeds
                    if (bus.mem_rsp.evict_complete) begin
                        if (req_r_en)
                            state <= hit ? CACHE_IDLE : CACHE_REQ_FILL;

                        else
                            state <= (is_subword_w && miss) ? CACHE_REQ_FILL : CACHE_WRITE;
                    end
                end

                CACHE_FLUSH_DIRTY_SET : begin
                    if (curr_way_dirty) begin
                        if (bus.mem_rsp.evict_complete) begin

                            if (flush_set_done) begin
                                state     <= CACHE_CLR;
                                curr_meta <= '0;
                            end
                            else
                                curr_flush_way <= curr_flush_way + 1;
                        end
                    end
                    else begin
                        if (flush_set_done) begin
                            state     <= CACHE_CLR;
                            curr_meta <= '0;
                        end
                        else
                            curr_flush_way <= curr_flush_way + 1;
                    end
                end

                CACHE_REQ_FILL : begin
                    if (bus.mem_rsp.fill_en)
                        state <= req_r_en ? CACHE_R_FILL : CACHE_SUBWORD_W_FILL;
                end

                CACHE_SUBWORD_W_FILL : begin
                    state <= CACHE_WRITE;
                end

                CACHE_R_FILL, CACHE_WRITE : begin
                    state <= CACHE_IDLE;
                end
            endcase
        end
    end


    always_comb begin
        hit_way  = 0;
        hit_line = 0;
        cmp_out  = 0;

        for (uint i = 0; i < WAYS; i++) begin
            cmp_out[i]      = (curr_meta[i].valid && curr_line[i].tag == bus.req.tag);
            cmp_in_valid[i] =  curr_meta[i].valid;
        end

        /*
        Fix; an if-stmt might synthesize a priority encoder favouring the last HIGH
        I've explicitly made an AND-OR one-hot mux
        */
        for (uint i = 0; i < WAYS; i++) begin
            hit_way  |= ( i[WAY_LOG_W-1:0] & {WAY_LOG_W{cmp_out[i]}} );
            hit_line |= ( curr_line[i] & {$bits(line_t){cmp_out[i]}} );
        end

        bus.rsp.hit = |cmp_out;
        hit         = bus.rsp.hit;
        miss        = !hit;
    end


    // WRITE

    // LRU

    /* Fix; to cut the critical path as well as to remove a caching ff + a fwd-ing mux,
    plru update was changed to happen only when the ready signal is set. Previously:

    victim_way = (state == CACHE_TAG_CMP) ? curr_victim_way : victim_way_ff;
    */
    way_idx_t victim_way;

    tree_plru #(
        .SETS      (SETS),
        .WAYS      (WAYS),
        .WAY_LOG_W (WAY_LOG_W)
    )
    u_tree_plru (
        .clk          (clk),
        .rst          (rst),

        .set_idx      (bus.req.set_idx),
        .ctrl         ({bus.rsp.hit, bus.mem_req.fill_req, bus.rsp.ready}),

        .hit_way      (hit_way),
        .cmp_in_valid (cmp_in_valid),

        .victim_way   (victim_way)
    );


    line_t victim_line;
    meta_t victim_meta;

    line_t flush_line;  // flush dirty wb fsm

    always_comb begin
        victim_line = curr_line[victim_way];
        victim_meta = curr_meta[victim_way];

        flush_line  = curr_line[curr_flush_way];

        // fill_data must remain stable till ready fires
        bus.rsp.r_data = hit ? hit_line.data : bus.mem_rsp.fill_data;

        bus.mem_req.fill_req =
            ((state == CACHE_TAG_CMP) && miss && (req_r_en || (req_w_en && is_subword_w))) ||
            (state == CACHE_REQ_FILL);

        bus.mem_req.evict_wb =
            (state == CACHE_TAG_CMP && miss && victim_meta.valid && victim_meta.dirty) ||
            (state == CACHE_EVICT) ||
            (state == CACHE_FLUSH_DIRTY_SET && curr_way_dirty);

        bus.mem_req.evict_tag    = (state == CACHE_FLUSH_DIRTY_SET) ? flush_line.tag  : victim_line.tag;
        bus.mem_req.evicted_data = (state == CACHE_FLUSH_DIRTY_SET) ? flush_line.data : victim_line.data;

        norm_w =
            (state == CACHE_TAG_CMP && req_w_en && !(miss && is_subword_w)) ||
            (state == CACHE_SUBWORD_W_FILL);

        write  = norm_w || (state == CACHE_REQ_FILL && bus.mem_rsp.fill_en);
        w_way  = (norm_w && hit) ? hit_way : victim_way;


        // hit write/subword-write (note that bus.w_en is already gated to logic 'write'...)
        if (norm_w) begin
            w_data  = bus.req.w_data;
            w_wmask = bus.req.w_mask;
            w_dirty = 1;
        end
        // miss fill; when (state == CACHE_REQ_FILL && bus.fill_en)
        else begin
            w_data  = bus.mem_rsp.fill_data;
            w_wmask = '1;
            w_dirty =  0;
        end

        bus.rsp.busy  = (state != CACHE_IDLE) && !bus.rsp.ready;

        bus.rsp.ready = (state == CACHE_TAG_CMP && req_r_en && hit) ||
                        (state == CACHE_R_FILL || state == CACHE_WRITE);
    end

    always_ff @(posedge clk) begin
        if (!rst && write) begin
            mem [bus.req.set_idx][w_way].tag   <= bus.req.tag;
            
            // # moved upwards...
            // meta[bus.set_idx][w_way].valid <= 1;
            // meta[bus.set_idx][w_way].dirty <= w_dirty;

            for (uint i = 0; i < bus.W_MASK_LEN; i++) begin
                if (w_wmask[i])
                    mem[bus.req.set_idx][w_way].data[8*i +: 8] <= w_data[8*i +: 8];
            end
        end
    end

endmodule
