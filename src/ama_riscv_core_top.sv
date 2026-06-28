`include "ama_riscv_defines.svh"

module ama_riscv_core_top #(
    parameter unsigned CLOCK_FREQ = 100_000_000 // Hz
)(
    input  logic clk,
    input  logic rst,
    rv_if.TX     req_imem,
    rv_if.RX     rsp_imem,
    rv_if.TX     req_dmem_r,
    rv_if_da.TX  req_dmem_w,
    rv_if.RX     rsp_dmem,
    uart_if.TX   uart_ch,
    input  logic meip,
    output logic inst_retired
);

// core <-> icache
rv_if #(.DW(CORE_WORD_ADDR_BUS)) imem_req_ch ();
rv_if #(.DW(INST_WIDTH)) imem_rsp_ch ();
spec_exec_t spec;
perf_event_icache_t pe_ic;

// core <-> dcache
rv_if_dc #(.AW(CORE_BYTE_ADDR_BUS), .DW(ARCH_WIDTH)) dmem_req_ch ();
rv_if #(.DW(ARCH_WIDTH)) dmem_rsp_ch ();
perf_event_dcache_t pe_dc;

// core <-> clint
clint_if clint_ch ();
logic mtip;

//------------------------------------------------------------------------------
ama_riscv_core #(
    .SIMD_EN (CPU_SIMD_EN),
    .MULT_USE_BW (CPU_MULT_USE_BW)
) core_i (
    .clk,
    .rst,
    .pe_ic,
    .pe_dc,
    .imem_req (imem_req_ch),
    .imem_rsp (imem_rsp_ch),
    .dmem_req (dmem_req_ch),
    .dmem_rsp (dmem_rsp_ch),
    .uart_ch,
    .clint_ch,
    .mtip,
    .meip,
    .spec,
    .inst_retired
);

ama_riscv_icache #(
    .SETS (ICACHE_SETS),
    .WAYS (ICACHE_WAYS)
) icache_i (
    .clk (clk),
    .rst (rst),
    .spec (spec),
    .pe (pe_ic),
    .req_core (imem_req_ch.RX),
    .rsp_core (imem_rsp_ch.TX),
    .req_mem (req_imem),
    .rsp_mem (rsp_imem)
);

ama_riscv_dcache #(
    .SETS (DCACHE_SETS),
    .WAYS (DCACHE_WAYS)
) dcache_i (
    .clk (clk),
    .rst (rst),
    .pe (pe_dc),
    .req_core (dmem_req_ch.RX),
    .rsp_core (dmem_rsp_ch.TX),
    .req_mem_r (req_dmem_r),
    .req_mem_w (req_dmem_w),
    .rsp_mem (rsp_dmem)
);

ama_riscv_clint #(
    .CLOCK_FREQ(CLOCK_FREQ)
) clint_i (
    .clk,
    .rst,
    .mmio (clint_ch),
    .mtip
);

endmodule
