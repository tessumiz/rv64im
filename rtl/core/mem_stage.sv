import defs_pkg::*;

module mem_stage (
    input  ex_mem_t ex_mem,
    dmem_if.master  dmem_bus,

    output logic        wb,
    output logic [4:0]  wb_rd,
    output logic [63:0] fwd_data,
    output mem_wb_t     out
);

    logic [63:0] addr;
    logic [63:0] r_data;

    assign addr = ex_mem.ex_res;

    ld_sto_fmt u_lsfmt (
        .f3         (ex_mem.f3),
        .addr       (addr),
        .w_data_raw (ex_mem.rs2),
        .r_data_raw (dmem_bus.r_data),

        .w_data_fmt (dmem_bus.w_data),
        .r_data_fmt (r_data)
    );

    always_comb begin
        dmem_bus.f3_2 = ex_mem.f3[1:0];
        dmem_bus.w_en = ex_mem.ctrl.mem_w;
        dmem_bus.r_en = ex_mem.ctrl.mem_r;
        dmem_bus.addr = addr;

        out.pc   = ex_mem.pc;
        out.data = ex_mem.ctrl.mem_r ? r_data : ex_mem.ex_res;
        out.rd   = ex_mem.rd;
        out.ctrl = ex_mem.ctrl;

        wb       = !ex_mem.ctrl.mem_r;
        wb_rd    = ex_mem.rd;
        fwd_data = out.data;
    end

endmodule
