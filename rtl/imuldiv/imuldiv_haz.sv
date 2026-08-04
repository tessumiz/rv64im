// waw / raw
module imuldiv_haz (
    input logic clk,
    input logic rst,

    input logic [4:0] rs1_a,
    input logic [4:0] rs2_a,
    input logic [4:0] rd,

    input logic has_rs1,
    input logic has_rs2,
    input logic has_rd,
    input logic if_id_stall,

    input logic is_imuldiv,
    input logic wb_en,
    input logic [4:0] wb_rd,

    output logic imuldiv_haz
);

    typedef enum logic [1:0] {
        NONE,
        MAIN_PIPE,
        IMULDIV
    } rsrv_t;

    rsrv_t rsrv[0:31];

    logic rs1_raw, rs2_raw, rd_waw;

    always_comb begin
        rs1_raw = has_rs1 && (rsrv[rs1_a] != NONE) && (is_imuldiv || rsrv[rs1_a] == IMULDIV);
        rs2_raw = has_rs2 && (rsrv[rs2_a] != NONE) && (is_imuldiv || rsrv[rs2_a] == IMULDIV);
        rd_waw  = has_rd && ((rsrv[rd] != NONE) && (is_imuldiv || rsrv[rd] == IMULDIV));

        imuldiv_haz = rs1_raw || rs2_raw || rd_waw;
    end


    always_ff @(posedge clk) begin
        rsrv[0] <= NONE;

        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                rsrv[i] <= NONE;
            end
        end
        else begin
            if (!if_id_stall && has_rd && (rd != 0)) begin
                rsrv[rd] <= is_imuldiv ? IMULDIV : MAIN_PIPE;
            end

            if ((wb_rd != 0) && !(!if_id_stall && has_rd && wb_rd == rd) && wb_en) begin
                rsrv[wb_rd] <= NONE;
            end
        end
    end
endmodule
