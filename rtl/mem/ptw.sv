    import mem_pkg::*;


    // sv39
    module ptw(
        input  clk,
        input rst,

        input logic        valid,
        input logic [43:0] root,
        input logic [63:0] vaddr,

        input logic        is_write,
        input logic        is_exec,
        input logic        u_mode,

        dram_if.master bus,

        output logic        ready,
        output logic [43:0] ppn,
        output logic page_fault, access_fault
    );

        ptw_fsm_t    state;
        ptw_lvl_t    level;

        logic [2:0][8:0] v_ppn;

        // riscv guarantees 4KiB alignment for curr_root, and 8B for curr_addr
        logic [55:12] curr_root;
        logic [55:3]  curr_addr;

        logic         is_mega_pg, is_giga_pg;
        logic         is_leaf;

        sv39_pte_t    entry;  // pte at (root + offset) [latch]
        sv39_pte_t    pte;  // [comb]

        logic         rmw;
        sv39_pte_t    AD_mask;  // Access / Dirty
        logic         is_read;


        always_comb begin
            v_ppn[2] = vaddr[38:30];
            v_ppn[1] = vaddr[29:21];
            v_ppn[0] = vaddr[20:12];

            is_read  = !(is_write || is_exec);


            pte = (state == PTW_READ && !access_fault && bus.ready) ? bus.r_data : entry;

            bus.addr = {curr_addr, 3'b0};
            bus.r_en = (state == PTW_WALK) && !(bus.w_en || page_fault || is_leaf);


            // A and D bits handled in hardware...
            is_leaf = pte.r || pte.w || pte.x;

            rmw = is_leaf && (!pte.a || (is_write && !pte.d));
            bus.w_en = (state == PTW_WRITE) && rmw;

            AD_mask = '{ a: 1'b1,  d: is_write,  default: 0 };
            bus.w_data = pte | AD_mask;


            curr_addr = {curr_root, (
                (level == PTW_LVL2) ? v_ppn[2] :
                (level == PTW_LVL1) ? v_ppn[1] :
                v_ppn[0]
            )};

            is_giga_pg = (level == PTW_LVL2 && pte.ppn1 == 0 && pte.ppn0 == 0);
            is_mega_pg = (level == PTW_LVL1 && pte.ppn0 == 0);

            page_fault = (state == PTW_WALK && level != PTW_LVL2) && (
                !pte.v ||
                pte[63:54] == 0 ||    // reserved bits, riscv standard...
                (!pte.r && pte.w) ||  // XOM exists for security; X^W is an OS-only feature...
                (pte.u ^ u_mode)  ||

                (!pte.w  && is_write) ||
                (!pte.x  && is_exec)  ||
                (!pte.r  && is_read)  ||

                (is_leaf && (level != PTW_LVL0) && !(is_mega_pg || is_giga_pg))
            );

            access_fault = (bus.ready && bus.access_fault);

            ppn = { pte.ppn2, (
                is_giga_pg ? { v_ppn[1], v_ppn[0] } :
                is_mega_pg ? { pte.ppn1, v_ppn[0] } :
                            { pte.ppn1, pte.ppn0 }
            )};

            ready = (state != PTW_IDLE) && is_leaf;
        end


        always_ff @(posedge clk) begin
            if (rst) begin
                state <= PTW_IDLE;
            end
            else begin
                unique case (state)
                    PTW_IDLE : begin
                        if (valid) begin
                            state     <= PTW_WALK;
                            level     <= PTW_LVL2;
                            curr_root <= root;
                            entry     <= 0;
                        end
                    end

                    PTW_READ : begin
                        if (access_fault) begin
                            state <= PTW_IDLE;
                            level <= PTW_LVL2;
                        end
                        else if (bus.ready) begin
                            entry <= bus.r_data;

                            if (rmw) begin
                                state <= PTW_WRITE;
                            end
                            else begin
                                state <= PTW_WALK;
                                level <= (level == PTW_LVL2) ? PTW_LVL1 : PTW_LVL0;

                                curr_root <= { pte.ppn2, pte.ppn1, pte.ppn0 };
                            end
                        end
                    end

                    PTW_WRITE : begin
                        if (access_fault) begin
                            state <= PTW_IDLE;
                            level <= PTW_LVL2;
                        end
                        else if (bus.ready) begin
                            state <= PTW_IDLE;
                            level <= PTW_LVL2;
                        end
                    end

                    PTW_WALK : begin
                        if (page_fault || is_leaf) begin
                            state <= PTW_IDLE;
                            level <= PTW_LVL2;
                        end
                        else
                            state <= PTW_READ;
                    end
                endcase
            end
        end
    endmodule
