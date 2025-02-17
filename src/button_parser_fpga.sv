//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Button Parser RTL for FPGA implementation
// File:            button_parser_fpga.v
// Date created:    2021-06-01
// Author:          Aleksandar Lilic
// Description:     Module instantiates the 
//                  (synchronizer -> debouncer -> edge_detector) signal chain
//                  for the button inputs
//                  Use `define MODE to switch to small counter values for tb
//
// Version history:
//      2021-06-01  AL  0.1.0 - Initial
//      2021-06-01  AL  1.0.0 - Release
//-----------------------------------------------------------------------------

`define MODE 0      // 0 = FPGA, 1 = Testbench

`define CLOCK_FREQ 125_000_000

module button_parser_fpga (
    input         CLK_125MHZ_FPGA,
    input         RST,
    input   [3:0] BUTTONS,
    input   [3:0] SWITCHES,
    output  [5:0] LEDS
);
//-----------------------------------------------------------------------------
// Parameters
`ifdef MODE 
// MODE = Testbench
// Sample the button signal every 10 clk pulses
localparam integer B_SAMPLE_COUNT_MAX   = 10;
// The button is considered 'pressed' after 5*10 pulses of continuous pressing
localparam integer B_PULSE_COUNT_MAX    = 5;

`else
// MODE = FPGA
// Sample the button signal every 500us
localparam integer B_SAMPLE_COUNT_MAX   = 0.0005 * `CLOCK_FREQ;
// The button is considered 'pressed' after 100ms of continuous pressing
localparam integer B_PULSE_COUNT_MAX    = 0.100 / 0.0005;
`endif

//-----------------------------------------------------------------------------
// Signals
logic [3:0] buttons_pressed;
logic [3:0] count = 0;

//-----------------------------------------------------------------------------
assign LEDS[5:4] = 2'b00;

//-----------------------------------------------------------------------------
button_parser #(
    .WIDTH              (4),
    .SAMPLE_COUNT_MAX   (B_SAMPLE_COUNT_MAX),
    .PULSE_COUNT_MAX    (B_PULSE_COUNT_MAX)
) bp (
    .clk        (CLK_125MHZ_FPGA),
    .rst        (RST),
    .btn_in     (BUTTONS),
    .btn_out    (buttons_pressed)
);

always @(posedge CLK_125MHZ_FPGA) begin
    if (buttons_pressed[0])         // count up
        count <= count + 'd1;
    else if (buttons_pressed[1])    // count down
        count <= count - 'd1;
    else if (buttons_pressed[2])    // reset cnt
        count <= 'd0;
    else if (buttons_pressed[3])    // count up mod2
        count <= count + 'd2;
end

assign LEDS[3:0] = count;

endmodule
