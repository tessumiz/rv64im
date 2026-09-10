import mem_pkg::*;
import defs_pkg::uint;

/*
Previously:

Several reasons why set_cache can't be reused here:

(i) TLBs use ffs, while set_cache uses SRAM; synth hints are different.
    Plus, clr doesn't require an fsm here.

(ii) Dealing with superpages (and ASID, based on the 'g' bit)

(iii) Overkill fsm; eviction logic and writes absent

(iv) Fill logic might diverge in the future; burst for cache, single fill
for tlb.

I *could* create a monolithic set_assoc_cache module with a lot of generate
stmts, but repeating myself just for once here seems like the better choice...

NOTE: Operations like writing back evicted page are assumed to be non-faultable


After adding superpages, wholly different:

Regular pages use a set assoc CAM, while superpages use a fully assoc CAM. They're
parallely queried and the output is muxed. Norm uses a tree plru, while super uses
a bit plru.
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

    // assuming this is common; parametrize later...
    localparam uint SUPERPAGE_CAM_SIZE = 8;
    localparam uint SUPERPAGE_CAM_LOGW = $clog2(SUPERPAGE_CAM_SIZE);

    localparam uint WAY_LOG_W =    bus.WAY_LOG_W;
    typedef logic  [WAY_LOG_W-1:0] norm_way_idx_t;

    typedef struct packed {
        logic  valid;
        TAG_T  tag;
        DATA_T data;
    } line_t;

    typedef struct packed {
        logic        valid;
        vpn_t        vpn;       // ignore vpn0
        logic [2:0]  vpn_mask;  // 000 = mega, 001 = giga, 011 = terra, 111 = peta
        logic [15:0] asid;
        logic        g;
        DATA_T       data;
    } super_line_t;


    // 4KB normal pages
    line_t mem [SETS-1:0][WAYS-1:0];
    line_t [WAYS-1:0] cmp_in_line;
    logic  [WAYS-1:0] cmp_out;
    line_t            norm_hit_line;
    norm_way_idx_t    norm_hit_way;
    logic             norm_hit;

    // superpages
    super_line_t  superpage_mem [SUPERPAGE_CAM_SIZE];  // CAM
    logic         [SUPERPAGE_CAM_SIZE-1:0] super_cmp_out;
    logic [44:0]  full_vpn;
    super_line_t  super_hit_line;
    logic         super_hit;
    logic [SUPERPAGE_CAM_LOGW-1:0] super_hit_idx;

    logic [2:0]   hit_vmask;
    logic [43:0]  super_mask;

    assign hit_vmask  = super_hit_line.vpn_mask;
    assign super_mask = { 8'b0, {9{hit_vmask[2]}}, {9{hit_vmask[1]}}, {9{hit_vmask[0]}}, 9'h1FF };


    // superpage CAM uses a bit-plru
    logic [SUPERPAGE_CAM_SIZE-1:0] super_touched;
    logic [SUPERPAGE_CAM_SIZE-1:0] super_nxt_touched;
    logic [SUPERPAGE_CAM_LOGW-1:0] super_victim_idx;


    DATA_T read_data;
    logic  hit, miss;


    set_tlb_fsm_t state;

    logic          write_page;
    norm_way_idx_t victim_way;

    logic [bus.WAYS-1:0] cmp_in_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            mem           <= '0;
            super_touched <= '0;
            state         <= TLB_IDLE;
        end
        else begin
            unique case (state)
                TLB_IDLE : begin
                    if (bus.valid) 
                        state <= TLB_READ_AND_TAG_CMP;
                end

                TLB_READ_AND_TAG_CMP : begin
                    if (hit)
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
                    state <= TLB_FAULT_CHECK;
                end

                TLB_FAULT_CHECK : begin
                    if (bus.page_fault)
                        state <= TLB_IDLE;

                    else if (bus.evict_page_update)
                        state <= TLB_EVICT_PAGE;

                    else
                        state <= TLB_IDLE;
                end

                TLB_EVICT_PAGE : begin
                    if (bus.evict_done)
                        state <= TLB_IDLE;
                end
            endcase
        end
    end


    always_comb begin
        // async read
        cmp_in_line = mem[bus.set_idx];

        cmp_out        = 0;
        super_cmp_out  = 0;

        norm_hit_line  = 0;
        norm_hit_way   = 0;
        super_hit_line = 0;
        super_hit_idx  = 0;


        // norm
        for (uint i = 0; i < WAYS; i++) begin
            automatic line_t curr_line = cmp_in_line[i];

            cmp_out[i] = (
                curr_line.valid &&
                curr_line.tag.vpn_upper == bus.tag.vpn_upper &&

                // gated asid check
                (curr_line.tag.g || curr_line.tag.asid == bus.tag.asid)
            );

            cmp_in_valid[i] = curr_line.valid;
        
            norm_hit_way  |= ( i[WAY_LOG_W-1:0] & {WAY_LOG_W{cmp_out[i]}} );
            norm_hit_line |= ( curr_line & {$bits(line_t){cmp_out[i]}} );
        end


        full_vpn = { bus.tag.vpn_upper, bus.set_idx };  // could optimize this, but I'll let the synth do it for me...

        // super
        for (uint i = 0; i < SUPERPAGE_CAM_SIZE; i++) begin
            automatic super_line_t super_line = superpage_mem[i];
            automatic vpn_t super_way_cmp = (super_line.vpn ~^ full_vpn);

            automatic logic [2:0] _super_mask = super_line.vpn_mask;
            automatic logic super_way_cmp_eq = (
                (&super_way_cmp.vpn1 | _super_mask[0]) &
                (&super_way_cmp.vpn2 | _super_mask[1]) &
                (&super_way_cmp.vpn3 | _super_mask[2]) &
                (&super_way_cmp.vpn4)
            );

            super_cmp_out[i] = (
                super_line.valid &&
                super_way_cmp_eq &&
                (super_line.g || super_line.asid == bus.tag.asid)
            );

            super_hit_line |= ( super_line & {$bits(super_line_t){super_cmp_out[i]}} );
            super_hit_idx  |= i[SUPERPAGE_CAM_LOGW-1:0] & { SUPERPAGE_CAM_LOGW{super_cmp_out[i]} };
        end

        norm_hit  = |cmp_out;
        super_hit = |super_cmp_out;

        hit       = norm_hit | super_hit;
        miss      = !hit;
        bus.hit   = hit;
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
        .ctrl         ({norm_hit, bus.page_req, bus.ready}),

        .hit_way      (norm_hit_way),
        .cmp_in_valid (cmp_in_valid),

        .victim_way   (victim_way)
    );


    // superpage b-plru
    always_comb begin
        super_victim_idx = 0;  // scapegoat

        for (uint i = 0; i < SUPERPAGE_CAM_SIZE; i++) begin
            if (!superpage_mem[i].valid || !super_touched[i])
                super_victim_idx  = i[SUPERPAGE_CAM_LOGW-1:0];
        end

        super_nxt_touched = super_touched;
        
        if (hit) begin
            super_nxt_touched = super_touched | (1 << super_hit_idx);

            // wrap-around reset; scapegoat is idx-0
            if (&super_nxt_touched) super_nxt_touched = (1 << super_hit_idx);
        end
        else begin
            super_nxt_touched = super_touched | (1 << super_victim_idx);

            if (&super_nxt_touched) super_nxt_touched = (1 << super_victim_idx);
        end
    end


    always_comb begin
        read_data  = hit ? (super_hit ? super_hit_line.data : norm_hit_line.data) :
                     bus.fetched_page;

        write_page = (state == TLB_FETCH_PAGE && bus.page_fetched);


        bus.page_req = (state == TLB_IDLE) && bus.valid && miss;

        bus.page_fault = (state == TLB_FAULT_CHECK) && (
            ( bus.w & !read_data.w) |
            ( bus.x & !read_data.x) |
            ( bus.r & !read_data.r & !(read_data.x & bus.mmu_ctx.MXR)) |
            ((bus.u & !read_data.u) | (!bus.u & read_data.u & (!bus.mmu_ctx.SUM | bus.x)))
        );

        bus.evict_page_update = (state == TLB_FAULT_CHECK && !bus.page_fault) && bus.w && !read_data.d && hit;

        bus.ppn_out = super_hit ? ((read_data.ppn & ~super_mask) | (full_vpn[43:0] & super_mask)) :
                      read_data.ppn;

        bus.busy  = (state != TLB_IDLE);
        bus.ready = (state == TLB_IDLE && bus.valid && hit) ||
                    (state == TLB_WRITE_PAGE) ||
                    (state == TLB_EVICT_PAGE && bus.evict_done);
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            if (bus.ready && super_hit) begin
                super_touched <= super_nxt_touched;
            end
            else if (bus.evict_page_update) begin
                if (super_hit)
                    superpage_mem[super_hit_idx].data.d   <= 1;
                else
                    mem[bus.set_idx][norm_hit_way].data.d <= 1;
            end
            else if (write_page) begin
                if (!bus.fetched_is_super) begin
                    mem[bus.set_idx][victim_way] <= '{
                        valid: 1,
                        tag: { bus.tag.vpn_upper, bus.tag.asid, bus.fetched_page.g },
                        data: bus.fetched_page
                    };
                end
                else begin
                    superpage_mem[super_victim_idx] <= '{
                        valid: 1,
                        vpn: full_vpn,
                        vpn_mask: bus.fetched_super_mask,
                        asid: bus.tag.asid,
                        g: bus.tag.g,
                        data: bus.fetched_page
                    };

                    super_touched <= super_touched | (1 << super_victim_idx);
                end

                /*
                typedef struct packed {
                    logic        valid;
                    vpn_t        vpn;       // ignore vpn0
                    logic [2:0]  vpn_mask;  // 000 = mega, 001 = giga, 011 = terra, 111 = peta
                    logic [15:0] asid;
                    logic        g;
                    DATA_T       data;
                } super_line_t;
                */
            end
        end
    end

endmodule
