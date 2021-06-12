//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          UART RTL
// File:            uart.v
// Date created:    2021-06-08
// Author:          Aleksandar Lilic
// Description:     UART module with uart_core and two fifo modules
//
// Version history:
//      2021-06-08  AL  0.1.0 - Initial (Limited functionality)
//
// Note: Limited functionality
// Module does not work as a stand-alone unit since there is no logic 
// that populates TX FIFO, nor is there any logic to use data from RX FIFO
// These actions are simulated in the current testbench and will be fully 
// implemented once CPU Core logic is finalized
//-----------------------------------------------------------------------------

module uart #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE  =     115_200
) (
    input         clk,
    input         rst,
    input         start_tx,
    input         serial_rx,
    output        serial_tx
);

//-----------------------------------------------------------------------------
// Parameters
localparam DATA_WIDTH =  8;
localparam FIFO_DEPTH = 16;

//-----------------------------------------------------------------------------
// Signals
reg   [7:0] data_transfer;
// UART
// tx side
wire  [7:0] tx_uart_fifo_dout;
wire        data_in_valid;
reg         data_in_valid_prev;
wire        data_in_ready;
// rx side
wire  [7:0] rx_uart_fifo_din;
wire        data_out_valid;
wire        data_out_ready;

// TX UART FIFO
// write
wire        tx_uart_wr_en;
wire  [7:0] tx_uart_fifo_din;
wire        tx_uart_fifo_full;
// read
wire        tx_uart_rd_en;
wire        tx_uart_fifo_empty;
reg         f_tx_fifo_rd;

wire        sending;
reg         has_char;
reg         has_char_q1;
wire        data_sent;

// RX UART FIFO
// write
wire        rx_uart_wr_en;
wire        rx_uart_fifo_full;
// read
wire        rx_uart_rd_en;
wire  [7:0] rx_uart_fifo_dout;
wire        rx_uart_fifo_empty;

//-----------------------------------------------------------------------------
// UART module
uart_core # (
    .CLOCK_FREQ     (CLOCK_FREQ),
    .BAUD_RATE      (BAUD_RATE)
) uart_i (
    .clk            (clk),
    .rst            (rst),
    // tx side
    .data_in        (tx_uart_fifo_dout),    // in, data to send
    .data_in_valid  (data_in_valid),        // in
    .data_in_ready  (data_in_ready),        // out
    // rx side
    .data_out       (rx_uart_fifo_din),     // out, received data
    .data_out_valid (data_out_valid),       // out
    .data_out_ready (data_out_ready),       // in
    // PHY
    .serial_in      (serial_rx),
    .serial_out     (serial_tx)
);

//-----------------------------------------------------------------------------
// FIFO_RX_UART
fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
) fifo_rx_uart_i (
    .clk        (clk),
    .rst        (rst),    
    // write
    .wr_en      (rx_uart_wr_en),     // in
    .din        (rx_uart_fifo_din),  // in
    .fifo_full  (rx_uart_fifo_full), // out
    // read
    .rd_en      (rx_uart_rd_en),     // in
    .dout       (rx_uart_fifo_dout), // out
    .fifo_empty (rx_uart_fifo_empty) // out
);

assign rx_uart_rd_en  = 1'b0;
assign data_out_ready = !rx_uart_fifo_full;
assign rx_uart_wr_en  = data_out_valid && data_out_ready;

//-----------------------------------------------------------------------------
// FIFO_TX_UART
fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
) fifo_tx_uart_i (
    .clk        (clk),
    .rst        (rst),
    
    // write
    .wr_en      (tx_uart_wr_en),     // in
    .din        (tx_uart_fifo_din),  // in
    .fifo_full  (tx_uart_fifo_full), // out
    // read
    .rd_en      (tx_uart_rd_en),     // in
    .dout       (tx_uart_fifo_dout), // out
    .fifo_empty (tx_uart_fifo_empty) // out
);

assign sending       =  start_tx ? 1'b1 : has_char_q1;
assign data_sent     = (data_in_valid && data_in_ready);
assign tx_uart_rd_en = (sending && !tx_uart_fifo_empty && !has_char);

always @ (posedge clk) begin
    if (rst)
        has_char <= 1'b0;
    else if (tx_uart_rd_en)
        has_char <= 1'b1;
    else if (data_sent)
        has_char <= 1'b0;
end

always @ (posedge clk) begin
    if (rst)
        has_char_q1 <= 1'b0;
    else
        has_char_q1 <= has_char;
end

assign data_in_valid = has_char;

assign tx_uart_wr_en    = 'b0;
assign tx_uart_fifo_din = 'h0;

endmodule
