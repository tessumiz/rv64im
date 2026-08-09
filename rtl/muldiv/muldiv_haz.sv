// flush and mem fault exception behaviour pending...

module muldiv_haz (
    input logic clk,
    input logic rst,

    input logic [4:0] rs1_a,
    input logic [4:0] rs2_a,
    input logic [4:0] rd,

    input logic if_id_stall,

    input logic is_muldiv,
    input logic wb_en,
    input logic [4:0] wb_rd,

    output logic muldiv_haz
);

    typedef enum logic [1:0] {
        NONE,
        MAIN_PIPE,
        IMULDIV
    } rsrv_t;

    rsrv_t rsrv[0:31];

    logic has_rs1;
    logic has_rs2;
    logic has_rd;
    logic has_wb_rd;

    logic rs1_raw, rs2_raw, rd_waw;

    always_comb begin
        has_rs1   = (rs1_a != 0);
        has_rs2   = (rs2_a != 0);
        has_rd    = (rd    != 0);
        has_wb_rd = (wb_rd != 0);

        rs1_raw = has_rs1 && (rsrv[rs1_a] != NONE) && (is_muldiv || rsrv[rs1_a] == IMULDIV);
        rs2_raw = has_rs2 && (rsrv[rs2_a] != NONE) && (is_muldiv || rsrv[rs2_a] == IMULDIV);
        rd_waw  = has_rd  && (rsrv[rd]    != NONE) && (is_muldiv || rsrv[rd]    == IMULDIV);

        muldiv_haz = rs1_raw || rs2_raw || rd_waw;
    end

    always_ff @(posedge clk) begin
        rsrv[0] <= NONE;

        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                rsrv[i] <= NONE;
            end
        end
        else begin
            if (!if_id_stall && has_rd) begin
                rsrv[rd] <= is_muldiv ? IMULDIV : MAIN_PIPE;
            end

            if (wb_en && has_wb_rd && !(!if_id_stall && has_rd && (wb_rd == rd))) begin
                rsrv[wb_rd] <= NONE;
            end
        end
    end

endmodule
