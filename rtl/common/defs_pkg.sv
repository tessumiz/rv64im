package defs_pkg;

    localparam logic [4:0]
        OP_LD   = 5'b00000,
        OP_ST   = 5'b01000,
        OP_IMM  = 5'b00100,
        OP_REG  = 5'b01100,
        OP_IMMW = 5'b00110,
        OP_REGW = 5'b01110,
        OP_BR   = 5'b11000,
        OP_JAL  = 5'b11011,
        OP_JALR = 5'b11001,
        OP_LUI  = 5'b01101,
        OP_AU   = 5'b00101,
        OP_FEN  = 5'b00011,
        OP_SYS  = 5'b11100;

    localparam logic [2:0]
        BEQ=3'b000, BNE=3'b001, BLT=3'b100, BGE=3'b101, BLTU=3'b110, BGEU=3'b111,

        LB =3'b000, LH =3'b001, LW =3'b010, LD =3'b011, LBU =3'b100, LHU =3'b101, LWU =3'b110,
        SB =3'b000, SH =3'b001, SW =3'b010, SD =3'b011,

        ADD=3'b000, SLL=3'b001, SLT=3'b010, SLTU=3'b011,
        XOR=3'b100, SRL=3'b101, OR =3'b110, AND=3'b111,

        MUL=3'b000, MULH=3'b001, MULHSU=3'b010, MULHU=3'b011,
        DIV=3'b100, DIVU=3'b101, REM=3'b110, REMU=3'b111;


    localparam logic [6:0]
        F7_0 = 7'b0000000,
        F7_1 = 7'b0000001,
        F7_2 = 7'b0100000;

    localparam logic [1:0]
        MEM_BYTE = 2'b00,
        MEM_HWORD = 2'b01,
        MEM_WORD = 2'b10,
        MEM_DWORD = 2'b11;


    typedef struct packed {
        logic valid;

        logic alu_src1_pc;
        logic alu_src2_imm;
        logic is_mul;
        logic is_div;
        logic is_wd_op;
        logic is_lui;
        logic br;
        logic jmp;
        logic mem_r;
        logic mem_w;
        logic wb;

        logic is_csr;
        logic csr_we;
        logic is_zimm;
    } ctrl_t;

    typedef struct packed {
        logic valid;

        logic is_mret;
        logic is_sret;

        logic [63:0] cause;
        logic [63:0] tval;
    } exc_t;

    typedef struct packed {
        logic ext_int;
        logic tmr_int;
        logic sft_int;
    } irq_t;


    typedef struct packed {
        logic [63:0] pc;
        logic [31:0] ins;

        exc_t exc;
    } if_id_t;


    typedef struct packed {
        logic [63:0] pc;
        logic [63:0] rs1;
        logic [63:0] rs2;  // or csr_r_data
        logic [4:0]  rd;
        logic [4:0]  rs1_a;
        logic [4:0]  rs2_a;
        logic [63:0] imm;
        logic [2:0]  f3;
        logic [6:0]  f7;

        ctrl_t ctrl;
        exc_t  exc;
    } id_ex_t;


    typedef struct packed {
        logic [63:0] pc;
        logic [63:0] ex_res; // or csr_new_data
        logic [63:0] rs2;  // or csr_addr
        logic [11:0] csr_w_addr;
        logic [4:0]  rd;
        logic [4:0]  rs1_a;
        logic [4:0]  rs2_a;
        logic [2:0]  f3;

        ctrl_t ctrl;
        exc_t  exc;
    } ex_mem_t;


    typedef struct packed {
        logic [63:0] pc;
        logic [4:0]  rd;
        logic [4:0]  rs1_a;
        logic [4:0]  rs2_a;
        logic [63:0] data; // or csr_old_data
        logic [63:0] csr_new_data;
        logic [11:0] csr_addr;

        ctrl_t ctrl;
        exc_t  exc;
    } mem_wb_t;


    typedef struct packed {
        logic mem_fwd_rs1;
        logic mem_fwd_rs2;
        logic wb_fwd_rs1;
        logic wb_fwd_rs2;
    } fwd_sig_t;

endpackage
