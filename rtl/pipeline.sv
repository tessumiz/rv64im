import defs_pkg::*;

module pipeline(
    input logic clk,
    input logic rst,

    imem_if.master imem_bus,
    dmem_if.master dmem_bus
);

    if_id_t  if_id_d,  if_id_q;
    id_ex_t  id_ex_d,  id_ex_q;
    ex_mem_t ex_mem_d, ex_mem_q;
    mem_wb_t mem_wb_d, mem_wb_q;

    logic        take_br;
    logic [63:0] br_targ;

    fwd_sig_t    fwd_sig;
    logic [63:0] rs1_fwd;
    logic [63:0] rs2_fwd;

    logic        fwd_mem;
    logic [4:0]  mem_fwd_rd;
    logic [63:0] mem_fwd_data;

    logic        fwd_wb;
    logic [4:0]  wb_fwd_rd;
    logic [63:0] wb_fwd_data;

    logic ld_use_haz;
    logic imuldiv_haz;
    logic has_rs1;
    logic has_rs2;
    logic has_rd;

    logic if_id_stall, if_id_flush;
    logic id_ex_stall, id_ex_flush;
    logic ex_mem_stall, ex_mem_flush;
    logic mem_wb_stall, mem_wb_flush;

    // unused for now...
    assign mem_wb_stall = 0;


    // special internal reg for precise exceptions on ooo-complete imuldiv
    logic  pending_mem;
    assign pending_mem = (id_ex_q.ctrl.mem_r || id_ex_q.ctrl.mem_w) ||
                         (ex_mem_q.ctrl.mem_r || ex_mem_q.ctrl.mem_w);

    wb_if wb_stage_out();
    wb_if wb_bus();


    gen_reg #(.T(if_id_t)) u_if_id_reg (
        .clk (clk),
        .en  (~if_id_stall),
        .clr (if_id_flush),
        .d   (if_id_d),
        .q   (if_id_q)
    );

    gen_reg #(.T(id_ex_t)) u_id_ex_reg (
        .clk (clk),
        .en  (~id_ex_stall),
        .clr (id_ex_flush),
        .d   (id_ex_d),
        .q   (id_ex_q)
    );

    gen_reg #(.T(ex_mem_t)) u_ex_mem_reg (
        .clk (clk),
        .en  (~ex_mem_stall),
        .clr (ex_mem_flush),
        .d   (ex_mem_d),
        .q   (ex_mem_q)
    );

    gen_reg #(.T(mem_wb_t)) u_mem_wb_reg (
        .clk (clk),
        .en  (~mem_wb_stall),
        .clr (mem_wb_flush),
        .d   (mem_wb_d),
        .q   (mem_wb_q)
    );


    fetch u_fetch (
        .clk      (clk),
        .stall    (if_id_stall),
        .flush    (if_id_flush),

        .take_br  (take_br),
        .br_targ  (br_targ),
        .imem_bus (imem_bus),

        .out      (if_id_d)
    );

    decode u_decode (
        .clk      (clk),

        .wb_bus   (wb_bus),
        .if_id    (if_id_q),

        .has_rs1  (has_rs1),
        .has_rs2  (has_rs2),
        .has_rd   (has_rd),
        .out      (id_ex_d)
    );

    execute u_execute (
        .id_ex    (id_ex_q),

        .fwd_sig  (fwd_sig),
        .rs1_fwd  (rs1_fwd),
        .rs2_fwd  (rs2_fwd),
        .fwd_mem  (mem_fwd_data),
        .fwd_wb   (wb_fwd_data),

        .take_br  (take_br),
        .br_targ  (br_targ),
        .out      (ex_mem_d)
    );

    mem_stage u_mem_stage (
        .ex_mem   (ex_mem_q),
        .dmem_bus (dmem_bus),

        .wb       (fwd_mem),
        .wb_rd    (mem_fwd_rd),
        .fwd_data (mem_fwd_data),
        .out      (mem_wb_d)
    );

    writeback u_writeback (
        .mem_wb   (mem_wb_q),
        .wb_bus   (wb_stage_out),

        .wb       (fwd_wb),
        .rd       (wb_fwd_rd),
        .fwd_data (wb_fwd_data)
    );


    imuldiv_in_if imuldiv_in();
    logic is_imul, is_idiv;

    always_comb begin
        is_imul = id_ex_q.ctrl.is_imul;
        is_idiv = id_ex_q.ctrl.is_idiv;

        imuldiv_in.clk   = clk;
        imuldiv_in.valid = (is_imul || is_idiv) && !take_br;
        imuldiv_in.op1   = rs1_fwd;
        imuldiv_in.op2   = rs2_fwd;
        imuldiv_in.rd    = id_ex_q.rd;
        imuldiv_in.f3_2  = id_ex_q.f3[1:0];

        imuldiv_in.is_wd_op = id_ex_q.ctrl.is_wd_op;
        imuldiv_in.pending_mem_flg = pending_mem;
    end

    imuldiv_out_if imul_out();
    imuldiv_out_if idiv_out();


    imul u_imul (
        .in  (imuldiv_in),
        .out (imul_out)
    );

    idiv u_idiv (
        .in  (imuldiv_in),
        .out (idiv_out)
    );

    wb_arbiter u_wb_arbiter (
        .imul_out (imul_out),
        .idiv_out (idiv_out),
        .wb_out   (wb_stage_out),
        .out      (wb_bus)
    );


    fwd u_fwd (
        .id_ex_rs1_a (id_ex_q.rs1_a),
        .id_ex_rs2_a (id_ex_q.rs2_a),

        .ex_mem_wb   (fwd_mem),
        .ex_mem_rd   (mem_fwd_rd),

        .mem_wb_wb   (fwd_wb),
        .mem_wb_rd   (wb_fwd_rd),

        .fwd_sig     (fwd_sig)
    );

    ld_use_haz u_ld_use_haz (
        .id_ex_mem_r (id_ex_q.ctrl.mem_r),
        .id_ex_rd    (id_ex_q.rd),

        .has_rs1     (has_rs1),
        .has_rs2     (has_rs2),
        .rs1_a       (id_ex_d.rs1_a),
        .rs2_a       (id_ex_d.rs2_a),

        .ld_use_haz  (ld_use_haz)
    );

    imuldiv_haz u_imuldiv_haz (
        .clk   (clk),
        .rst   (rst),

        .rs1_a (id_ex_d.rs1_a),
        .rs2_a (id_ex_d.rs2_a),
        .rd    (id_ex_d.rd),
        .if_id_stall (if_id_stall),

        .has_rs1    (has_rs1),
        .has_rs2    (has_rs2),
        .has_rd     (has_rd),
        .is_imuldiv (id_ex_d.ctrl.is_imul || id_ex_d.ctrl.is_idiv),

        .wb_en      (wb_bus.valid),
        .wb_rd      (wb_bus.rd),

        .imuldiv_haz  (imuldiv_haz)
    );


    logic imuldiv_bkpres;

    always_comb begin
        imuldiv_bkpres = (id_ex_q.ctrl.is_imul && !imuldiv_in.imul_ready) ||
                         (id_ex_q.ctrl.is_idiv && !imuldiv_in.idiv_ready);

        if_id_stall  = id_ex_stall;
        id_ex_stall  = ld_use_haz || imuldiv_haz || imuldiv_bkpres || dmem_bus.busy;
        ex_mem_stall = dmem_bus.busy;

        if_id_flush  = take_br;
        id_ex_flush  = take_br || ld_use_haz || imuldiv_haz;
        ex_mem_flush = take_br || id_ex_d.ctrl.is_imul || id_ex_d.ctrl.is_idiv;
        mem_wb_flush = dmem_bus.busy;
    end
endmodule
