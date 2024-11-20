`include "ama_riscv_defines.v"

module ama_riscv_reg_file (
    input  wire        clk,
    input  wire        we,
    input  wire [ 4:0] addr_a,
    input  wire [ 4:0] addr_b,
    input  wire [ 4:0] addr_d,
    input  wire [31:0] data_d,
    output reg  [31:0] data_a,
    output reg  [31:0] data_b
);

reg [31:0] rf [31:1];

// synchronous register write back
always @ (posedge clk) begin
     if (we == 1'b1 && addr_d != `RF_X0_ZERO) rf[addr_d] <= data_d;
end

// asynchronous register read
always @ (*) begin
    if (addr_a == `RF_X0_ZERO) data_a = 32'h0;
    else data_a = rf[addr_a];
    if (addr_b == `RF_X0_ZERO) data_b = 32'h0;
    else data_b = rf[addr_b];
end

endmodule
