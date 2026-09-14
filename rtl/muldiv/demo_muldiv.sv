// functional dummy; to be purged after demo


module demo_muldiv (
    muldiv_if.slave bus
);
    logic [127:0] mul_res;
    logic [63:0]  div_res;
    logic [63:0]  rem_res;
    logic [63:0]  base_res;

    logic signed [63:0] op1_s;
    logic signed [63:0] op2_s;
    
    logic [63:0] div_op1_u, div_op2_u;
    logic signed [63:0] div_op1_s, div_op2_s;

    logic overflow;


    always_comb begin
        op1_s = $signed(bus.op1);
        op2_s = $signed(bus.op2);

        unique case (bus.f3_2)
            2'b00: mul_res = op1_s * op2_s;
            2'b01: mul_res = op1_s * op2_s;
            2'b10: mul_res = $signed(bus.op1) * $signed({1'b0, bus.op2});
            2'b11: mul_res = bus.op1 * bus.op2;
        endcase

        if (bus.is_wd_op) begin
            div_op1_u = {32'b0, bus.op1[31:0]};
            div_op2_u = {32'b0, bus.op2[31:0]};
            div_op1_s = $signed(bus.op1[31:0]);
            div_op2_s = $signed(bus.op2[31:0]);

            overflow = (bus.op1[31:0] == 32'h8000_0000) &&
                       (bus.op2[31:0] == 32'hFFFF_FFFF);
        end
        else begin
            div_op1_u = bus.op1;
            div_op2_u = bus.op2;
            div_op1_s = op1_s;
            div_op2_s = op2_s;

            overflow = (bus.op1 == 64'h8000_0000_0000_0000) &&
                       (bus.op2 == 64'hFFFF_FFFF_FFFF_FFFF);
        end

        if (bus.is_wd_op ? (bus.op2[31:0] == 0) : (bus.op2 == 0)) begin
            div_res = '1; // Maps to -1, fulfilling spec requirements
            rem_res = bus.is_wd_op ? {{32{bus.op1[31]}}, bus.op1[31:0]} : bus.op1;
        end
        else if (overflow) begin
            div_res = bus.is_wd_op ? {{32{bus.op1[31]}}, bus.op1[31:0]} : bus.op1;
            rem_res = 0;
        end
        else begin
            div_res = bus.f3_2[0] ? (div_op1_u / div_op2_u) : (div_op1_s / div_op2_s);
            rem_res = bus.f3_2[0] ? (div_op1_u % div_op2_u) : (div_op1_s % div_op2_s);
        end


        base_res = 0;

        if (bus.is_mul) begin
            bus.res = bus.is_wd_op ? {{32{mul_res[31]}}, mul_res[31:0]} : 
                         (bus.f3_2 == 2'b00) ? mul_res[63:0] : mul_res[127:64];
        end
        else if (bus.is_div) begin
            base_res = bus.f3_2[1] ? rem_res : div_res;
            bus.res = bus.is_wd_op ? {{32{base_res[31]}}, base_res[31:0]} : base_res;
        end
        else begin
            bus.res = '0;
        end
    end
endmodule
