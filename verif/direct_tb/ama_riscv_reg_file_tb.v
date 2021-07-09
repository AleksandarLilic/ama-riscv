//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Register File Testbench
// File:            ama_riscv_reg_file_tb.v
// Date created:    2021-07-09
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      - Empty on reset (x1-x31)?
//                      - Sync write (x1-x31)
//                      - Sync write to x0
//                      - Async read on port A (x1-x31)
//                      - Async read on port A from x0
//                      - Async read on port B (x1-x31)
//                      - Async read on port B from x0
//                      - Concurrent async read on port A and B
//                      - Sync write followed by async read in the same cycle
//                      - Sync write when we = 0
//                      - Async read when we = 0
//
// Version history:
//      2021-07-09  AL  0.1.0 - Initial
//      
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD              8
`define CLOCK_FREQ    125_000_000
`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define REG_DATA_WIDTH         32
`define REG_ADDR_WIDTH          5
`define REG_NUM                32

module ama_riscv_reg_file_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
reg         rst;
// inputs
reg         we    ; 
reg  [ 4:0] addr_a;
reg  [ 4:0] addr_b;
reg  [ 4:0] addr_d;
reg  [31:0] data_d;
// outputs
reg  [31:0] data_a;
reg  [31:0] data_b;

// Testbench variables
reg         done;
integer     i;
reg [`REG_DATA_WIDTH-1:0]       test_values[`REG_NUM-1:0];
reg [`REG_DATA_WIDTH-1:0] received_values_a[`REG_NUM-1:0];
reg [`REG_DATA_WIDTH-1:0] received_values_b[`REG_NUM-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_reg_file DUT_ama_riscv_reg_file_i (
    .clk    (clk   ),
    .rst    (rst   ),
    // inputs
    .we     (we    ),
    .addr_a (addr_a),
    .addr_b (addr_b),
    .addr_d (addr_d),
    .data_d (data_d),
    // outputs
    .data_a (data_a),
    .data_b (data_b)    
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task write_to_reg_file;
    input                       write_enable;
    input [`REG_ADDR_WIDTH-1:0] write_addr;
    input [`REG_DATA_WIDTH-1:0] write_data;
    
    begin
        we     <= write_enable; 
        addr_d <= write_addr;
        data_d <= write_data;
        // Wait for the clock edge to perform the write
        @(posedge clk);
        #1;        
    end
endtask

task read_from_reg_file;
    input                       port;   // A = 0, B = 1
    input [`REG_ADDR_WIDTH-1:0] read_addr;
    input [`REG_DATA_WIDTH-1:0] read_data;
    
    begin
        if (!port) /*port A*/ begin
            addr_a    <= read_addr;
            read_data <= data_a; 
        end 
        else /*port B*/ begin
            addr_b    <= read_addr;
            read_data <= data_b; 
        end
    end
endtask

task compare_data;
    input compare_type; // 0 = compare with zeros, 1 = compare with test_values
    
    if(!compare_type) /*zeros*/ begin
        for (i = 0; i < `REG_NUM; i = i + 1) begin
            if (received_values_a[i] != 'h0)
                $display("Failure on port A read: data not zero. Expected value: 0, Received value: %d", received_values_a[i]);
            if (received_values_b[i] != 'h0)
                $display("Failure on port B read: data not zero. Expected value: 0, Received value: %d", received_values_b[i]);
        end
    end
    else /*test_values*/ begin
        for (i = 0; i < `REG_NUM; i = i + 1) begin
            if (received_values_a[i] != test_values[i])
                $display("Failure on port A read: data not zero. Expected value: %d, Received value: %d", test_values[i], received_values_a[i]);
            if (received_values_b[i] != test_values[i])
                $display("Failure on port B read: data not zero. Expected value: %d, Received value: %d", test_values[i], received_values_b[i]);
        end
    end
    
endtask

task reset;
    input [3:0] clk_pulses_on;
    
    begin
        rst = 1'b0;
        @(posedge clk); #1;
        rst = 1'b1;
        repeat (clk_pulses_on) @(posedge clk); #1;
        rst = 1'b0;
        @(posedge clk); #1;

    end
endtask

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    // Generate the random test data to write to the reg file
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        test_values[i] <= $random;
    end
    
    // Initialize received data array, pattern 0 to 31
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        received_values_a[i] <= i;
        received_values_b[i] <= i;
    end
    
    done <= 0;
end

//-----------------------------------------------------------------------------
// Test

initial begin
    reset(4'd3);
    
    //-----------------------------------------------------------------------------
    // Test 1: reg file empty on reset?
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        read_from_reg_file(0,i,received_values_a[i]);
        //#1;
        read_from_reg_file(1,i,received_values_b[i]);
        @(posedge clk); #1;
    end
    
    compare_data(0);

    /* fork
        begin
            for (i = 0; i < 10; i = i + 1) begin
                // Wait until the DUT_uart_core_i transmitter is ready
                while (data_in_ready == 1'b0) 
                    @(posedge clk); #1;

                // Send a character to the DUT_uart_core_i transmitter to transmit over the serial line
                payload         = 8'h11 + i;
                data_in         = payload;
                data_in_valid   = 1'b1;
                @(posedge clk); #1;
                data_in_valid   = 1'b0;
                
                // Wait until the DUT_uart_core_j receiver indicates that is has valid data
                while (data_out_valid == 1'b0) 
                    @(posedge clk); #1;
                
                $display("Status val-%0d @ time t=%0t: DUT_uart_core_j got data: %h, expected: %h", i, $time, data_out, payload); 
                
                // Check that the data is correct
                if (data_out !== payload) begin
                    $display("Failure 1-%0d @ time t=%0t: DUT_uart_core_j got data: %h, but expected: %h", i, $time, data_out, payload);
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
    join */

    repeat (20) @(posedge clk);
    $display("Test Successful");
    $finish();
end

endmodule
