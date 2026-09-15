#include "types.h"


typedef struct {
    u64 right : 1;
    u64 left  : 1;
    u64 down  : 1;
    u64 up    : 1;
    u64 _pad  : 60;
} Keyinp;

#define KEYINP (*(volatile Keyinp*)0x04000000)


typedef enum { PPU_BG, PPU_OAM, PPU_VBLANK } PPU_State;

typedef struct {
    u16 scroll_x;
    u16 scroll_y;
    PPU_State state : 2;
    u32 _pad : 30;
} PPU_Ctrl;

#define CTRL (*(volatile PPU_Ctrl*)0x04000008)


typedef struct {
    i16 x;
    i16 y;
    u8  tile_id;
    u8  attrs;
    u16 padding;
} OAM_Entry;


#define PALETTE  ((volatile u16*)0x04000200)
#define ANIM_LUT ((volatile u8*)0x04000400)
#define BG_MAP   ((volatile u8*)0x04001000)
#define TILE_RAM ((volatile u8*)0x04002000)
#define OAM      ((volatile OAM_Entry*)0x04006000)


int main(void)
{
    PALETTE[0] = 0x0000;
    PALETTE[1] = 0x7C00;
    PALETTE[2] = 0x001F;
    PALETTE[3] = 0x03E0;

    for (u16 i = 0; i < 256; ++i)
        TILE_RAM[256 + i] = 1;

    for (u16 i = 0; i < 256; ++i)
        TILE_RAM[512 + i] = 2;

    for (u16 i = 0; i < 256; ++i)
        TILE_RAM[768 + i] = 3;

    for (u16 y = 0; y < 15; ++y) {
        for (u16 x = 0; x < 20; ++x)
            BG_MAP[y * 64 + x] = ((x + y) & 1) ? 0x81 : 0x80;
    }

    ANIM_LUT[0] = 1;
    ANIM_LUT[1] = 2;

    OAM[0].x = 152;
    OAM[0].y = 112;
    OAM[0].tile_id = 3;
    OAM[0].attrs = (1 << 2);

    PPU_State prev_state = PPU_BG;

    while (1) {
        PPU_State curr_state = (PPU_State)CTRL.state;
        int temp;

        if (curr_state == PPU_VBLANK && prev_state != PPU_VBLANK) {
            Keyinp keys = KEYINP;

            if (keys.right) {
                temp = ANIM_LUT[0];
                ANIM_LUT[0] = ANIM_LUT[1];
                ANIM_LUT[1] = temp;
            }

            if (keys.right) OAM[0].x += 5;
            if (keys.left)  OAM[0].x -= 5;
            if (keys.down)  OAM[0].y += 5;
            if (keys.up)    OAM[0].y -= 5;
        }

        prev_state = curr_state;
    }

    return 0;
}