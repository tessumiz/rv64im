#include "types.h"


#define KEYINP   ((volatile u64*)0x04000000)
#define CTRL     ((volatile u64*)0x04000008)
#define PALETTE  ((volatile u16*)0x04000200)
#define BG_MAP   ((volatile u8*) 0x04001000)
#define TILE_RAM ((volatile u8*) 0x04002000)
#define OAM      ((volatile u64*)0x04006000)


#define SCR_W 320
#define SCR_H 240

#define TILE_SIZE 16
#define MAP_WIDTH 64
#define MAP_SIZE 4096
#define MAX_SPRITES 64

#define KEY_RIGHT (1ULL << 0)
#define KEY_LEFT  (1ULL << 1)
#define STATE_VBLANK 2
#define PPU_STATE(ctrl) (((ctrl) >> 32) & 3)

#define WHITE  0x7FFF
#define SILVER 0x39CE
#define RED    0x0E0E
#define GREEN  0x0EE0
#define BLUE   0x3C0E

#define PAL_BALL   1
#define PAL_WALL   2
#define PAL_BRICK1 3
#define PAL_BRICK2 4
#define PAL_PAD    5

#define TILE_WALL   1
#define TILE_BRICK1 2
#define TILE_BRICK2 3
#define TILE_PAD    4
#define TILE_BALL   5

#define OAM_VALID (1ULL << 42)


#define WALL_WIDTH TILE_SIZE

#define PAD_SPRITES 3
#define PAD_W (PAD_SPRITES * TILE_SIZE)
#define PAD_H TILE_SIZE
#define PAD_SPEED 5
#define PAD_START_X ((SCR_W - PAD_W) / 2)
#define PAD_START_Y (SCR_H - 32)

#define BALL_SIZE 16
#define BALL_START_X ((SCR_W - BALL_SIZE) / 2)
#define BALL_START_Y (SCR_H / 2)
#define BALL_SPEED_X 2
#define BALL_SPEED_Y 2


void gen_tile(int tile_id, u8 col) {
    volatile u8 *ram = TILE_RAM + (tile_id * 256);
    for (int y = 0; y < TILE_SIZE; y++) {
        for (int x = 0; x < TILE_SIZE; x++)
            ram[y * TILE_SIZE + x] = col;
    }
}

void set_oam_attr(int idx, int x, int y, int tile_id) {
    OAM[idx] = OAM_VALID | ((u64)(tile_id & 0xFF) << 32) |
               (((u64)y & 0xFFFF) << 16) | ((u64)x & 0xFFFF);
}


int main(void) {
    PALETTE[PAL_BALL]   = WHITE;
    PALETTE[PAL_WALL]   = SILVER;
    PALETTE[PAL_BRICK1] = RED;
    PALETTE[PAL_BRICK2] = GREEN;
    PALETTE[PAL_PAD]    = BLUE;

    gen_tile(TILE_WALL,   PAL_WALL);
    gen_tile(TILE_BRICK1, PAL_BRICK1);
    gen_tile(TILE_BRICK2, PAL_BRICK2);
    gen_tile(TILE_PAD,    PAL_PAD);
    gen_tile(TILE_BALL,    PAL_BALL);


    // clr is mandatory...
    for (int i = 0; i < MAP_SIZE; i++)
        BG_MAP[i] = 0;

    for (int i = 0; i < MAX_SPRITES; i++)
        OAM[i] = 0;


    int scr_tiles_w = SCR_W / TILE_SIZE;
    int scr_tiles_h = SCR_H / TILE_SIZE;

    for (int y = 0; y < scr_tiles_h; y++) {
        for (int x = 0; x < scr_tiles_w; x++) {
            int map_idx = y * MAP_WIDTH + x;

            if (x == 0 || x == (scr_tiles_w - 1) || y == 0)
                BG_MAP[map_idx] = TILE_WALL;

            else if (y == 3 || y == 4)
                BG_MAP[map_idx] = TILE_BRICK1;

            else if (y == 5 || y == 6)
                BG_MAP[map_idx] = TILE_BRICK2;
        }
    }

    int pad_x = PAD_START_X;
    int pad_y = PAD_START_Y;
    
    int ball_x = BALL_START_X;
    int ball_y = BALL_START_Y;
    
    int ball_dx = BALL_SPEED_X;
    int ball_dy = -BALL_SPEED_Y;


    while (1) {
        while (PPU_STATE(*CTRL) != STATE_VBLANK);

        u64 keys = *KEYINP;
        if (keys & KEY_LEFT)  pad_x -= PAD_SPEED;
        if (keys & KEY_RIGHT) pad_x += PAD_SPEED;

        if (pad_x < WALL_WIDTH) 
            pad_x = WALL_WIDTH;

        if (pad_x > SCR_W - WALL_WIDTH - PAD_W) 
            pad_x = SCR_W - WALL_WIDTH - PAD_W;


        ball_x += ball_dx;
        ball_y += ball_dy;

        if (ball_x <= WALL_WIDTH) { 
            ball_dx = -ball_dx;
            ball_x  = WALL_WIDTH;
            ball_x      = WALL_WIDTH;
        }
        if (ball_x >= SCR_W - WALL_WIDTH - BALL_SIZE) { 
            ball_dx = -ball_dx;
            ball_x  = SCR_W - WALL_WIDTH - BALL_SIZE;
            ball_x      = ball_x;
        }
        if (ball_y <= WALL_WIDTH) { 
            ball_dy = -ball_dy;
            ball_y  = WALL_WIDTH;
            ball_y      = WALL_WIDTH;
        }

        if (ball_y > SCR_H) {
            ball_x  = BALL_START_X;
            ball_y  = BALL_START_Y;
            ball_dy = -BALL_SPEED_Y;
            ball_dx = BALL_SPEED_X;
        }

        if (ball_dy > 0 && ball_y + BALL_SIZE >= pad_y && ball_y <= pad_y + PAD_H) {
            if (ball_x + BALL_SIZE >= pad_x && ball_x <= pad_x + PAD_W) {
                ball_dy = -ball_dy;

                ball_dx = (ball_dx > 0) ? BALL_SPEED_X : -BALL_SPEED_X;
            }
        }

        int cx = ball_x + (BALL_SIZE / 2);
        int cy = ball_y + (BALL_SIZE / 2);
        int tx = cx / TILE_SIZE;
        int ty = cy / TILE_SIZE;
        int map_idx = ty * MAP_WIDTH + tx;

        u8 hit_tile = BG_MAP[map_idx];

        if (hit_tile == TILE_BRICK1 || hit_tile == TILE_BRICK2) {
            BG_MAP[map_idx] = 0;
            ball_dy = -ball_dy;
        }

        for (int i = 0; i < PAD_SPRITES; i++)
            set_oam_attr(i, pad_x + (i * TILE_SIZE), pad_y, TILE_PAD);

        set_oam_attr(3, ball_x, ball_y, TILE_BALL);

        while (PPU_STATE(*CTRL) == STATE_VBLANK);
    }
    
    return 0;
}