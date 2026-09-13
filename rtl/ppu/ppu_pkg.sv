import defs_pkg::uint;


package ppu_pkg;

    // ctrl
    localparam logic [63:0]
        ADDR_BG_SCROLL = 64'h0400_0008,
        ADDR_VBLANK    = 64'h0400_0010;


    // mmio regions
    localparam logic [63:0]
        ADDR_PALETTE   = 64'h0400_0200,
        SIZE_PALETTE   = 512,

        ADDR_BG_MAP    = 64'h0400_1000,
        SIZE_BG_MAP    = 4096,

        ADDR_TILE_RAM  = 64'h0400_2000,
        SIZE_TILE_RAM  = 16384,

        // to be decided...
        ADDR_OAM       = 0,
        SIZE_OAM       = 0,

        ADDR_FRM_BUFF  = 64'h0401_0000,
        SIZE_FRM_BUFF  = 153600;


    // dims
    localparam uint SCR_W = 320, SCR_H = 240;
    
    // vblank is fixed cycle as of now, consider another arch in the future...
    localparam uint VBLANK_CYC = 10000;
endpackage
