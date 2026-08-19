import mem_pkg::*;
import zicsr_pkg::*;


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

    pwc_data_t  mem [15:0];
    logic       cmp_out [15:0];
    
    pwc_tag_t   masked_tag;
    logic [3:0] fifo;  // just a wrapping up-counter (will improve this later...)

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
        
        for (int i = 0; i < 16; i++) begin
            cmp_out[i] = mem[i].valid && (mem[i].tag == masked_tag);

            if (cmp_out[i]) begin
                lvl1_root = mem[i].lvl1_root;
                hit       = 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mem  <= '{ default: 0 };
            fifo <= '0;
        end
        else if (w_en) begin
            mem[fifo].valid     <= 1;
            mem[fifo].tag       <= masked_tag;
            mem[fifo].lvl1_root <= w_root;
            
            fifo <= fifo + 1;
        end
    end

endmodule
