module writeback import defs_pkg::*; (
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

        // neutered again
        csr_w_bus.w_en = 0;
        // csr_w_bus.w_en   = mem_wb.ctrl.is_csr && mem_wb.ctrl.csr_we;
        csr_w_bus.w_addr = mem_wb.csr_addr;
        csr_w_bus.w_data = mem_wb.csr_new_data;
    end


// // ============================================================
// // VERILATOR WRITEBACK DEBUG
// // ============================================================

// logic        dbg_valid          /* verilator public_flat */;
// logic [63:0] dbg_pc             /* verilator public_flat */;

// logic [4:0]  dbg_rd             /* verilator public_flat */;
// logic [63:0] dbg_data           /* verilator public_flat */;

// logic        dbg_wb             /* verilator public_flat */;

// logic        dbg_wb_bus_valid   /* verilator public_flat */;
// logic [4:0]  dbg_wb_bus_rd      /* verilator public_flat */;
// logic [63:0] dbg_wb_bus_data    /* verilator public_flat */;

// logic        dbg_fwd_valid      /* verilator public_flat */;
// logic [4:0]  dbg_fwd_rd         /* verilator public_flat */;
// logic [63:0] dbg_fwd_data       /* verilator public_flat */;

// assign dbg_valid = mem_wb.ctrl.valid;
// assign dbg_pc    = mem_wb.pc;

// assign dbg_rd   = mem_wb.rd;
// assign dbg_data = mem_wb.data;

// assign dbg_wb = mem_wb.ctrl.wb;

// assign dbg_wb_bus_valid = wb_bus.valid;
// assign dbg_wb_bus_rd    = wb_bus.rd;
// assign dbg_wb_bus_data  = wb_bus.data;

// assign dbg_fwd_valid = wb;
// assign dbg_fwd_rd    = rd;
// assign dbg_fwd_data  = fwd_data;

endmodule
