import defs_pkg::*;


module pipeline(
    input logic clk,
    input logic rst_n
);
    // Fetch
    logic [31:0] instr;
    logic if_id_fls;
    logic if_id_stall;

    logic [63:0] pc;
    logic take_br;
    logic [63:0] br_targ;

    // IF_ID
    logic [63:0] if_id_pc;
    logic [31:0] if_id_ins;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || if_id_fls) begin
            if_id_pc  <= 0;
            if_id_ins <= 0;
            pc <= 0;
        end
        else if (!if_id_stall) begin
            if_id_pc  <= pc;
            if_id_ins <= instr;

            pc <= take_br ? br_targ : pc + 4;
        end
    end

    imem u_imem (
        .addr (pc[31:0]),
        .r_en (1'b1),

        .data (instr)
    );


    // Decode
    logic [31:0] ins;
    logic [4:0]  rs1_a;
    logic [4:0]  rs2_a;
    logic [4:0]  rd;
    logic [2:0]  f3;
    logic [6:0]  f7;
    ctrl_t       ctrl;

    decoder decoder_inst (
        .*
    );

    logic [63:0] rs1;
    logic [63:0] rs2;
    logic [63:0] wb_data;
    logic        wb_en;

    regfile u_regfile (
        .*
    );

    logic [63:0] imm;

    immgen u_immgen (
        .*
    );

    // ID_EX
    logic id_ex_fls, id_ex_stall;

    ctrl_t id_ex_ctrl;
    logic [4:0]  id_ex_rd;
    logic [4:0]  id_ex_rs1_a;
    logic [4:0]  id_ex_rs2_a;
    logic [63:0] id_ex_rs1;
    logic [63:0] id_ex_rs2;
    logic [63:0] id_ex_imm;
    logic [63:0] id_ex_pc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || id_ex_fls) begin
            id_ex_ctrl <= 0;
        end else if (!id_ex_stall) begin
            id_ex_ctrl <= ctrl;
            id_ex_rd   <= rd;
            id_ex_rs1  <= rs1;
            id_ex_rs2  <= rs2;
            id_ex_imm  <= imm;
            id_ex_pc   <= if_id_pc;
        end
    end


    // Execute
    logic rs1_mem_fwd;
    logic rs2_mem_fwd;
    logic rs1_wb_fwd;
    logic rs2_wb_fwd;

    logic [63:0] rs1_fwded;
    logic [63:0] rs2_fwded;
    logic [63:0] alu_in1;
    logic [63:0] alu_in2;

    always_comb begin
        rs1_fwded = rs1_mem_fwd ? ex_mem_alu_out : (rs1_wb_fwd ? wb_data : id_ex_rs1);
        rs2_fwded = rs2_mem_fwd ? ex_mem_alu_out : (rs2_wb_fwd ? wb_data : id_ex_rs2);

        alu_in1 = id_ex_ctrl.alu_src1_pc  ? id_ex_pc  : rs1_fwded;
        alu_in2 = id_ex_ctrl.alu_src2_imm ? id_ex_imm : rs2_fwded;
    end

    logic [63:0] alu_out;
    logic [3:0]  alu_op = { id_ex_ctrl.f7[5], id_ex_ctrl.f3 };

    alu u_alu (
        .a      (alu_in1),
        .b      (alu_in2),
        .alu_op   (alu_op),
        .is_word_op (id_ex_ctrl.is_word_op),

        .alu_out (alu_out)
    );

    assign br_targ = alu_out & ~1;

    bcu u_bcu (
        .rs1 (rs1_fwded),
        .rs2 (rs2_fwded),
        .is_br (is_br),
        .is_jmp (is_jmp),
        .f3 (f3),

        .take_br (take_br)
    );

    // EX_MEM
    logic ex_mem_fls, ex_mem_stall;
    ctrl_t       ex_mem_ctrl;
    logic [63:0] ex_mem_alu_out;
    logic [63:0] ex_mem_rs2;
    logic [4:0]  ex_mem_rd;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ex_mem_fls) begin
            ex_mem_ctrl <= 0;
        end else if (!ex_mem_stall) begin
            ex_mem_ctrl    <= id_ex_ctrl;
            ex_mem_alu_out <= alu_out;
            ex_mem_rs2     <= rs2_fwded;
            ex_mem_rd      <= id_ex_rd;
        end
    end


    // Mem
    logic [63:0] mem_rdata;

    dmem u_dmem (
        .clk  (clk),
        .addr (ex_mem_alu_out[31:0]),
        .wdata(ex_mem_rs2),
        .w_en (ex_mem_ctrl.mem_w),
        .r_en (ex_mem_ctrl.mem_r),

        .rdata(mem_rdata)
    );

    // MEM_WB
    logic mem_wb_fls, mem_wb_stall;
    ctrl_t       mem_wb_ctrl;
    logic [4:0]  mem_wb_rd;
    logic [63:0] mem_wb_wdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || mem_wb_fls) begin
            mem_wb_ctrl <= 0;
        end else if (!mem_wb_stall) begin
            mem_wb_ctrl  <= ex_mem_ctrl;
            mem_wb_rd    <= ex_mem_rd;
            mem_wb_wdata <= ex_mem_ctrl.mem_r ? mem_rdata : ex_mem_alu_out;
        end
    end

    // Writeback
    assign wb_data = mem_wb_wdata;
    assign wb_en   = mem_wb_ctrl.reg_w_en;

    // Fwding
    fwd u_fwd (
        .id_ex_rs1_a  (id_ex_rs1_a),
        .id_ex_rs2_a  (id_ex_rs2_a),

        .ex_mem_wb    (ex_mem_ctrl.reg_w_en),
        .ex_mem_rd    (ex_mem_rd),

        .mem_wb_wb    (mem_wb_ctrl.reg_w_en),
        .wb_a         (mem_wb_rd),

        .rs1_mem_fwd  (rs1_mem_fwd),
        .rs1_wb_fwd   (rs1_wb_fwd),
        .rs2_mem_fwd  (rs2_mem_fwd),
        .rs2_wb_fwd   (rs2_wb_fwd)
    );

    // Hazards
    logic ld_use_haz;

    haz_det u_haz_det (
        .id_ex_memr (id_ex_ctrl.mem_r_en),
        .op         (id_ex_ctrl.op),
        .rd         (id_ex_rd),
        .if_id_rs1  (rs1_a),
        .if_id_rs2  (rs2_a),

        .ld_use_haz (ld_use_haz)
    );

    assign if_id_stall = ld_use_haz;
    assign id_ex_fls   = take_br;

endmodule
