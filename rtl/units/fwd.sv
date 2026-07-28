module fwd(
    input logic [4:0] id_ex_rs1_a,
    input logic [4:0] id_ex_rs2_a,

    input logic       ex_mem_wb,
    input logic [4:0] ex_mem_rd,

    input logic       mem_wb_wb,
    input logic [4:0] mem_wb_rd,

    output fwd_sig_t fwd_sig
);

    logic mem_fwd = ex_mem_wb && (ex_mem_rd != 5'b0);
    logic wb_fwd  = mem_wb_wb && (wb_a != 5'b0);

    always_comb begin
        fwd_sig.mem_fwd_rs1 = 0;
        fwd_sig.wb_fwd_rs1  = 0;
        fwd_sig.mem_fwd_rs2 = 0;
        fwd_sig.wb_fwd_rs2  = 0;

        if (mem_fwd && ex_mem_rd == id_ex_rs1) begin
            fwd_sig.mem_fwd_rs1 = 1;
        end else if (wb_fwd && wb_a == id_ex_rs1) begin
            fwd_sig.wb_fwd_rs1 = 1;
        end

        if (mem_fwd && ex_mem_rd == id_ex_rs2) begin
            fwd_sig.mem_fwd_rs2 = 1;
        end else if (wb_fwd && wb_a == id_ex_rs2) begin
            fwd_sig.wb_fwd_rs2 = 1;
        end
    end

endmodule
