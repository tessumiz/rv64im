# 1. Cache read + TLB lookup (when IDLE and !busy)

(same as IFU...)



# 2. Cache lookup + fault-chk + MMIO-routing  (when TLB ready or BARE)

* Cache tag addr_top if MODE is BARE else TLB-out
* TLB_FAULT_CHECK if !BARE else TLB_IDLE

* PMP fault       => abort cache + tlb
* pg fault / MMIO => abort cache  (ONLY for uncacheable MMIO, unlike ROM)
* Cache miss      => only fill if !(abort | stall). Wait for BRAM if busy.


>> Abort:

- filling    : wait till txn ends and discard rsp fills
- fill req   : abort the req
- tlb to ptw : abort signal passed down to ptw, which uses the above rules to end the txn

>> The only side-effect posible in IFU is A being set, which doesn't affect correctness;
   just a minor performance penalty.



# 3. Cache read / MMIO

* If !MMIO, read data and de-assert flush on IF/ID, as well as stall on PC.

* Else, proceed with MMIO op (refer below).

>> If at any point anyone faults, carry over exc_t to ID. Let the PC + IFU stall till a
   later stage flushes it.



# - br-taken / CSR-flush / DCU-fault / IRQ / exc

* Abort cache + TLB (+ PTW if TLB is waiting for it) IFF it isn't being flushed.



# Fence

...