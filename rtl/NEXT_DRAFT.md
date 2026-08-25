Rough; think through this once again before finalizing!


### Building the IFU + DCU (right until our crossbar milestone)


>> Pipeline IFU / DCU later (3 stages). Rn, have a basic fsm.

>> Add PMA unit (think of restricting IFU's peripiheral access *later*)

>> Add abort pins to caches/tlbs/ptw. Adding it to ptw requires
caution; the DRAM req if pending must be acked...


## IFU

1. An appropriate slice of PC goes to cache, tlb, pma paralelly:

Cache: reads bram
TLB:   reads ff + selects line
PMA:   emits an is_illegal sig


2. If (descending priority):

(a) is_illegal is 1, assert abort for cache/tlb
(b) tlb is a miss, stall cache till the ptw completes. If the ptw faults,
    abort all.

If no issues:

Cache: compares with tlb's ppn
TLB:   checks access legality
PMA:   emits an is_mmio sig

NOTE: Currently, mmio is decided to use the upper 4 bits of ppn


3. If:

(a) TLB illegal, abort
(b) is_mmio = 1, abort and begin another journey (to be decided...)
(c) the regular cache hit/miss behaviour


# Branches (including context switch)

Abort everything immediately. Since there is no staleness issue for IF stage,
the only thing to be aware of is acking DRAM during walks...

The same applies to faults raised by DCU too (think through this...)



## DCU

Just a few remarks:

1. Interrupt latency and staleness

Consider early abort during async interrupts *if* there hasn't been made any perm
changes; writes, fills, evicts, etc. Find a way to delay them as much as possible;
(maybe tie this to no. 3; buffering)


2. PTW backpressure

Stall both if ptw is busy; else, think of an optimal priority


3. Buffering evictions

Do this once you add a DMA. At that point, consider prefetching too.