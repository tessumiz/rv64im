module gen_reg #(
  parameter type T = logic [31:0],
  parameter T RST_VAL = 0
)(
    input logic clk,
    input logic clr,
    input logic en,

    input  T    d,
    output T    q
);

    always_ff @(posedge clk) begin
        if (clr) begin
            q <= RST_VAL;
        end
        else if (en) begin
            q <= d;
        end
    end
endmodule
