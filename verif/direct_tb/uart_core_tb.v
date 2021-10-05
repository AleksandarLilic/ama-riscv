//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          UART Core Testbench
// File:            uart_core_tb.v
// Date created:    2021-06-06
// Author:          Aleksandar Lilic
// Description:     
//      Module instantiates 2 UART Core sub-modules and connects them via RX/TX lines. 
//      Data Flow: Testbench -> UART_Core_1_TX -> Serial line -> UART_Core_2_RX -> Testbench
//      Testbench drives some data to TX and than compares it with the RX side
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Version history:
//      2021-06-06  AL  0.1.0 - Initial
//      2021-06-06  AL  1.0.0 - Sign-off
//      2021-10-05  AL  1.1.0 - Add longer wait times for data_out_ready
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD              8
`define CLOCK_FREQ    125_000_000
`define BAUD_RATE         115_200
`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us

module uart_core_tb();

//-----------------------------------------------------------------------------
// Signals

// I/O of off-chip and on-chip UART
reg         clk = 0;
reg         rst;
wire        FPGA_SERIAL_RX;
wire        FPGA_SERIAL_TX;

reg   [7:0] data_in;
reg         data_in_valid;
wire        data_in_ready;

wire  [7:0] data_out;
wire        data_out_valid;
reg         data_out_ready;

// Testbench variables
reg         done = 0;
reg   [7:0] payload;
integer     i;

//-----------------------------------------------------------------------------
// DUT instances
uart_core # (
    .CLOCK_FREQ     (`CLOCK_FREQ),
    .BAUD_RATE      (`BAUD_RATE)
) DUT_uart_core_i (
    .clk            (clk),
    .rst            (rst),
    
    .data_in        (data_in),
    .data_in_valid  (data_in_valid),  // ready/valid input
    .data_in_ready  (data_in_ready),  // ready/valid output
    
    // Receiver not used, only the transmitter
    .data_out       (), 
    .data_out_valid (),
    .data_out_ready (),
    
    .serial_in      (FPGA_SERIAL_RX),
    .serial_out     (FPGA_SERIAL_TX)
);

uart_core # (
    .CLOCK_FREQ     (`CLOCK_FREQ),
    .BAUD_RATE      (`BAUD_RATE)
) DUT_uart_core_j (
    .clk            (clk),
    .rst            (rst),
    
    // Transmitter not used, only the receiver
    .data_in        (),
    .data_in_valid  (),
    .data_in_ready  (),
    
    .data_out       (data_out),
    .data_out_valid (data_out_valid),    // ready/valid output
    .data_out_ready (data_out_ready),    // ready/valid input
    
    // Note: lines are cross connected from first UART
    .serial_in      (FPGA_SERIAL_TX),
    .serial_out     (FPGA_SERIAL_RX)
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
end

//-----------------------------------------------------------------------------
// Test
initial begin
    rst             = 1'b0;
    data_in         = 8'd0;
    data_in_valid   = 1'b0;
    data_out_ready  = 1'b0;
    repeat (2) @(posedge clk); #1;

    // Reset the UARTs
    rst = 1'b1;
    @(posedge clk); #1;
    rst = 1'b0;

    fork
        begin
            for (i = 0; i < 10; i = i + 1) begin
                // Wait until the DUT_uart_core_i transmitter is ready
                while (data_in_ready == 1'b0) begin 
                    @(posedge clk); #1;
                end

                // Send a character to the DUT_uart_core_i transmitter to transmit over the serial line
                payload         = 8'h11 + i;
                data_in         = payload;
                data_in_valid   = 1'b1;
                @(posedge clk); #1;
                data_in_valid   = 1'b0;
                
                // Wait until the DUT_uart_core_j receiver indicates that is has valid data
                while (data_out_valid == 1'b0) begin
                    @(posedge clk); #1;
                end
                
                $display("Status val-%0d @ time t=%0t: DUT_uart_core_j got data: %h, expected: %h", i, $time, data_out, payload); 
                
                // Check that the data is correct
                if (data_out !== payload) begin
                    $display("Failure 1-%0d @ time t=%0t: DUT_uart_core_j got data: %h, but expected: %h", i, $time, data_out, payload);
                end                
                
                // wait a few cycles
                repeat(1*i) begin 
                    @(posedge clk); #1; 
                end
                
                // Consume data
                data_out_ready = 1'b1;
                @(posedge clk); #1;
                data_out_ready = 1'b0;
                @(posedge clk); #1;
                
                // Check if no longer valid
                if (data_out_valid == 1'b1) begin
                    $display("Failure r/v-%0d @ time t=%0t: DUT_uart_core_j didn't clear data_out_valid when data_out_ready was asserted", i, $time);
                end
            end

            // Data should not change though
            repeat (10) @(posedge clk); #1;
            if (data_out !== payload) begin
                $display("Failure 2 @ time t=%0t: DUT_uart_core_j got correct data, but it didn't hold data_out until data_out_ready was asserted", $time);
            end

            // DUT_uart_core_i transmitter should be idle FPGA_SERIAL_TX line should be idle
            if (FPGA_SERIAL_TX !== 1'b1) begin
                $display("Failure 3 @ time t=%0t: FPGA_SERIAL_TX was not high when the DUT_uart_core_i transmitter should be idle", $time);
            end

            // If data_out_ready is asserted to the DUT_uart_core_j receiver, it should pull its data_out_valid signal low
            data_out_ready = 1'b1;
            @(posedge clk); #1;
            data_out_ready = 1'b0;
            @(posedge clk); #1;
            
            if (data_out_valid == 1'b1) begin
                $display("Failure 4 @ time t=%0t: DUT_uart_core_j didn't clear data_out_valid when data_out_ready was asserted", $time);
            end
            done = 1;
        end
        
        // Catch time-out:
        begin
            repeat (`SIM_TIME) @(posedge clk);
            if (!done) begin
                $display("Failure: timing out");
                $finish();
            end
        end
    join

    repeat (20) @(posedge clk);
    $display("Test Successful");
    $finish();
end

endmodule
