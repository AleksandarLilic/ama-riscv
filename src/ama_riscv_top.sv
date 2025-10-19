`include "ama_riscv_defines.svh"

module ama_riscv_top #(
    parameter unsigned CLOCK_FREQ = 100_000_000,
    parameter unsigned UART_BR = BR_115200
)(
    input  logic clk,
    input  logic rst,
    input  logic uart_serial_in,
    output logic uart_serial_out,
    output logic inst_retired
);

// icache <-> main mem
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_imem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_imem ();
// dcache <-> main mem
rv_if #(.DW(MEM_ADDR_BUS)) mem_r_req_ch_dmem ();
rv_if_da #(.AW(MEM_ADDR_BUS), .DW(MEM_DATA_BUS)) mem_w_req_ch_dmem ();
rv_if #(.DW(MEM_DATA_BUS)) mem_r_rsp_ch_dmem ();

// core <-> uart
rv_if #(.DW(8)) uart_send_req_ch ();
rv_if #(.DW(8)) uart_recv_rsp_ch ();

ama_riscv_core_top ama_riscv_core_top_i(
    .clk (clk),
    .rst (rst),
    .req_imem (mem_r_req_ch_imem.TX),
    .rsp_imem (mem_r_rsp_ch_imem.RX),
    .req_dmem_r (mem_r_req_ch_dmem.TX),
    .req_dmem_w (mem_w_req_ch_dmem.TX),
    .rsp_dmem (mem_r_rsp_ch_dmem.RX),
    .uart_send_req (uart_send_req_ch.TX),
    .uart_recv_rsp (uart_recv_rsp_ch.RX),
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

uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (UART_BR)
) uart_i (
    .clk (clk),
    .rst (rst),
    .send_req (uart_send_req_ch.RX),
    .recv_rsp (uart_recv_rsp_ch.TX),
    .serial_in (uart_serial_in),
    .serial_out (uart_serial_out)
);

endmodule
