module decode import defs_pkg::*, zicsr_pkg::*; (
    input logic clk,

    input wb_bus_t wb_bus_in,

    csr_rw_if.r_master csr_bus,

    input logic [1:0] priv,
    input if_id_t     if_id,

    output id_ex_t out
);

    logic [4:0]  rs1_a, rs2_a, rd;
    logic [2:0]  f3;
    logic [6:0]  f7;
    logic [63:0] rs1, rs2;
    logic [63:0] imm;

    exc_t  dec_exc;
    ctrl_t dec_ctrl;

    logic  is_ecall;

    decoder u_decoder (
        .ins   (if_id.ins),
        .priv  (priv),

        .rs1_a (rs1_a),
        .rs2_a (rs2_a),
        .rd    (rd),
        .f3    (f3),
        .f7    (f7),
        .ctrl  (dec_ctrl),
        .exc   (dec_exc),

        .ecall (is_ecall)
    );

    regfile u_reg (
        .clk     (clk),
        .rs1_a   (rs1_a),
        .rs2_a   (rs2_a),
        .rd      (wb_bus_in.rd),
        .wb_data (wb_bus_in.data),
        .wb_en   (wb_bus_in.valid),

        .rs1     (rs1),
        .rs2     (rs2)
    );

    immgen u_immgen (
        .ins (if_id.ins),
        .imm (imm)
    );

    logic illegal_csr_rw, is_csr;

    always_comb begin
        automatic ctrl_t ctrl_tmp = dec_ctrl;

        out.exc  = '0;

        is_csr = ctrl_tmp.is_csr;

        ctrl_tmp.is_csr  = is_csr;
        ctrl_tmp.is_zimm = dec_ctrl.is_zimm;
        csr_bus.r_addr   = imm[11:0];

        illegal_csr_rw = is_csr && (
            csr_bus.r_exc ||
            ((imm[11:10] == CSR_ADDR_RO && ctrl_tmp.csr_we) || priv < imm[9:8])
        );

        out.rs1_a = rs1_a;
        out.rs2_a = rs2_a;
        out.rd    = rd;
        out.f3    = f3;
        out.f7    = f7;
        out.rs1   = rs1;
        out.imm   = imm;

        out.pc  = if_id.pc;
        out.rs2 = ctrl_tmp.is_csr ? csr_bus.r_data : rs2;

        out.exc = dec_exc;

        out.exc.valid = if_id.exc.valid || (if_id.valid && (illegal_csr_rw || dec_exc.valid));

        out.exc.cause =
            if_id.exc.valid ? EXC_INSTR_MISALIGNED :
            if_id.valid && illegal_csr_rw ? EXC_ILLEGAL_INSTR :
            dec_exc.cause;  // no mux strictly required here...

        out.exc.tval  =
            if_id.exc.valid ? if_id.pc :
            (if_id.valid && is_ecall) ? 0 :
            {32'b0, if_id.ins};

        ctrl_tmp.wb &= (rd != 0);
        out.ctrl  = ctrl_tmp;
        out.valid = if_id.valid;
    end


// // ============================================================
// // VERILATOR DECODE DEBUG
// // ============================================================

// logic        dbg_valid            /* verilator public_flat */;
// logic [63:0] dbg_pc               /* verilator public_flat */;
// logic [31:0] dbg_ins              /* verilator public_flat */;

// logic [4:0]  dbg_rs1_a            /* verilator public_flat */;
// logic [4:0]  dbg_rs2_a            /* verilator public_flat */;
// logic [4:0]  dbg_rd               /* verilator public_flat */;

// logic [2:0]  dbg_f3               /* verilator public_flat */;
// logic [6:0]  dbg_f7               /* verilator public_flat */;

// logic [63:0] dbg_rs1          /* verilator public_flat */;
// logic [63:0] dbg_rs2          /* verilator public_flat */;
// logic [63:0] dbg_imm              /* verilator public_flat */;

// logic [63:0] dbg_out_rs1          /* verilator public_flat */;
// logic [63:0] dbg_out_rs2          /* verilator public_flat */;

// // Final control outputs after ctrl_tmp modifications.
// logic        dbg_ctrl_valid       /* verilator public_flat */;
// logic        dbg_ctrl_br          /* verilator public_flat */;
// logic        dbg_ctrl_jmp         /* verilator public_flat */;
// logic        dbg_ctrl_we      /* verilator public_flat */;
// logic        dbg_ctrl_mem_re      /* verilator public_flat */;
// logic        dbg_ctrl_mem_we      /* verilator public_flat */;
// logic        dbg_ctrl_alu_src1_pc  /* verilator public_flat */;
// logic        dbg_ctrl_alu_src2_imm /* verilator public_flat */;
// logic        dbg_ctrl_is_wd_op     /* verilator public_flat */;
// logic        dbg_ctrl_is_lui       /* verilator public_flat */;

// assign dbg_valid = if_id.valid;
// assign dbg_pc    = if_id.pc;
// assign dbg_ins   = if_id.ins;

// assign dbg_rs1_a = rs1_a;
// assign dbg_rs2_a = rs2_a;
// assign dbg_rd    = rd;

// assign dbg_f3 = f3;
// assign dbg_f7 = f7;

// assign dbg_rs1 = rs1;
// assign dbg_rs2 = rs2;
// assign dbg_imm     = imm;

// assign dbg_out_rs1 = out.rs1;
// assign dbg_out_rs2 = out.rs2;

// assign dbg_ctrl_valid = out.valid;
// assign dbg_ctrl_br    = out.ctrl.br;
// assign dbg_ctrl_jmp   = out.ctrl.jmp;
// assign dbg_ctrl_we = out.ctrl.wb;
// assign dbg_ctrl_mem_re = out.ctrl.mem_r;
// assign dbg_ctrl_mem_we = out.ctrl.mem_w;

// assign dbg_ctrl_alu_src1_pc  = out.ctrl.alu_src1_pc;
// assign dbg_ctrl_alu_src2_imm = out.ctrl.alu_src2_imm;
// assign dbg_ctrl_is_wd_op     = out.ctrl.is_wd_op;
// assign dbg_ctrl_is_lui       = out.ctrl.is_lui;

endmodule
