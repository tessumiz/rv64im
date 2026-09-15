#include <stdint.h>

#define CTRL    (*(volatile uint64_t *)0x04000008)
#define PALETTE ((volatile uint16_t *)0x04000200)
#define BG      ((volatile uint8_t  *)0x04001000)

int main(void)
{
    CTRL = 0;

    PALETTE[0] = 0x001F;
    PALETTE[1] = 0x7C00;

    for (int i = 0; i < 64 * 64; i++)
        BG[i] = 1;

    while (1)
        ;
}