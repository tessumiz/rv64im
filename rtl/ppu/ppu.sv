module ppu import defs_pkg::uint, ppu_pkg::*; (
    input logic clk,
    input logic rst,

    gen_mem_if.slave mmio_bus
);

    ppu_ctrl_t   ctrl /* verilator public_flat_rd */;

    logic [15:0] palette  [SIZE_PALETTE/2 - 1:0];
    logic [7:0]  anim_lut [SIZE_ANIM_LUT - 1:0];
    logic [7:0]  bg_map   [SIZE_BG_MAP - 1:0];
    logic [7:0]  tile_ram [SIZE_TILE_RAM - 1:0];
    oam_t        oam [63:0];

    logic [15:0] frm_buff [SIZE_FRM_BUFF/2 - 1:0] /* verilator public_flat_rd */;


    // decode (move this into another module later)
    logic [63:0]  addr;
    logic         r_en, w_en;

    logic [15:0] pal_idx;
    logic [31:0] anim_lut_idx;
    logic [15:0] bg_idx;
    logic [15:0] tile_idx;
    logic [5:0]  oam_idx;

    always_comb begin
        addr = mmio_bus.addr;
        r_en = mmio_bus.r_en;
        w_en = mmio_bus.w_en;

        pal_idx      = ((addr & ~64'h7) - ADDR_PALETTE) / 2;
        anim_lut_idx = ((addr & ~64'h7) - ADDR_ANIM_LUT);
        bg_idx       = ((addr & ~64'h7) - ADDR_BG_MAP);
        tile_idx     = ((addr & ~64'h7) - ADDR_TILE_RAM);
        oam_idx      = ((addr & ~64'h7) - ADDR_OAM) / 8;
    end


    // raster bg (again, move this monolith out later...)

    // pipe regs
    raster_bg_t tile_q,  // tile fetch
                col_q,   // col  fetch
                blit_q;  // blit pix

    logic [8:0]  scr_x; 
    logic [7:0]  scr_y;
    logic [31:0] frm_cyc;


    logic [11:0] bg_map_addr;
    logic [13:0] tile_px_addr;
    logic [7:0]  color_idx;


    always_ff @(posedge clk) begin
        if (rst) begin
            mmio_bus.ready  <= 0;
            mmio_bus.r_data <= 0;

            ctrl    <= 0;
            scr_x   <= 0;
            scr_y   <= 0;
            frm_cyc <= 0;

            tile_q <= '0;
            col_q  <= '0;
            blit_q <= '0;
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
                
                else if (addr >= ADDR_PALETTE && addr < ADDR_ANIM_LUT) begin
                    if (w_en)
                        for (int i = 0; i < 4; i++)
                            if (mmio_bus.w_mask[i*2])
                                palette[pal_idx + i] <= mmio_bus.w_data[i*16 +: 16];

                    if (r_en)
                        for (int i = 0; i < 4; i++)
                            mmio_bus.r_data[i*16 +: 16] <= palette[pal_idx + i];
                end

                else if (addr >= ADDR_ANIM_LUT && addr < ADDR_BG_MAP) begin
                    if (w_en)
                        for (int i = 0; i < 8; i++)
                            if (mmio_bus.w_mask[i])
                                anim_lut[anim_lut_idx + i] <= mmio_bus.w_data[i*8 +: 8];
                    
                    if (r_en)
                        for (int i = 0; i < 8; i++)
                            mmio_bus.r_data[i*8 +: 8] <= anim_lut[anim_lut_idx + i];
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

                else if (addr >= ADDR_OAM && addr < ADDR_OAM + SIZE_OAM) begin
                    if (w_en)
                        for (int i = 0; i < 8; i++)
                            if (mmio_bus.w_mask[i])
                                oam[oam_idx][i*8 +: 8] <= mmio_bus.w_data[i*8 +: 8];
                    
                    if (r_en)
                        mmio_bus.r_data <= oam[oam_idx];
                end
            end


            if (frm_cyc == BG_TOTAL_CYC - 1) begin
                scr_x    <= 0;
                scr_y    <= 0;
                frm_cyc  <= 0;
            end
            else
                frm_cyc <= frm_cyc + 1;


            // find screen coord
            if (frm_cyc < BG_FETCH_CYC) begin
                logic [9:0] abs_x, abs_y;

                abs_x = scr_x + ctrl.scroll_x[9:0];
                abs_y = scr_y + ctrl.scroll_y[9:0];

                bg_map_addr  <= {abs_y[9:4], abs_x[9:4]};  // div 16

                if (scr_x == SCR_W - 1) begin  // y-overflw handled by tot cyc guard above
                    scr_x <= 0;
                    scr_y <= scr_y + 1;
                end
                else
                    scr_x <= scr_x + 1;
                
                tile_q.x      <= scr_x;
                tile_q.y      <= scr_y;
                tile_q.valid  <= 1;
                ctrl.state    <= BG;
                tile_q.is_spr <= 0;
            end

            else if (frm_cyc >= BG_ACTIVE_CYC && frm_cyc < OAM_FETCH_CYC) begin
                logic [13:0] oam_cyc;
                logic [5:0]  spr_idx;
                oam_t        spr;
                
                logic [3:0]  px_x, px_y;
                logic signed [16:0] screen_x, screen_y;

                ctrl.state <= OAM;

                oam_cyc = 14'(frm_cyc - BG_ACTIVE_CYC);

                spr_idx = oam_cyc[13:8];
                px_y    = oam_cyc[7:4];
                px_x    = oam_cyc[3:0];

                spr = oam[spr_idx];
                
                screen_x = spr.x + signed'({1'b0, px_x});
                screen_y = spr.y + signed'({1'b0, px_y});

                if (spr.valid && (screen_x >= 0 && screen_x < SCR_W) && (screen_y >= 0 && screen_y < SCR_H)) begin
                    tile_q.valid   <= 1;
                    tile_q.is_spr  <= 1;
                    tile_q.x       <= screen_x[8:0];
                    tile_q.y       <= screen_y[7:0];
                    tile_q.tile_id <= spr.tile_id;
                    
                    tile_q.sub_x   <= px_x ^ {4{spr.flip_h}};
                    tile_q.sub_y   <= px_y ^ {4{spr.flip_v}};
                end
                else
                    tile_q.valid <= 0;
            end

            else begin
                if (frm_cyc >= OAM_ACTIVE_CYC)
                    ctrl.state <= VBLANK;

                tile_q.valid <= 0;
            end


            // stages
            col_q  <= tile_q;
            blit_q <= col_q;


            // 1; fetch tile-idx  + sub-px inside it (optional anim-lut)
            // think about the combinational path delay here...
            if (tile_q.valid) begin

                if (tile_q.is_spr)
                    tile_px_addr <= {tile_q.tile_id[5:0], tile_q.sub_y, tile_q.sub_x};
                
                else begin
                    logic [7:0] fetched_tile;
                    logic [7:0] actual_tile;
                    logic       is_anim;

                    logic [3:0] sub_x, sub_y;

                    fetched_tile = bg_map[bg_map_addr];
                    is_anim      = fetched_tile[7];
                    actual_tile  = is_anim ? anim_lut[fetched_tile[4:0]] : fetched_tile;

                    sub_x = 4'(tile_q.x + ctrl.scroll_x);
                    sub_y = 4'(tile_q.y + ctrl.scroll_y);
                    
                    tile_px_addr <= {actual_tile[5:0], sub_y, sub_x};
                end
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

                // Fix; OAMs are allowed to be transparent
                // the black-screen bg bug is gone now
                else if (!blit_q.is_spr)
                    frm_buff[fb_addr] <= {1'b1, 15'b0};
            end
        end
    end

endmodule
