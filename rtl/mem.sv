module imem(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic        r_en,
    output logic [31:0] data
);
    logic [31:0] mem [0:1023];

    always_ff @(posedge clk) begin
        data <= r_en ? mem[addr[11:2]] : 32'b0;
    end
endmodule


module dmem(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [63:0] wdata,
    input  logic [1:0]  w_width,
    input  logic        r_en,
    input  logic        w_en,
    output logic [63:0] rdata
);
    logic [63:0] mem [0:1023];

    always_comb begin
        logic lane   = addr[31:3];
        logic w_msk = 8'b0;

        if (w_en) begin
            // assumes addr is aligned
            case (w_width)
                2'b00: w_msk = 8'b1111_1111;
                2'b01: w_msk = 8'b0000_0001 << addr[2:0];
                2'b10: w_msk = 8'b0000_0011 << {addr[2:1], 1'b0};
                2'b11: w_msk = 8'b0000_1111 << {addr[2], 2'b00};
            endcase
        end
    end

    always_ff @(posedge clk) begin
        rdata <= r_en ? mem[addr[11:2]] : 64'b0;  // resolution deferred to main pipeline

        if (w_en) begin
            if (w_msk[0]) mem[lane][7:0]   <= wdata[7:0];
            if (w_msk[1]) mem[lane][15:8]  <= wdata[15:8];
            if (w_msk[2]) mem[lane][23:16] <= wdata[23:16];
            if (w_msk[3]) mem[lane][31:24] <= wdata[31:24];
            if (w_msk[4]) mem[lane][39:32] <= wdata[39:32];
            if (w_msk[5]) mem[lane][47:40] <= wdata[47:40];
            if (w_msk[6]) mem[lane][55:48] <= wdata[55:48];
            if (w_msk[7]) mem[lane][63:56] <= wdata[63:56];
        end
    end
endmodule