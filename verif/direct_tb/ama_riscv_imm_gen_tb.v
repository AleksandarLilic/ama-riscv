//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Immediate Generation Testbench
// File:            ama_riscv_imm_gen_tb.v
// Date created:    2021-07-12
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Few specific test cases (instructions and imm values)
//                      2.  Randomized instructions with randomized imm values
//                          - Includes invalid ops and disabled module cases
//
// Version history:
//      2021-07-12  AL  0.1.0 - Initial
//      2021-07-13  AL  0.2.0 - Match RTL 0.1.5 changes
//      2021-07-13  AL  1.0.0 - Sign-off
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

`define CLK_PERIOD              8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES             64

module ama_riscv_imm_gen_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
reg         rst;
// inputs
reg  [ 2:0] ig_sel;
reg  [31:7] ig_in ;
// outputs
wire [31:0] ig_out;

// Testbench variables
//reg         done;
integer    i;
integer    errors;
reg        test_values_en     [`TEST_CASES-1:0];
reg [ 3:0] test_values_ig_sel [`TEST_CASES-1:0];
reg [31:0] test_values_ig_in  [`TEST_CASES-1:0];
reg [31:0] received_values    [`TEST_CASES-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_imm_gen DUT_ama_riscv_imm_gen_i (
    .clk      (clk    ),
    .rst      (rst    ),
    // inputs
    .ig_sel   (ig_sel),
    .ig_in    (ig_in ),
    // outputs
    .ig_out   (ig_out)
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task check;
    input  [ 2:0] task_ig_sel;
    input  [31:0] task_ig_in ;
    input  [31:0] task_ig_out_prev ;
    
    output [31:0] task_dout;
    
    reg    [11:0] imm_temp_12;
    reg    [12:0] imm_temp_13;
    reg    [20:0] imm_temp_21;
    reg    [31:0] expected_result;
    reg           invalid_op;
    
    begin
        
        begin   // drive inputs
            ig_sel <= task_ig_sel;
            ig_in  <= task_ig_in[31:7];
            // Wait for clk
            @(posedge clk);
            task_dout  <= ig_out;
            #1;
        end     // drive inputs
        
        begin   // check outputs
        invalid_op = 1'b0;
            case (task_ig_sel)
                `IG_I_TYPE: begin
                    imm_temp_12     = task_ig_in[31:20];
                    expected_result = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
                end
                
                `IG_S_TYPE: begin
                    imm_temp_12     = {task_ig_in[31:25], task_ig_in[11: 7]};
                    expected_result = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
                end
                
                `IG_B_TYPE: begin
                    imm_temp_13     = {task_ig_in[31], task_ig_in[7], task_ig_in[30:25], task_ig_in[11: 8], 1'b0};
                    expected_result = $signed({imm_temp_13, 19'h0}) >>> 19;    // shift 13 MSBs to 13 LSBs, keep sign
                end
                
                `IG_J_TYPE: begin
                    imm_temp_21     = {task_ig_in[31], task_ig_in[19:12], task_ig_in[20], task_ig_in[30:21], 1'b0};
                    expected_result = $signed({imm_temp_21, 11'h0}) >>> 11;    // shift 21 MSBs to 21 LSBs, keep sign
                end
                
                `IG_U_TYPE: begin
                    imm_temp_21     = task_ig_in[31:12];
                    expected_result = {imm_temp_21, 12'h0};    // keep 21 MSBs, pad 11 bits with zeros
                end
                
                `IG_DISABLED: begin
                    expected_result = task_ig_out_prev;    // keep previous result
                end
                                
                default: begin  // invalid operation
                    invalid_op = 1'b1;
                end
                
            endcase
        end // check
        
        if ((expected_result != ig_out) && !invalid_op) begin    // print status if not invalid op
            $display("Temps: imm_temp_12: 'h%0h, imm_temp_13: 'h%0h, imm_temp_21: 'h%0h; Sign: %1b", imm_temp_12, imm_temp_13, imm_temp_21, task_ig_in[31]);
            $display("*ERROR @ %0t. Input ig_sel: %3b, Input instruction: 'h%8h, Expected: 'h%8h, Received: 'h%8h \n", 
            $time, task_ig_sel, task_ig_in, expected_result, ig_out);
            errors = errors + 1;
        end     // print status
        
        if (invalid_op) $display("Selected operation is not valid"); // print status 2
    
    end // main task body
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
    input enable;           // 0: randomize, 1: always on
    input incl_invalid;     // if included, go for full range, if not, up to 5
    
    reg [3:0] upper_bound;
    begin
    
        upper_bound = (incl_invalid) ? 7'd3 : 5'd3;
        for (i = 0; i < `TEST_CASES; i = i + 1) begin
           test_values_en     [i]  <= $urandom;
           test_values_ig_sel [i]  <= $urandom_range(enable,upper_bound);
           test_values_ig_in  [i]  <= $urandom;
        end
    end
endtask

task initialize_receive_arrays;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        received_values[i] <= i;  // array has value 0 at 0 index, important for task check
    end
endtask

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    generate_random_values_array(1, 0);
    
    //done   <= 0;
    errors <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n------------------------ Testing started -------------------------\n\n");
    reset(4'd3);
    
    //-----------------------------------------------------------------------------
    // Test 1: Hit specific cases
    $display("Test  1: Hit specific cases ...");
    
    // $display("Run 1: op: 3'b001 (i_type)");
    check(3'b001, {12'hFFF,20'h0}, received_values[0], received_values[1]);
    #1;
    
    // $display("Run 2: op: 3'b010 (s_type)");
    check(3'b010, {7'h7F,13'h0,5'h1F,7'h0}, received_values[1], received_values[2]);
    #1;
    
    // $display("Run 3: op: 3'b011 (b_type)");
    check(3'b011, {7'h7F,13'h0,5'h1F,7'h0}, received_values[2], received_values[3]);
    #1;
    
    // $display("Run 4: op: 3'b100 (j_type)");
    check(3'b100, {20'hFFFFF,12'h0}, received_values[3], received_values[4]);
    #1;
    
    // $display("Run 5: op: 3'b101 (u_type)");
    check(3'b101, {20'hFFFFF,12'h0}, received_values[4], received_values[5]);
    #1;
    
    $display("Test  1: Checking specific cases done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 2: Random hits
    $display("Test  2: Random hits ...");
    for (i = 5; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_ig_sel[i], test_values_ig_in[i], received_values[i-1], received_values[i]);
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  2: Checking random hits done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    
    generate_random_values_array(0,1);    
    initialize_receive_arrays();
    
    //-----------------------------------------------------------------------------
    // Test 3: Random hits (incl. invalid operations & disabled module cases)
    $display("Test  3: Random hits including invalid operations & disabled module cases ...");
    for (i = 1; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_ig_sel[i], test_values_ig_in[i], received_values[i-1], received_values[i]);
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  3: Checking random hits including invalid operations & disabled module cases done\n");
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
