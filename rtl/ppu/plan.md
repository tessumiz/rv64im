Demo: A short vertical slice of a castle level from supertux


>> MMIO starts at 0x0400_0000, so all the addrs below would be offsets from this.
   (0000-0007 is KEYINP)

>> Scrolls assume +ve offset starting from bot-left

* BG_SCROLL :  8B,  (0008 to 000F),  [Y: 4B, X: 4B]

* VBLANK : 8B (check LSB),  (0010 to 0017)

* PALETTE :  256 colors, RGB555,  512B,  (0200 to 03FF)

* BG : 64x64, 1B tile ids,  4KB,  (1000 to 1FFF)
  (will add more BG layers later)

* TILERAM : 16x16, 8bpp,  16KB (256B/tile => 64 tiles),  (2000 to 5FFF)
  (no metatiles for now)

* OAM : <to be decided...>

* FRM_BUFF : 320x240, RGB555, 150KB,  (0x0401_0000 to 0x0403_57FF)



>> Not going to use double-buffering for the MVP