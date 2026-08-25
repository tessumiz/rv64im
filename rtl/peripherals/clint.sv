module clint (
    input logic clk_32kHz,
    input logic rst
);
    
    logic [63:0] mtime;
    logic [63:0] mtimecmp;

    always_ff @(posedge clk_32kHz) begin
        if (rst) begin
            mtime <= 0;
        end
        else begin
            mtime <= mtime + 1;
        end
    end
endmodule
