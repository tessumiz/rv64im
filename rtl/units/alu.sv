module alu(
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic [3:0]  alu_op,
    input  logic        is_wd_op,
    output logic [63:0] alu_out
);
    logic [63:0] sum;
    logic        cout;
    logic        cmp_out;
    logic [63:0] shft_out;
    logic [63:0] res;


    always_comb begin
        logic is_sub;
        logic [64:0] x, y;

        is_sub = (alu_op == 4'b1000) | (alu_op[2:0] == 3'b010) | (alu_op[2:0] == 3'b011);

        x = {1'b0, a};
        y = {1'b0, is_sub ? ~b : b};

        {cout, sum} = x + y + { 64'b0, is_sub};
    end

    always_comb begin
        logic sltu;
        logic sig_diff;

        sltu = (alu_op[2:0] == 3'b011);
        sig_diff = a[63] ^ b[63];

        if (sltu) begin
            cmp_out = ~cout;
        end else begin
            cmp_out = sig_diff ? a[63] : sum[63];
        end
    end

    always_comb begin
        logic rev;
        logic sra;
        logic [63:0] x;
        logic [63:0] sr_out;
        logic [5:0]  shamt;

        rev = (alu_op[2:0] == 3'b001);
        sra = (alu_op == 4'b1101);

        shamt = is_wd_op ? {1'b0, b[4:0]} : b[5:0];

        x = rev ? {<<{a}} : a;
        sr_out = sra ? $signed(x) >>> shamt : x >> shamt;
        shft_out = rev ? {<<{sr_out}} : sr_out;
    end

    always_comb begin
        unique case (alu_op[2:0])
            3'b000: res = sum;
            3'b001: res = shft_out;
            3'b010: res = {63'b0, cmp_out};
            3'b011: res = {63'b0, cmp_out};
            3'b100: res = a ^ b;
            3'b101: res = shft_out;
            3'b110: res = a | b;
            3'b111: res = a & b;
        endcase

        if (is_wd_op) begin
            alu_out = {{32{res[31]}}, res[31:0]};
        end else begin
            alu_out = res;
        end
    end
endmodule
