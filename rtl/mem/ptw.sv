import mem_pkg::*;

module ptw(
    input  clk,
    input rst,

    input logic        valid,
    input logic [43:0] root,
    input logic [63:0] vaddr,

    dram_if.master bus,

    output logic [63:0] paddr,
    output logic page_fault, access_fault
);

    ptw_fsm_t    state;
    ptw_lvl_t    level;
    logic [55:0] curr_root;


    logic [8:0] vpn [2:0];

    assign vpn[2] = vaddr[38:30];
    assign vpn[1] = vaddr[29:21];
    assign vpn[0] = vaddr[20:12];


    always_ff @(posedge clk) begin
        if (rst) begin
            curr_root <= 0;
            state     <= PTW_IDLE;
            level     <= PTW_LVL1;
        end
        else begin
            unique case (state)
                PTW_IDLE : begin
                    if (valid) begin
                        state     <= PTW_WALK;
                        curr_root <= {root, 12'b0};
                    end
                end

                PTW_WAIT : begin
                    if (bus.ready)
                        state <= PTW_WALK;
                end

                PTW_WALK : begin
                    // ...
                end
            endcase
        end
    end
endmodule
