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

logic [31:0] rf [1:31];

// synchronous register writeback
`DFF_CI_EN((we && (addr_d != `RF_X0_ZERO)), data_d, rf[addr_d])

// asynchronous register read
always_comb begin
    if (addr_a == `RF_X0_ZERO) data_a = 'h0;
    else data_a = rf[addr_a];
    if (addr_b == `RF_X0_ZERO) data_b = 'h0;
    else data_b = rf[addr_b];
end

endmodule
