module pipeline import defs_pkg::*; (
    input logic clk,
    input logic rst,

    // will clean this up later through structs/intfs

    gen_mem_if.master ifu_ram,
    gen_mem_if.master dcu_ram,
    gen_mem_if.master dcu_mmio,

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
    // logic muldiv_haz;

    logic if_flush;
    logic if_id_stall,  if_id_flush;
    logic id_ex_stall,  id_ex_flush;
    logic ex_mem_stall, ex_mem_flush;
    logic mem_wb_stall, mem_wb_flush;

    logic icache_stall;
    logic mem_stall;

    logic trap_flush, csr_flush;  // from mem


    wb_if wb_stage_out();
    wb_if wb_bus();

    csr_rw_if   u_csr_rw_bus();
    csr_trap_if u_csr_trap_bus();


    gen_reg #(.T(if_id_t)) u_if_id_reg (
        .clk (clk),
        .en  (~if_id_stall),
        .clr (if_id_flush || rst),
        .d   (if_id_d),
        .q   (if_id_q)
    );

    gen_reg #(.T(id_ex_t)) u_id_ex_reg (
        .clk (clk),
        .en  (~id_ex_stall),
        .clr (id_ex_flush || rst),
        .d   (id_ex_d),
        .q   (id_ex_q)
    );

    gen_reg #(.T(ex_mem_t)) u_ex_mem_reg (
        .clk (clk),
        .en  (~ex_mem_stall),
        .clr (ex_mem_flush || rst),
        .d   (ex_mem_d),
        .q   (ex_mem_q)
    );

    gen_reg #(.T(mem_wb_t)) u_mem_wb_reg (
        .clk (clk),
        .en  (~mem_wb_stall),
        .clr (mem_wb_flush || rst),
        .d   (mem_wb_d),
        .q   (mem_wb_q)
    );


    fetch u_fetch (
        .clk      (clk),
        .rst      (rst),
        .stall    (if_id_stall),
        .flush    (if_flush),

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

        .ram_bus    (ifu_ram),

        .out          (if_id_d),
        .icache_stall (icache_stall)
    );

    decode u_decode (
        .clk      (clk),

        .wb_bus   (wb_bus),
        .if_id    (if_id_q),

        .priv     (priv),
        .csr_bus  (u_csr_rw_bus.r_master),

        .out      (id_ex_d)
    );

    ex_mem_t ex_mem_d_raw;

    execute u_execute (
        .id_ex    (id_ex_q),

        .fwd_sig  (fwd_sig),
        .rs1_fwd  (rs1_fwd),
        .rs2_fwd  (rs2_fwd),

        .fwd_mem   (mem_fwd_data),
        .fwd_wb    (wb_fwd_data),

        .take_br  (take_br),
        .br_targ  (br_targ),
        .out      (ex_mem_d_raw)
    );

    // dummy for demo; never synths...
    always_comb begin
        ex_mem_d = ex_mem_d_raw;

        if (id_ex_q.ctrl.is_mul || id_ex_q.ctrl.is_div) begin
            ex_mem_d.ex_res = u_muldiv_bus.res;
        end
    end


    mem_stage u_mem_stage (
        .clk      (clk),
        .rst      (rst),
        .ex_mem   (ex_mem_q),
        
        .trap_bus (u_csr_trap_bus.master),
        .ram_bus  (dcu_ram),
        .mmio_bus (dcu_mmio),

        .mem_stall   (mem_stall),

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
        .wb_bus   (wb_bus),  // arbiter disabled temporarily; revert this later

        .csr_w_bus (u_csr_rw_bus.w_master),

        .wb       (fwd_wb),
        .rd       (wb_fwd_rd),
        .fwd_data (wb_fwd_data)
    );


    // MULDIV

    muldiv_if u_muldiv_bus();
    
    always_comb begin
        u_muldiv_bus.op1      = rs1_fwd;
        u_muldiv_bus.op2      = rs2_fwd;
        u_muldiv_bus.f3_2     = id_ex_q.f3[1:0];
        u_muldiv_bus.is_wd_op = id_ex_q.ctrl.is_wd_op;
        u_muldiv_bus.is_mul   = id_ex_q.ctrl.is_mul;
        u_muldiv_bus.is_div   = id_ex_q.ctrl.is_div;
    end
    
    demo_muldiv u_muldiv (.bus(u_muldiv_bus.slave));


    // Add this back later...

    // muldiv_in_if muldiv_in();
    // logic is_mul, is_div;

    // logic  mem_branch;
    // assign mem_branch = take_mepc  || take_mtvec || take_sepc || take_stvec || csr_flush;


    // always_comb begin
    //     is_mul = id_ex_q.ctrl.is_mul;
    //     is_div = id_ex_q.ctrl.is_div;

    //     muldiv_in.clk   = clk;
    //     muldiv_in.op1   = rs1_fwd;
    //     muldiv_in.op2   = rs2_fwd;
    //     muldiv_in.rd    = id_ex_q.rd;
    //     muldiv_in.f3_2  = id_ex_q.f3[1:0];
    //     muldiv_in.is_wd_op = id_ex_q.ctrl.is_wd_op;

    //     muldiv_in.ready     = (is_mul || is_div)  && !mem_branch;
    //     muldiv_in.mark_spec = ex_mem_q.ctrl.valid && !mem_branch;
    // end

    // muldiv_out_if mul_out();
    // muldiv_out_if div_out();


    // mul u_mul (
    //     .in  (muldiv_in),
    //     .out (mul_out)
    // );

    // div u_div (
    //     .in  (muldiv_in),
    //     .out (div_out)
    // );


    // wb_arbiter u_wb_arbiter (
    //     .mul_out  (mul_out),
    //     .div_out  (div_out),
    //     .wb_out   (wb_stage_out),
    //     .out      (wb_bus)
    // );


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


    // muldiv_haz u_muldiv_haz (
    //     .clk   (clk),
    //     .rst   (rst),

    //     .rs1_a (id_ex_d.rs1_a),
    //     .rs2_a (id_ex_d.rs2_a),
    //     .rd    (id_ex_d.rd),
    //     .if_id_stall (if_id_stall),

    //     .is_muldiv (id_ex_d.ctrl.is_mul || id_ex_d.ctrl.is_div),

    //     .wb_en      (wb_bus.valid),
    //     .wb_rd      (wb_bus.rd),

    //     .muldiv_haz  (muldiv_haz)
    // );


    // flush / stall
    logic branch;

    assign branch = take_mepc || take_mtvec || take_sepc || take_stvec || csr_flush || take_br;

    assign if_id_stall  = mem_stall || ld_use_haz;
    assign id_ex_stall  = mem_stall;
    assign ex_mem_stall = mem_stall;
    assign mem_wb_stall = mem_stall;

    assign if_flush     = !mem_stall && (trap_flush  || csr_flush || branch);
    assign if_id_flush  = if_flush || (icache_stall && !if_id_stall);
    assign id_ex_flush  = !mem_stall && (if_flush || ld_use_haz);
    assign ex_mem_flush = !mem_stall && (trap_flush  || csr_flush);
    assign mem_wb_flush = !mem_stall && trap_flush;


    // logic muldiv_bkpres;
    // always_comb begin
    //     muldiv_bkpres =
    //         (id_ex_q.ctrl.is_mul && !muldiv_in.mul_ready) ||
    //         (id_ex_q.ctrl.is_div && !muldiv_in.div_ready);


    //     branch = mem_branch || take_br;

    //     // Upstream stages must freeze identically when the DCU is choked by a ram/MMIO miss
    //     if_id_stall  = id_ex_stall && !branch;
    //     id_ex_stall  = ld_use_haz || muldiv_haz || muldiv_bkpres || mem_stall;
    //     ex_mem_stall = mem_stall;

    //     if_id_flush  = trap_flush  || csr_flush  || branch;
    //     id_ex_flush  = if_id_flush || ld_use_haz || muldiv_haz;
    //     ex_mem_flush = (trap_flush || csr_flush) || id_ex_q.ctrl.is_mul || id_ex_q.ctrl.is_div;
        
    //     // Flushes the WB stage during a multi-cycle memory stall to prevent spurious commits
    //     mem_wb_flush = trap_flush  || mem_stall;

    //     mul_out.mark_safe = ex_mem_q.ctrl.valid && !mem_branch;
    //     div_out.mark_safe = mul_out.mark_safe;

    //     mul_out.flush_spec = ex_mem_q.ctrl.valid && mem_branch;
    //     div_out.flush_spec = mul_out.flush_spec;
    // end


// // ============================================================
// // VERILATOR PIPELINE DEBUG
// // ============================================================

// // -------- Pipeline register state --------

// logic        dbg_if_valid        /* verilator public_flat */;
// logic [63:0] dbg_if_pc           /* verilator public_flat */;
// logic [31:0] dbg_if_ins          /* verilator public_flat */;

// logic        dbg_id_valid        /* verilator public_flat */;
// logic [63:0] dbg_id_pc           /* verilator public_flat */;

// logic        dbg_ex_valid        /* verilator public_flat */;
// logic [63:0] dbg_ex_pc          /* verilator public_flat */;
// logic [4:0]  dbg_ex_rs1_a       /* verilator public_flat */;
// logic [4:0]  dbg_ex_rs2_a       /* verilator public_flat */;
// logic [4:0]  dbg_ex_rd          /* verilator public_flat */;
// logic [2:0]  dbg_ex_f3          /* verilator public_flat */;
// logic [6:0]  dbg_ex_f7          /* verilator public_flat */;

// logic        dbg_mem_valid       /* verilator public_flat */;
// logic [63:0] dbg_mem_pc          /* verilator public_flat */;
// logic [4:0]  dbg_mem_rd          /* verilator public_flat */;
// logic [2:0]  dbg_mem_f3          /* verilator public_flat */;

// logic        dbg_wb_valid        /* verilator public_flat */;
// logic [63:0] dbg_wb_pc           /* verilator public_flat */;
// logic [4:0]  dbg_wb_rd           /* verilator public_flat */;

// // -------- Stall / flush control --------

// logic dbg_if_stall              /* verilator public_flat */;
// logic dbg_id_stall              /* verilator public_flat */;
// logic dbg_ex_stall              /* verilator public_flat */;
// logic dbg_mem_stall_pipe        /* verilator public_flat */;

// logic dbg_if_flush              /* verilator public_flat */;
// logic dbg_if_id_flush           /* verilator public_flat */;
// logic dbg_id_ex_flush           /* verilator public_flat */;
// logic dbg_ex_mem_flush          /* verilator public_flat */;
// logic dbg_mem_wb_flush          /* verilator public_flat */;

// logic dbg_icache_stall          /* verilator public_flat */;
// logic dbg_mem_stage_stall       /* verilator public_flat */;
// logic dbg_ld_use_haz            /* verilator public_flat */;

// // -------- Control flow --------

// logic dbg_take_br               /* verilator public_flat */;
// logic [63:0] dbg_br_targ        /* verilator public_flat */;
// logic dbg_branch                /* verilator public_flat */;

// // -------- Forwarding --------

// logic dbg_fwd_mem               /* verilator public_flat */;
// logic [4:0] dbg_mem_fwd_rd      /* verilator public_flat */;
// logic [63:0] dbg_mem_fwd_data   /* verilator public_flat */;

// logic dbg_fwd_wb                /* verilator public_flat */;
// logic [4:0] dbg_wb_fwd_rd       /* verilator public_flat */;
// logic [63:0] dbg_wb_fwd_data    /* verilator public_flat */;

// logic dbg_mem_fwd_rs1           /* verilator public_flat */;
// logic dbg_wb_fwd_rs1            /* verilator public_flat */;
// logic dbg_mem_fwd_rs2           /* verilator public_flat */;
// logic dbg_wb_fwd_rs2            /* verilator public_flat */;

// // -------- Hazard / pipeline movement --------

// logic dbg_if_id_en              /* verilator public_flat */;
// logic dbg_id_ex_en              /* verilator public_flat */;
// logic dbg_ex_mem_en             /* verilator public_flat */;
// logic dbg_mem_wb_en             /* verilator public_flat */;


// // ============================================================
// // Assignments
// // ============================================================

// assign dbg_if_valid = if_id_q.valid;
// assign dbg_if_pc    = if_id_q.pc;
// assign dbg_if_ins   = if_id_q.ins;

// assign dbg_id_valid = id_ex_q.ctrl.valid;
// assign dbg_id_pc    = id_ex_q.pc;

// assign dbg_ex_valid = id_ex_q.ctrl.valid;
// assign dbg_ex_pc    = id_ex_q.pc;
// assign dbg_ex_rs1_a = id_ex_q.rs1_a;
// assign dbg_ex_rs2_a = id_ex_q.rs2_a;
// assign dbg_ex_rd    = id_ex_q.rd;
// assign dbg_ex_f3    = id_ex_q.f3;
// assign dbg_ex_f7    = id_ex_q.f7;

// assign dbg_mem_valid = ex_mem_q.ctrl.valid;
// assign dbg_mem_pc    = ex_mem_q.pc;
// assign dbg_mem_rd    = ex_mem_q.rd;
// assign dbg_mem_f3    = ex_mem_q.f3;

// assign dbg_wb_valid = mem_wb_q.ctrl.valid;
// assign dbg_wb_pc    = mem_wb_q.pc;
// assign dbg_wb_rd    = mem_wb_q.rd;


// // -------- Stall / flush --------

// assign dbg_if_stall       = if_id_stall;
// assign dbg_id_stall       = id_ex_stall;
// assign dbg_ex_stall       = ex_mem_stall;
// assign dbg_mem_stall_pipe = mem_wb_stall;

// assign dbg_if_flush   = if_flush;
// assign dbg_if_id_flush = if_id_flush;
// assign dbg_id_ex_flush = id_ex_flush;
// assign dbg_ex_mem_flush = ex_mem_flush;
// assign dbg_mem_wb_flush = mem_wb_flush;

// assign dbg_icache_stall   = icache_stall;
// assign dbg_mem_stage_stall = mem_stall;
// assign dbg_ld_use_haz     = ld_use_haz;


// // -------- Branch --------

// assign dbg_take_br  = take_br;
// assign dbg_br_targ  = br_targ;
// assign dbg_branch   = branch;


// // -------- Forwarding --------

// assign dbg_fwd_mem       = fwd_mem;
// assign dbg_mem_fwd_rd    = mem_fwd_rd;
// assign dbg_mem_fwd_data  = mem_fwd_data;

// assign dbg_fwd_wb        = fwd_wb;
// assign dbg_wb_fwd_rd     = wb_fwd_rd;
// assign dbg_wb_fwd_data   = wb_fwd_data;

// assign dbg_mem_fwd_rs1 = fwd_sig.mem_fwd_rs1;
// assign dbg_wb_fwd_rs1  = fwd_sig.wb_fwd_rs1;
// assign dbg_mem_fwd_rs2 = fwd_sig.mem_fwd_rs2;
// assign dbg_wb_fwd_rs2  = fwd_sig.wb_fwd_rs2;


// // -------- Enables --------

// assign dbg_if_id_en = ~if_id_stall;
// assign dbg_id_ex_en = ~id_ex_stall;
// assign dbg_ex_mem_en = ~ex_mem_stall;
// assign dbg_mem_wb_en = ~mem_wb_stall;

endmodule
