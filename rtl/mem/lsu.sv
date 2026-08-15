import defs_pkg::*;

module lsu (
    input  logic        mem_op,

    input  logic [2:0]  f3,
    input  logic [63:0] addr,
    input  logic [63:0] w_data_raw,
    input  logic [63:0] r_data_raw,

    output logic [63:0] w_data_fmt,
    output logic [63:0] r_data_fmt,
    output logic        is_misaligned
);

    always_comb begin
        is_misaligned = 0;

        if (mem_op) begin
            unique case (f3[1:0])
                MEM_BYTE:  is_misaligned = (addr[0] != 0);
                MEM_HWORD: is_misaligned = (addr[1:0] != 0);
                MEM_WORD:  is_misaligned = (addr[2:0] != 0);
                MEM_DWORD: is_misaligned = 0;
            endcase
        end
    end

    always_comb begin
        unique case (f3[1:0])
            2'b00: w_data_fmt = {8{w_data_raw[7:0]}};
            2'b01: w_data_fmt = {4{w_data_raw[15:0]}};
            2'b10: w_data_fmt = {2{w_data_raw[31:0]}};
            2'b11: w_data_fmt = w_data_raw;
        endcase
    end

    logic [63:0] shft_rdata;

    always_comb begin
        shft_rdata = r_data_raw >> {addr[2:0], 3'b0};

        case (f3)
            3'b011: r_data_fmt = shft_rdata;

            3'b000: r_data_fmt = {{56{shft_rdata[7]}}, shft_rdata[7:0]};
            3'b001: r_data_fmt = {{48{shft_rdata[15]}}, shft_rdata[15:0]};
            3'b010: r_data_fmt = {{32{shft_rdata[31]}}, shft_rdata[31:0]};

            3'b100: r_data_fmt = {56'b0, shft_rdata[7:0]};
            3'b101: r_data_fmt = {48'b0, shft_rdata[15:0]};
            3'b110: r_data_fmt = {32'b0, shft_rdata[31:0]};

            default: r_data_fmt = 0;
        endcase
    end

endmodule
