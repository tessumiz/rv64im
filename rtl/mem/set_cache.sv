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
    line_t [7:0] cmp_in_meta;

    logic  [7:0] cmp_out;

    set_cache_fsm_t state;

    logic  mem_op, w_op;
    assign w_op   = bus.w_en || bus.fill_en;
    assign mem_op = bus.r_en || w_op;


    // read fsm
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            meta  <= '0;
        end
        else begin
           unique case (state)
                IDLE : begin
                    if (mem_op) begin
                        state  <= TAG_CMP;
                        cmp_in_line <= mem[bus.set_idx];
                    end
                end

                TAG_CMP : begin
                    if (bus.r_en)
                        state <= bus.hit ? IDLE : REQ_FILL;
                    else begin
                        state <= (bus.w_width != $bits(DATA_T)) ? REQ_FILL : WRITE;
                    end
                end

                REQ_FILL : begin
                    state <= bus.r_en ? R_FILL : SUBWORD_W_FILL;
                end

                SUBWORD_W_FILL : begin
                    state <= WRITE;
                end

                R_FILL, WRITE : begin
                    state <= IDLE;
                end
            endcase
        end
    end

    
    // all combinatoric sigs
    line_t hit_line;

    logic [2:0] hit_way;

    logic       miss;

    always_comb begin
        cmp_in_meta = meta[bus.set_idx];

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
        miss    = !bus.hit;
    end


    // WRITE
    logic [2:0] victim_way;

    // LRU
    tree_plru  #(.line_t(line_t), .meta_t(meta_t))
    u_tree_plru (
        .clk        (clk),
        .rst        (rst),

        .state      (state),
        .cmp_in_line(cmp_in_line),
        .cmp_in_meta(cmp_in_meta),
        .hit_way    (hit_way),

        .bus        (bus),

        .victim_way (victim_way)
    );


    line_t victim_line = cmp_in_line[victim_way];
    meta_t victim_meta = cmp_in_meta[victim_way];

    logic  write;
    DATA_T w_data;
    logic [2:0] w_way;

    always_comb begin
        bus.r_data = hit_line.data;

        bus.fill_req =
            (state == TAG_CMP) && miss && (
            (bus.r_en || (bus.w_en && (bus.w_width != $bits(DATA_T))))
        );

        bus.evict_wb  = (state == TAG_CMP && miss && victim_meta.valid && victim_meta.dirty);
        bus.evict_tag = victim_line.tag;
        bus.evicted_data = victim_line.data;

        write = (state == R_FILL || state == SUBWORD_W_FILL || state == WRITE);
        w_way   = (state == TAG_CMP && bus.hit) ? hit_way : victim_way;

        bus.ready = (state == R_FILL || state == WRITE);
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            if (write) begin
                mem [bus.set_idx][w_way].tag   <= bus.tag;
                meta[bus.set_idx][w_way].valid <= 1;
                meta[bus.set_idx][w_way].dirty <= victim_meta.valid;

                // masking needs to be done here
                mem[bus.set_idx][w_way].data   <= w_data;
            end
        end
    end

endmodule
