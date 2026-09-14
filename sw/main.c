#include "types.h"


#define PALETTE  ((volatile u16 *) 0x04000200)
#define BG_MAP   ((volatile u8  *) 0x04001000)
#define TILE_RAM ((volatile u8  *) 0x04002000)


static inline u16 rgb555(u32 r, u32 g, u32 b) {
    return ((r & 31) << 10) | ((g & 31) << 5) | (b & 31);
}

int main(void) {
    // tearing doesn't matter at the start; CTRL.VBLAKN check unnecessary here
    PALETTE[0] = rgb555(0, 0, 0);
    PALETTE[1] = rgb555(31, 0, 0);
    PALETTE[2] = rgb555(0, 0, 31);


    for (u32 i = 0; i < 256; i++) {
        TILE_RAM[i] = 1;
        TILE_RAM[256 + i] = 2;
    }

    // check pattern
    for (u32 y = 0; y < 64; y++) {
        for (u32 x = 0; x < 64; x++)
            BG_MAP[y * 64 + x] = (x ^ y) & 1;
    }

    return 0;
}