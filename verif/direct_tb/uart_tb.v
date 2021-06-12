//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          UART Testbench
// File:            uart_tb.v
// Date created:    2021-06-08
// Author:          Aleksandar Lilic
// Description:     Checks two independent functions:
//                  1. Receive on the RX line and store to the FIFO
//                  2. Send data on the TX line from the FIFO
//                     For testbench, data writing to FIFO TX is simulated
//
// Version history:
//      2021-06-08  AL  0.1.0 - Initial
//      2021-06-08  AL  1.0.0 - Sign-off
//-----------------------------------------------------------------------------

`timescale 1ns/100ps

`define SECOND      1_000_000_000
`define MS              1_000_000

`define CLOCK_FREQ    125_000_000
`define BAUD_RATE         115_200

`define CLK_PERIOD  8

`define DATA_WIDTH  8
`define TEST_DEPTH 20
`define FIFO_DEPTH 16

module uart_tb();
//-----------------------------------------------------------------------------
// Signals

// I/O for the UART
reg         clk = 0;
reg         rst;
reg         start_tx;
wire        FPGA_SERIAL_RX;
wire        FPGA_SERIAL_TX;

// I/O of the off-chip UART
reg   [7:0] data_in;
reg         data_in_valid;
wire        data_in_ready;
wire  [7:0] data_out;
wire        data_out_valid;
reg         data_out_ready;

// Testbench variables
integer     i, ii;
integer     valid_cnt = 0;
reg         done = 0;
reg   [4:0] wr_ptr_simulated;   // for 16 words FIFO, has one bit extra for full/empty
reg   [3:0] wr_addr_simulated;  // for 16 words FIFO

// Test values
// Reg filled with test vectors for the testbench
reg [`DATA_WIDTH-1:0]     test_values [`TEST_DEPTH-1:0];
// Reg used to collect the data read from the FIFO
reg [`DATA_WIDTH-1:0] received_values [`TEST_DEPTH-1:0];

//-----------------------------------------------------------------------------
// Parameters
localparam TEST_LEN_TX = `FIFO_DEPTH - 4;

//-----------------------------------------------------------------------------
// DUT instance
uart #(
    .CLOCK_FREQ (`CLOCK_FREQ),
    .BAUD_RATE  (`BAUD_RATE)
) DUT (
    .clk        (clk),
    .rst        (rst),
    .start_tx   (start_tx),
    .serial_rx  (FPGA_SERIAL_RX),
    .serial_tx  (FPGA_SERIAL_TX)
);

//-----------------------------------------------------------------------------
// The off-chip UART (simulates desktop/workstation computer)
uart_core # (
    .CLOCK_FREQ     (`CLOCK_FREQ),
    .BAUD_RATE      (`BAUD_RATE)
) off_chip_uart (
    .clk            (clk),
    .rst            (rst),
    .data_in        (data_in),
    .data_in_valid  (data_in_valid),
    .data_in_ready  (data_in_ready),
    .data_out       (data_out),
    .data_out_valid (data_out_valid),
    .data_out_ready (data_out_ready),
    .serial_in      (FPGA_SERIAL_TX), 
    .serial_out     (FPGA_SERIAL_RX)
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task reset_sequence;
    begin
        // reset DUT
        rst = 1'b0;
        @(posedge clk); #1;
        rst = 1'b1;
        @(posedge clk); #1;
        rst = 1'b0;
    end
endtask

//-----------------------------------------------------------------------------
// Test
initial begin    
    // Generate the random data to write to the FIFO
    for (i = 0; i < `TEST_DEPTH; i = i + 1) begin
        test_values[i] = $random;
    end
    
    start_tx         = 1'b0;
    data_in          = 8'h41; // Represents the character 'A' in ASCII
    data_in_valid    = 1'b0;
    data_out_ready   = 1'b0;
    wr_ptr_simulated = 'h0;
    
    repeat (2) @(posedge clk); #1;
    
    reset_sequence();    
    
    fork
    begin
        // Test 1: RX & FIFO
        $display("\nStarted UART receive test");
        for (i = 0; i < `TEST_DEPTH; i = i + 1) begin
            data_in = test_values[i];
            while (!data_in_ready) @(posedge clk); #1;
            
            @(posedge clk); #1;
            data_in_valid = 1'b1;
            @(posedge clk); #1;
            data_in_valid = 1'b0;
            
            // Once all the data reaches the on-chip UART, it should set DUT/on_chip_uart/data_out_valid high
            while (!DUT.uart_i.data_out_valid) @(posedge clk); #1;
            
            // wait for FIFO write
            @(posedge clk); #1;
            
            if(data_in !== DUT.fifo_rx_uart_i.fifo_reg[i]) begin
                if(i > `FIFO_DEPTH - 1)
                    $write("Expected error, `FIFO_DEPTH: %0d;  ", `FIFO_DEPTH);
                $display("Error in communication # %2d", i+1 );
            end
            
            //$display("Data count: %2d; Data sent: 'h%2h; Data in FIFO: 'h%2h", i, data_in, DUT.fifo_rx_uart_i.fifo_reg[i]);
        end

        @(posedge clk); #1;

        // read again to make sure no corrupt data:
        for (i = 0; i < `FIFO_DEPTH; i = i + 1) begin
            if(test_values[i] !== DUT.fifo_rx_uart_i.fifo_reg[i]) begin
                $display("FIFO corrupted @ location: %0d", i);
                valid_cnt = valid_cnt + 1;
            end
        end

        if(valid_cnt != 0)
            $display("UART receive test - number of corrupted FIFO fields: %0d \n", valid_cnt);
        else
            $display("UART receive test completed without errors \n");

        while (!data_in_ready) @(posedge clk); #1;
        @(posedge clk); #1;
        
        // Test 2: TX & FIFO
        repeat(2) begin
            $display("Started UART transmit test");
            
            // Generate the random data
            for (i = 0; i < `FIFO_DEPTH; i = i + 1) begin
                test_values[i] = $random;
            end
            
            // Write (insert) data to the TX FIFO
            for (i = 0; i < TEST_LEN_TX; i = i + 1) begin
                wr_addr_simulated           = wr_ptr_simulated[3:0];
                DUT.fifo_tx_uart_i.fifo_reg[wr_addr_simulated] = test_values[i];
                wr_ptr_simulated            = wr_ptr_simulated + 1;
                DUT.fifo_tx_uart_i.wr_ptr   = wr_ptr_simulated;
            end

            // initiate transmission
            repeat (1) @(posedge clk); #1;
            start_tx = 1'b1;
            @(posedge clk); #1;
            start_tx = 1'b0;
            
            // Delay needed to wait for rx uart to drive low data_out_valid signal
            // Issue recorded in uart_core.v
            repeat (20) @(posedge clk); #1;

            // receive data
            for (i = 0; i < TEST_LEN_TX; i = i + 1) begin
                while (!data_out_valid) @(posedge clk); #1;                
                @(posedge clk); #1;
                data_out_ready      = 1'b1;
                received_values[i]  = data_out;
                @(posedge clk); #1;
                data_out_ready      = 1'b0;                
            end

            // check data
            valid_cnt = 0;
            for (i = 0; i < TEST_LEN_TX; i = i + 1) begin
                if(received_values[i] !== test_values[i]) begin
                    $display("FIFO corrupted @ location: %0d", i);
                    valid_cnt = valid_cnt + 1;
                end
            end

            if(valid_cnt != 0)
                $display("UART transmit test - number of corrupted FIFO field(s): %0d \n", valid_cnt);
            else
                $display("UART transmit test completed without errors \n");

            repeat (2) @(posedge clk); #1;
            done = 1;
        end // Test 2
    end // Main test
    
    // Catch time-out:
    begin
        repeat (55_000*11) @(posedge clk);
        if (!done) begin
            $display("Failure: Timing out");
            $finish();
        end
    end
    join
    
    repeat (55_000) @(posedge clk);
    $display("Test done.\n");
    $finish();
end

endmodule
