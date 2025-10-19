
`include "ama_riscv_defines.svh"

module  uart_rx #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst,
    rv_if.TX     recv_rsp,
    input  logic serial_in
);

// about FPGA_OFFSET
// Onboard 125MHz oscillator from the Ethernet does not have the best stability
// Adding -5 offset seems to perfectly align the edges with observed no drift
// at >200 UART back-to-back characters, measured with logic analyzer @ 20MS/s

localparam unsigned FPGA_OFFSET = 5; // 0
localparam unsigned SYMBOL_EDGE_TIME = (CLOCK_FREQ / BAUD_RATE) - FPGA_OFFSET;
localparam unsigned SAMPLE_TIME = SYMBOL_EDGE_TIME / 2;
localparam unsigned CLOCK_COUNTER_WIDTH = $clog2(SYMBOL_EDGE_TIME);

logic        symbol_edge;
logic        sample;
logic        start;
logic        rx_running;

logic        has_byte;
logic  [9:0] rx_shift;
logic  [3:0] bit_counter;
logic  [CLOCK_COUNTER_WIDTH-1:0] clock_counter;

// Goes high when it is time to start receiving a new character
assign start = !serial_in && !rx_running;

// Counts down from 10 bits for every character
always_ff @(posedge clk) begin
    if (rst) bit_counter <= 0;
    else if (start) bit_counter <= 10;
    else if (symbol_edge && rx_running) bit_counter <= bit_counter - 1;
end

// Goes high while receiving a character
assign rx_running = bit_counter != 4'd0;

// Counts cycles until a single symbol is done
always_ff @(posedge clk) begin
    if (rst) clock_counter <= 1'b0;
    else if (start || symbol_edge) clock_counter <= 1'b0;
    else clock_counter <= clock_counter + 1;
end

// Goes high at every symbol edge
assign symbol_edge = (clock_counter == (SYMBOL_EDGE_TIME - 1));

// Goes high halfway through each symbol to sample the serial line
assign sample = (clock_counter == SAMPLE_TIME);

// Shift register
always_ff @(posedge clk) begin
    if (rst) rx_shift <= 9'h0;
    else if (sample && rx_running) rx_shift <= {serial_in, rx_shift[9:1]};
end

// ready/valid
always_ff @(posedge clk) begin
    if (rst) has_byte <= 1'b0;
    else if (bit_counter == 1 && symbol_edge) has_byte <= 1'b1;
    else if (recv_rsp.ready) has_byte <= 1'b0;
end

// Outputs
assign recv_rsp.data = rx_shift[8:1];
assign recv_rsp.valid = has_byte && !rx_running;

endmodule
