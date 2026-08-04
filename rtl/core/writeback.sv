import defs_pkg::*;

module writeback (
    input logic clk,
    input logic clr,

    input mem_wb_t mem_wb,
    input irq_t    irq,

    wb_if.master   wb_bus,
    csr_rw_if.w_master csr_w_bus,
    csr_trap_if.master trap_bus,

    output logic        wb,
    output logic [4:0]  rd,
    output logic [63:0] fwd_data,

    output logic [63:0] trap_pc,
    output logic        take_br,
    output logic        flush_all
);

    logic is_exc, is_mret, is_csr;
    logic safe;

    logic  pending_irq;
    logic  interrupt;

    gen_reg #(.T(logic))
    u_pending_irq (
        .clk(clk),
        .clr(clr),

        .en (1),
        .d  (interrupt),
        .q  (pending_irq)
    );

    always_comb begin
        interrupt = irq.ext_int || irq.timer_int || irq.soft_int;

        is_exc  = mem_wb.exc.valid;
        is_mret = mem_wb.ctrl.is_mret;
        is_csr  = mem_wb.ctrl.is_csr;

        safe = !(is_exc || is_mret || pending_irq);

        // wb is prioritized in the arbiter so no issues with exc...
        wb_bus.data  = mem_wb.data;
        wb_bus.rd    = mem_wb.rd;
        wb_bus.valid = mem_wb.ctrl.wb && safe;

        wb       = mem_wb.ctrl.wb && safe;
        rd       = mem_wb.rd;
        fwd_data = mem_wb.data;

        csr_w_bus.w_en   = is_csr && mem_wb.ctrl.csr_we && safe;
        csr_w_bus.w_addr = mem_wb.csr_addr;
        csr_w_bus.w_data = mem_wb.csr_new_data;

        trap_bus.is_exc  = is_exc;
        trap_bus.is_mret = is_mret;
        trap_bus.cause   = mem_wb.exc.cause;
        
        trap_bus.pc = mem_wb.pc;

        take_br  = is_exc || is_mret || is_csr;

        if (is_exc) begin
            trap_pc = trap_bus.mtvec;
        end else if (is_csr) begin
            trap_pc = mem_wb.pc + 4;
        end else begin
            trap_pc = trap_bus.mepc;
        end

        flush_all = is_exc || is_mret || is_csr;
    end

endmodule
