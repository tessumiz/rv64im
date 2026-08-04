module csr_file(
    input logic clk,
    input logic rst,

    input logic [11:0] r_addr,
    input logic        w_en,
    input logic [11:0] w_addr,
    input logic [63:0] w_data,

    output logic [63:0] r_data
);

    gen_reg #(.T(logic [12:0]))
    mstatus (
        .clk (clk)
    );
endmodule
