module ram #(
    parameter SIZE_BYTES = 1 * 1024 * 1024
)(
    input  logic clk,
    gen_mem_if.slave bus
);

    localparam LINES = SIZE_BYTES / 64;

    logic [511:0] mem [LINES-1:0];

    logic [$clog2(LINES)-1:0] idx;
    assign idx = bus.addr[$clog2(LINES) + 5 : 6];

    always_ff @(posedge clk) begin
        if (bus.w_en)
            mem[idx] <= bus.w_data;

        if (bus.r_en)
            bus.r_data <= mem[idx];
    end

    always_ff @(posedge clk) begin
        bus.ready <= (bus.r_en || bus.w_en);
    end
endmodule
