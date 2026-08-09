import defs_pkg::*;


module dmem(
    input logic clk,
    dmem_if.slave bus
);

    logic [63:0] mem [1023];
    logic [7:0]  w_msk;
    logic [9:0]  lane;

    assign lane = bus.addr[12:3];

    always_comb begin
        if (bus.w_en) begin
            unique case (bus.f3_2)
                MEM_BYTE: w_msk = 8'b0000_0001 << bus.addr[2:0];
                MEM_HWORD: w_msk = 8'b0000_0011 << {bus.addr[2:1], 1'b0};
                MEM_WORD: w_msk = 8'b0000_1111 << {bus.addr[2], 2'b00};
                MEM_DWORD: w_msk = 8'b1111_1111;
            endcase
        end else begin
            w_msk = 0;
        end

        bus.r_data = bus.r_en ? mem[lane] : 64'b0;
    end

    always_ff @(posedge clk) begin
        if (bus.w_en) begin
            if (w_msk[0]) mem[lane][7:0]   <= bus.w_data[7:0];
            if (w_msk[1]) mem[lane][15:8]  <= bus.w_data[15:8];
            if (w_msk[2]) mem[lane][23:16] <= bus.w_data[23:16];
            if (w_msk[3]) mem[lane][31:24] <= bus.w_data[31:24];
            if (w_msk[4]) mem[lane][39:32] <= bus.w_data[39:32];
            if (w_msk[5]) mem[lane][47:40] <= bus.w_data[47:40];
            if (w_msk[6]) mem[lane][55:48] <= bus.w_data[55:48];
            if (w_msk[7]) mem[lane][63:56] <= bus.w_data[63:56];
        end
    end
endmodule
