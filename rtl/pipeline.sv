import defs_pkg::*;

module pipeline(
    input logic clk,
    input logic rst,

    imem_if.master imem_bus,
    dmem_if.master dmem_bus,

    input irq_t irq
);

    if_id_t  if_id_d,  if_id_q;
    id_ex_t  id_ex_d,  id_ex_q;
    ex_mem_t ex_mem_d, ex_mem_q;
    mem_wb_t mem_wb_d, mem_wb_q;

    logic take_br;
    logic take_mepc;
    logic take_sepc;
    logic take_mtvec;
    logic take_stvec;

    logic [63:0] br_targ;
    logic [63:0] mepc_targ;
    logic [63:0] mtvec_targ;

    logic [63:0] sepc_targ;
    logic [63:0] stvec_targ;

    logic [63:0] csr_br_targ;


    fwd_sig_t    fwd_sig;
    logic [63:0] rs1_fwd;
    logic [63:0] rs2_fwd;

    logic        fwd_mem;
    logic [4:0]  mem_fwd_rd;
    logic [63:0] mem_fwd_data;

    logic        fwd_wb;
    logic [4:0]  wb_fwd_rd;
    logic [63:0] wb_fwd_data;

    logic [1:0]  priv;
    logic [63:0] satp;


    logic ld_use_haz;
    logic muldiv_haz;

    logic if_id_stall,  if_id_flush;
    logic id_ex_stall,  id_ex_flush;
    logic ex_mem_stall, ex_mem_flush;
    logic mem_wb_stall, mem_wb_flush;

    assign mem_wb_stall = 0;  // wb never stalls (as of now...)

    logic trap_flush, csr_flush;  // from mem


    wb_if wb_stage_out();
    wb_if wb_bus();

    csr_rw_if   u_csr_rw_bus();
    csr_trap_if u_csr_trap_bus();


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
        .rst      (rst),
        .stall    (if_id_stall),
        .flush    (if_id_flush),

        .take_br    (take_br),
        .br_targ    (br_targ),

        .take_mepc  (take_mepc),
        .mepc_targ  (mepc_targ),

        .take_mtvec (take_mtvec),
        .mtvec_targ (mtvec_targ),
    
        .take_sepc  (take_sepc),
        .sepc_targ  (sepc_targ),

        .take_stvec (take_stvec),
        .stvec_targ (stvec_targ),

        .take_csr_br (csr_flush),
        .csr_br_targ (csr_br_targ),

        .imem_bus (imem_bus),

        .out      (if_id_d)
    );

    decode u_decode (
        .clk      (clk),

        .wb_bus   (wb_bus),
        .if_id    (if_id_q),

        .priv     (priv),
        .csr_bus  (u_csr_rw_bus.r_master),

        .out      (id_ex_d)
    );

    execute u_execute (
        .id_ex    (id_ex_q),

        .fwd_sig  (fwd_sig),
        .rs1_fwd  (rs1_fwd),
        .rs2_fwd  (rs2_fwd),

        .fwd_mem   (mem_fwd_data),
        .fwd_wb    (wb_fwd_data),

        .take_br  (take_br),
        .br_targ  (br_targ),
        .out      (ex_mem_d)
    );

    mem_stage u_mem_stage (
        .ex_mem   (ex_mem_q),
        .dmem_bus (dmem_bus),

        .trap_bus (u_csr_trap_bus.master),

        .wb       (fwd_mem),
        .wb_rd    (mem_fwd_rd),
        .fwd_data (mem_fwd_data),

        .trap_flush  (trap_flush),
        .csr_flush   (csr_flush),
        .csr_br_targ (csr_br_targ),

        .out       (mem_wb_d)
    );

    writeback u_writeback (
        .mem_wb   (mem_wb_q),
        .wb_bus   (wb_stage_out),

        .csr_w_bus (u_csr_rw_bus.w_master),

        .wb       (fwd_wb),
        .rd       (wb_fwd_rd),
        .fwd_data (wb_fwd_data)
    );


    // MULDIV
    muldiv_in_if muldiv_in();
    logic is_mul, is_div;

    logic  mem_branch;
    assign mem_branch = take_mepc  || take_mtvec || take_sepc || take_stvec || csr_flush;


    always_comb begin
        is_mul = id_ex_q.ctrl.is_mul;
        is_div = id_ex_q.ctrl.is_div;

        muldiv_in.clk   = clk;
        muldiv_in.op1   = rs1_fwd;
        muldiv_in.op2   = rs2_fwd;
        muldiv_in.rd    = id_ex_q.rd;
        muldiv_in.f3_2  = id_ex_q.f3[1:0];
        muldiv_in.is_wd_op = id_ex_q.ctrl.is_wd_op;

        muldiv_in.ready     = (is_mul || is_div)  && !mem_branch;
        muldiv_in.mark_spec = ex_mem_q.ctrl.valid && !mem_branch;
    end

    muldiv_out_if mul_out();
    muldiv_out_if div_out();


    mul u_mul (
        .in  (muldiv_in),
        .out (mul_out)
    );

    div u_div (
        .in  (muldiv_in),
        .out (div_out)
    );

    wb_arbiter u_wb_arbiter (
        .mul_out (mul_out),
        .div_out (div_out),
        .wb_out   (wb_stage_out),
        .out      (wb_bus)
    );


    // ZICSR
    csr_file u_csr_file (
        .clk (clk),
        .rst (rst),

        .irq (irq),

        .rw_bus   (u_csr_rw_bus.slave),
        .trap_bus (u_csr_trap_bus.slave),

        .mepc_out  (mepc_targ),
        .mtvec_out (mtvec_targ),

        .sepc_out  (sepc_targ),
        .stvec_out (stvec_targ),

        .take_mepc  (take_mepc),
        .take_mtvec (take_mtvec),

        .take_sepc  (take_sepc),
        .take_stvec (take_stvec),

        .priv      (priv),
        .satp_out  (satp)
    );


    // FWD / HAZ
    fwd u_fwd (
        .rs1_a (id_ex_q.rs1_a),
        .rs2_a (id_ex_q.rs2_a),

        .ex_mem_wb   (fwd_mem),
        .ex_mem_rd   (mem_fwd_rd),

        .mem_wb_wb   (fwd_wb),
        .mem_wb_rd   (wb_fwd_rd),

        .fwd_sig     (fwd_sig)
    );

    ld_use_haz u_ld_use_haz (
        .id_ex_mem_r (id_ex_q.ctrl.mem_r),
        .id_ex_rd    (id_ex_q.rd),

        .rs1_a       (id_ex_d.rs1_a),
        .rs2_a       (id_ex_d.rs2_a),

        .ld_use_haz  (ld_use_haz)
    );

    muldiv_haz u_muldiv_haz (
        .clk   (clk),
        .rst   (rst),

        .rs1_a (id_ex_d.rs1_a),
        .rs2_a (id_ex_d.rs2_a),
        .rd    (id_ex_d.rd),
        .if_id_stall (if_id_stall),

        .is_muldiv (id_ex_d.ctrl.is_mul || id_ex_d.ctrl.is_div),

        .wb_en      (wb_bus.valid),
        .wb_rd      (wb_bus.rd),

        .muldiv_haz  (muldiv_haz)
    );


    // flush / stall
    logic muldiv_bkpres;
    logic branch;

    always_comb begin
        muldiv_bkpres =
            (id_ex_q.ctrl.is_mul && !muldiv_in.mul_ready) ||
            (id_ex_q.ctrl.is_div && !muldiv_in.div_ready);


        branch = mem_branch || take_br;

        if_id_stall  = id_ex_stall && !branch;
        id_ex_stall  = ld_use_haz || muldiv_haz || muldiv_bkpres || dmem_bus.busy;
        ex_mem_stall = dmem_bus.busy;

        if_id_flush  = trap_flush  || csr_flush  || branch;
        id_ex_flush  = if_id_flush || ld_use_haz || muldiv_haz;
        ex_mem_flush = (trap_flush || csr_flush) || id_ex_q.ctrl.is_mul || id_ex_q.ctrl.is_div;
        mem_wb_flush = trap_flush  || dmem_bus.busy;

        mul_out.mark_safe = ex_mem_q.ctrl.valid && !mem_branch;
        div_out.mark_safe = mul_out.mark_safe;

        mul_out.flush_spec = ex_mem_q.ctrl.valid && mem_branch;
        div_out.flush_spec = mul_out.flush_spec;
    end

endmodule
