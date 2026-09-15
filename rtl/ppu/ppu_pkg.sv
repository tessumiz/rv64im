package ppu_pkg;
    import defs_pkg::uint;

    typedef enum logic [1:0] { BG, OAM, VBLANK } ppu_fsm_t;

    typedef struct packed {
        ppu_fsm_t    state;

        logic [15:0] scroll_y;
        logic [15:0] scroll_x;
    } ppu_ctrl_t;

    typedef struct packed {
        logic [20:0] _pad;

        logic valid;
        logic flip_h;
        logic flip_v;
        logic [7:0]  tile_id;
        logic signed [15:0] y;
        logic signed [15:0] x;
    } oam_t;


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
        SIZE_OAM       = 512,

        ADDR_FRM_BUFF  = 64'h0401_0000,
        SIZE_FRM_BUFF  = 153600;


    // dims
    localparam uint SCR_W = 320, SCR_H = 240;



    localparam uint
        NET_CYC = 100000,  // arbitrary
        OAM_CYC = 16384,
        BG_PIPE_DELAY = 3,

        BG_FETCH_CYC  = SCR_W * SCR_H,
        VBLANK_CYC    = NET_CYC - OAM_CYC - BG_FETCH_CYC,
        BG_ACTIVE_CYC = BG_FETCH_CYC  + BG_PIPE_DELAY,

        OAM_FETCH_CYC  = BG_ACTIVE_CYC + OAM_CYC,
        OAM_ACTIVE_CYC = OAM_FETCH_CYC + BG_PIPE_DELAY,

        BG_TOTAL_CYC   = OAM_ACTIVE_CYC + VBLANK_CYC;


    // for raster bg
    typedef struct packed {
        logic       valid;
        logic       is_spr;
        logic [8:0] x;
        logic [7:0] y;

        logic [7:0] tile_id; 
        logic [3:0] sub_x;
        logic [3:0] sub_y;
    } raster_bg_t;
endpackage
