#include "types.h"


#define KEYINP (*(volatile u64*)0x04000000)
#define CTRL   (*(volatile u64*)0x04000008)

int main(void)
{
    while (1) {
        while ((CTRL & (1ULL << 32)) == 0)
            ;

        u64 keys = KEYINP;

        CTRL = (keys & 0xFFFF) << 16;

        while ((CTRL & (1ULL << 32)) != 0)
            ;
    }

    return 0;
}