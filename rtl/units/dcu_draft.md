# 1. Cache read + TLB lookup

(same as IFU...)



# 2. Cache lookup + fault-chk + MMIO-routing

(same...)


>> Abort:

Same, plus:

- evicting   : wait till txn ends
- evict req  : abort the req itself if possible. No correctness issues since evicts
               precede fills

>> Abort mandates that all deferred lru updates, shall be aborted. This is just a perf
   issue, not a correctness one...

>> The D bit can be set during a tlb miss and a walk. Another issue where the side-effect
   marks a speculative dirty bit is when in stage 3 the tlb is doing an evict, while the
   cache needs to fill/evict. I am deciding to let the cache be favoured in such a case
   (internal arbitration), so that the D-bit set only happens after the cache succeeds.

   I'm currently ignoring the case where the tlb evict itself fails (access fault in pg
   table walker).

>> If a cache eviction is under progress currently, abort immediately after the txn; the
   "evicted line" would still be there in the cache.



# 3. Cache read / MMIO

* If !MMIO, read data and de-assert flush on MEM/WB, as well as stall on the previous
  stages.

* Else, proceed with MMIO op (refer below).

>> If at any point anyone faults, handle the fault right in the next cycle.



# - IRQ (the only external way DCU can be invalidated)

* Abort cache + PTw *only if* changes haven't been made; cache writes, TLB D evicts, MMIO
  which has side-effects. Note what isn't present; cache evicts and fills.

* If amidst an irreversible txn (a change), wait till the current instr ends, wait for the
  next non-bubble and only then take the interrupt. If an mem exc occurs in this window,
  prioritize the fault.

* I can wait on txns to end, as riscv guarantees it latches un-acked irqs.

* MMIO txns DON'T disable IRQ automatically; unset MIE manually in software instead...


# Fence

FENCE: For our in-order scalar case, this is a NOP.

FENCE.I: Must the DCU just write-back dirty lines, or must it clear the dcu too? dcache's flush
in my case both clears as well as writes back. After that, it asserts both flush on all prior
stages as well as icache_flush on IFU (refer ifu_design.md for the difference)