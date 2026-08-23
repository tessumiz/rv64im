## IMMEDIATE
- [ ] creating the miu and connecting it with mem_stage, with error handling

- [ ] intf overhaul; generic struct passing, axi4-lite, ditching my custom busy/ready
      protocol for the standard; valid/ready

- [ ] synth bugs in bram access; flatten ways using a for (or generate)

- [ ] Why VIPT at all? If the crit path bw tlb and cache isn't broken down, it saves
      2 cycles at the expense of reduced operational freq. Pipelining it yields a net
      latency reduction of 1 cycle. Consider doubling way-size to 8KB, halving ways to
      4 and moving on to a PIPT cache.


## PENDING
- [ ] peripherals; PLIC, CLINT, UART
- [ ] fixing imuldiv
- [ ] separate clocks for the appropriate units


## LATER
- [ ] reducing interrupt latency on bubbles / mem ops; early exits and fwd-ing pc
- [ ] br-pred and DMA
- [ ] filling in the mul and div circuits


## PERHAPS
- [ ] full-duplex to half-duplex to shrink buses


## ALMOST NEVER
- [ ] CSR fwd-ing (which means haz-det too)
- [ ] C and F extensions