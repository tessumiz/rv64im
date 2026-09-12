## BUGS / INCOMPLETE STUFF
- [ ] (later) have a review of all mem modules (not just correctness...)


## IMMEDIATE
- [ ] tweak the invariant parameteres of every cache/tlb (including pwc and plrus)

- [ ] synth bugs in bram access; flatten ways using a for (or generate)  (???)

- [ ] fixing muldiv and filling in the mul and div circuits

- [ ] ifu/dcu/ram-arbiter

- [ ] basic bimodal br-pred


## PENDING
- [ ] basic interconnect, mmio for key inputs


## LATER
- [ ] reducing interrupt latency on bubbles / mem ops; early exits and fwd-ing pc

- [ ] gshare and DMA

- [ ] document that our OS is not going to randomize page alloc; hence keeping the 16-CAM
      pwc reasonable. Maybe even tweak it down to 8-CAM...


## PERHAPS
- [ ] make set_assoc optionally split tag/data into two arrays and separate lookups; trading
      a cycle for smaller cmp_in ffs as well as reducing power, a really good choice.
      Making this parametric would be hard I suppose...

- [ ] CSR fwd-ing (which means haz-det too)

- [ ] C extension


## ALMOST NEVER
- [ ] F extension