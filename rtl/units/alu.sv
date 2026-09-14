module alu (
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic [3:0]  alu_op,
    input  logic        is_wd_op,
    output logic [63:0] alu_out
);

    logic [63:0] res;
    logic [5:0]  shamt;
    logic [31:0] a32;

    always_comb begin
        shamt = is_wd_op ? {1'b0, b[4:0]} : b[5:0];

        a32 = a[31:0];
        
        case (alu_op)
            4'b0000: res = a + b;
            4'b1000: res = a - b;

            4'b0001: res = is_wd_op ? {32'b0, (a32 << shamt)}
                                    : (a << shamt); 
                                    
            4'b0010: res = {63'b0, $signed(a) < $signed(b)};
            4'b0011: res = {63'b0, a < b};

            4'b0100: res = a ^ b;

            4'b0101: res = is_wd_op ? {32'b0, (a32 >> shamt)}
                                    : (a >> shamt);

            4'b1101: res = is_wd_op ? {32'b0, unsigned'($signed(a32) >>> shamt)}
                                    : unsigned'($signed(a) >>> shamt);

            4'b0110: res = a | b;
            4'b0111: res = a & b;

            default: res = 0;
        endcase

        alu_out = is_wd_op ? {{32{res[31]}}, res[31:0]} : res;
    end

endmodule
