`include "ama_riscv_defines.svh"

module uart_fpga #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  CLK100MHZ,
    input  [3:0] BUTTONS,
    input  [3:0] SWITCHES,
    output [5:0] LEDS,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

logic rst;
rv_if #(.DW(8)) send_req_ch ();
rv_if #(.DW(8)) recv_rsp_ch ();

assign LEDS[4:0] = 5'b0_0001; // light up on boot
assign rst = BUTTONS[0];

uart # (
    .CLOCK_FREQ (CLOCK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) uart_i (
    .clk (CLK100MHZ),
    .rst (rst),
    .send_req (send_req_ch.RX),
    .recv_rsp (recv_rsp_ch.TX),
    .serial_in (FPGA_SERIAL_RX),
    .serial_out (FPGA_SERIAL_TX)
);

// Loopback
// Logic below will pull a character from the uart_receiver over the
// ready/valid interface, modify that character, and send the character to the
// uart_transmitter, which will send it over the serial line.

// If an ASCII character matching alphabet letters is received
// its case will be reversed (upper->lower and vice verse) and sent back
// Any other ASCII character will be echoed back without any modification

logic has_char;
logic [7:0] char;

always @(posedge CLK100MHZ) begin
    if (rst) has_char <= 1'b0;
    else has_char <= has_char ? !send_req_ch.ready : recv_rsp_ch.valid;
end

always @(posedge CLK100MHZ) begin
    if (!has_char) char <= recv_rsp_ch.data;
end

always_comb begin
    if (char >= 8'd65 && char <= 8'd90) send_req_ch.data = (char + 8'd32);
    else if (char >= 8'd97 && char <= 8'd122) send_req_ch.data = (char - 8'd32);
    else send_req_ch.data = char;
end

// Light up an LED when ASCII 'A' arrives
assign LEDS[5] = (char == 8'd65);
assign send_req_ch.valid = has_char;
assign recv_rsp_ch.ready = !has_char;

endmodule
