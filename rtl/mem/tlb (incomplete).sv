import mem_pkg::*;
import defs_pkg::uint;

/*
Several reasons why set_cache can't be reused here:

(i) TLBs use ffs, while set_cache uses SRAM; synth hints are different.
    Plus, clr doesn't require an fsm here.

(ii) Dealing with superpages (and ASID, based on the 'g' bit)

(iii) Overkill fsm; eviction logic and writes absent

(iv) Fill logic might diverge in the future; burst for cache, single fill
for tlb.

I *could* create a monolithic set_assoc_cache module with a lot of generate
stmts, but repeating myself just for once here seems like the better choice...
*/


module tlb (
    input  logic clk,
    input  logic rst,

    tlb_if.cache bus
);

    localparam type DATA_T = bus.DATA_T;
    localparam type TAG_T  = bus.TAG_T;
    localparam uint SETS   = bus.SETS;
    localparam uint WAYS   = bus.WAYS;

    localparam uint WAY_LOG_W = bus.WAY_LOG_W;
    typedef logic  [WAY_LOG_W-1:0] way_idx_t;

    typedef struct packed {
        logic  valid;
        TAG_T  tag;
        DATA_T data;
    } line_t;


    // ffs
    line_t mem [SETS-1:0][WAYS-1:0];

    line_t [WAYS-1:0] cmp_in_line;
    logic  [WAYS-1:0] cmp_out;

    line_t      hit_line;
    way_idx_t   hit_way;
    logic       hit, miss;

    set_tlb_fsm_t state;

    logic       write;
    way_idx_t   victim_way;

    logic [bus.WAYS-1:0] cmp_in_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            mem   <= '0;
            state <= TLB_IDLE;
        end
        else begin
            if (write) begin
                mem[bus.set_idx][victim_way].valid <= 1;
            end

            unique case (state)
                TLB_IDLE : begin
                    if (bus.valid) 
                        state <= TLB_READ_AND_TAG_CMP;
                end

                TLB_READ_AND_TAG_CMP : begin
                    if (bus.page_fault)
                        state <= TLB_IDLE;

                    else if (hit)
                        state <= TLB_FAULT_CHECK;

                    else
                        state <= TLB_FETCH_PAGE;
                end

                TLB_FETCH_PAGE : begin
                    if (bus.fetch_fault)
                        state <= TLB_IDLE;

                    else if (bus.page_fetched)
                        state <= TLB_WRITE_PAGE;
                end

                TLB_WRITE_PAGE : begin
                    state <= (bus.evict_page_wb) ? TLB_EVICT : TLB_IDLE;
                end

                TLB_FAULT_CHECK : begin
                    
                end
            endcase
        end
    end

    line_t curr_line;

    always_comb begin
        // async read
        cmp_in_line = mem[bus.set_idx];

        hit_way    = 0;
        hit_line   = 0;
        cmp_out    = 0;
        bus.data   = 0;

        for (uint i = 0; i < WAYS; i++) begin
            curr_line = cmp_in_line[i];

            cmp_out[i] = (
                curr_line.valid &&
                curr_line.tag.vpn_upper == bus.tag.vpn_upper &&

                // gated asid check
                (curr_line.tag.g || curr_line.tag.asid == bus.tag.asid)
            );

            cmp_in_valid[i] = curr_line.valid;
        
            hit_way  |= ( i[WAY_LOG_W-1:0] & {WAY_LOG_W{cmp_out[i]}} );
            hit_line |= ( curr_line & {$bits(line_t){cmp_out[i]}} );
        end

        hit     = |cmp_out;
        miss    = !hit;
        bus.hit = hit;
    end


    tree_plru #(
        .SETS      (SETS),
        .WAYS      (WAYS),
        .WAY_LOG_W (WAY_LOG_W)
    )
    u_tree_plru (
        .clk          (clk),
        .rst          (rst),

        .set_idx      (bus.set_idx),
        .ctrl         ({bus.hit, bus.fill_req, bus.ready}),

        .hit_way      (hit_way),
        .cmp_in_valid (cmp_in_valid),

        .victim_way   (victim_way)
    );

    always_comb begin
        bus.data     = hit ? hit_line.data : bus.fill_data;

        bus.fill_req = (state == TLB_IDLE) && bus.valid && miss;

        write        = (state == TLB_REQ_FILL && bus.fill_en);

        bus.busy     = (state != TLB_IDLE);
        bus.ready    = (state == TLB_IDLE && bus.valid && hit) || (state == TLB_R_FILL);
    end

    always_ff @(posedge clk) begin
        if (!rst && write) begin
            mem[bus.set_idx][victim_way].tag  <= bus.tag;
            mem[bus.set_idx][victim_way].data <= bus.fill_data;
        end
    end

endmodule
