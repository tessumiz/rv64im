#EX_MEM_REG
T: clk, rst_n, stall, flush
L: vpn, off[12], ...
R: vpn, off[12], v, w, ...


#DCACHE
T: stall_t, flush_t, miu_bus
L: s1_v, s1_off[12]
B: s2_v, s2_ppn[22], s3_v, s3_w, w_data, w_mask
R: r_data


@DTLB
L: v, vpn[]
R: ppn[22], pg_fault, acc_fault


#DCU1
T: clk, rst_n, stall, flush
L: tags, ppn[22], exc, ...
R: tags, ppn[22], 