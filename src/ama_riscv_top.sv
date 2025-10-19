`include "ama_riscv_defines.svh"

module ama_riscv_top (
    input  logic        clk,
    input  logic        rst,
    output logic        inst_retired
);

// icache <-> main mem
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_imem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_imem ();
// dcache <-> main mem
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_dmem ();
rv_if_da #(.AW(MEM_ADDR_BUS), .DW(MEM_DATA_BUS)) mem_w_req_ch_dmem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_dmem ();

ama_riscv_core_top ama_riscv_core_top_i(
    .clk (clk),
    .rst (rst),
    .req_imem (mem_r_req_ch_imem.TX),
    .rsp_imem (mem_r_rsp_ch_imem.RX),
    .req_dmem_r (mem_r_req_ch_dmem.TX),
    .req_dmem_w (mem_w_req_ch_dmem.TX),
    .rsp_dmem (mem_r_rsp_ch_dmem.RX),
    .inst_retired (inst_retired)
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
