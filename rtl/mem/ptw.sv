import mem_pkg::*;
import zicsr_pkg::*;


// supports sv39, sv48 and sv57
module ptw(
    input clk,
    input rst,

    input logic valid,
    input vpn_t vaddr,
    input logic w, x, u,

    mmu_ctx_if.ptw_view mmu_ctx,
    dram_if.master      ram_bus,

    output logic        ready,
    output logic [43:0] ppn_out,
    output logic page_fault, access_fault
);

    ptw_fsm_t    state;
    ptw_lvl_t    level;

    logic [3:0]  mode;
    assign mode = mmu_ctx.mode;

    ptw_lvl_t    start_level;
    assign start_level =
        (mode == SATP_SV57) ? PTW_LVL4 :
        (mode == SATP_SV48) ? PTW_LVL3 :
        (mode == SATP_SV39) ? PTW_LVL2 :
                              PTW_LVL0;


    logic [55:12] curr_root;  // ppn (4KiB aligned)
    logic [55:3]  curr_addr;  // 8B aligned

    pte_t    entry;  // pte at (root + offset) [latch]
    pte_t    pte;   // [comb]
    
    logic [43:0] pte_ppn;
    assign pte_ppn = { pte.ppn4, pte.ppn3, pte.ppn2, pte.ppn1, pte.ppn0 };

    logic    is_leaf;
    logic    misaligned_superpage;

    
    logic    r;  // is_read
    logic    rmw_A_D;  // Access / Dirty write


    logic [8:0] vpn4, vpn3, vpn2, vpn1, vpn0;


    logic        pwc_hit;
    logic [43:0] pwc_lvl1_root;

    pwc_tag_t pwc_tag;

    pwc u_pwc (
        .clk (clk),
        .rst (rst),  // sfence.vma asserts this...

        .pwc_in (pwc_tag),

        .hit       (pwc_hit),
        .lvl1_root (pwc_lvl1_root),

        .w_en      (
            (state == PTW_CHECK_PTE) &&
            (level == PTW_LVL2) &&
            !(page_fault || is_leaf)
        ),
        .w_root    (pte_ppn)
    );


    always_comb begin
        vpn4 = vaddr.vpn4;
        vpn3 = vaddr.vpn3;
        vpn2 = vaddr.vpn2;
        vpn1 = vaddr.vpn1;
        vpn0 = vaddr.vpn0;

        pwc_tag = '{
            vpn4: vpn4, vpn3: vpn3, vpn2: vpn2,
            asid: mmu_ctx.asid, mode: mode[1:0],
            default: 0
        };

        r  = !(w | x);

        if (state == PTW_READ && !access_fault && ram_bus.ready)
            pte = ram_bus.r_data;
        else if (state == PTW_IDLE)
            pte = 0;
        else
            pte = entry;

        ram_bus.addr = {curr_addr, 3'b0};
        ram_bus.r_en = (state == PTW_CHECK_PWC && !pwc_hit) ||
                       (state == PTW_CHECK_PTE && !page_fault && !is_leaf);


        is_leaf = pte.r || pte.w || pte.x;

        // no error is thrown for any combination of A and D if not a leaf
        rmw_A_D = is_leaf && (!pte.a || (w && !pte.d)) && !(page_fault || access_fault);

        /* 'ready' being a pulse, I would have to latch it if I were to dispatch
        the A/D write one cycle earlier, which has poor ROI... */
        ram_bus.w_en   = (state == PTW_WRITE) && rmw_A_D;
        ram_bus.w_data = pte | pte_t'{ a: 1, d: w, default: 0 };


        curr_addr  = { curr_root,
            (level == PTW_LVL4) ? vpn4 :
            (level == PTW_LVL3) ? vpn3 :
            (level == PTW_LVL2) ? vpn2 :
            (level == PTW_LVL1) ? vpn1 :
                                  vpn0
        };

        ppn_out = pte_ppn;
        unique case (level)
            PTW_LVL4: ppn_out[35:0] = { vpn3, vpn2, vpn1, vpn0 };
            PTW_LVL3: ppn_out[26:0] = { vpn2, vpn1, vpn0 };
            PTW_LVL2: ppn_out[17:0] = { vpn1, vpn0 };
            PTW_LVL1: ppn_out[8:0]  = vpn0;
            PTW_LVL0: ;
        endcase


        misaligned_superpage = is_leaf && (
            (level == PTW_LVL4 && { pte.ppn3, pte.ppn2, pte.ppn1, pte.ppn0 } != 0) ||
            (level == PTW_LVL3 && { pte.ppn2, pte.ppn1, pte.ppn0 } != 0) ||
            (level == PTW_LVL2 && { pte.ppn1, pte.ppn0 } != 0) ||
            (level == PTW_LVL1 && pte.ppn0 != 0)
        );

        page_fault = (state == PTW_CHECK_PTE) && (
            !pte.v ||
            pte[63:54] != 0 ||    // reserved
            (!pte.r && pte.w) ||  // write-only memory is illegal
            ((u && !pte.u) || (!u && pte.u && !mmu_ctx.SUM)) ||  // allow U reads for sv iff SUM

            (!pte.w  && w) ||
            (!pte.x  && x) ||
            (!pte.r  && r && !(pte.x && mmu_ctx.MXR)) ||  // allow R=0 reads iff X and MXR

            misaligned_superpage
        );

        access_fault = (ram_bus.ready && ram_bus.access_fault);
        
        // doesn't mask with faults!
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
                        /* (input + curr_addr-mux + r_en-hold) creates a critical path
                        otherwise not an issue for subsequent level walks as the latency
                        is just (level-tCQ + curr_addr-mux + r_en-hold)
                        
                        Instead of wasting a clock cycle with a lame state like PTW_SETUP,
                        I've used the extra time for checking a pwc. Yeah, might be overkill
                        but it doesn't affect clk freq */

                        state     <= PTW_CHECK_PWC;
                        level     <= start_level;
                        curr_root <= mmu_ctx.root_ppn;
                    end
                end

                PTW_CHECK_PWC : begin
                    if (pwc_hit) begin
                        level     <= PTW_LVL1;
                        curr_root <= pwc_lvl1_root;
                    end

                    state <= PTW_READ;
                end

                PTW_READ : begin
                    if (access_fault)
                        state <= PTW_IDLE;

                    else if (ram_bus.ready) begin
                        entry <= ram_bus.r_data;
                        state <= PTW_CHECK_PTE;
                    end
                end

                /* Broke a critical path favouring increased latency over decreased clk freq.
                The critical path if PTE check was done in PTW_READ is especially nasty given
                the bus latencies bw ptw and dram */
                PTW_CHECK_PTE : begin
                    if (page_fault)
                        state <= PTW_IDLE;

                    else if (rmw_A_D)
                        state <= PTW_WRITE;

                    else if (is_leaf)
                        state <= PTW_IDLE;

                    else begin
                        state <= PTW_READ;

                        level <= (level == PTW_LVL4) ? PTW_LVL3 :
                                 (level == PTW_LVL3) ? PTW_LVL2 :
                                 (level == PTW_LVL2) ? PTW_LVL1 :
                                 PTW_LVL0;

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
