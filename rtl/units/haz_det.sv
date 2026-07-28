import defs_pkg::*;

module haz_det(
    input logic        id_ex_mem_r,
    input logic [31:0] if_id_ins,
    input logic [4:0]  id_ex_rd,

    output logic ld_use_haz
);
    logic [4:0] op, rs1, rs2;
    logic has_rs1, has_rs2;

    always_comb begin
        op  = if_id_ins[6:2];
        rs1 = if_id_ins[19:15];
        rs2 = if_id_ins[24:20];

        has_rs1 = (op == OP_BR)   || (op == OP_LD)   || 
                  (op == OP_ST)   || (op == OP_IMM)  || 
                  (op == OP_IMMW) || (op == OP_REG)  || 
                  (op == OP_REGW) || (op == OP_JALR);

        has_rs2 = (op == OP_BR)   || (op == OP_ST)   || 
                  (op == OP_REG)  || (op == OP_REGW);

        ld_use_haz = id_ex_mem_r & (id_ex_rd != 5'b0) & (
                     has_rs1 & (rs1 == id_ex_rd) |
                     has_rs2 & (rs2 == id_ex_rd)
        );
    end

endmodule
