import defs_pkg::*;

module pipeline(
    input logic clk,
    input logic rst_n,

    imem_if.master imem_bus,
    dmem_if.master dmem_bus
);

    // regs
    if_id_t  if_id;
    id_ex_t  id_ex;
    ex_mem_t ex_mem;
    mem_wb_t mem_wb;

    // br
    logic        take_br;
    logic [63:0] br_targ;

    // fwd
    fwd_sig_t    fwd_sig;

    logic        fwd_mem;
    logic [4:0]  mem_fwd_rd;
    logic [63:0] mem_fwd_data;

    logic        fwd_wb;
    logic [4:0]  wb_fwd_rd;
    logic [63:0] wb_fwd_data;

    // haz / stall / fls
    logic ld_use_haz;

    logic if_stall, if_flush;
    logic id_stall, id_flush;
    logic ex_stall, ex_flush;
    logic mem_stall, mem_flush;

    // wb intf
    wb_if wb_bus();


    fetch u_fetch (
        .clk      (clk),
        .stall    (if_stall),
        .flush    (if_flush),

        .take_br  (take_br),
        .br_targ  (br_targ),
        .imem_bus (imem_bus),

        .out      (if_id)
    );

    decode u_decode (
        .clk      (clk),
        .stall    (id_stall),
        .flush    (id_flush),

        .wb_bus   (wb_bus),
        .if_id    (if_id),

        .out      (id_ex)
    );

    execute u_execute (
        .clk      (clk),
        .stall    (ex_stall),
        .flush    (ex_flush),
        
        .id_ex    (id_ex),
        
        .fwd_sig  (fwd_sig),
        .fwd_mem  (mem_fwd_data),
        .fwd_wb   (wb_fwd_data),
        
        .take_br  (take_br),
        .br_targ  (br_targ),
        .out      (ex_mem)
    );

    mem_stage u_mem_stage (
        .clk      (clk),
        .stall    (mem_stall),
        .flush    (mem_flush),

        .ex_mem   (ex_mem),
        .dmem_bus (dmem_bus),
        
        .wb       (fwd_mem),
        .wb_rd    (mem_fwd_rd),
        .fwd_data (mem_fwd_data),
        .out      (mem_wb)
    );

    writeback u_writeback (
        .mem_wb   (mem_wb),
        .wb_bus   (wb_bus),
        
        .wb       (fwd_wb),
        .rd       (wb_fwd_rd),
        .fwd_data (wb_fwd_data)
    );

    fwd u_fwd (
        .id_ex_rs1_a (id_ex.rs1_a),
        .id_ex_rs2_a (id_ex.rs2_a),
        
        .ex_mem_wb   (mem_fwd_wb),
        .ex_mem_rd   (mem_fwd_rd),
        
        .mem_wb_wb   (wb_fwd_wb),
        .mem_wb_rd   (wb_fwd_rd),
        
        .fwd_sig     (fwd_sig)
    );

    haz_det u_haz_det (
        .id_ex_mem_r (id_ex.ctrl.mem_r),
        .if_id_ins   (if_id.ins),
        .id_ex_rd    (id_ex.rd),
        
        .ld_use_haz  (ld_use_haz)
    );
endmodule
