#include "types.h"


#define KEYINP   (*(volatile u64*)0x04000000)
#define CTRL     (*(volatile u64*)0x04000008)
#define PALETTE  ( (volatile u16*)0x04000200)
#define BG_MAP   ( (volatile u8*) 0x04001000)
#define TILE_RAM ( (volatile u8*) 0x04002000)


int main() {
    PALETTE[1] = 0x7FFF;  // WHITE

    for (int i = 0; i < 256; i++) {
        TILE_RAM[256 + i] = 1; 
    }

    // rand rect at (10, 10)
    for (int y = 10; y < 14; y++) {
        for (int x = 10; x < 14; x++)
            BG_MAP[(y * 64) + x] = 1;
    }

    u32 sx = 0, sy = 0;

    while (1) {
        // spin-wait (for now, unfortunately)
        while ((CTRL & (1ULL << 32)) == 0);

        // 16384 cyc budget now

        u64 keys = KEYINP;

        if (keys & (1 << 0)) sy--;
        if (keys & (1 << 1)) sy++;
        if (keys & (1 << 2)) sx--;
        if (keys & (1 << 3)) sx++;

        CTRL = ((sy & 0xFFFF) << 16) | (sx & 0xFFFF);

        // spin again; else multiple iters of mainloop will run
        while ((CTRL & (1ULL << 32)) != 0);
    }
    
    return 0;
}