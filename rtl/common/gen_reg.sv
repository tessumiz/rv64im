module gen_reg #(
  parameter type T = logic [31:0]
)(
    input logic clk,
    input logic clr,
    input logic en,

    input  T    d,
    output T    q
);

    always_ff @(posedge clk) begin
        if (clr) begin
            q <= 0;
        end
        else if (en) begin
            q <= d;
        end
    end
endmodule
