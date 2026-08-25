import defs_pkg::uint;
import mem_pkg::*;


module tree_plru #(
    parameter uint SETS = 64,
    parameter uint WAYS = 4,
    parameter uint WAY_LOG_W = 2
)(
    input logic clk,
    input logic rst,

    input logic [$clog2(SETS)-1:0] set_idx,
    input plru_ctrl_t              ctrl,

    input logic [WAY_LOG_W-1:0]    hit_way,
    input logic [WAYS-1:0]         cmp_in_valid,

    output logic [WAY_LOG_W-1:0]   victim_way
);

    typedef logic [WAY_LOG_W-1:0] way_idx_t;
    typedef logic [WAYS-2:0]      plru_t;

    plru_t plru [SETS-1:0];
    plru_t curr_plru, nxt_plru;

    way_idx_t accessed_way;


    always_comb begin
        // finding a victim; empty lines can be victims as well
        curr_plru = plru[set_idx];

        for (uint i = 0; i < WAY_LOG_W; i++) begin
            automatic uint way_idx  = (WAY_LOG_W - 1) - i;
            automatic uint plru_idx = (2 ** i) - 1;
            automatic uint offset   = (victim_way >> (way_idx + 1));

            victim_way[way_idx] = curr_plru[plru_idx + offset];
        end

        /*
        An issue with tree plru is; one freq accessed elm can act as a
        proxy to lesser accessed elms in its same binary bucket, which means
        hotter elms get selected for eviction. In one way, this can help due to
        spatial locality; a conflict between spatial as well as temporal locality.

        But invalid lines are an exception. I'm using a priotity encoder to at
        the least evict any empty lines first..
        */
        for (uint i = 0; i < WAYS; i++) begin
            if (!cmp_in_valid[i])
                victim_way = i[WAY_LOG_W-1 : 0];
        end


        // generating nxt_plru; fills dealt with here
        accessed_way = ctrl.hit ? hit_way : victim_way;
        nxt_plru = curr_plru;

        if (ctrl.hit || ctrl.fill_req) begin
            for (uint i = 0; i < WAY_LOG_W; i++) begin
                automatic uint way_idx  = (WAY_LOG_W - 1) - i;
                automatic uint plru_idx = (2 ** i) - 1;
                automatic uint offset   = (accessed_way >> (way_idx + 1));

                nxt_plru[plru_idx + offset] = ~accessed_way[way_idx];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            plru <= '{ default: 0 };
        end
        else if (ctrl.ready) begin
            plru[set_idx] <= nxt_plru;
        end
    end
endmodule
