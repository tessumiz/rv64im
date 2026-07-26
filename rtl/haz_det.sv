import defs_pkg::*;


module haz_det(
    input logic       id_ex_memr,
    input logic [4:0] op,
    input logic [4:0] rd,
    input logic [4:0] if_id_rs1,
    input logic [4:0] if_id_rs2,

    output logic ld_use_haz
);
    always_comb begin
        logic has_rs1 = (op == OP_BR)   || (op == OP_LD)   || 
                  (op == OP_ST)   || (op == OP_IMM)  || 
                  (op == OP_IMMW) || (op == OP_REG)  || 
                  (op == OP_REGW) || (op == OP_JALR);

        logic has_rs2 = (op == OP_BR)   || (op == OP_ST)   || 
                  (op == OP_REG)  || (op == OP_REGW);

        ld_use_haz = id_ex_memr & (rd != 5'b0) & (
                     has_rs1 & (if_id_rs1 == rd) |
                     has_rs2 & (if_id_rs2 == rd)
        );
    end
    
endmodule