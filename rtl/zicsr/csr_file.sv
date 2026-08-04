module csr_file(
    input logic clk,
    input logic rst,

    csr_rw_if.slave   csr_rw_bus,
    csr_trap_if.slave csr_trap_bus
);

    logic [63:0] mstatus;
    logic [63:0] mtvec;
    logic [63:0] mepc;
    logic [63:0] mcause;
    logic [63:0] mtval;

    localparam MSTATUS_MIE  = 3;
    localparam MSTATUS_MPIE = 7;

    logic [63:0] mie;
    logic [63:0] mip;


    logic [63:0] r_data;

    always_comb begin
        case (csr_rw_bus.r_addr)
            12'h300: r_data = mstatus;
            12'h305: r_data = mtvec;
            12'h341: r_data = mepc;
            12'h342: r_data = mcause;
            12'h343: r_data = mtval;

            default: r_data = '0;
        endcase

        csr_rw_bus.r_data = r_data;
    end

    assign csr_trap_bus.mtvec = mtvec;
    assign csr_trap_bus.mepc  = mepc;


    always_ff @(posedge clk) begin
        if (rst) begin
            mstatus <= 0;
            mtvec   <= 0;
            mepc    <= 0;
            mcause  <= 0;
            mtval   <= 0;
        end
        else begin
            if (csr_rw_bus.w_en) begin
                unique case (csr_rw_bus.w_addr)  // check's done in id, hence exhaustive
                    12'h300: mstatus <= csr_rw_bus.w_data;
                    12'h305: mtvec   <= csr_rw_bus.w_data;
                    12'h341: mepc    <= csr_rw_bus.w_data;
                    12'h342: mcause  <= csr_rw_bus.w_data;
                    12'h343: mtval   <= csr_rw_bus.w_data;
                endcase
            end

            if (csr_trap_bus.is_exc) begin
                mstatus[MSTATUS_MPIE] <= mstatus[MSTATUS_MIE];
                mepc          <= csr_trap_bus.pc;
                mcause        <= csr_trap_bus.cause;
            end
        end
    end

endmodule
