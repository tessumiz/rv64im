module ld_use_haz(
    input logic       id_ex_mem_r,

    input logic [4:0] rs1_a,
    input logic [4:0] rs2_a,
    input logic [4:0] id_ex_rd,

    input logic       has_rs1,
    input logic       has_rs2,

    output logic ld_use_haz
);
    assign ld_use_haz = id_ex_mem_r & (id_ex_rd != 5'b0) & (
        (has_rs1 & (rs1_a == id_ex_rd)) |
        (has_rs2 & (rs2_a == id_ex_rd))
    );

endmodule
