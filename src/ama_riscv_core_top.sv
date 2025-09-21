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
rv_if #(.DW(CORE_ADDR_BUS_W)) imem_addr_ch ();
rv_if #(.DW(CORE_DATA_BUS)) imem_data_ch ();

// DMEM
logic [CORE_DATA_BUS-1:0] dmem_write_data;
logic [CORE_ADDR_BUS_W-1:0] dmem_addr;
logic        dmem_en;
logic [ 3:0] dmem_we;
logic [CORE_DATA_BUS-1:0] dmem_read_data_mem;

// core
ama_riscv_core ama_riscv_core_i(
    .clk (clk),
    .rst (rst),
    .imem_req (imem_addr_ch.TX),
    .imem_rsp (imem_data_ch.RX),
    .dmem_write_data (dmem_write_data),
    .dmem_addr (dmem_addr),
    .dmem_en (dmem_en),
    .dmem_we (dmem_we),
    .dmem_read_data_mem (dmem_read_data_mem),
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
    .req (imem_addr_ch.RX),
    .rsp (imem_data_ch.TX)
);

ama_riscv_dmem ama_riscv_dmem_i (
    .clk (clk),
    .en (dmem_en),
    .we (dmem_we),
    .addr (dmem_addr),
    .din (dmem_write_data),
    .dout (dmem_read_data_mem)
);

endmodule
