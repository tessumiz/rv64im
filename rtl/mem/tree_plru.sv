import mem_pkg::*;

module tree_plru #(
    parameter type line_t,
    parameter type meta_t
)(
    input logic clk,
    input logic rst,

    input line_t cmp_in_line,
    input meta_t cmp_in_meta,
    input [2:0]  hit_way,

    set_cache_fsm_t state,

    set_cache_if.slave bus,

    output logic [2:0] victim_way
);

    typedef logic [6:0] plru_t;

    plru_t plru [bus.SETS-1:0];
    plru_t curr_plru, nxt_plru;

    logic [2:0] accessed_way;

    always_comb begin
        // Finding a victim; empty lines can be victims as well
        curr_plru = plru[bus.set_idx];

        victim_way[2] = curr_plru[0];
        victim_way[1] = !curr_plru[0] ? curr_plru[1] : curr_plru[2];

        unique case (victim_way[2:1])
            2'b00: victim_way[0] = curr_plru[3];
            2'b01: victim_way[0] = curr_plru[4];
            2'b10: victim_way[0] = curr_plru[5];
            2'b11: victim_way[0] = curr_plru[6];
        endcase

        // updating the plru; fills dealt with here
        accessed_way = bus.hit ? hit_way : victim_way;
        nxt_plru = curr_plru;

        if (bus.hit || bus.fill_en) begin
            nxt_plru[0] = ~accessed_way[2];

            if (accessed_way[2] == 0)
                nxt_plru[1] = !accessed_way[1];
            else
                nxt_plru[2] = !accessed_way[1];
            
            unique case (accessed_way[2:1])
                2'b00: nxt_plru[3] = ~accessed_way[0];
                2'b01: nxt_plru[4] = ~accessed_way[0];
                2'b10: nxt_plru[5] = ~accessed_way[0];
                2'b11: nxt_plru[6] = ~accessed_way[0];
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            plru <= '0;
        end
        else if (state == TAG_CMP) begin
            plru[bus.set_idx] <= nxt_plru;
        end
    end
endmodule
