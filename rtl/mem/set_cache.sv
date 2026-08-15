import mem_pkg::*;

module set_cache #(
    parameter type DATA_T,
    parameter type TAG_T
)(
    input  logic clk,
    input  logic rst,

    set_cache_if.slave bus
);

    typedef struct packed {
        TAG_T  tag;
        DATA_T data;
    } line_t;

    typedef struct packed {
        logic valid;
        logic dirty;
    } meta_t;


    line_t mem  [bus.SETS-1:0][7:0];
    meta_t meta [bus.SETS-1:0][7:0];

    line_t [7:0] cmp_in_line;
    meta_t [7:0] cmp_in_meta;
    logic  [7:0] cmp_out;

    line_t      hit_line;
    logic [2:0] hit_way;
    logic       hit, miss;

    set_cache_fsm_t state;

    logic  is_subword_w;
    assign is_subword_w = !(&bus.w_mask);


    // meta clear fsm
    logic clr_in_prog;
    int   curr_clr_addr;  // set idx...


    // sigs for writes to cache
    logic       norm_w;
    logic       write;
    logic [2:0] w_way;
    DATA_T      w_data;
    logic       w_dirty;
    logic [bus.W_MASK_LEN-1:0] w_wmask;


    // master fsm
    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= CACHE_IDLE;
            clr_in_prog   <= 1;
            curr_clr_addr <= 0;
        end
        else if (clr_in_prog) begin
            clr_in_prog         <= (curr_clr_addr != bus.SETS - 1);
            curr_clr_addr       <= curr_clr_addr + 1;
            meta[curr_clr_addr] <= '0;
        end
        else begin
            if (write) begin
                meta[bus.set_idx][w_way].valid <= 1;
                meta[bus.set_idx][w_way].dirty <= w_dirty;
            end

            unique case (state)
                CACHE_IDLE : begin
                    if (bus.r_en || bus.w_en) begin
                        state  <= TAG_CMP;
                        cmp_in_line <= mem [bus.set_idx];
                        cmp_in_meta <= meta[bus.set_idx];
                    end
                end

                TAG_CMP : begin
                    if (bus.evict_wb)
                        state <= EVICT;
                    else if (bus.r_en)
                        state <= hit ? CACHE_IDLE : REQ_FILL;
                    else
                        state <= (is_subword_w && miss) ? REQ_FILL : WRITE;
                end

                EVICT : begin
                    if (bus.evict_complete) begin
                        if (bus.r_en)
                            state <= hit ? CACHE_IDLE : REQ_FILL;
                        else
                            state <= (is_subword_w && miss) ? REQ_FILL : WRITE;
                    end
                end

                REQ_FILL : begin
                    if (bus.fill_en)
                        state <= bus.r_en ? R_FILL : SUBWORD_W_FILL;
                end

                SUBWORD_W_FILL : begin
                    state <= WRITE;
                end

                R_FILL, WRITE : begin
                    state <= CACHE_IDLE;
                end
            endcase
        end
    end


    always_comb begin
        hit_way    = 0;
        hit_line   = 0;
        cmp_out    = 0;
        bus.r_data = 0;

        for (int i = 0; i < 8; i++)
            cmp_out[i] = (cmp_in_meta[i].valid && cmp_in_line[i].tag == bus.tag);

        // Read; one-hot mux
        for (int i = 0; i < 8; i++)
            if (cmp_out[i]) begin
                hit_way  = i[2:0];
                hit_line = cmp_in_line[i];
            end

        bus.hit = |cmp_out;
        hit     = bus.hit;
        miss    = !hit;
    end


    // WRITE
    logic [2:0] curr_victim_way;

    // latched; since plru updates in the next cycle...
    logic [2:0] victim_way_ff;

    always_ff @(posedge clk) begin
        if (rst) begin
            victim_way_ff <= 0;
        end
        else if (state == TAG_CMP) begin
            victim_way_ff <= curr_victim_way;
        end
    end


    // LRU
    tree_plru u_tree_plru (
        .clk        (clk),
        .rst        (rst),

        .state      (state),
        .hit_way    (hit_way),

        .bus        (bus),

        .victim_way (curr_victim_way)
    );


    // solving the 1-cycle ff lag with fwd-ing
    logic [2:0] victim_way;
    line_t victim_line;
    meta_t victim_meta;

    always_comb begin
        victim_way  = (state == TAG_CMP) ? curr_victim_way : victim_way_ff;
        victim_line = cmp_in_line[victim_way];
        victim_meta = cmp_in_meta[victim_way];


        // fill_data must remain stable till ready fires
        bus.r_data = hit ? hit_line.data : bus.fill_data;

        bus.fill_req =
            (state == TAG_CMP) && miss && (
            (bus.r_en || (bus.w_en && is_subword_w))
        );

        bus.evict_wb =
            (state == TAG_CMP && miss && victim_meta.valid && victim_meta.dirty) ||
            (state == EVICT);

        bus.evict_tag = victim_line.tag;
        bus.evicted_data = victim_line.data;

        norm_w =
            (state == TAG_CMP && bus.w_en && !(miss && is_subword_w)) ||
            (state == SUBWORD_W_FILL);

        write  = norm_w || (state == REQ_FILL && bus.fill_en);
        w_way  = norm_w && hit ? hit_way : victim_way;


        // hit write/subword-write (note that bus.w_en is already gated to logic 'write'...)
        if (norm_w) begin
            w_data  = bus.w_data;
            w_wmask = bus.w_mask;
            w_dirty = 1;
        end
        // miss fill; when (state == REQ_FILL && bus.fill_en)
        else begin
            w_data  = bus.fill_data;
            w_wmask = '1;
            w_dirty =  0;
        end

        bus.ready = ((state == TAG_CMP && bus.r_en) || state == R_FILL || state == WRITE);
    end

    always_ff @(posedge clk) begin
        if (!rst && write) begin
            mem [bus.set_idx][w_way].tag   <= bus.tag;
            
            // # moved upwards...
            // meta[bus.set_idx][w_way].valid <= 1;
            // meta[bus.set_idx][w_way].dirty <= w_dirty;

            for (int i = 0; i < bus.W_MASK_LEN; i++) begin
                if (w_wmask[i])
                    mem[bus.set_idx][w_way].data[8*i +: 8] <= w_data[8*i +: 8];
            end
        end
    end

endmodule
