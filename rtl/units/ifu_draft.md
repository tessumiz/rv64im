# 1. Cache read + TLB lookup (when IDLE and !busy)

* TLB enable iff MODE isn't BARE

* TLB miss  => stall cache
* PTW fault => abort cache

>> if TLB is busy (on-going flush, pending D writes), stall

>> both i/d caches are VIPT



# 2. Cache lookup + fault-chk + MMIO-routing  (when TLB ready or BARE)

* Cache tag addr_top if MODE is BARE else TLB-out
* TLB_FAULT_CHECK if !BARE else TLB_IDLE

* PMP fault       => abort cache + tlb
* pg fault / MMIO => abort cache  (ONLY for uncacheable MMIO, unlike ROM)
* Cache miss      => only fill if !(abort | stall). Wait for BRAM if busy.


>> Abort:

- filling    : wait till the current beat ends, and mark the whole line as invalid
- fill req   : abort the req
- tlb to ptw : abort signal passed down to ptw, which uses the above rules to end the txn

>> The only side-effect posible in IFU is A being set, which doesn't affect correctness;
   just a minor performance penalty.



# 3. Cache read / MMIO

* If !MMIO, read data and de-assert flush on IF/ID, as well as stall on PC.

* Else, proceed with MMIO op (refer below).

>> If at any point anyone faults, wait for any pending txn to close, then carry over exc_t
   to ID. Let the PC + IFU stall till a later stage flushes it; no point in proceeding.



# - br-taken / CSR-flush / DCU-fault / IRQ / exc

* Routed through the IFU's flush signal; abort cache + TLB (+ PTW if TLB is waiting for it).

* Note; "flush" here does NOT mean flushing the icache; that happens through a separate
  icache_flush signal (reserved for fence.I).
  Consecutive icache_flushes can never occur in our design.



# Fence

* FENCE.I asserts flush on icache (icache_flush sig will be asserted from MEM stage)
* SFENCE.VMA asserts rst on itlb; no wb (as evicts are on-the-spot), single-cycle clr
  (similarly, itlb_flush sig will be asserted from MEM stage)
