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

Storing both together leads to the aliasing issue; superpages always alias to set 0,
increasing conflict misses.

NOTE: flush is unnecessary here. Unlike caches, the D bit in the pte must be in sync
with the tlb (specs)
*/


module tlb import mem_pkg::*, defs_pkg::uint; (
    input  logic clk,
    input  logic rst,

    tlb_if.cache bus
);

    localparam type DATA_T = bus.DATA_T;
    localparam type TAG_T  = bus.TAG_T;
    localparam uint SETS   = bus.SETS;
    localparam uint WAYS   = bus.WAYS;

    // assuming this is common to i/d; parametrize later
    localparam uint SUPERPAGE_CAM_SIZE = 8;
    localparam uint SUPERPAGE_CAM_LOGW = $clog2(SUPERPAGE_CAM_SIZE);

    localparam uint WAY_LOG_W =    bus.WAY_LOG_W;
    typedef logic  [WAY_LOG_W-1:0] norm_way_idx_t;

    typedef struct packed {
        // logic  valid;  // stored separately...
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
    line_t [WAYS-1:0] mem [SETS-1:0];
    logic  [WAYS-1:0] mem_valid [SETS-1:0];  // saves power for rst; unnecessary for super

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
            mem_valid     <= '0;
            superpage_mem <= '0;
            super_touched <= '0;

            state         <= TLB_IDLE;
        end
        else begin
            unique case (state)
                TLB_IDLE : begin
                    if (bus.req.valid) 
                        state <= TLB_READ_AND_TAG_CMP;
                end

                TLB_READ_AND_TAG_CMP : begin
                    if (hit)
                        state <= TLB_FAULT_CHECK;

                    else
                        state <= TLB_FETCH_PAGE;
                end

                TLB_FETCH_PAGE : begin
                    if (bus.mem_rsp.fetch_fault)
                        state <= TLB_IDLE;

                    else if (bus.mem_rsp.page_fetched)
                        state <= TLB_WRITE_PAGE;
                end

                TLB_WRITE_PAGE : begin
                    state <= TLB_FAULT_CHECK;
                end

                TLB_FAULT_CHECK : begin
                    if (bus.rsp.page_fault)
                        state <= TLB_IDLE;

                    else if (bus.mem_req.evict_page_wb)
                        state <= TLB_EVICT_PAGE;

                    else
                        state <= TLB_IDLE;
                end

                TLB_EVICT_PAGE : begin
                    if (bus.mem_rsp.evict_done)
                        state <= TLB_IDLE;
                end
            endcase
        end
    end


    always_comb begin
        cmp_out        = 0;
        super_cmp_out  = 0;

        norm_hit_line  = 0;
        norm_hit_way   = 0;
        super_hit_line = 0;
        super_hit_idx  = 0;


        // norm
        for (uint i = 0; i < WAYS; i++) begin
            automatic line_t curr_line  = mem      [bus.req.set_idx][i];  // async read
            automatic logic  curr_valid = mem_valid[bus.req.set_idx][i];

            cmp_out[i] = (
                curr_valid &&
                (curr_line.tag.vpn_upper == bus.req.tag.vpn_upper) &&

                // gated asid check
                (curr_line.tag.g || curr_line.tag.asid == bus.req.tag.asid)
            );

            cmp_in_valid[i] = curr_valid;
        
            norm_hit_way  |= ( i[WAY_LOG_W-1:0] & {WAY_LOG_W{cmp_out[i]}} );
            norm_hit_line |= ( curr_line & {$bits(line_t){cmp_out[i]}} );
        end


        full_vpn = { bus.req.tag.vpn_upper, bus.req.set_idx };  // could optimize this, but I'll let the synth do it for me...

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
                (super_line.g || super_line.asid == bus.req.tag.asid)
            );

            super_hit_line |= ( super_line & {$bits(super_line_t){super_cmp_out[i]}} );
            super_hit_idx  |= i[SUPERPAGE_CAM_LOGW-1:0] & { SUPERPAGE_CAM_LOGW{super_cmp_out[i]} };
        end

        norm_hit    = |cmp_out;
        super_hit   = |super_cmp_out;

        hit         = norm_hit | super_hit;
        miss        = !hit;
        bus.rsp.hit = hit;
    end


    tree_plru #(
        .SETS      (SETS),
        .WAYS      (WAYS),
        .WAY_LOG_W (WAY_LOG_W)
    )
    u_tree_plru (
        .clk          (clk),
        .rst          (rst),

        .set_idx      (bus.req.set_idx),
        .ctrl         ({norm_hit, bus.mem_req.page_req, bus.rsp.ready}),

        .hit_way      (norm_hit_way),
        .cmp_in_valid (cmp_in_valid),

        .victim_way   (victim_way)
    );


    // superpage b-plru (will go for a cheaper one (FIFO) if found enough)
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
                     bus.mem_rsp.fetched_page;

        write_page = (state == TLB_FETCH_PAGE && bus.mem_rsp.page_fetched);


        bus.mem_req.page_req = (state == TLB_IDLE) && bus.req.valid && miss;

        bus.rsp.page_fault =
            ((state == TLB_FAULT_CHECK) && (
                ( bus.req.w & !read_data.w) |
                ( bus.req.x & !read_data.x) |
                ( bus.req.r & !read_data.r & !(read_data.x & bus.req.mmu_ctx.MXR)) |
                ((bus.req.u & !read_data.u) | (!bus.req.u & read_data.u & (!bus.req.mmu_ctx.SUM | bus.req.x)))
            )) ||
            (state == TLB_FETCH_PAGE && bus.mem_rsp.fetch_fault);

        bus.mem_req.evict_page_wb = (state == TLB_FAULT_CHECK && !bus.rsp.page_fault) &&
                                    (bus.req.w && !read_data.d && hit);

        bus.rsp.ppn_out = super_hit ? ((read_data.ppn & ~super_mask) | (full_vpn[43:0] & super_mask)) :
                          read_data.ppn;


        bus.rsp.busy  = (state != TLB_IDLE);

        // ready here means stage 1 is done; stage 2 is checking for faults
        bus.rsp.ready = (state == TLB_IDLE && bus.req.valid && hit) ||
                        (state == TLB_WRITE_PAGE) ||
                        (state == TLB_EVICT_PAGE && bus.mem_rsp.evict_done);
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            if (bus.rsp.ready && super_hit) begin
                super_touched <= super_nxt_touched;
            end
            else if (bus.mem_req.evict_page_wb) begin
                if (super_hit)
                    superpage_mem[super_hit_idx].data.d       <= 1;
                else
                    mem[bus.req.set_idx][norm_hit_way].data.d <= 1;
            end
            else if (write_page) begin
                if (!bus.mem_rsp.fetched_is_super) begin
                    mem[bus.req.set_idx][victim_way] <= '{
                        tag: { bus.req.tag.vpn_upper, bus.req.tag.asid, bus.mem_rsp.fetched_page.g },
                        data: bus.mem_rsp.fetched_page
                    };

                    mem_valid[bus.req.set_idx][victim_way] <= 1;
                end
                else begin
                    superpage_mem[super_victim_idx] <= '{
                        valid: 1,
                        vpn: full_vpn,
                        vpn_mask: bus.mem_rsp.fetched_super_mask,
                        asid: bus.req.tag.asid,
                        g: bus.mem_rsp.fetched_page.g,
                        data: bus.mem_rsp.fetched_page
                    };

                    super_touched <= super_touched | (1 << super_victim_idx);
                end
            end
        end
    end

endmodule
