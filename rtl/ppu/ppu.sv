module ppu import defs_pkg::uint, ppu_pkg::*; (
    input logic clk,
    input logic rst,

    gen_mem_if.slave mmio_bus
);

    ppu_ctrl_t   ctrl /* verilator public_flat_rd */;

    logic [15:0] palette  [SIZE_PALETTE/2 - 1:0];
    logic [7:0]  bg_map   [SIZE_BG_MAP - 1:0];
    logic [7:0]  tile_ram [SIZE_TILE_RAM - 1:0];
    logic [15:0] frm_buff [SIZE_FRM_BUFF/2 - 1:0] /* verilator public_flat_rd */;


    // decode (move this into another module later)
    logic [63:0]  addr;
    logic         r_en, w_en;

    logic [$clog2(SIZE_PALETTE)-1:0]  pal_idx;
    logic [$clog2(SIZE_BG_MAP)-1:0]   bg_idx;
    logic [$clog2(SIZE_TILE_RAM)-1:0] tile_idx;

    always_comb begin
        addr = mmio_bus.addr;
        r_en = mmio_bus.r_en;
        w_en = mmio_bus.w_en;

        pal_idx  = ((addr & ~64'h7) - ADDR_PALETTE) >> 1;
        bg_idx   = ((addr & ~64'h7) - ADDR_BG_MAP);
        tile_idx = ((addr & ~64'h7) - ADDR_TILE_RAM);
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            mmio_bus.ready  <= 0;
            mmio_bus.r_data <= 0;
            ctrl <= 0;
        end
        else begin
            mmio_bus.ready <= 0;

            if (r_en || w_en) begin
                mmio_bus.ready <= 1;

                if (addr == ADDR_CTRL) begin
                    if (w_en) begin
                        ctrl.scroll_x <= mmio_bus.w_data[15:0];
                        ctrl.scroll_y <= mmio_bus.w_data[31:16];
                    end

                    mmio_bus.r_data <= {31'b0, ctrl};
                end
                
                else if (addr >= ADDR_PALETTE && addr < ADDR_BG_MAP) begin
                    if (w_en)
                        for (int i = 0; i < 4; i++)
                            if (mmio_bus.w_mask[i*2])
                                palette[pal_idx + i] <= mmio_bus.w_data[i*16 +: 16];

                    if (r_en)
                        for (int i = 0; i < 4; i++)
                            mmio_bus.r_data[i*16 +: 16] <= palette[pal_idx + i];
                end
                
                else if (addr >= ADDR_BG_MAP && addr < ADDR_TILE_RAM) begin
                    if (w_en)
                        for (int i = 0; i < 8; i++)
                            if (mmio_bus.w_mask[i])
                                bg_map[bg_idx + i] <= mmio_bus.w_data[i*8 +: 8];
                    
                    if (r_en)
                        for (int i = 0; i < 8; i++)
                            mmio_bus.r_data[i*8 +: 8] <= bg_map[bg_idx + i];
                end
                
                else if (addr >= ADDR_TILE_RAM && addr < ADDR_OAM) begin
                    if (w_en)
                        for (int i = 0; i < 8; i++)
                            if (mmio_bus.w_mask[i])
                                tile_ram[tile_idx + i] <= mmio_bus.w_data[i*8 +: 8];
                    
                    if (r_en)
                        for (int i = 0; i < 8; i++)
                            mmio_bus.r_data[i*8 +: 8] <= tile_ram[tile_idx + i];
                end
            end
        end
    end


    // raster bg (again, move this monolith out later...)

    // pipe regs
    raster_bg_t tile_q,  // tile fetch
                col_q,   // col  fetch
                blit_q;  // blit pix

    logic [8:0]  scr_x; 
    logic [7:0]  scr_y;
    logic [31:0] frm_cyc;


    localparam uint
        BG_PIPE_DELAY = 3,
        BG_FETCH_CYC  = SCR_W * SCR_H,
        BG_ACTIVE_CYC = BG_FETCH_CYC  + BG_PIPE_DELAY,
        BG_TOTAL_CYC  = BG_ACTIVE_CYC + VBLANK_CYC;


    logic [11:0] bg_map_addr;
    logic [13:0] tile_px_addr;
    logic [7:0]  color_idx;

    always_ff @(posedge clk) begin
        if (rst) begin
            scr_x   <= 0;
            scr_y   <= 0;
            frm_cyc <= 0;

            ctrl.vblank <= 0;

            tile_q <= '0;
            col_q  <= '0;
            blit_q <= '0;
        end
        else begin
            if (frm_cyc == BG_TOTAL_CYC - 1) begin
                scr_x    <= 0;
                scr_y    <= 0;
                frm_cyc  <= 0;
                ctrl.vblank <= 0;
            end
            else begin
                frm_cyc <= frm_cyc + 1;

                if (frm_cyc == BG_ACTIVE_CYC - 1)
                    ctrl.vblank <= 1;
            end

            // find screen coord
            if (!ctrl.vblank && frm_cyc < BG_FETCH_CYC) begin
                logic [9:0] abs_x, abs_y;

                abs_x = scr_x + ctrl.scroll_x[9:0];
                abs_y = scr_y + ctrl.scroll_y[9:0];

                bg_map_addr  <= {abs_y[9:4], abs_x[9:4]};  // div 16
                
                tile_q.x     <= scr_x;
                tile_q.y     <= scr_y;
                tile_q.valid <= 1;
                
                if (scr_x == SCR_W - 1) begin  // y-overflw handled by tot cyc guard above
                    scr_x <= 0;
                    scr_y <= scr_y + 1;
                end
                else scr_x <= scr_x + 1;
            end
            else tile_q.valid <= 0;  // ins nops during vblank


            // stages
            col_q  <= tile_q;
            blit_q <= col_q;


            // 1; fetch tile-idx + sub-px inside it
            if (tile_q.valid) begin
                logic [3:0] sub_x, sub_y;
                
                // 4' takes the mod
                sub_x = 4'(tile_q.x + ctrl.scroll_x);
                sub_y = 4'(tile_q.y + ctrl.scroll_y);
                
                tile_px_addr <= {bg_map[bg_map_addr][5:0], sub_y, sub_x};
            end

            // 2; fetch col idx
            if (col_q.valid) begin
                color_idx <= tile_ram[tile_px_addr];
            end

            // 3; fetch col from pal and blit
            if (blit_q.valid) begin
                logic [16:0] fb_addr;
                fb_addr = (blit_q.y * SCR_W) + blit_q.x;

                // idx-0 as usual is transparent
                if (color_idx != 0)
                    frm_buff[fb_addr] <= {1'b1, palette[color_idx][14:0]};  // formatting for raylib; bit-16 is alpha
                
                // without this, past screen garbage ilngers
                // for the non-mvp, we'll include a clr routine...
                else
                    frm_buff[fb_addr] <= {1'b1, 15'b0};
            end
        end
    end

endmodule
