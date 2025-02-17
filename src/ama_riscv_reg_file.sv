`include "ama_riscv_defines.svh"

module ama_riscv_reg_file (
    input  logic        clk,
    input  logic        we,
    input  logic [ 4:0] addr_a,
    input  logic [ 4:0] addr_b,
    input  logic [ 4:0] addr_d,
    input  logic [31:0] data_d,
    output logic [31:0] data_a,
    output logic [31:0] data_b
);

logic [31:0] rf [31:1];

// synchronous register write back
always_ff @(posedge clk) begin
    if (we == 1'b1 && addr_d != `RF_X0_ZERO) rf[addr_d] <= data_d;
end

// asynchronous register read
always_comb begin
    if (addr_a == `RF_X0_ZERO) data_a = 32'h0;
    else data_a = rf[addr_a];
    if (addr_b == `RF_X0_ZERO) data_b = 32'h0;
    else data_b = rf[addr_b];
end

endmodule
