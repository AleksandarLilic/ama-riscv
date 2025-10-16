`include "ama_riscv_defines.svh"

module ama_riscv_reg_file (
    input  logic        clk,
    input  logic        we,
    input  rf_addr_t    addr_a,
    input  rf_addr_t    addr_b,
    input  rf_addr_t    addr_d,
    input  arch_width_t data_d,
    output arch_width_t data_a,
    output arch_width_t data_b
);

arch_width_t rf [1:RF_NUM-1];

// synchronous register writeback
`DFF_CI_EN((we && (addr_d != RF_X0_ZERO)), data_d, rf[addr_d])

// asynchronous register read
always_comb begin
    if (addr_a == RF_X0_ZERO) data_a = 'h0;
    else data_a = rf[addr_a];
    if (addr_b == RF_X0_ZERO) data_b = 'h0;
    else data_b = rf[addr_b];
end

endmodule
