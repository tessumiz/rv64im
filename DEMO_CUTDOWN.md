MMU, bursts, early-aborts, etc. have been neutered for the sake
of the demo; correctness over features/performance.

These are the temporary compromises made:


1. MMU is neutered; only BARE mode works now

2. IFU/DCU doesn't exist; instead, caches have been instantiated
   directly inside IF and MEM.

2. Instead of impl bursts, the quickest way to get this working is
   to widen the main BRAM itself to 512 bits.

3. Interconnect is as primitive as it could get.

4. PMP isn't present; all necessary behaviours are hardcoded (PMA)

5. muldiv scoreboarding was disabled; mul is unpipelined as of now,
   and div doesn't have early exits

6. No fence instrs


>> The MMU design currently is substantial, but buggy and unverified.
   Getting everything together is going to take another month or so.