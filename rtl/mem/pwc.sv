import mem_pkg::*;
import zicsr_pkg::*;
import defs_pkg::uint;


/*
16-len CAM mapping <ppn4, ppn3, ppn2, mode, asid> to <lvl1_root>

2MiB access stride (512 pages) is assumed to be mostly unchanged for
the majority of access (especially from sv48/57). Maybe parametrize
it to lvl1/lvl2 later if thrashing becomes an issue (very unlikely).

As this is a basic ff array, reads are async

set_cache/tree_plru is too heavy to be used here...
*/

module pwc (
    input  logic        clk,
    input  logic        rst,

    input  pwc_tag_t    pwc_in,
    output logic        hit,
    output logic [43:0] lvl1_root,

    input  logic        w_en,
    input  logic [43:0] w_root
);

    pwc_data_t   mem [15:0];
    logic        cmp_out [15:0];
    pwc_tag_t    masked_tag;

    // bit plru
    logic [15:0] touched;  // ff
    logic [15:0] nxt_touched;
    logic [3:0]  victim_idx;
    logic [3:0]  hit_idx;

    always_comb begin
        masked_tag = pwc_in;

        // 8, 9, 10
        unique case ({2'b10, pwc_in.mode})
            SATP_SV39: begin
                masked_tag.vpn4 = 0;
                masked_tag.vpn3 = 0;
            end

            SATP_SV48:
                masked_tag.vpn4 = 0;
            
            SATP_SV57: ;
        endcase

        hit       = 0;
        lvl1_root = 0;
        hit_idx   = 0;
        
        for (int i = 0; i < 16; i++) begin
            cmp_out[i] = mem[i].valid && (mem[i].tag == masked_tag);

            if (cmp_out[i]) begin
                lvl1_root = mem[i].lvl1_root;
                hit       = 1;
                hit_idx   = i[3:0];
            end
        end


        victim_idx  = 0;  // default scapegoat idx 0
        for (uint i = 0; i < 16; i++) begin
            if (!mem[i].valid || !touched[i]) begin
                victim_idx  = i[3:0];  // uint truncate, nothing special...
                break;
            end
        end
        
        nxt_touched = touched;
        
        if (hit) begin
            nxt_touched = touched | (1 << hit_idx);

            // wrap-around reset; scapegoat is idx-0
            if (&nxt_touched) nxt_touched = (1 << hit_idx);
        end
        // not strictly necessary; could be a mere "else". "else if" saves power ig...
        else if (w_en) begin
            nxt_touched = touched | (1 << victim_idx);

            if (&nxt_touched) nxt_touched = (1 << victim_idx);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mem     <= '{ default: 0 };
            touched <= '0;
        end
        else begin
            if (hit || w_en) begin
                touched <= nxt_touched;
            end
            
            if (w_en) begin
                mem[victim_idx].valid     <= 1;
                mem[victim_idx].tag       <= masked_tag;
                mem[victim_idx].lvl1_root <= w_root;
            end
        end
    end

endmodule
