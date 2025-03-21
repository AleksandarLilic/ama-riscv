//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Button Parser RTL
// File:            button_parser.v
// Date created:    2021-05-31
// Author:          Aleksandar Lilic
// Description:     Module instantiates the 
//                  (synchronizer -> debouncer -> edge_detector) signal chain
//                  for the button inputs
//
// Version history:
//      2021-05-31  AL  0.1.0 - Initial
//      2021-06-01  AL  1.0.0 - Release (on account of FPGA version passing TB
//                              and implementation)
//-----------------------------------------------------------------------------

module button_parser #(
    parameter WIDTH             = 1,
    parameter SAMPLE_COUNT_MAX  = 25000,
    parameter PULSE_COUNT_MAX   = 150
) (
    input   logic             clk,
    input   logic             rst,
    input   logic [WIDTH-1:0] btn_in,
    output  logic [WIDTH-1:0] btn_out
);

//-----------------------------------------------------------------------------
// Signals
logic [WIDTH-1:0] sync_signals;
logic [WIDTH-1:0] deb_signals;

//-----------------------------------------------------------------------------
synchronizer # (
    .WIDTH          (WIDTH)
) button_synchronizer (
    .clk            (clk), 
    .rst            (rst),
    // input
    .async_signal   (btn_in), 
    // output
    .sync_signal    (sync_signals)
);

debouncer # (
    .WIDTH              (WIDTH), 
    .SAMPLE_COUNT_MAX   (SAMPLE_COUNT_MAX), 
    .PULSE_COUNT_MAX    (PULSE_COUNT_MAX)
) button_debouncer (
    .clk                (clk), 
    .rst                (rst), 
    // input
    .glitchy_signal     (sync_signals), 
    // output 
    .debounced_signal   (deb_signals)
);

edge_detector # (
    .WIDTH              (WIDTH)
) button_edge_detector (
    .clk                (clk), 
    .rst                (rst), 
    // input
    .signal_in          (deb_signals),  
    // output
    .edge_detect_pulse  (btn_out)
);

endmodule
