module button_parser_fpga #(
    parameter MODE = 0  // 0 = fpga, 1 = testbench
) (
    input         CLK_125MHZ_FPGA,
    input         RST,
    input   [3:0] BUTTONS,
    input   [3:0] SWITCHES,
    output  [5:0] LEDS
);
localparam integer B_SAMPLE_COUNT_MAX = (MODE == 0) ? 62500 : 10;
localparam integer B_PULSE_COUNT_MAX  = (MODE == 0) ? 200   : 5;

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
