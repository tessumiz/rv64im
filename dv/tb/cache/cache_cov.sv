module cache_cov import mem_pkg::set_cache_fsm_t; (
    input logic clk,
    input logic rst,

    input set_cache_fsm_t state,

    input logic       req_r_en,
    input logic       req_w_en,
    input logic [7:0] req_w_mask,

    input logic       hit,
    input logic       miu_w_en,

    input logic       ready,
    input logic       flush,
    input logic       abort_sig
);

    logic evict_latched;
    always_ff @(posedge clk) begin
        if (rst || ready || abort_sig)
            evict_latched <= 0;

        else if (state == mem_pkg::CACHE_TAG_CMP && miu_w_en)
            evict_latched <= 1;
    end

    logic is_full_w;
    logic is_sub_w;
    logic is_miss_clean;
    logic is_miss_dirty;

    always_comb begin
        is_full_w = req_w_en && (req_w_mask == 8'hFF);
        is_sub_w  = req_w_en && (req_w_mask != 8'hFF);
        is_miss_clean = !hit && !evict_latched;
        is_miss_dirty = !hit && evict_latched;
    end


    covergroup cache_cg @(posedge clk iff !rst);
        cp_op: coverpoint {req_r_en, is_full_w, is_sub_w} {
            bins read   = {3'b100};
            bins full_w = {3'b010};
            bins subw_w = {3'b001};
        }

        cp_cmp: coverpoint {hit, is_miss_clean, is_miss_dirty} {
            bins hit        = {3'b100};
            bins miss_clean = {3'b010};
            bins miss_dirty = {3'b001};
        }

        cp_misc: coverpoint abort_sig {
            bins normal = {1'b0};
            bins abort  = {1'b1};
        }

        cross_op_cmp_misc: cross cp_op, cp_cmp, cp_misc;
    endgroup

    cache_cg cg = new();

    always_ff @(posedge clk) begin
        if (!rst && (ready || abort_sig)) begin
            cg.sample();
        end
    end
endmodule
