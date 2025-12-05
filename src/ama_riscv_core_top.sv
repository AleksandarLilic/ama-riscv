`include "ama_riscv_defines.svh"

module ama_riscv_core_top (
    input  logic clk,
    input  logic rst,
    rv_if.TX     req_imem,
    rv_if.RX     rsp_imem,
    rv_if.TX     req_dmem_r,
    rv_if_da.TX  req_dmem_w,
    rv_if.RX     rsp_dmem,
    uart_if.TX   uart_ch,
    output logic inst_retired
);

// core <-> icache
rv_if #(.DW(CORE_WORD_ADDR_BUS)) imem_req_ch ();
rv_if #(.DW(INST_WIDTH)) imem_rsp_ch ();
logic spec_wrong;

// core <-> dcache
rv_if_dc #(.AW(CORE_BYTE_ADDR_BUS), .DW(ARCH_WIDTH)) dmem_req_ch ();
rv_if #(.DW(ARCH_WIDTH)) dmem_rsp_ch ();

ama_riscv_core ama_riscv_core_i(
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req_ch.TX),
    .imem_rsp (imem_rsp_ch.RX),
    .dmem_req (dmem_req_ch),
    .dmem_rsp (dmem_rsp_ch),
    .uart_ch (uart_ch),
    .spec_wrong (spec_wrong),
    .inst_retired (inst_retired)
);

ama_riscv_icache #(
    .SETS (ICACHE_SETS),
    .WAYS (ICACHE_WAYS)
) ama_riscv_icache_i (
    .clk (clk),
    .rst (rst),
    .spec_wrong (spec_wrong),
    .req_core (imem_req_ch.RX),
    .rsp_core (imem_rsp_ch.TX),
    .req_mem (req_imem),
    .rsp_mem (rsp_imem)
);

ama_riscv_dcache #(
    .SETS (DCACHE_SETS),
    .WAYS (DCACHE_WAYS)
) ama_riscv_dcache_i (
    .clk (clk),
    .rst (rst),
    .req_core (dmem_req_ch.RX),
    .rsp_core (dmem_rsp_ch.TX),
    .req_mem_r (req_dmem_r),
    .req_mem_w (req_dmem_w),
    .rsp_mem (rsp_dmem)
);

endmodule
