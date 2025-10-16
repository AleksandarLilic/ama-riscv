`include "ama_riscv_defines.svh"

module ama_riscv_core_top (
    input  logic        clk,
    input  logic        rst,
    output logic        inst_retired
);

// IMEM
rv_if #(.DW(CORE_WORD_ADDR_BUS)) imem_req_ch ();
rv_if #(.DW(INST_WIDTH)) imem_rsp_ch ();

// DMEM
rv_if_dc #(.AW(CORE_BYTE_ADDR_BUS), .DW(ARCH_WIDTH)) dmem_req_ch ();
rv_if #(.DW(ARCH_WIDTH)) dmem_rsp_ch ();

// main mem <-> icache
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_imem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_imem ();
// main mem <-> dcache
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_dmem ();
rv_if_da #(.AW(MEM_ADDR_BUS), .DW(MEM_DATA_BUS)) mem_w_req_ch_dmem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_dmem ();

// core
ama_riscv_core ama_riscv_core_i(
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req_ch.TX),
    .imem_rsp (imem_rsp_ch.RX),
    .dmem_req (dmem_req_ch),
    .dmem_rsp (dmem_rsp_ch),
    .inst_retired (inst_retired)
);

ama_riscv_icache #(
    .SETS (4),
    .WAYS (2)
) ama_riscv_icache_i (
    .clk (clk),
    .rst (rst),
    .req_core (imem_req_ch.RX),
    .rsp_core (imem_rsp_ch.TX),
    .req_mem (mem_r_req_ch_imem.TX),
    .rsp_mem (mem_r_rsp_ch_imem.RX)
);

ama_riscv_dcache #(
    .SETS (8)
) ama_riscv_dcache_i (
    .clk (clk),
    .rst (rst),
    .req_core (dmem_req_ch.RX),
    .rsp_core (dmem_rsp_ch.TX),
    .req_mem_r (mem_r_req_ch_dmem.TX),
    .req_mem_w (mem_w_req_ch_dmem.TX),
    .rsp_mem (mem_r_rsp_ch_dmem.RX)
);

ama_riscv_mem ama_riscv_mem_i (
    .clk (clk),
    .rst (rst),
    .req_imem (mem_r_req_ch_imem.RX),
    .rsp_imem (mem_r_rsp_ch_imem.TX),
    .req_dmem_r (mem_r_req_ch_dmem.RX),
    .req_dmem_w (mem_w_req_ch_dmem.RX),
    .rsp_dmem (mem_r_rsp_ch_dmem.TX)
);

// TODO: MMIO to be moved here

endmodule
