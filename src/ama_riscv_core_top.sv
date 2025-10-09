`include "ama_riscv_defines.svh"

module ama_riscv_core_top (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] mmio_instr_cnt,
    input  logic [31:0] mmio_cycle_cnt,
    input  logic [ 7:0] mmio_uart_data_out,
    input  logic        mmio_data_out_valid,
    input  logic        mmio_data_in_ready,
    output logic        store_to_uart,
    output logic        load_from_uart,
    output logic        inst_wb_nop_or_clear,
    output logic        mmio_reset_cnt,
    output logic [ 7:0] mmio_uart_data_in
);

// IMEM
rv_if #(.DW(CORE_ADDR_BUS_W)) imem_req_ch ();
rv_if #(.DW(CORE_DATA_BUS)) imem_rsp_ch ();

// DMEM
rv_if_da #(.AW(CORE_ADDR_BUS_W), .DW(CORE_DATA_BUS)) dmem_req_ch ();
rv_if #(.DW(CORE_DATA_BUS)) dmem_rsp_ch ();
logic [ 3:0] dmem_we; // to be removed with dcache

// core
ama_riscv_core ama_riscv_core_i(
    .clk (clk),
    .rst (rst),
    .imem_req (imem_req_ch.TX),
    .imem_rsp (imem_rsp_ch.RX),
    .dmem_we (dmem_we),
    .dmem_req (dmem_req_ch.TX),
    .dmem_rsp (dmem_rsp_ch.RX),
    .mmio_instr_cnt (mmio_instr_cnt),
    .mmio_cycle_cnt (mmio_cycle_cnt),
    .mmio_uart_data_out (mmio_uart_data_out),
    .mmio_data_out_valid (mmio_data_out_valid),
    .mmio_data_in_ready (mmio_data_in_ready),
    .store_to_uart (store_to_uart),
    .load_from_uart (load_from_uart),
    .inst_wb_nop_or_clear (inst_wb_nop_or_clear),
    .mmio_reset_cnt (mmio_reset_cnt),
    .mmio_uart_data_in (mmio_uart_data_in)
);

ama_riscv_imem #(
    .D(`IMEM_DELAY_CLK)
) ama_riscv_imem_i (
    .clk (clk),
    .rst (rst),
    .req (imem_req_ch.RX),
    .rsp (imem_rsp_ch.TX)
);

ama_riscv_dmem ama_riscv_dmem_i (
    .clk (clk),
    .we (dmem_we),
    .req (dmem_req_ch.RX),
    .rsp (dmem_rsp_ch.TX)
);

endmodule
