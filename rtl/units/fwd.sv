import defs_pkg::*;

module fwd(
    input logic [4:0] rs1_a,
    input logic [4:0] rs2_a,

    input logic       ex_mem_wb,
    input logic [4:0] ex_mem_rd,

    input logic       mem_wb_wb,
    input logic [4:0] mem_wb_rd,

    output fwd_sig_t fwd_sig
);

    logic has_rs1;
    logic has_rs2;
    logic has_ex_mem_rd;
    logic has_mem_wb_rd;

    logic mem_fwd;
    logic wb_fwd;

    always_comb begin
        has_rs1       = (rs1_a != 0);
        has_rs2       = (rs2_a != 0);
        has_ex_mem_rd = (ex_mem_rd != 0);
        has_mem_wb_rd = (mem_wb_rd != 0);

        mem_fwd = ex_mem_wb && has_ex_mem_rd;
        wb_fwd  = mem_wb_wb && has_mem_wb_rd;

        fwd_sig = '0;

        if (mem_fwd && has_rs1 && (ex_mem_rd == rs1_a)) begin
            fwd_sig.mem_fwd_rs1 = 1;
        end else if (wb_fwd && has_rs1 && (mem_wb_rd == rs1_a)) begin
            fwd_sig.wb_fwd_rs1 = 1;
        end

        if (mem_fwd && has_rs2 && (ex_mem_rd == rs2_a)) begin
            fwd_sig.mem_fwd_rs2 = 1;
        end else if (wb_fwd && has_rs2 && (mem_wb_rd == rs2_a)) begin
            fwd_sig.wb_fwd_rs2 = 1;
        end
    end

endmodule
