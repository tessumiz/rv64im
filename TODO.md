## 1
- [ ] abort whilst evicting

- [ ] gate all ready/busy sigs with faults



## 2
- [ ] flush must only unset ctrl.valid and exc.valid; power optimization

- [ ] Propagate page/access faults from RAM/PTW to the master, or let the ifu/dcu
      units handle it separately, since the transaction itself is separate? Propagation
      seems unnecessary...



## 3
- [ ] reducing interrupt latency on bubbles / mem ops; early exits and fwd-ing pc

- [ ] gshare and DMA

- [ ] document that our OS is not going to randomize page alloc; hence keeping the 16-CAM
      pwc reasonable. Maybe even tweak it down to 8-CAM...

- [*] signals which latch vs pulse


## 4
- [ ] make set_assoc optionally split tag/data into two arrays and separate lookups; trading
      a cycle for smaller cmp_in ffs as well as reducing power, a really good choice.
      Making this parametric would be hard I suppose...

- [ ] CSR fwd-ing (which means haz-det too)

- [ ] C extension


## NEVER
- [ ] F extension