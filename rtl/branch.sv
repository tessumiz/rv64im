module bcu (
    input  logic [63:0] rs1,
    input  logic [63:0] rs2,
    input  logic        is_br,
    input  logic        is_jmp,
    input  logic [2:0]  f3,

    output logic        take_br
);

    logic cond_met;

    always_comb begin
        cond_met = 1'b0;

        case (f3)
            3'b000: cond_met = (rs1 == rs2);
            3'b001: cond_met = (rs1 != rs2);
            3'b100: cond_met = ($signed(rs1) <  $signed(rs2));
            3'b101: cond_met = ($signed(rs1) >= $signed(rs2));
            3'b110: cond_met = (rs1 < rs2);
            3'b111: cond_met = (rs1 >= rs2);
            default: cond_met = 1'b0;
        endcase
        
        take_br = is_jmp | (is_br & cond_met);
    end

endmodule