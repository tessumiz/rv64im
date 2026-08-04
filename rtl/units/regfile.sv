module regfile(
    input  logic        clk,
    input  logic [4:0]  rs1_a,
    input  logic [4:0]  rs2_a,
    input  logic [4:0]  rd,
    input  logic [63:0] wb_data,
    input  logic        wb_en,
    output logic [63:0] rs1,
    output logic [63:0] rs2
);

    logic [63:0] regs [0:31];

    always_comb begin
        rs1 = (wb_en && rd == rs1_a) ? wb_data :
              regs[rs1_a];

        rs2 = (wb_en && rd == rs2_a) ? wb_data :
              regs[rs2_a];
    end

    always_ff @(posedge clk) begin
        regs[0] <= 0;

        if (wb_en && rd != 0)
            regs[rd] <= wb_data;
    end

endmodule
