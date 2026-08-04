module wb_arbiter (
    imuldiv_out_if.slave imul_out,
    imuldiv_out_if.slave idiv_out,
    wb_if.slave wb_out,

    wb_if.master out
);

    // prioritizing wb; cuz of the possibility that muldiv can wb on a natural wb bubble. No difference
    // if it was caused by a dependency stall in the first place. Div comes next because of longer latency;
    // more likely to create dependency bubbles... mul is pipelined; most tolerable.

    always_comb begin
        if (wb_out.valid) begin
            out.valid = 1;
            out.rd    = wb_out.rd;
            out.data  = wb_out.data;
        end
        else if (imul_out.valid) begin
            out.valid = 1;
            out.rd    = imul_out.rd;
            out.data  = imul_out.result;
        end
        else if (idiv_out.valid) begin
            out.valid = 1;
            out.rd    = idiv_out.rd;
            out.data  = idiv_out.result;
        end
        else begin
            out.valid = 0;
            out.rd    = 0;
            out.data  = 0;
        end
    end
endmodule
