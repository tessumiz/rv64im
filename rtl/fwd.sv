module fwd(
    input logic [4:0]  id_ex_rs1_a,
    input logic [4:0]  id_ex_rs2_a,
 
    input logic        ex_mem_wb,
    input logic [4:0]  ex_mem_rd,

    input logic        mem_wb_wb,
    input logic [4:0]  wb_a,

    output logic      rs1_mem_fwd,
    output logic      rs1_wb_fwd,
    output logic      rs2_mem_fwd,
    output logic      rs2_wb_fwd
);
    always_comb begin
        logic mem_fwd = ex_mem_wb && (ex_mem_rd != 5'b0);
        logic wb_fwd  = mem_wb_wb && (wb_a != 5'b0);

        rs1_mem_fwd = 0;
        rs1_wb_fwd  = 0;
        rs2_mem_fwd = 0;
        rs2_wb_fwd  = 0;

        if (mem_fwd && ex_mem_rd == id_ex_rs1) begin
            rs1_mem_fwd = 1;
        end else if (wb_fwd && wb_a == id_ex_rs1) begin
            rs1_wb_fwd = 1;
        end

        if (mem_fwd && ex_mem_rd == id_ex_rs2) begin
            rs2_mem_fwd = 1;
        end else if (wb_fwd && wb_a == id_ex_rs2) begin
            rs2_wb_fwd = 1;
        end
    end

endmodule
