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
            pc <= 0;  // coupled...
        end
        else if (!if_id_stall) begin
            if_id_pc  <= pc;
            if_id_ins <= instr;

            pc <= take_br ? br_targ : pc + 4;  // coupled to if_id_stall...
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
    logic [2:0]  id_ex_f3;
    logic [6:0]  id_ex_f7;

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
            id_ex_rs1_a <= rs1_a;
            id_ex_rs2_a <= rs2_a;
            id_ex_f3   <= f3;
            id_ex_f7   <= f7;
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
    logic [3:0]  alu_op = { id_ex_f7[5], id_ex_f3 };

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
        .is_br (id_ex_ctrl.br),
        .is_jmp (id_ex_ctrl.jmp),
        .f3 (id_ex_f3),

        .take_br (take_br)
    );

    // EX_MEM
    logic ex_mem_fls, ex_mem_stall;
    ctrl_t       ex_mem_ctrl;  // tools remove dead code, so the whole of ctrl_t wouldn't be synthed
    logic [63:0] ex_mem_alu_out;
    logic [63:0] ex_mem_rs2;
    logic [4:0]  ex_mem_rd;
    logic [2:0]  ex_mem_f3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ex_mem_fls) begin
            ex_mem_ctrl <= 0;
        end else if (!ex_mem_stall) begin
            ex_mem_ctrl    <= id_ex_ctrl;
            ex_mem_alu_out <= alu_out;
            ex_mem_rs2     <= rs2_fwded;
            ex_mem_rd      <= id_ex_rd;
            ex_mem_f3      <= id_ex_f3;
        end
    end


    // Mem
    logic [63:0] unfmt_rdata;
    logic [63:0] fmt_wdata;
    logic [31:0] mem_addr = ex_mem_alu_out[31:0];

    always_comb begin
        unique case (ex_mem_f3[1:0])
            2'b00: fmt_wdata = {8{ex_mem_rs2[7:0]}};
            2'b01: fmt_wdata = {4{ex_mem_rs2[15:0]}};
            2'b10: fmt_wdata = {2{ex_mem_rs2[31:0]}};
            2'b11: fmt_wdata = ex_mem_rs2;
        endcase
    end

    dmem u_dmem (
        .clk  (clk),
        .addr (mem_addr),
        .f3_2 (ex_mem_f3[1:0]),
        .wdata(fmt_wdata),
        .w_en (ex_mem_ctrl.mem_w),
        .r_en (ex_mem_ctrl.mem_r),

        .rdata(unfmt_rdata)
    );

    logic [63:0] shft_rdata;
    logic [63:0] mem_rdata;

    always_comb begin
        shft_rdata = unfmt_rdata >> {mem_addr[2:0], 3'b0};

        case (ex_mem_f3)
            3'b011: mem_rdata = shft_rdata;

            3'b000: mem_rdata = {{56{shft_rdata[7]}}, shft_rdata[7:0]};
            3'b001: mem_rdata = {{48{shft_rdata[15]}}, shft_rdata[15:0]};
            3'b010: mem_rdata = {{32{shft_rdata[31]}}, shft_rdata[31:0]};

            3'b100: mem_rdata = {56'b0, shft_rdata[7:0]};
            3'b101: mem_rdata = {48'b0, shft_rdata[15:0]};
            3'b110: mem_rdata = {32'b0, shft_rdata[31:0]};

            default: mem_rdata = 64'b0;
        endcase
    end

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
    assign wb_en   = mem_wb_ctrl.wb;

    // Fwding
    fwd u_fwd (
        .id_ex_rs1_a  (id_ex_rs1_a),
        .id_ex_rs2_a  (id_ex_rs2_a),

        .ex_mem_wb    (ex_mem_ctrl.wb),
        .ex_mem_rd    (ex_mem_rd),

        .mem_wb_wb    (mem_wb_ctrl.wb),
        .wb_a         (mem_wb_rd),

        .rs1_mem_fwd  (rs1_mem_fwd),
        .rs1_wb_fwd   (rs1_wb_fwd),
        .rs2_mem_fwd  (rs2_mem_fwd),
        .rs2_wb_fwd   (rs2_wb_fwd)
    );

    // Hazards
    logic ld_use_haz;

    haz_det u_haz_det (
        .id_ex_memr (id_ex_ctrl.mem_r),
        .if_id_ins  (if_id_ins),
        .id_ex_rd   (id_ex_rd),

        .ld_use_haz (ld_use_haz)
    );

    assign if_id_stall = ld_use_haz;
    assign if_id_fls   = take_br;
    assign id_ex_fls   = take_br;

endmodule
