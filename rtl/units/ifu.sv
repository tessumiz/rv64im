import mem_pkg::*;


module ifu (
    input               clk,
    input               rst,

    input mmu_ctx_t     mmu_ctx,
    input logic [63:0]  pc,
    input               valid,

    output logic [31:0] instr,

    output logic        page_fault,
    output logic        access_fault,
    output logic        misaligned_load,

    output logic        busy,
    output logic        ready
);

    tlb_if #(
        .DATA_T(itlb_data_t),
        .TAG_T (itlb_tag_t),
        .SETS  (ITLB_SETS),
        .WAYS  (ITLB_WAYS)
    ) itlb_bus ();

    tlb u_itlb (
        .clk(clk),
        .rst(rst),
        .bus(itlb_bus)
    );


    set_cache_if #(
        .DATA_T(icache_data_t),
        .TAG_T (icache_tag_t),
        .SETS  (ICACHE_SETS),
        .WAYS  (ICACHE_WAYS)
    ) icache_bus ();

    set_cache u_icache (
        .clk(clk),
        .rst(rst),

        .bus(icache_bus)
    );

    
    // please don't rely on ugly macros like `define I itlb_bus; try to make the intfs take structs instead
endmodule
