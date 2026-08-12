import defs_pkg::*;
import zicsr_pkg::*;

// !!!!!##### INTERRUPTS ON BUBBLES

module mem_stage (
    input  ex_mem_t     ex_mem,
    dmem_if.master      dmem_bus,
    csr_trap_if.master  trap_bus,

    output logic        wb,
    output logic [4:0]  wb_rd,
    output logic [63:0] fwd_data,

    output logic [63:0] csr_br_targ,

    output logic        trap_flush,
    output logic        csr_flush,
    output mem_wb_t     out
);

    logic [63:0] addr;
    logic [63:0] r_data;
    
    logic        is_misaligned;
    logic [63:0] mem_cause;
    
    logic  is_exc;
    logic  is_mret;
    logic  is_sret;
    logic  is_irq;

    logic  safe;

    assign addr  = ex_mem.ex_res;

    logic  mem_op;
    assign mem_op = (ex_mem.ctrl.mem_r || ex_mem.ctrl.mem_w) && safe;


    lsu u_lsu (
        .mem_op     (mem_op),
        .f3         (ex_mem.f3),
        .addr       (addr),

        .r_data_raw (dmem_bus.r_data),
        .r_data_fmt (r_data),

        .w_data_raw    (ex_mem.rs2),
        .w_data_fmt    (dmem_bus.w_data),
        .is_misaligned (is_misaligned)
    );


    always_comb begin
        mem_cause = ex_mem.exc.valid ? ex_mem.exc.cause :
                    64'(ex_mem.ctrl.mem_w ? EXC_STORE_MISALIGNED : EXC_LOAD_MISALIGNED);

        is_exc  = (ex_mem.exc.valid || is_misaligned);
        is_mret = ex_mem.exc.is_mret;
        is_sret = ex_mem.exc.is_sret;
        is_irq  = trap_bus.irq_pending && !dmem_bus.busy;  // wait for dmem...

        safe = !(is_exc || is_mret || is_sret || is_irq);  // irq flushes curr instr; else finding nxt_pc would be hard

        dmem_bus.f3_2 = ex_mem.f3[1:0];
        dmem_bus.w_en = ex_mem.ctrl.mem_w && safe;
        dmem_bus.r_en = ex_mem.ctrl.mem_r && safe;
        dmem_bus.v_addr = addr;

        trap_bus.take_exc  = is_exc;
        trap_bus.take_mret = is_mret;
        trap_bus.take_sret = is_sret;
        trap_bus.take_irq  = is_irq && !(is_exc || is_mret);

        trap_bus.cause = is_exc ? mem_cause : 0;  // irq_cause handled inside csr_file
        trap_bus.pc    = ex_mem.pc;

        trap_bus.tval  = ex_mem.exc.tval;  // #####!!!!! will sort out is_misaligned later.....

        trap_flush  = !safe;
        csr_flush   = ex_mem.ctrl.is_csr && safe;  // for now, all csr ops flush unconditionally
        csr_br_targ = ex_mem.pc + 4;


        out.pc           = ex_mem.pc;
        out.data         = ex_mem.ctrl.mem_r ? r_data : ex_mem.ex_res;
        out.rd           = ex_mem.rd;
        out.csr_new_data = ex_mem.rs2;
        out.csr_addr     = ex_mem.csr_w_addr;
        out.ctrl         = ex_mem.ctrl;
        // out.ctrl.valid   = valid && safe;  bubble detection is unnecessary in wb...
        out.ctrl.is_csr  = ex_mem.ctrl.is_csr && safe;

        wb       = ex_mem.ctrl.wb && safe;
        wb_rd    = ex_mem.rd;
        fwd_data = out.data;
    end

endmodule
