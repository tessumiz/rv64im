import defs_pkg::*;


module soc (
    input logic  clk,
    input logic  rst,

    logic [63:0] keyinp
);

    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) ifu_ram ();
    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) dcu_ram ();
    gen_mem_if #(.ADDR_W(64), .DATA_W(512)) main_ram ();
    
    gen_mem_if #(.ADDR_W(64), .DATA_W(64))  dcu_mmio ();
    gen_mem_if #(.ADDR_W(64), .DATA_W(64))  ppu_mmio ();

    irq_t  irq;
    assign irq = '0;  // none for now


    pipeline u_core (
        .clk      (clk),
        .rst      (rst),
        .ifu_ram  (ifu_ram.master),
        .dcu_ram  (dcu_ram.master),
        .dcu_mmio (dcu_mmio.master),
        .irq      (irq)
    );

    ram_arbiter u_ram_arbiter (
        .ifu_bus (ifu_ram.slave),
        .dcu_bus (dcu_ram.slave),
        .ram_bus (main_ram.master)
    );

    ram #(.SIZE_BYTES (1 * 1024 * 1024))
    u_ram (
        .clk (clk),
        .bus (main_ram.slave)
    );

    ppu u_ppu (
        .clk      (clk),
        .rst      (rst),
        .mmio_bus (ppu_mmio.slave)
    );


    always_comb begin
        ppu_mmio.addr   = dcu_mmio.addr;
        ppu_mmio.w_data = dcu_mmio.w_data;
        ppu_mmio.w_mask = dcu_mmio.w_mask;
        ppu_mmio.r_en   = 0;
        ppu_mmio.w_en   = 0;
        
        dcu_mmio.r_data = 0;
        dcu_mmio.ready  = 0;


        // bounds chk is alr done in mem_stage we just need to choose now
        if (dcu_mmio.addr < 64'h0400_0008) begin
            dcu_mmio.ready  = dcu_mmio.r_en || dcu_mmio.w_en;
            dcu_mmio.r_data = dcu_mmio.r_en ? keyinp : 0;
        end
        else begin
            ppu_mmio.r_en   = dcu_mmio.r_en;
            ppu_mmio.w_en   = dcu_mmio.w_en;
            
            dcu_mmio.r_data = ppu_mmio.r_data;
            dcu_mmio.ready  = ppu_mmio.ready;
        end
    end

endmodule
