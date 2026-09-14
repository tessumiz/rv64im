module ram_arbiter (
    gen_mem_if.slave  ifu_bus,
    gen_mem_if.slave  dcu_bus,
    gen_mem_if.master ram_bus
);

    logic  dcu_active;
    assign dcu_active = dcu_bus.r_en || dcu_bus.w_en;

    // cpu to ram
    always_comb begin
        ram_bus.addr   = dcu_active ? dcu_bus.addr   : ifu_bus.addr;
        ram_bus.w_data = dcu_active ? dcu_bus.w_data : ifu_bus.w_data;
        ram_bus.r_en   = dcu_active ? dcu_bus.r_en   : ifu_bus.r_en;
        ram_bus.w_en   = dcu_active ? dcu_bus.w_en   : ifu_bus.w_en;
        ram_bus.w_mask = dcu_active ? dcu_bus.w_mask : ifu_bus.w_mask;
    end

    // ram to cpu
    always_comb begin
        dcu_bus.r_data  = ram_bus.r_data;
        ifu_bus.r_data  = ram_bus.r_data;

        dcu_bus.ready   = dcu_active ? ram_bus.ready : 0;
        ifu_bus.ready   = dcu_active ? 0 : ram_bus.ready;
    end
endmodule
