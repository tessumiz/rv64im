module ptw import mem_pkg::*; (
    input clk,
    input rst,

    input logic     valid,
    input vpn_t     vaddr,
    input logic     w, x, u,  // set w=1 for mark_dirty evict op from tlb
    input mmu_ctx_t mmu_ctx,

    gen_mem_if.master ram_bus,

    output logic ready,
    output pte_t pte_out,

    output logic is_mega,
    output logic is_giga,

    output logic page_fault,
    output logic access_fault
);

    ptw_fsm_t    state;
    ptw_lvl_t    level;

    logic [55:12] curr_root;  // ppn (4KiB aligned)
    logic [55:3]  curr_addr;  // 8B aligned

    pte_t    pte;  // pte at (root + offset) [ff]

    logic [43:0] pte_ppn;
    assign pte_ppn = { pte.ppn2, pte.ppn1, pte.ppn0 };

    logic    is_leaf;
    logic    misaligned_superpage;

    
    logic    r;  // is_read
    logic    rmw_A_D;  // Access / Dirty write


    logic [8:0] vpn2, vpn1, vpn0;


    always_comb begin
        vpn2 = vaddr.vpn2;
        vpn1 = vaddr.vpn1;
        vpn0 = vaddr.vpn0;

        r = !(w | x);

        ram_bus.addr = {curr_addr, 3'b0};

        /*
        Fix; pre-emptive read (as well as write) requests were purged because it
        makes the pipeline more complicated (fwd-ing, latches, larger comb circuits),
        just to save 1 cycle before a dram read...
        */
        ram_bus.r_en = (state == PTW_READ);


        is_leaf = pte.r || pte.w || pte.x;

        // no error is thrown for any combination of A and D if not a leaf
        rmw_A_D = is_leaf && (!pte.a || (w && !pte.d)) && !(page_fault || access_fault);


        /*
        "ready" being a pulse, I would have to latch it if I were to dispatch
        the A/D write one cycle earlier, which has poor ROI. At the cost of a single
        cycle, I can use "state == PTW_WRITE" as a latched, persistent signal
        */
        ram_bus.w_en   = (state == PTW_WRITE);
        ram_bus.w_data = pte | pte_t'{ a: 1, d: w, default: 0 };


        curr_addr  = { curr_root,
            (level == PTW_LVL2) ? vpn2 :
            (level == PTW_LVL1) ? vpn1 : vpn0
        };

        pte_out = pte;


        misaligned_superpage = (
            (level == PTW_LVL2 && { pte.ppn1, pte.ppn0 } != 0) ||
            (level == PTW_LVL1 && pte.ppn0 != 0)
        );

        page_fault = (state == PTW_CHECK_PTE) & (
            !pte.v |
            pte[63:54] != 0 |    // reserved
            (!pte.r & pte.w) |  // write-only memory is illegal

            (is_leaf & (
                (!pte.w  & w) |
                (!pte.x  & x) |
                (!pte.r  & r & !(pte.x & mmu_ctx.MXR)) |  // allow R=0 reads iff X and MXR
                ((u & !pte.u) | (!u & pte.u & (!mmu_ctx.SUM | x))) |  // allow U rw for sv iff SUM
                misaligned_superpage
            )) |

            (!is_leaf & (pte.d | pte.a | pte.u | (level == PTW_LVL0)))
        );

        is_mega = (level == PTW_LVL1);
        is_giga = (level == PTW_LVL2);

        access_fault = (ram_bus.ready && ram_bus.access_fault);

        // I can't assert ready when A/D is being written back; these might fault (to be considered
        // in the future), so I can't let the master move on without receiving this txn's status.
        ready = (state == PTW_CHECK_PTE && is_leaf && !rmw_A_D) || 
                (state == PTW_WRITE && ram_bus.ready);
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            state <= PTW_IDLE;
        end
        else begin
            unique case (state)
                PTW_IDLE : begin
                    if (valid) begin
                        // crit path analysis deferred till the asic route opens...

                        state     <= PTW_READ;
                        level     <= PTW_LVL2;
                        curr_root <= mmu_ctx.root_ppn;
                        pte       <= '0;
                    end
                end

                PTW_READ : begin
                    if (access_fault)
                        state <= PTW_IDLE;

                    else if (ram_bus.ready) begin
                        pte   <= ram_bus.r_data;
                        state <= PTW_CHECK_PTE;
                    end
                end

                /*
                Broke a critical path favouring increased latency over decreased clk freq.
                The critical path if PTE check was done in PTW_READ is especially nasty given
                the bus latencies bw ptw and dram.

                Previously had a fwd-mux for ram_bus.r_data, removed it...

                * P.S. I'm keeping all this perf work until the asic synth. Rn, correctness is
                  the priority (what I ditched at the start for assumed "performance")
                */
                PTW_CHECK_PTE : begin
                    if (page_fault)
                        state <= PTW_IDLE;

                    else if (rmw_A_D)
                        state <= PTW_WRITE;

                    else if (is_leaf)
                        state <= PTW_IDLE;

                    else begin
                        state <= PTW_READ;
                        level <= (level == PTW_LVL2) ? PTW_LVL1 : PTW_LVL0;
                        curr_root <= pte_ppn;
                    end
                end

                PTW_WRITE : begin
                    if (access_fault || ram_bus.ready)
                        state <= PTW_IDLE;
                end
            endcase
        end
    end
endmodule
