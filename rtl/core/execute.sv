module execute import defs_pkg::*, zicsr_pkg::*; (
    input id_ex_t id_ex,

    input fwd_sig_t    fwd_sig,
    input logic [63:0] fwd_mem,
    input logic [63:0] fwd_wb,

    output logic        take_br,
    output logic [63:0] br_targ,

    output logic [63:0] rs1_fwd,
    output logic [63:0] rs2_fwd,

    output ex_mem_t out
);

    logic [63:0] alu_in1, alu_in2, alu_out;

    always_comb begin
        rs1_fwd = (fwd_sig.mem_fwd_rs1) ? fwd_mem : (fwd_sig.wb_fwd_rs1 ? fwd_wb : id_ex.rs1);
        rs2_fwd = (fwd_sig.mem_fwd_rs2) ? fwd_mem : (fwd_sig.wb_fwd_rs2 ? fwd_wb : id_ex.rs2);

        alu_in1 = id_ex.ctrl.alu_src1_pc  ? id_ex.pc  : rs1_fwd;
        alu_in2 = id_ex.ctrl.alu_src2_imm ? id_ex.imm : rs2_fwd;
    end

    logic [3:0]  alu_op;

    always_comb begin
        if (id_ex.ctrl.mem_r || id_ex.ctrl.mem_w || 
           (id_ex.ctrl.alu_src1_pc && !id_ex.ctrl.jmp && !id_ex.ctrl.br)) begin
            alu_op = 4'b0000;
        end
        else if (id_ex.ctrl.alu_src2_imm && (id_ex.f3 != 3'b001 && id_ex.f3 != 3'b101)) begin
            alu_op = {1'b0, id_ex.f3};
        end
        else begin
            alu_op = {id_ex.f7[5], id_ex.f3}; 
        end
    end

    alu u_alu (
        .a        (alu_in1),
        .b        (alu_in2),
        .alu_op   (alu_op),
        .is_wd_op (id_ex.ctrl.is_wd_op),
        .alu_out  (alu_out)
    );

    assign br_targ =
        (id_ex.ctrl.br || id_ex.ctrl.jmp)
        ? ((alu_in1 + alu_in2) & ~64'd1)
        : (alu_out & ~64'd1);

    bcu u_bcu (
        .rs1     (rs1_fwd),
        .rs2     (rs2_fwd),
        .is_br   (id_ex.ctrl.br),
        .is_jmp  (id_ex.ctrl.jmp),
        .f3      (id_ex.f3),
        .take_br (take_br)  // For garbage ins, is_br/jmp will be 0
    );


    logic [63:0] csr_w_data;
    logic [63:0] csr_src_data;

    always_comb begin
        csr_src_data = id_ex.ctrl.is_zimm ? { 59'b0, id_ex.rs1_a} : rs1_fwd;
        
        case (id_ex.f3[1:0])
            CSR_RW: csr_w_data = csr_src_data;
            CSR_RS: csr_w_data = id_ex.rs2 | csr_src_data;
            CSR_RC: csr_w_data = id_ex.rs2 & ~csr_src_data;
            default: csr_w_data = 0;
        endcase

        out.csr_w_addr = id_ex.imm[11:0];

        if (id_ex.ctrl.jmp) begin
            out.ex_res = id_ex.pc + 4;
        end
        else if (id_ex.ctrl.is_csr) begin
            out.ex_res = id_ex.rs2;
        end
        else if (id_ex.ctrl.is_lui) begin  // mux-ing alu_src1 to 0 is even uglier; requires mux-ing f3 n' f7 as well...
            out.ex_res = id_ex.imm;
        end
        else begin
            out.ex_res = alu_out;
        end

        out.pc     = id_ex.pc;
        out.rs2    = id_ex.ctrl.is_csr ? csr_w_data : rs2_fwd;
        out.rd     = id_ex.rd;
        out.rs1_a  = id_ex.rs1_a;
        out.rs2_a  = id_ex.rs2_a;
        out.f3     = id_ex.f3;
        out.ctrl   = id_ex.ctrl;
        out.exc    = id_ex.exc;
    end


// // ============================================================
// // VERILATOR EX DEBUG
// // ============================================================

// logic        dbg_valid        /* verilator public_flat */;
// logic [63:0] dbg_pc           /* verilator public_flat */;
// logic [63:0] dbg_imm          /* verilator public_flat */;

// logic [4:0]  dbg_rs1_a        /* verilator public_flat */;
// logic [4:0]  dbg_rs2_a        /* verilator public_flat */;
// logic [4:0]  dbg_rd           /* verilator public_flat */;

// logic [2:0]  dbg_f3            /* verilator public_flat */;
// logic [6:0]  dbg_f7            /* verilator public_flat */;

// logic [63:0] dbg_rs1_fwd       /* verilator public_flat */;
// logic [63:0] dbg_rs2_fwd       /* verilator public_flat */;

// logic [63:0] dbg_alu_in1       /* verilator public_flat */;
// logic [63:0] dbg_alu_in2       /* verilator public_flat */;
// logic [63:0] dbg_alu_out       /* verilator public_flat */;

// logic        dbg_take_br       /* verilator public_flat */;
// logic [63:0] dbg_br_targ       /* verilator public_flat */;

// logic        dbg_ctrl_br       /* verilator public_flat */;
// logic        dbg_ctrl_jmp      /* verilator public_flat */;
// logic        dbg_ctrl_lui      /* verilator public_flat */;
// logic        dbg_ctrl_pc1      /* verilator public_flat */;
// logic        dbg_ctrl_imm2     /* verilator public_flat */;
// logic        dbg_ctrl_wd       /* verilator public_flat */;

// assign dbg_valid = id_ex.ctrl.valid;
// assign dbg_pc    = id_ex.pc;
// assign dbg_imm   = id_ex.imm;

// assign dbg_rs1_a = id_ex.rs1_a;
// assign dbg_rs2_a = id_ex.rs2_a;
// assign dbg_rd    = id_ex.rd;

// assign dbg_f3 = id_ex.f3;
// assign dbg_f7 = id_ex.f7;

// assign dbg_rs1_fwd = rs1_fwd;
// assign dbg_rs2_fwd = rs2_fwd;

// assign dbg_alu_in1 = alu_in1;
// assign dbg_alu_in2 = alu_in2;
// assign dbg_alu_out = alu_out;

// assign dbg_take_br = take_br;
// assign dbg_br_targ = br_targ;

// assign dbg_ctrl_br  = id_ex.ctrl.br;
// assign dbg_ctrl_jmp = id_ex.ctrl.jmp;
// assign dbg_ctrl_lui = id_ex.ctrl.is_lui;

// assign dbg_ctrl_pc1  = id_ex.ctrl.alu_src1_pc;
// assign dbg_ctrl_imm2 = id_ex.ctrl.alu_src2_imm;
// assign dbg_ctrl_wd   = id_ex.ctrl.is_wd_op;

endmodule
