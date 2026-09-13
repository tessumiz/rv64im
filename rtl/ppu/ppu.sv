import ppu_pkg::*;


module ppu (
    input  logic clk,
    input  logic rst,

    gen_mem_if.slave mmio_bus
);

    
    logic vblank;
    logic [15:0] scroll_x;
    logic [15:0] scroll_y;

    logic [15:0] palette  [SIZE_PALETTE-1:0];
    logic [7:0]  bg_map   [SIZE_BG_MAP-1:0];
    logic [7:0]  tile_ram [SIZE_TILE_RAM-1:0];
    logic [15:0] frm_buff [SIZE_FRM_BUFF-1:0];

    
    
endmodule
