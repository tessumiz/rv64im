import defs_pkg::*;

module mem_stage (
    input  logic clk,
    input  logic stall,
    input  logic flush,

    input  ex_mem_t ex_mem,
    dmem_if.master  dmem_bus,

    output logic        wb,
    output logic        wb_rd,
    output logic [63:0] fwd_data,
    output mem_wb_t     out
);

    logic [63:0] addr;
    logic [63:0] r_data;

    assign addr = ex_mem.ex_res;

    mem_wb_t mem_wb;

    ld_sto_fmt u_lsfmt (
        .f3         (ex_mem.f3),
        .addr       (addr),
        .w_data_raw (ex_mem.rs2),
        .r_data_raw (dmem_bus.r_data),

        .w_data_fmt (dmem_bus.w_data),
        .r_data_fmt (r_data)
    );

    assign dmem_bus.f3_2 = ex_mem.f3[1:0];
    assign dmem_bus.w_en = ex_mem.ctrl.mem_w;
    assign dmem_bus.r_en = ex_mem.ctrl.mem_r;
    assign dmem_bus.addr = addr;

    assign mem_wb.data = ex_mem.ctrl.mem_r ? r_data : ex_mem.ex_res;
    assign mem_wb.rd   = ex_mem.rd;
    assign mem_wb.ctrl = ex_mem.ctrl;

    assign wb       = !ex_mem.ctrl.mem_r;
    assign wb_rd    = ex_mem.rd;
    assign fwd_data = mem_wb.data;

    pipe_reg #(.T(mem_wb_t))
    u_mem_wb (
        .clk (clk),
        .en  (~stall),
        .clr (flush),
        .d   (mem_wb),
        .q   (out)
    );

endmodule
