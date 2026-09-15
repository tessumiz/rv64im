#include <stdint.h>

#define KEYINP   (*(volatile uint64_t*)0x04000000)
#define CTRL     (*(volatile uint64_t*)0x04000008)
#define PALETTE  ((volatile uint16_t*)0x04000200)
#define ANIM_LUT ((volatile uint8_t *)0x04000400)
#define BG_MAP   ((volatile uint8_t *)0x04001000)
#define TILE_RAM ((volatile uint8_t *)0x04002000)

int main(void)
{
    PALETTE[0] = 0x0000;
    PALETTE[1] = 0x7C00;   // red
    PALETTE[2] = 0x001F;   // blue

    /* Physical Tile 1 = red */
    for (int i = 0; i < 256; ++i) TILE_RAM[256 + i] = 1;

    /* Physical Tile 2 = blue */
    for (int i = 0; i < 256; ++i) TILE_RAM[512 + i] = 2;

    /* 
     * Draw the checkerboard using VIRTUAL tiles (MSB set).
     * 0x80 points to LUT[0].
     * 0x81 points to LUT[1].
     */
    for (int y = 0; y < 64; ++y) {
        for (int x = 0; x < 64; ++x) {
            BG_MAP[y * 64 + x] = ((x + y) & 1) ? 0x81 : 0x80;
        }
    }

    /* Initial LUT state */
    ANIM_LUT[0] = 1;
    ANIM_LUT[1] = 2;

    uint64_t last_vblank = 0;
    uint64_t last_key = 0;

    while (1) {
        // Read bit 32 of CTRL to check VBLANK
        uint64_t vblank = (CTRL >> 32) & 1;

        // Trigger ONLY on the rising edge of VBLANK
        if (vblank && !last_vblank) {
            
            // Poll the Right Arrow Key
            uint64_t right_pressed = KEYINP & 1;

            // Swap LUT ONLY on the initial key press
            if (right_pressed && !last_key) {
                uint8_t temp = ANIM_LUT[0];
                ANIM_LUT[0]  = ANIM_LUT[1];
                ANIM_LUT[1]  = temp;
            }
            
            last_key = right_pressed;
        }
        
        last_vblank = vblank;
    }

    return 0;
}