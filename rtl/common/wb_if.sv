interface wb_if;
    logic        valid;
    logic [4:0]  rd;
    logic [63:0] data;

    modport master (
        output valid, rd, data
    );

    modport slave (
        input valid, rd, data
    );
endinterface
