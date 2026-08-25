## BUGS / INCOMPLETE STUFF
- [ ] tlb.sv has been implemented rather quick and fragile; scrutinize it

- [ ] make tlb as well as pwc support superpages

- [ ] integrate eviction wb from tlb on ptw

- [ ] tweak the invariant parameteres of every cache/tlb (including pwc and plrus)

- [ ] separate rst from flush; extend the fsms to wb all pending dirty data


## IMMEDIATE
- [ ] total interface overhaul; use structs for req/rsp rather than be forced to use
      unreadable prefix macros everywhere to set intfs...

- [ ] making ifu + dcu + PMA, connecting ifu + dcu to the ptw (using an arbiter),
      handling faults (check NEXT_DRAFT.md)

- [ ] synth bugs in bram access; flatten ways using a for (or generate)  (???)


## PENDING
- [ ] crossbar and peripherals

- [ ] fixing imuldiv


## LATER
- [ ] reducing interrupt latency on bubbles / mem ops; early exits and fwd-ing pc

- [ ] br-pred and DMA

- [ ] filling in the mul and div circuits

- [ ] separate clocks for the appropriate units

- [ ] document that our OS is not going to randomize page alloc; hence keeping the 16-CAM
      pwc reasonable. Maybe even tweak it down to 8-CAM...


## PERHAPS
- [ ] make set_assoc optionally split tag/data into two arrays and separate lookups; trading
      a cycle for smaller cmp_in ffs as well as reducing power, a really good choice.
      Making this parametric would be hard I suppose...


## ALMOST NEVER
- [ ] CSR fwd-ing (which means haz-det too)
- [ ] C and F extensions