import defs_pkg::*;

module clint #(
    parameter integer CLINT_BASE = 32'h0200_0000
)(
    input  logic clk,
    input  logic rst,

    dmem_if.slave bus,

    output logic timer_irq,
    output logic ipi_irq
);

    logic [31:0] msip;
    logic [63:0] mtimecmp;
    logic [63:0] mtime;

    logic [15:0] offset;
    assign offset = bus.v_addr[15:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            mtime <= 64'd0;
        end else begin
            mtime <= mtime + 1'b1;
        end
    end

    // 2. Read Multiplexer and Bus Responses
    always_comb begin
        bus.r_data       = 64'd0;
        bus.ready        = bus.r_en || bus.w_en; // Instant completion for internal MMIO regs
        bus.access_fault = 0;
        bus.page_fault   = 0;

        case (offset)
            16'h0000: bus.r_data = {32'd0, msip};
            16'h4000: bus.r_data = mtimecmp;
            16'hBFF8: bus.r_data = mtime;
            default:  bus.r_data = 64'd0;
        endcase
    end

    // 3. Write Decoder & Register Updates
    always_ff @(posedge clk) begin
        if (rst) begin
            msip     <= 32'd0;
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF; // Initialize high to avoid boot-time spam
        end else if (bus.w_en) begin
            case (offset)
                16'h0000: begin
                    if (bus.w_mask[0]) msip[7:0]   <= bus.w_data[7:0];
                    if (bus.w_mask[1]) msip[15:8]  <= bus.w_data[15:8];
                    if (bus.w_mask[2]) msip[23:16] <= bus.w_data[23:16];
                    if (bus.w_mask[3]) msip[31:24] <= bus.w_data[31:24];
                end

                16'h4000: begin
                    for (int i = 0; i < 8; i++) begin
                        if (bus.w_mask[i]) begin
                            mtimecmp[i*8 +: 8] <= bus.w_data[i*8 +: 8];
                        end
                    end
                end

                default: ; // mtime is read-only from software perspective
            endcase
        end
    end

    // 4. Interrupt Generation Logic
    assign ipi_irq   = msip[0];
    assign timer_irq = (mtime >= mtimecmp);

endmodule
