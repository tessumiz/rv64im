interface tilelink_ul_64 #(
    parameter int AW = 32,
    parameter int DW = 64,
    parameter int SW = 4  // src width (id of the requester, usually 4-8 bits)
);

    // ---------------------------------------------------------
    // Channel A (Master Request -> Slave)
    // ---------------------------------------------------------
    logic            a_valid;
    logic            a_ready;
    logic [2:0]      a_opcode;  // 0: PutFull, 1: PutPartial, 4: Get
    logic [2:0]      a_param;   // Always 0 for TL-UL
    logic [2:0]      a_size;    // 2^size bytes (0=1B, 1=2B, 2=4B, 3=8B)
    logic [SW-1:0]   a_source;  // Master ID
    logic [AW-1:0]   a_address; // Must be aligned to a_size
    logic [(DW/8)-1:0] a_mask;  // 8-bit mask for 64-bit data
    logic [DW-1:0]   a_data;    // 64-bit payload
    logic            a_corrupt; // Usually 0

    // ---------------------------------------------------------
    // Channel D (Slave Response -> Master)
    // ---------------------------------------------------------
    logic            d_valid;
    logic            d_ready;
    logic [2:0]      d_opcode;  // 0: AccessAck, 1: AccessAckData
    logic [1:0]      d_param;   // Always 0 for TL-UL
    logic [2:0]      d_size;    // Must match a_size of request
    logic [SW-1:0]   d_source;  // Must match a_source of request
    logic            d_sink;    // Slave ID (can be 0 for simple CLINT)
    logic            d_denied;  // 1 if access violated permissions/address
    logic [DW-1:0]   d_data;    // 64-bit read payload
    logic            d_corrupt; // 1 if data is corrupted (usually 0)

    // Master port modport (Used by your CPU's Load/Store Unit)
    modport Master (
        output a_valid, a_opcode, a_param, a_size, a_source, a_address, a_mask, a_data, a_corrupt, d_ready,
        input  a_ready, d_valid, d_opcode, d_param, d_size, d_source, d_sink, d_denied, d_data, d_corrupt
    );

    // Slave port modport (Used by your CLINT and Memory)
    modport Slave (
        input  a_valid, a_opcode, a_param, a_size, a_source, a_address, a_mask, a_data, a_corrupt, d_ready,
        output a_ready, d_valid, d_opcode, d_param, d_size, d_source, d_sink, d_denied, d_data, d_corrupt
    );

endinterface
