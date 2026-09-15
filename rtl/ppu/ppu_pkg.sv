package ppu_pkg;
    import defs_pkg::uint;

    typedef struct packed {
        logic vblank;
        logic [15:0] scroll_y;
        logic [15:0] scroll_x;
    } ppu_ctrl_t;


    // mmio regions
    localparam logic [63:0]
        ADDR_CTRL = 64'h0400_0008,  // 33b, treated as 64b

        ADDR_PALETTE   = 64'h0400_0200,
        SIZE_PALETTE   = 512,

        ADDR_ANIM_LUT  = 64'h0400_0400,
        SIZE_ANIM_LUT  = 32,

        ADDR_BG_MAP    = 64'h0400_1000,
        SIZE_BG_MAP    = 4096,

        ADDR_TILE_RAM  = 64'h0400_2000,
        SIZE_TILE_RAM  = 16384,

        // to be decided...
        ADDR_OAM       = 64'h0400_6000,  // adding this now cuz I want the decoder to work
        SIZE_OAM       = 0,

        ADDR_FRM_BUFF  = 64'h0401_0000,
        SIZE_FRM_BUFF  = 153600;


    // dims
    localparam uint SCR_W = 320, SCR_H = 240;
    
    // vblank is fixed cycle as of now, consider another arch in the future...
    localparam uint VBLANK_CYC = 16384;


    // for raster bg
    typedef struct packed {
        logic       valid;
        logic [8:0] x;
        logic [7:0] y;
    } raster_bg_t;
endpackage
