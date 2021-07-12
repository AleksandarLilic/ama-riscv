//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          ALU Testbench
// File:            ama_riscv_alu_tb.v
// Date created:    2021-07-10
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Few specific test cases (operation and operands combination)
//                      2.  Randomized operations with randomized data
//
// Version history:
//      2021-07-11  AL  0.1.0 - Initial
//      2021-07-11  AL  1.0.0 - Sign-off
//      2021-07-11  AL  1.0.1 - Signal width fix, did not impact results
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define ALU_ADD     4'b0000
`define ALU_SUB     4'b1000
`define ALU_SLL     4'b0001
`define ALU_SRL     4'b0101
`define ALU_SRA     4'b1101
`define ALU_SLT     4'b0010
`define ALU_SLTU    4'b0011
`define ALU_XOR     4'b0100
`define ALU_OR      4'b0110
`define ALU_AND     4'b0111
`define ALU_PASS_B  4'b1111

`define CLK_PERIOD              8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES             64

module ama_riscv_alu_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
// inputs
reg  [ 3:0] op_sel; 
reg  [31:0] in_a  ;
reg  [31:0] in_b  ;
// outputs
wire [31:0] out_s ;

// Testbench variables
//reg         done;
integer   i;
integer   errors;
reg [ 4:0] test_values_op_sel [`TEST_CASES-1:0];
reg [31:0] test_values_in_a   [`TEST_CASES-1:0];
reg [31:0] test_values_in_b   [`TEST_CASES-1:0];
// reg [3:0] received_values    [`TEST_CASES-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_alu DUT_ama_riscv_alu_i (
    // inputs
    .op_sel (op_sel),
    .in_a   (in_a  ),
    .in_b   (in_b  ),
    // outputs
    .out_s  (out_s )   
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task check;
    input  [ 3:0] task_op_sel;
    input  [31:0] task_in_a  ;
    input  [31:0] task_in_b  ;
    
    reg    [31:0] expected_result;
    reg    [ 4:0] shamt;
    
    begin
    shamt = task_in_b[4:0];
        
        begin   // drive inputs
            op_sel <= task_op_sel;
            in_a   <= task_in_a  ;
            in_b   <= task_in_b  ;
            // Wait for DUT to react to input changes
            #1;        
        end     // drive inputs
        
        begin   // check outputs
            case (task_op_sel)
                `ALU_ADD: begin
                    expected_result = task_in_a + task_in_b;
                end
                
                `ALU_SUB: begin
                    expected_result = task_in_a - task_in_b;
                end
                
                `ALU_SLL: begin
                    expected_result = task_in_a << shamt;
                end
                
                `ALU_SRL: begin
                    expected_result = task_in_a >> shamt;
                end
                
                `ALU_SRA: begin
                    expected_result = $signed(task_in_a) >>> shamt;
                end
                
                `ALU_SLT: begin
                    expected_result = ($signed(task_in_a) < $signed(task_in_b)) ? 32'h0001 : 32'h0000;
                end
                
                `ALU_SLTU: begin
                    expected_result = (task_in_a < task_in_b) ? 32'h0001 : 32'h0000;
                end
                
                `ALU_XOR: begin
                    expected_result = task_in_a ^ task_in_b;
                end
                
                `ALU_OR: begin
                    expected_result = task_in_a | task_in_b;
                end
                
                `ALU_AND: begin
                    expected_result = task_in_a & task_in_b;
                end
                
                `ALU_PASS_B: begin
                    expected_result = task_in_b;
                end
                
                default: begin  // invalid operation
                    // $display("Selected operation is not valid. Here, have some zeros");
                    expected_result = 32'h0000;
                    
                end        
                
            endcase
        end // check
        
        if (expected_result != out_s) begin    // print status
            // $display("*ERROR @ %0t. Input op: %4b, Input a: %9d, Input b: %9d (shamt: %2d), Expected: %9d, Received: %9d", 
            // $time, task_op_sel, task_in_a, task_in_b, shamt, expected_result, out_s);
            $display("*ERROR @ %0t. Input op: %4b, Input a: 'h%8h, Input b: 'h%8h (shamt: %2d), Expected: 'h%8h, Received: 'h%8h", 
            $time, task_op_sel, task_in_a, task_in_b, shamt, expected_result, out_s);
            errors = errors + 1;
        end     // print status
    
    end // main task body
endtask

task generate_random_values_array;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
       test_values_op_sel[i]  <= $random;
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
    
    //done   <= 0;
    errors <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n------------------------ Testing started -------------------------\n\n");
    @(posedge clk); #1;
    //-----------------------------------------------------------------------------
    // Test 1: Hit specific cases
    $display("Test  1: Hit specific cases ...");
    
    // $display("Run 1: op: 4'b0000 (ADD)");
    check(4'b0000, 32'd16, 32'd11);
    #1;
    
    // $display("Run 2: op: 4'b0001 (SUB)");
    check(4'b1000, 32'd17, 32'd10);
    #1;
    
    // $display("Run 3: op: 4'b1111 (PASS_B)");
    check(4'b1111, 32'd35, 32'd192);
    #1;
    
    // $display("Run 4: op: 4'b1101 (SRA)");
    check(4'b1101, 32'd35, 32'd4);
    #1;
    
    // $display("Run 5: op: 4'b0101 (SRL)");
    check(4'b0101, 32'd35, 32'd4);
    #1;
    
    // $display("Run 6: op: 4'b0001 (SLL)");
    check(4'b0001, 32'd35, 32'd4);
    #1;
    
    $display("Test  1: Checking specific cases done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 2: Random hits (incl. invalid operations)
    $display("Test  2: Random hits ...");
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_op_sel[i], test_values_in_a[i], test_values_in_b[i]);
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  2: Checking random hits done\n");
    @(posedge clk); #1;
    
    
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
