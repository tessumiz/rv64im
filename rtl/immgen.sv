import defs_pkg::*;

module immgen(
    input  logic [31:0] ins,
    output logic [63:0] imm
);
    logic [4:0] op;
    logic is_i, is_s, is_b, is_u, is_j;

    always_comb begin
        op = ins[6:2];

        is_i = (op == OP_IMM || op == OP_IMMW || op == OP_LD || op == OP_JALR);
        is_s = (op == OP_ST);
        is_b = (op == OP_BR);
        is_u = (op == OP_LUI || op == OP_AU);
        is_j = (op == OP_JAL);

        imm[63:32] = {32{ins[31]}};

        imm[31:20] = is_u ? ins[31:20] : {12{ins[31]}};

        imm[19:12] = (is_u || is_j) ? ins[19:12] : {8{ins[31]}};

        imm[11]    = is_b ? ins[7]  :
                     is_u ? 1'b0    :
                     is_j ? ins[20] :
                            ins[31] ;

        imm[10:5]  = is_u ? 6'b0 : ins[30:25];

        imm[4:1]   = is_u ? 4'b0 :
                     (is_s || is_b) ? ins[11:8] :
                                      ins[24:21];

        imm[0]     = is_s ? ins[7]  :
                     is_i ? ins[20] : 1'b0;
    end
endmodule
