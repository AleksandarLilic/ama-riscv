`timescale 1ns/1ns

`define CLK_PERIOD               8
`define SECOND       1_000_000_000
`define MS               1_000_000
`define SAMPLE_COUNT_MAX        10
`define PULSE_COUNT_MAX          5

module button_parser_fpga_tb();
//-----------------------------------------------------------------------------
// Signals

// I/O of button_parser
reg         clk = 0;
reg         rst;
wire  [5:0] leds;
reg   [3:0] buttons  = 4'h0;
reg   [3:0] switches = 4'h0;

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// DUT instance
button_parser_fpga #(.MODE(1)) DUT (
    .CLK_125MHZ_FPGA    (clk),
    .RST                (rst),
    .BUTTONS            (buttons),
    .SWITCHES           (switches),
    .LEDS               (leds)
);


initial begin
    // Reset
    rst = 0;
    #(`CLK_PERIOD * 2) rst = 1;
    #(`CLK_PERIOD * 2) rst = 0;
    
    // Test 1:
    fork
        // Thread 1: provide the inputs to the module
        begin
            // inc by 1
            buttons[0] = 1'b1;
            repeat (100) @(posedge clk); #1;
            buttons[0] = 1'b0;
            
            // dec by 1
            buttons[1] = 1'b1;
            repeat (100) @(posedge clk); #1;
            buttons[1] = 1'b0;
            
            // inc by 2
            buttons[3] = 1'b1;
            repeat (100) @(posedge clk); #1;
            buttons[3] = 1'b0;
            
            // clear to 0
            buttons[2] = 1'b1;
            repeat (100) @(posedge clk); #1;
            buttons[2] = 1'b0;
            
            repeat (100) @(posedge clk); #1;
        end
        
        // Thread 2: check the outputs
        begin
            @(negedge buttons[0]);
            @(posedge clk); #1;
            if (leds !== 5'd1) $display("First button function failed");
            
            @(negedge buttons[1]);
            @(posedge clk); #1;
            if (leds !== 5'd0) $display("Second button function failed");
            
            @(negedge buttons[3]);
            @(posedge clk); #1;
            if (leds !== 5'd2) $display("Fourth button function failed");
            
            @(negedge buttons[2]);
            @(posedge clk); #1;
            if (leds !== 5'd0) $display("Third button function failed");
            
        end
    join
    
    $display("Test Done.");
    $finish();
end

endmodule
