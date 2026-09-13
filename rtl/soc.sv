import defs_pkg::*;


module soc (
    input logic clk,
    input logic rst,
    
    input logic [63:0] keyinp 
);

    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) ifu_ram_bus ();
    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) dcu_ram_bus ();
    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) main_ram_bus ();
    
    gen_mem_if #(.ADDR_W(64), .DATA_W(64))  dcu_mmio_bus ();

    irq_t  irq;
    assign irq = '0;  // none for now


    pipeline u_core (
        .clk      (clk),
        .rst      (rst),
        .ifu_ram  (ifu_ram_bus.master),
        .dcu_ram  (dcu_ram_bus.master),
        .dcu_mmio (dcu_mmio_bus.master),
        .irq      (irq)
    );

    ram_arbiter u_ram_arbiter (
        .ifu_bus  (ifu_ram_bus.slave),
        .dcu_bus  (dcu_ram_bus.slave),
        .ram_bus (main_ram_bus.master)
    );

    ram #(.SIZE_BYTES (1 * 1024 * 1024))
    u_ram (
        .clk (clk),
        .bus (main_ram_bus.slave)
    );


    always_ff @(posedge clk) begin
        static logic [63:0] addr = dcu_mmio_bus.addr;

        if (rst) begin
            dcu_mmio_bus.ready  <= 0;
            dcu_mmio_bus.r_data <= 0;
        end

        else begin
            dcu_mmio_bus.ready  <= 0;

            if (dcu_mmio_bus.r_en || dcu_mmio_bus.w_en) begin
                dcu_mmio_bus.ready <= 1;
                
                if (dcu_mmio_bus.r_en) begin
                    case (addr)
                        64'h0400_0000:
                            dcu_mmio_bus.r_data <= keyinp;
                        
                        // ...
                        
                        default:
                            dcu_mmio_bus.r_data <= 0;
                    endcase
                end
                
                if (dcu_mmio_bus.w_en) begin
                    case (addr)
                        // ...
                        
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
