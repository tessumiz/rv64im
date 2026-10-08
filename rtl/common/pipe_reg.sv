module pipe_reg #(
  parameter type T
)(
    input logic clk,
    input logic rst_n,

    input logic flush,
    input logic stall,

    input  T    d,
    output T    q
);

    always_ff @(posedge clk) begin
        if (!rst_n)
            q.valid <= 0;

        else if (flush)
            q.valid <= 0;

        else if (!stall)
            q <= d;
    end
endmodule
