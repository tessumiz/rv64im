module regfile(
    input logic clk,
    input logic [4:0]  rs1_a,
    input logic [4:0]  rs2_a,
    input logic [4:0]  rd,
    input logic [63:0] wb_data,
    input logic        wb_en,

    output logic [63:0] rs1,
    output logic [63:0] rs2
);

    logic [63:0] regs[1:31];

    always_comb begin
        rs1 = rs1_a == 0 ? 64'b0 : regs[rs1_a];
        rs2 = rs2_a == 0 ? 64'b0 : regs[rs2_a];
    end

    always_ff @(posedge clk) begin
        if (wb_en && rd != 0) begin
            regs[rd] <= wb_data;
        end
    end
endmodule
