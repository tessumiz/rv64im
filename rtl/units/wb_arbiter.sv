module wb_arbiter (
    muldiv_out_if.slave mul_out,
    muldiv_out_if.slave div_out,
    wb_if.slave wb_out,

    wb_if.master out
);

    // prioritizing wb; cuz of the possibility that muldiv can wb on a natural wb bubble. No difference
    // if it was caused by a dependency stall in the first place. Div comes next because of longer latency;
    // more likely to create dependency bubbles... mul is pipelined; most tolerable.

    always_comb begin
        mul_out.stall = 1;
        div_out.stall = 1;

        out.valid = 0;
        out.rd    = 0;
        out.data  = 0;

        if (wb_out.valid) begin
            out.valid = 1;
            out.rd    = wb_out.rd;
            out.data  = wb_out.data;
        end
        else if (mul_out.commit_ready) begin
            out.valid = 1;
            out.rd    = mul_out.rd;
            out.data  = mul_out.result;

            mul_out.stall = 0;
        end
        else if (div_out.commit_ready) begin
            out.valid = 1;
            out.rd    = div_out.rd;
            out.data  = div_out.result;

            div_out.stall = 0;
        end
    end
endmodule
