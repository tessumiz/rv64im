/*
16-len CAM mapping <ppn4, ppn3, ppn2, mode, asid> to <lvl1_root>

2MiB access stride (512 pages) is assumed to be mostly unchanged for
the majority of access (especially from sv48/57). Maybe parametrize
it to lvl1/lvl2 later if thrashing becomes an issue (very unlikely).

set_cache is too generic and heavy to be used here. tree_plru would
be an overkill here in terms of gate complexity; poor ROI.

TODO; need to think of the ROI of supporting superpages of various
levels for various modes.
*/

module pwc import mem_pkg::*, defs_pkg::uint; (
    input  logic        clk,
    input  logic        rst,

    input  pwc_tag_t    pwc_in,

    input  logic        w_en,
    input  logic [43:0] w_root,

    output logic        hit,
    output logic [43:0] lvl1_root
);

    // ff
    pwc_data_t   mem [15:0];
    logic        cmp_out [15:0];


    // bit plru (considering an even simpler FIFO now...)
    logic [15:0] touched;  // ff
    logic [15:0] nxt_touched;
    logic [3:0]  victim_idx;
    logic [3:0]  hit_idx;

    always_comb begin
        hit       = 0;
        lvl1_root = 0;
        hit_idx   = 0;
        
        for (int i = 0; i < 16; i++) begin
            /*
            We don't have to mask vpn as the sig-extended data is what gets stored in the
            cache in the first place, which guarantees correctness by default.
            */
            automatic pwc_tag_t asid_mask = '{
                asid:    mem[i].tag.g ? 0 : '1,
                default: '1
            };

            cmp_out[i] = mem[i].valid && ~|((mem[i].tag ^ pwc_in) & asid_mask);

            // Fix; explicit one-hot
            hit       |= cmp_out[i];
            lvl1_root |= { $bits(lvl1_root){cmp_out[i]} } & mem[i].lvl1_root;
            hit_idx   |= { $bits(hit_idx){cmp_out[i]} }   & i[$bits(hit_idx)-1:0];
        end


        victim_idx  = 0;  // default scapegoat idx 0
        for (uint i = 0; i < 16; i++) begin
            if (!mem[i].valid || !touched[i])
                victim_idx  = i[3:0];  // uint truncate, nothing special...
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
                mem[victim_idx].tag       <= pwc_in;
                mem[victim_idx].lvl1_root <= w_root;
            end
        end
    end

endmodule
