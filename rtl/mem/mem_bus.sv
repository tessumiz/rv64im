interface imem_if;
    logic [63:0] addr;
    logic        r_en;
    logic [31:0] data;

    modport master (
        output addr, r_en,
        input data
    );

    modport slave (
        input addr, r_en,
        output data
    );
endinterface


interface dmem_if;
    logic [63:0] addr;

    logic        r_en;
    logic [63:0] r_data;

    logic        w_en;
    logic [63:0] w_data;
    logic [1:0]  f3_2;

    logic        busy;

    modport master (
        output addr, f3_2, w_data, w_en, r_en,
        input  r_data, busy
    );

    modport slave (
        input  addr, f3_2, w_data, w_en, r_en,
        output r_data, busy
    );
endinterface
