module ld_use_haz(
    input logic       id_ex_mem_r,

    input logic [4:0] rs1_a,
    input logic [4:0] rs2_a,
    input logic [4:0] id_ex_rd,

    output logic ld_use_haz
);

    logic has_rs1, has_rs2, has_rd;

    always_comb begin
        has_rs1 = (rs1_a != 0);
        has_rs2 = (rs2_a != 0);
        has_rd  = (id_ex_rd != 0);

        ld_use_haz = id_ex_mem_r & has_rd & (
            (has_rs1 & (rs1_a == id_ex_rd)) |
            (has_rs2 & (rs2_a == id_ex_rd))
        );
    end

endmodule
