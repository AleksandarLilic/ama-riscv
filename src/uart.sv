`include "ama_riscv_defines.svh"

module uart #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input   logic        clk,
    input   logic        rst,
    // tx
    input   logic  [7:0] data_in,
    input   logic        data_in_valid,
    output  logic        data_in_ready,
    output  logic        serial_out,
    // rx
    output  logic  [7:0] data_out,
    output  logic        data_out_valid,
    input   logic        data_out_ready,
    input   logic        serial_in
);

logic serial_in_d;
logic serial_out_tx;

// flop the in/out
`DFF_CI_RI_RVI(serial_in, serial_in_d);
`DFF_CI_RI_RVI(serial_out_tx, serial_out);

uart_tx #(
    .CLOCK_FREQ     (CLOCK_FREQ),
    .BAUD_RATE      (BAUD_RATE)
) uart_tx_i (
    .clk            (clk),
    .rst            (rst),
    .data_in        (data_in),
    .data_in_valid  (data_in_valid),
    .data_in_ready  (data_in_ready),
    .serial_out     (serial_out_tx)
);

uart_rx #(
    .CLOCK_FREQ     (CLOCK_FREQ),
    .BAUD_RATE      (BAUD_RATE)
) uart_rx_i (
    .clk            (clk),
    .rst            (rst),
    .data_out       (data_out),
    .data_out_valid (data_out_valid),
    .data_out_ready (data_out_ready),
    .serial_in      (serial_in_d)
);

endmodule
