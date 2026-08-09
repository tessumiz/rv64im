import defs_pkg::*;

module writeback (
    input mem_wb_t mem_wb,

    wb_if.master   wb_bus,
    csr_rw_if.w_master csr_w_bus,

    output logic        wb,
    output logic [4:0]  rd,
    output logic [63:0] fwd_data
);

    always_comb begin
        // wb is prioritized in the arbiter so no issues with exc...
        wb_bus.data  = mem_wb.data;
        wb_bus.rd    = mem_wb.rd;
        wb_bus.valid = mem_wb.ctrl.wb;

        wb       = mem_wb.ctrl.wb;
        rd       = mem_wb.rd;
        fwd_data = mem_wb.data;

        csr_w_bus.w_en   = mem_wb.ctrl.is_csr && mem_wb.ctrl.csr_we;
        csr_w_bus.w_addr = mem_wb.csr_addr;
        csr_w_bus.w_data = mem_wb.csr_new_data;
    end

endmodule
