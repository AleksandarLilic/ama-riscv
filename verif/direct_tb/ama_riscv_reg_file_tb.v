//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Register File Testbench
// File:            ama_riscv_reg_file_tb.v
// Date created:    2021-07-09
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Empty on reset (x0-x31)?
//                      2.  Sync write (x1-x31)
//                      3.  Sync write (x0)
//                      4.  Async read on port A (x1-x31)
//                      5.  Async read on port A (x0)
//                      6.  Async read on port B (x1-x31)
//                      7.  Async read on port B (x0)
//                      8.  Concurrent async read on port A and B
//                      9.  Sync write followed by async read in the same cycle
//                      10. Sync write when we = 0 (x1-x31)
//                      11. Sync write when we = 0 (x0)
//
// Version history:
//      2021-07-09  AL  0.1.0 - Initial
//      2021-07-09  AL  1.0.0 - Sign-off
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
parameter   PORT_A = 1'b0,
            PORT_B = 1'b1;

parameter   TEST_ZERO   = 1'b0,
            TEST_VALUES = 1'b1;

parameter   WRITE_ENABLE = 1'b1;

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
wire [31:0] data_a;
wire [31:0] data_b;

// Testbench variables
reg         done;
integer     i;
integer     errors;
reg [`REG_DATA_WIDTH-1:0]       test_values[`REG_NUM-1:0];
reg [`REG_DATA_WIDTH-1:0]  test_values_hold[`REG_NUM-1:0];
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
    input                        write_enable;
    input  [`REG_ADDR_WIDTH-1:0] write_addr;
    input  [`REG_DATA_WIDTH-1:0] write_data;
    
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
    input                        port;   // A = 0, B = 1
    input  [`REG_ADDR_WIDTH-1:0] read_addr;
    output [`REG_DATA_WIDTH-1:0] read_data;
    
    begin
        if (!port) /*port A*/ begin
            addr_a    <= read_addr; #1;
            read_data <= data_a;    #1;
        end 
        else /*port B*/ begin
            addr_b    <= read_addr; #1;
            read_data <= data_b;    #1;
        end
    end
endtask

task compare_data;
    input [`REG_ADDR_WIDTH-1:0] read_addr;
    input [`REG_DATA_WIDTH-1:0] read_data;
    input [`REG_DATA_WIDTH-1:0] expected_data;
    
    begin
        if (read_data != expected_data) begin
            $display("*ERROR @ %0t. Register accessed: %2d, Expected value: %0d, Received value: %0d", $time, read_addr, expected_data, read_data);
            errors = errors + 1;
        end
    end
    
endtask

task compare_data_dut_direct;
    input [`REG_ADDR_WIDTH-1:0] read_addr;
    input [`REG_DATA_WIDTH-1:0] expected_data;
    
    begin    
        case (read_addr)
            5'd0:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.x0_zero, expected_data);
            5'd1:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r1,  expected_data);
            5'd2:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r2,  expected_data);
            5'd3:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r3,  expected_data);
            5'd4:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r4,  expected_data);
            5'd5:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r5,  expected_data);
            5'd6:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r6,  expected_data);
            5'd7:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r7,  expected_data);
            5'd8:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r8,  expected_data);
            5'd9:    compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r9,  expected_data);
            5'd10:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r10, expected_data);
            5'd11:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r11, expected_data);
            5'd12:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r12, expected_data);
            5'd13:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r13, expected_data);
            5'd14:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r14, expected_data);
            5'd15:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r15, expected_data);
            5'd16:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r16, expected_data);
            5'd17:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r17, expected_data);
            5'd18:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r18, expected_data);
            5'd19:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r19, expected_data);
            5'd20:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r20, expected_data);
            5'd21:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r21, expected_data);
            5'd22:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r22, expected_data);
            5'd23:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r23, expected_data);
            5'd24:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r24, expected_data);
            5'd25:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r25, expected_data);
            5'd26:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r26, expected_data);
            5'd27:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r27, expected_data);
            5'd28:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r28, expected_data);
            5'd29:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r29, expected_data);
            5'd30:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r30, expected_data);
            5'd31:   compare_data(read_addr, DUT_ama_riscv_reg_file_i.reg_r31, expected_data);
            default: $display("Something's amiss");
        endcase
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

task generate_random_values_array;
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        test_values[i] <= $random;
    end
endtask
    

task initialize_receive_arrays;
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        received_values_a[i] <= i;
        received_values_b[i] <= i;
    end
endtask

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    generate_random_values_array();    
    initialize_receive_arrays();
    
    done   <= 0;
    errors <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n------------------------ Testing started -------------------------\n\n");
    reset(4'd3);
    
    //-----------------------------------------------------------------------------
    // Test 1: Empty on reset (x0-x31)?
    $display("Test  1: Checking data inside the DUT ...");
    for (i = 0; i < `REG_NUM; i = i + 1) begin
        compare_data_dut_direct(i, 'h0);
    end
    $display("Test  1: Checking data inside the DUT done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 2: Sync write (x1-x31)
    $display("Test  2: Writing data to regs x1-x31 ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        write_to_reg_file (WRITE_ENABLE, i, test_values[i]);
        compare_data_dut_direct(i, test_values[i]);
    end
    $display("Test  2: Checking data inside the DUT done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 3: Sync write to x0
    $display("Test  3: Writing data to (x0) ...");
    write_to_reg_file(WRITE_ENABLE, 0, test_values[0]);
    compare_data_dut_direct        (0,            'h0);
    $display("Test  3: Checking data inside the DUT (x0) done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 4: Async read on port A (x1-x31)
    $display("Test  4: Getting data from async read on port A (x1-x31) ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        read_from_reg_file(PORT_A, i, received_values_a[i]);
        compare_data(i, received_values_a[i], test_values[i]);
        #1;
    end
    $display("Test  4: Checking data from async read on port A (x1-x31) done\n");
    
    
    //-----------------------------------------------------------------------------
    // Test 5: Async read on port A from x0
    $display("Test  5: Getting data from async read on port A (x0) ...");
    read_from_reg_file(PORT_A, 0, received_values_a[0]);
    compare_data(0, received_values_a[0], 'h0);
    $display("Test  5: Checking data from async read on port A (x0) done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 6: Async read on port B (x1-x31)
    $display("Test  6: Getting data from async read on port B (x1-x31) ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        read_from_reg_file(PORT_B, i, received_values_b[i]);
        compare_data(i, received_values_b[i], test_values[i]);
        #1;
    end
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 7: Async read on port B from x0
    $display("Test  7: Getting data from async read on port B (x0) ...");
    read_from_reg_file(PORT_B, 0, received_values_b[0]);
    compare_data(0, received_values_b[0], 'h0);
    $display("Test  7: Checking data from async read on port B (x0) done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Initialize (clear) receive arrays to default values
    initialize_receive_arrays();
    
    //-----------------------------------------------------------------------------
    // Test 8: Concurrent async read on port A and B
    $display("Test  8: Getting data from ports A & B for regs (x1-x31) ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        read_from_reg_file(PORT_A, i, received_values_a[i]);
        compare_data(i, received_values_a[i], test_values[i]);
        read_from_reg_file(PORT_B, i, received_values_b[i]);
        compare_data(i, received_values_b[i], test_values[i]);
        #1;
    end    
    $display("Test  8: Checking data from ports A & B for regs (x1-x31) done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Generate new values
    generate_random_values_array(); 
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 9: Sync write followed by async read in the same cycle
    $display("Test  9: Sync write followed by async read in the same cycle from ports A & B (x1-x31) ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        write_to_reg_file (WRITE_ENABLE, i, test_values[i]);
        #1
        read_from_reg_file(PORT_A, i, received_values_a[i]);
        compare_data(i, received_values_a[i], test_values[i]);
        #1
        read_from_reg_file(PORT_B, i, received_values_b[i]);
        compare_data(i, received_values_b[i], test_values[i]);
    end
    $display("Test  9: Checking data for sync write followed by async read in the same cycle from ports A & B (x1-x31) done\n");
    
    //-----------------------------------------------------------------------------
    // Keep old values for reference
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        test_values_hold[i] = test_values[i];
    end
    // Generate new values
    generate_random_values_array(); 
    @(posedge clk); #1;    
    
    //-----------------------------------------------------------------------------
    // Test 10: Sync write when we = 0 (x1-x31)
    $display("Test 10: Writing data when we = 0 (x1-x31) ...");
    for (i = 1; i < `REG_NUM; i = i + 1) begin
        write_to_reg_file (!WRITE_ENABLE, i, test_values[i]);
        compare_data_dut_direct(i, test_values_hold[i]);
    end
    $display("Test 10: Checking data inside the DUT done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 11: Sync write when we = 0 (x0)
    $display("Test 11: Writing data when we = 0 (x0) ...");
    write_to_reg_file (!WRITE_ENABLE, 0, test_values[0]);
    compare_data_dut_direct(0, 'h0);
    $display("Test 11: Checking data inside the DUT done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    $display("\n----------------------- Simulation results -----------------------");
    $display("Tests ran to completion");
    $display("Errors: %0d", errors);
    $display("----------------- End of the simulation results ------------------\n");
    $finish();
end

endmodule
