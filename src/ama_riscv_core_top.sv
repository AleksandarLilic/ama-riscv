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
logic [31:0] inst_id_read;
logic [13:0] imem_addr;
// DMEM
logic [31:0] dmem_write_data;
logic [13:0] dmem_addr;
logic        dmem_en;
logic [ 3:0] dmem_we;
logic [31:0] dmem_read_data_mem;

// core
ama_riscv_core ama_riscv_core_i(
    .clk (clk),
    .rst (rst),
    .inst_id_read (inst_id_read),
    .dmem_read_data_mem (dmem_read_data_mem),
    .imem_addr (imem_addr),
    .dmem_write_data (dmem_write_data),
    .dmem_addr (dmem_addr),
    .dmem_en (dmem_en),
    .dmem_we (dmem_we),
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

// IMEM
ama_riscv_imem ama_riscv_imem_i (
    .clk (clk),
    .addrb (imem_addr),
    .doutb (inst_id_read)
);

// DMEM
ama_riscv_dmem ama_riscv_dmem_i (
    .clk (clk),
    .en (dmem_en),
    .we (dmem_we),
    .addr (dmem_addr),
    .din (dmem_write_data),
    .dout (dmem_read_data_mem)
);

endmodule
