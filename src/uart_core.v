//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          UART Core RTL
// File:            uart_core.v
// Date created:    2021-06-06
// Author:          Aleksandar Lilic
// Description:     UART Core module using 
//                  one uart_transmitter and one uart_receiver
//
// Version history:
//      2021-06-06  AL  0.1.0 - Initial
//      2021-06-06  AL  1.0.0 - Release
//
// Open items: 
//  1. Counters are working non-stop in both rx and tx modules
//  2. Issue with simulation where data_out_valid is not removed immediately
//-----------------------------------------------------------------------------

module uart_core #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE  =     115_200)
(
    input   wire        clk,
    input   wire        rst,

    input   wire  [7:0] data_in,
    input   wire        data_in_valid,
    output  wire        data_in_ready,

    output  wire  [7:0] data_out,
    output  wire        data_out_valid,
    input   wire        data_out_ready,

    input   wire        serial_in,
    output  wire        serial_out
);

//-----------------------------------------------------------------------------
// Signals
reg     serial_in_reg;
reg     serial_out_reg;
wire    serial_out_tx;

//-----------------------------------------------------------------------------

// always @ (posedge clk) begin
    // serial_out_reg <= rst ? 1'b1 : serial_out_tx;
    // serial_in_reg  <= rst ? 1'b1 : serial_in;
// end

always @ (posedge clk) begin
    if (rst) begin
        serial_out_reg <= 0;
        serial_in_reg  <= 0;
    end 
    else begin
        serial_out_reg <= serial_out_tx;
        serial_in_reg  <= serial_in;
    end
end

assign serial_out = serial_out_reg;

uart_transmitter #(
    .CLOCK_FREQ     (CLOCK_FREQ),
    .BAUD_RATE      (BAUD_RATE)
) uart_transmitter_i (
    .clk            (clk),
    .rst            (rst),
    .data_in        (data_in),
    .data_in_valid  (data_in_valid),
    .data_in_ready  (data_in_ready),
    .serial_out     (serial_out_tx)
);

uart_receiver #(
    .CLOCK_FREQ     (CLOCK_FREQ),
    .BAUD_RATE      (BAUD_RATE)
) uart_receiver_i (
    .clk            (clk),
    .rst            (rst),
    .data_out       (data_out),
    .data_out_valid (data_out_valid),
    .data_out_ready (data_out_ready),
    .serial_in      (serial_in_reg)
);
endmodule
