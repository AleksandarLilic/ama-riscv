//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Branch Compare Testbench
// File:            ama_riscv_branch_compare_tb.v
// Date created:    2021-07-15
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Few specific test cases (un/signed and operands combination)
//                      2.  Randomized un/signed with randomized data
//
// Version history:
//      2021-07-15  AL  0.1.0 - Initial
//      2021-07-15  AL  1.0.0 - Sign-off
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES             192
`define BIAS           100_000_000

module ama_riscv_branch_compare_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
// inputs
reg         op_uns    ; 
reg  [31:0] in_a      ;
reg  [31:0] in_b      ;
// outputs
wire        op_a_eq_b ;
wire        op_a_lt_b ;

// Testbench variables
//reg         done;
integer   i;
integer   errors;
integer   collect_eq;
integer   collect_lt;
integer   collect_total;
reg [ 0:0] test_values_op_uns [`TEST_CASES-1:0];
reg [31:0] test_values_in_a   [`TEST_CASES-1:0];
reg [31:0] test_values_in_b   [`TEST_CASES-1:0];
// reg [3:0] received_values    [`TEST_CASES-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_branch_compare DUT_ama_riscv_branch_compare_i (
    // inputs
    .op_uns    (op_uns   ),
    .in_a      (in_a     ),
    .in_b      (in_b     ),
    // outputs
    .op_a_eq_b (op_a_eq_b), 
    .op_a_lt_b (op_a_lt_b)
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
// Not needed for DUT, useful for aligning events
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task check;
    input  [ 0:0] task_op_uns;
    input  [31:0] task_in_a  ;
    input  [31:0] task_in_b  ;
    
    reg    [ 0:0] expected_result_eq;
    reg    [ 0:0] expected_result_lt;
    
    begin
        
        begin   // drive inputs
            op_uns <= task_op_uns;
            in_a   <= task_in_a  ;
            in_b   <= task_in_b  ;
            // Wait for DUT to react to input changes
            #1;        
        end     // drive inputs
        
        begin   // check outputs
            case (task_op_uns)
                1'b0: begin // signed
                    expected_result_eq = ($signed(in_a) == $signed(in_b));
                    expected_result_lt = ($signed(in_a) <  $signed(in_b));
                end
                
                1'b1: begin // unsigned
                    expected_result_eq = (in_a == in_b);
                    expected_result_lt = (in_a <  in_b);
                end
                                
                default: begin  // invalid operation
                    // $display("This is an error, Zs or Xs or some other wilderness");
                    expected_result_eq = 1'b0;
                    expected_result_lt = 1'b0;                    
                end        
                
            endcase
        end // check
        
        if (expected_result_eq != op_a_eq_b) begin    // print status
            $display("*ERROR @ %0t. Input op_uns: %1b, Input a: %0d, Input b: %0d, Expected eq: %1b, Received eq: %1b", 
            $time, task_op_uns, task_in_a, task_in_b, expected_result_eq, op_a_eq_b);
            errors = errors + 1;
        end     // print status
        
        if (expected_result_lt != op_a_lt_b) begin    // print status
            $display("*ERROR @ %0t. Input op_uns: %1b, Input a: %0d, Input b: %0d, Expected lt: %1b, Received lt: %1b", 
            $time, task_op_uns, task_in_a, task_in_b, expected_result_lt, op_a_lt_b);
            errors = errors + 1;
        end     // print status
        
        // collect hits if either is true
        if (op_a_eq_b) collect_eq = collect_eq + 1;
        if (op_a_lt_b) collect_lt = collect_lt + 1;
        collect_total = collect_total + 1;
    
    end // main task body
endtask

task generate_random_values_array;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
       test_values_op_uns[i]  <= $urandom;
       test_values_in_a  [i]  <= $random;
       test_values_in_b  [i]  <= $random;
    end
endtask

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    generate_random_values_array();
    
    //done          <= 0;
    errors        <= 0;
    collect_eq    <= 0;
    collect_lt    <= 0;
    collect_total <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n------------------------ Testing started -------------------------\n\n");
    @(posedge clk); #1;
    //-----------------------------------------------------------------------------
    // Test 1: Hit specific cases
    $display("Test  1: Hit specific cases ...");
    
    // $display("Run 1: op: signed, a > b");
    check(1'b0, 32'd16, -32'd16);
    #1;
    
    // $display("Run 2: op: signed a = b");
    check(1'b0, -32'd16, -32'd16);
    #1;
    
    // $display("Run 3: op: signed a < b");
    check(1'b0, -32'd16, 32'd16);
    #1;
    
    // $display("Run 4: op: unsigned, a > b");
    check(1'b1, 32'd16, 32'd11);
    #1;
    
    // $display("Run 5: op: unsigned a = b");
    check(1'b1, 32'd16, 32'd16);
    #1;
    
    // $display("Run 6: op: unsigned a < b");
    check(1'b1, 32'd13, 32'd16);
    #1;
    
    $display("Test  1: Checking specific cases done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 2: Random hits
    $display("Test  2: Random hits ...");
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_op_uns[i], test_values_in_a[i], test_values_in_b[i]);
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  2: Checking random hits done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Collected info print
    $write("Before Bias: ");
    $display("Collected EQs: %0d/%0d, Collected LTs: %0d/%0d \n", collect_eq, collect_total, collect_lt, collect_total);
    
    //-----------------------------------------------------------------------------
    // Test 3: Random hits, bias values towards equality
    // Bias simply divides random values with i*BIAS and casts it to integer
    // For larger i, greater chance of both being equal
    // +1 to avoid dividing by zero
    $display("Test  3: Random hits biased...");
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_op_uns[i], (test_values_in_a[i]/(i*`BIAS+1)), (test_values_in_b[i]/(i*`BIAS+1)));
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  3: Checking random hits biased done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Collected info print
    $write("After Bias: ");
    $display("Collected EQs: %0d/%0d, Collected LTs: %0d/%0d \n", collect_eq, collect_total, collect_lt, collect_total);    
    
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    $display("\n----------------------- Simulation results -----------------------");
    $display("Tests ran to completion");
    $write("Status: ");
    if(!errors)
        $display("Passed");
    else
        $display("Failed");
    $display("Errors: %0d", errors);
    $display("----------------- End of the simulation results ------------------\n");
    $finish();
end

endmodule
