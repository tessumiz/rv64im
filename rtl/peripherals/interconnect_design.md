## Arbitration

ROM    - IFU [x]
BRAM   - DCU [rw] > PTW [rw] > IFU [x] ; IFU reads have a greater chance of invalidation

KEYINP - DCU [r]
OAM/.. - PPU [r] > DCU [rw] ; OAM/BG/PALETTE/TILEMAP
VBUFF  - PPU [rw]  ;  framebuffer


## Ownership

BRAM   - 8-beat bursts / single-write completion
OAM/.. - double-buffering; no contention


## PMA

ROM    -  cacheable + read-only
KEYINP - !cacheable + read-only


## Mappings

To prevent comb delay (and save gates) in stage 2, NAPOT is the only PMP present.

ROM : 0001_0000 - 0001_FFFF
(WIP; yet to be decided...)