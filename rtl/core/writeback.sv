import defs_pkg::*;

module writeback (
    input mem_wb_t mem_wb,

    wb_if.master   wb_bus,

    output logic        wb,
    output logic [4:0]  rd,
    output logic [63:0] fwd_data
);

    assign wb_bus.data  = mem_wb.data;
    assign wb_bus.rd    = mem_wb.rd;
    assign wb_bus.valid = mem_wb.ctrl.wb;

    assign wb       = mem_wb.ctrl.wb;
    assign rd       = mem_wb.rd;
    assign fwd_data = mem_wb.data;
endmodule
