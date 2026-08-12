package zicsr_pkg;
    localparam logic [11:0] 
        CSR_MSTATUS   = 12'h300,
        CSR_MTVEC     = 12'h305,
        CSR_MCAUSE    = 12'h342,
        CSR_MEPC      = 12'h341,
        CSR_MTVAL     = 12'h343,
        CSR_MSCRATCH  = 12'h340,

        CSR_SSTATUS   = 12'h100,
        CSR_STVEC     = 12'h105,
        CSR_SCAUSE    = 12'h142,
        CSR_SEPC      = 12'h141,
        CSR_STVAL     = 12'h143,
        CSR_SSCRATCH  = 12'h140,

        CSR_MIE       = 12'h304,
        CSR_MIP       = 12'h344,
        CSR_MIDELEG   = 12'h303,
        CSR_MEDELEG   = 12'h302,
        
        CSR_SATP      = 12'h180;

    localparam logic [1:0]
        PRIV   = 0,  // priv instr
        CSR_RW = 2'b01,
        CSR_RS = 2'b10,
        CSR_RC = 2'b11;
    
    localparam logic [1:0] CSR_ADDR_RO = 2'b11;

    localparam logic [11:0]
        ECALL = 12'h000,
        MRET  = 12'h302,
        SRET  = 12'h102;


    localparam int unsigned
        MSTATUS_SIE  = 1,
        MSTATUS_MIE  = 3,
        MSTATUS_SPIE = 5,
        MSTATUS_MPIE = 7,
        MSTATUS_SPP  = 8,
        MSTATUS_MPP  = 12,  // high bit

        MSTATUS_S_MASK = (1 << MSTATUS_SIE) | (1 << MSTATUS_SPIE) | (3 << MSTATUS_SPP);
    
    localparam int unsigned
        EXT_INT  = 11,
        TMR_INT  = 7,
        SFT_INT  = 3;

    localparam logic [1:0] VEC_MODE = 2'b01;

    localparam int unsigned
        EXC_ILLEGAL_INSTR = 2,

        EXC_INSTR_MISALIGNED = 0,
        EXC_LOAD_MISALIGNED  = 4,
        EXC_STORE_MISALIGNED = 6,

        EXC_INSTR_ACCESS_FAULT = 1,
        EXC_LOAD_ACCESS_FAULT  = 5,
        EXC_STORE_ACCESS_FAULT = 7,

        EXC_INSTR_PAGE_FAULT = 12,
        EXC_LOAD_PAGE_FAULT  = 13,
        EXC_STORE_PAGE_FAULT = 15,

        EXC_ECALL_M = 11,
        EXC_ECALL_S = 9,
        EXC_ECALL_U = 8;
    
    localparam int unsigned
        PRIV_U = 2'b00,
        PRIV_S = 2'b01,
        PRIV_M = 2'b11;
endpackage
