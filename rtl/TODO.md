## BUGS / INCOMPLETE STUFF
- [ ] Propagate page/access faults from RAM/PTW to the master, or let the ifu/dcu
      units handle it separately, since the transaction itself is separate? Propagation
      seems unnecessary...

- [ ] Cache line evictions needing the same 8-beat bursts

- [ ] superpages in pwc; consider several cases and judge the ROI since pwc is tiny


## IMMEDIATE
- [ ] basic bimodal br-pred

- [ ] fixing muldiv


## PENDING
- [ ] tweak the invariant parameteres of every cache/tlb (including pwc and plrus)

- [ ] synth bugs in bram access; flatten ways using a for (or generate)  (???)

- [ ] doing everything that got stripped for the demo



## LATER
- [ ] reducing interrupt latency on bubbles / mem ops; early exits and fwd-ing pc

- [ ] gshare and DMA

- [ ] document that our OS is not going to randomize page alloc; hence keeping the 16-CAM
      pwc reasonable. Maybe even tweak it down to 8-CAM...

- [*] signals which latch vs pulse


## PERHAPS
- [ ] make set_assoc optionally split tag/data into two arrays and separate lookups; trading
      a cycle for smaller cmp_in ffs as well as reducing power, a really good choice.
      Making this parametric would be hard I suppose...

- [ ] CSR fwd-ing (which means haz-det too)

- [ ] C extension


## ALMOST NEVER
- [ ] F extension