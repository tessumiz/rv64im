import defs_pkg::*;
import zicsr_pkg::*;


module csr_file(
    input logic clk,
    input logic rst,

    input irq_t irq,

    csr_rw_if.slave   rw_bus,
    csr_trap_if.slave trap_bus,

    output logic [63:0] mepc_out,
    output logic [63:0] mtvec_out,

    output logic [63:0] stvec_out,
    output logic [63:0] sepc_out,

    output logic        take_mepc,
    output logic        take_mtvec,
    output logic        take_sepc,
    output logic        take_stvec,

    output logic [1:0] priv,
    output satp_t      satp_out

);

    logic [63:0] mstatus;
    logic [63:0] mtvec;
    logic [63:0] mepc;
    logic [63:0] mcause;
    logic [63:0] mtval;
    logic [63:0] mscratch;

    logic [63:0] stvec;
    logic [63:0] sepc;
    logic [63:0] scause;
    logic [63:0] stval;
    logic [63:0] sscratch;

    logic [63:0] mie;
    logic [63:0] mip;  // hardwired; pseudo-ff...
    logic [63:0] medeleg;
    logic [63:0] mideleg;

    logic [1:0]  priv_lvl;
    satp_t       satp;

    assign priv     = priv_lvl;
    assign satp_out = satp;


    // SOFTWARE RW
    logic [63:0] r_data;

    always_comb begin
        case (rw_bus.r_addr)
            CSR_MSTATUS:  r_data = mstatus;
            CSR_MTVEC:    r_data = mtvec;
            CSR_MEPC:     r_data = mepc;
            CSR_MCAUSE:   r_data = mcause;
            CSR_MTVAL:    r_data = mtval;
            CSR_MSCRATCH: r_data = mscratch;

            CSR_SSTATUS:  r_data = mstatus & MSTATUS_S_MASK;
            CSR_SEPC:     r_data = sepc;
            CSR_STVEC:    r_data = stvec;
            CSR_SCAUSE:   r_data = scause;
            CSR_STVAL:    r_data = stval;
            CSR_SSCRATCH: r_data = sscratch;

            CSR_MIE:      r_data = mie;
            CSR_MIP:      r_data = mip;
            CSR_MEDELEG:  r_data = medeleg;
            CSR_MIDELEG:  r_data = mideleg;

            CSR_SATP:     r_data = satp;

            default: r_data = '0;
        endcase

        mepc_out  = mepc;
        sepc_out  = sepc;

        rw_bus.r_data = r_data;
    end



    // INTERRUPTS
    logic [63:0] irq_act;
    logic [63:0] irq_cause;

    // metastability prevention; not guaranteed, but reduces chance...
    irq_t irq_ff1;
    irq_t irq_ff2;

    always_ff @(posedge clk) begin
        if (rst) begin
            irq_ff1 <= '0;
            irq_ff2 <= '0;
        end
        else begin
            irq_ff1 <= irq;
            irq_ff2 <= irq_ff1;
        end
    end

    always_comb begin
        mip = 0;
        mip[EXT_INT] = irq_ff2.ext_int;
        mip[TMR_INT] = irq_ff2.tmr_int;
        mip[SFT_INT] = irq_ff2.sft_int;

        irq_act = (mie & mip);

        irq_cause =
        {
            1'b1,
            63'(
                irq_act[EXT_INT] ? EXT_INT :
                irq_act[SFT_INT] ? SFT_INT :
                irq_act[TMR_INT] ? TMR_INT :
                63'b0
            )
        };
    end


    // TRAPS
    logic [63:0] cause;

    always_comb begin
        trap_bus.irq_pending = |irq_act & mstatus[MSTATUS_MIE];

        cause = trap_bus.take_exc ? trap_bus.cause :
                trap_bus.take_irq ? irq_cause : 0;
    end


    logic  deleg, trap;
    assign deleg =
        (priv_lvl < PRIV_M) && (
        (trap_bus.take_exc  && medeleg[cause]) ||
        (trap_bus.take_irq  && mideleg[cause])
    );

    assign trap = trap_bus.take_exc | trap_bus.take_irq;

    // can't place this inside the always_ff below...
    always_comb begin
        take_mtvec = 0;
        take_mepc  = 0;
        take_stvec = 0;
        take_sepc  = 0;

        if (trap) begin
            if (deleg) take_stvec = 1;
            else       take_mtvec = 1;
        end
        else if (trap_bus.take_mret) begin
            take_mepc = 1;
        end
        else if (trap_bus.take_sret) begin
            take_sepc = 1;
        end
    end

    // direct/vec mode tvec calc
    logic [61:0] m_base, s_base;
    logic [62:0] bare_cause;

    always_comb begin
        m_base = mtvec[63:2];
        s_base = stvec[63:2];
        
        bare_cause = cause[62:0];

        mtvec_out =
            (mtvec[1:0] == VEC_MODE && trap_bus.take_irq) ?
            {m_base, 2'b00} + ({1'b0, bare_cause} << 2) :
            {m_base, 2'b00};
        
        stvec_out =
            (stvec[1:0] == VEC_MODE && trap_bus.take_irq) ?
            {s_base, 2'b00} + ({1'b0, bare_cause} << 2) :
            {s_base, 2'b00};
    end

    logic [63:0] w_data;
    logic [3:0]  w_data_satp_mode;

    assign w_data = rw_bus.w_data;
    assign w_data_satp_mode = w_data[63:60];


    always_ff @(posedge clk) begin
        if (rst) begin
            mstatus <= 0;
            mtvec   <= 0;
            mepc    <= 0;
            mcause  <= 0;
            mtval   <= 0;
            mie     <= 0;

            sepc    <= 0;
            stvec   <= 0;

            priv_lvl <= PRIV_M;
        end
        else begin
            if (rw_bus.w_en) begin
                // can't be deferred to another always_ff.....
                unique case (rw_bus.w_addr)  // check's done in id, hence exhaustive
                    CSR_MSTATUS:  mstatus  <= w_data;
                    CSR_MTVEC:    mtvec    <= w_data;
                    CSR_MEPC:     mepc     <= w_data;
                    CSR_MCAUSE:   mcause   <= w_data;
                    CSR_MTVAL:    mtval    <= w_data;
                    CSR_MIE:      mie      <= w_data;
                    CSR_MSCRATCH: mscratch <= w_data;

                    CSR_SSTATUS:  mstatus  <= (w_data & MSTATUS_S_MASK) |
                                              (mstatus & ~MSTATUS_S_MASK);

                    CSR_SEPC:     sepc     <= w_data;
                    CSR_STVEC:    stvec    <= w_data;
                    CSR_SCAUSE:   scause   <= w_data;
                    CSR_STVAL:    stval    <= w_data;
                    CSR_SSCRATCH: sscratch <= w_data;

                    CSR_MEDELEG:  medeleg  <= w_data;
                    CSR_MIDELEG:  mideleg  <= w_data;

                    CSR_SATP: begin
                        if (w_data_satp_mode == SATP_SV39 || w_data_satp_mode == SATP_BARE)
                            satp <= w_data;
                    end
                endcase
            end

            if (trap) begin
                if (!deleg) begin
                    mstatus[MSTATUS_MPP_H : MSTATUS_MPP_L] <= priv_lvl;
                    priv_lvl <= PRIV_M;

                    mstatus[MSTATUS_MPIE] <= mstatus[MSTATUS_MIE];
                    mstatus[MSTATUS_MIE]  <= 0;

                    mepc   <= trap_bus.pc;
                    mcause <= cause;
                    mtval  <= trap_bus.take_exc ? trap_bus.tval : 0;
                end
                else begin
                    mstatus[MSTATUS_SPP] <= priv_lvl[0];
                    priv_lvl <= PRIV_S;

                    mstatus[MSTATUS_SPIE] <= mstatus[MSTATUS_SIE];
                    mstatus[MSTATUS_SIE]  <= 0;

                    sepc   <= trap_bus.pc;
                    scause <= cause;
                    stval  <= trap_bus.take_exc ? trap_bus.tval : 0;
                end
            end
            else if (trap_bus.take_mret) begin
                priv_lvl <= mstatus[MSTATUS_MPP_H : MSTATUS_MPP_L];
                mstatus[MSTATUS_MPP_H : MSTATUS_MPP_L] <= PRIV_U;  // specs demand this; failsafe for buggy kernels...

                mstatus[MSTATUS_MIE]  <= mstatus[MSTATUS_MPIE];
                mstatus[MSTATUS_MPIE] <= 1;
            end
            else if (trap_bus.take_sret) begin
                priv_lvl <= {1'b0, mstatus[MSTATUS_SPP]};
                mstatus[MSTATUS_SPP] <= 0;  // specs again...

                mstatus[MSTATUS_SIE]  <= mstatus[MSTATUS_SPIE];
                mstatus[MSTATUS_SPIE] <= 1;
            end
        end
    end

endmodule
