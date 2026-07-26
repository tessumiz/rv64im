module imem(
    input  logic [31:0] addr,
    input  logic        r_en,

    output logic [31:0] data
);
    logic [31:0] mem [1023];

    assign data = r_en ? mem[addr[11:2]] : 32'b0;
endmodule
