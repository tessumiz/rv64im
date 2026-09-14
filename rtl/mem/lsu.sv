module lsu import mem_pkg::*; (
    input  logic        is_mem_op,

    input  logic [2:0]  f3,
    input  logic [63:0] addr,

    input  logic [63:0] r_data_raw,
    input  logic [63:0] w_data_raw,

    output logic [63:0] r_data_fmt,
    output logic [63:0] w_data_fmt,
    output logic [7:0]  w_mask,

    output logic        is_misaligned
);

    // Massive simplification of logic using bitwise ops

    always_comb begin
        // checks with a mask of illegal address bits
        is_misaligned = is_mem_op  &&   |(addr[2:0] & ((1 << f3[1:0]) - 1));
        w_data_fmt    = w_data_raw << {addr[2:0], 3'b0};

        unique case (f3[1:0])
            MEM_BYTE:  w_mask = 8'b0000_0001 << addr[2:0];
            MEM_HWORD: w_mask = 8'b0000_0011 << addr[2:0];
            MEM_WORD:  w_mask = 8'b0000_1111 << addr[2:0];
            MEM_DWORD: w_mask = 8'b1111_1111;
        endcase
    end

    logic [63:0] shft_rdata;

    always_comb begin
        shft_rdata = r_data_raw >> {addr[2:0], 3'b0};

        case (f3)
            3'b011:  r_data_fmt = shft_rdata;
            3'b100:  r_data_fmt = {56'b0, shft_rdata[7:0]};
            3'b101:  r_data_fmt = {48'b0, shft_rdata[15:0]};
            3'b110:  r_data_fmt = {32'b0, shft_rdata[31:0]};
            3'b000:  r_data_fmt = {{56{shft_rdata[7]}}, shft_rdata[7:0]};
            3'b001:  r_data_fmt = {{48{shft_rdata[15]}}, shft_rdata[15:0]};
            3'b010:  r_data_fmt = {{32{shft_rdata[31]}}, shft_rdata[31:0]};

            default: r_data_fmt = 0;
        endcase
    end

endmodule
