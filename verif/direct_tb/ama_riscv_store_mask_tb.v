//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Store Mask Testbench
// File:            ama_riscv_store_mask_tb.v
// Date created:    2021-07-10
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Byte access: width = 3'b000, offset from 0 to 3
//                      2.  Half access: width = 3'b001, offset from 0 to 3
//                      3.  Word access: width = 3'b010, offset from 0 to 3
//                      4.  Word access with !en
//
// Version history:
//      2021-07-10  AL  0.1.0 - Initial
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD              8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES             64

module ama_riscv_store_mask_tb();

//-----------------------------------------------------------------------------
// Signals
parameter   BYTE = 2'd0,
            HALF = 2'd1,
            WORD = 2'd2;

// DUT I/O 
reg         clk = 0;
// inputs
reg         en    ; 
reg  [ 1:0] offset;
reg  [ 2:0] width ;
// outputs
wire [ 3:0] mask  ;

// Testbench variables
//reg         done;
integer   i;
integer   errors;
reg       test_values_en [`TEST_CASES-1:0];
reg [1:0] test_values_off [`TEST_CASES-1:0];
reg [2:0] test_values_wid [`TEST_CASES-1:0];
reg [3:0] received_values [`TEST_CASES-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_store_mask DUT_ama_riscv_store_mask_i (
    // inputs
    .en     (en    ),
    .offset (offset),
    .width  (width ),
    // outputs
    .mask   (mask  )   
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
// Not needed for module operation, but useful for aligning events
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task check;
    input        task_en;
    input  [1:0] task_offset;
    input  [2:0] task_width;
    
    reg    [3:0] expected_mask;
    
    begin
        begin   // drive inputs
            en     <= task_en; 
            offset <= task_offset;
            width  <= task_width;
            // Wait for DUT to react to input changes
            #1;        
        end     // drive inputs
        
        begin   // check outputs
            if (task_en) begin
                case (task_width[1:0])
                5'd0:   // byte
                    case (task_offset)
                    2'd0:
                        expected_mask = 4'b0001;
                    2'd1:
                        expected_mask = 4'b0010;
                    2'd2:
                        expected_mask = 4'b0100;
                    2'd3:
                        expected_mask = 4'b1000;
                    default: 
                        $display("Offset input not valid");
                    endcase
                
                5'd1:   // half
                    case (task_offset)
                    2'd0:
                        expected_mask = 4'b0011;
                    2'd1:
                        expected_mask = 4'b0110;
                    2'd2:
                        expected_mask = 4'b1100;
                    2'd3: 
                    begin
                        $display("Unaligned access not supported");
                        expected_mask = 4'b0000;
                    end
                    default: 
                        $display("Offset input not valid");
                    endcase
               
                5'd2:   // word
                    case (task_offset)
                    2'd0:
                        expected_mask = 4'b1111;
                    2'd1,
                    2'd2,
                    2'd3:
                    begin
                        $display("Unaligned access not supported");
                        expected_mask = 4'b0000;
                    end
                    default: 
                        $display("Offset input not valid");
                    endcase
                
                default: 
                begin
                    $display("Width input not valid");
                    expected_mask = 4'b0000;
                end
                endcase
            end
            else /*en = 0*/ begin
                expected_mask = 4'b0000;
            end
        end // check outputs
        
        if (expected_mask != mask) begin    // print status
            $display("*ERROR @ %0t. Input width: %2d, Input offset: %2d, Expected mask: %4b, Received mask: %4b", $time, task_width[1:0], task_offset, expected_mask, mask);
            errors = errors + 1;
        end     // print status
    
    end
endtask

task generate_random_values_array;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        test_values_en[i]   <= $random;
        test_values_off[i]  <= $random;
        test_values_wid[i]  <= $random;
        received_values[i]  <= $random;
    end
endtask    

task initialize_receive_arrays;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        received_values[i] <= i;
    end
endtask

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    generate_random_values_array();    
    initialize_receive_arrays();
    
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
    
    $display("Run 1: off: 2'b00, funct3: lb");
    check(1'b1, 2'b00, 3'b000);
    #1;
    
    $display("Run 2: off: 2'b11, funct3: lb");
    check(1'b1, 2'b11, 3'b000);
    #1;
    
    $display("Run 3: off: 2'b11, funct3: lh");
    check(1'b1, 2'b11, 3'b001);
    #1;
    
    $display("Test  1: Checking specific cases done\n");
    @(posedge clk); #1;
    
    //-----------------------------------------------------------------------------
    // Test 2: Random hits (incl. unaligned access)
    $display("Test  2: Random hits ...");
    for (i = 1; i < `TEST_CASES; i = i + 1) begin
        $display("Run  %2d ...", i);
        check(test_values_en[i], test_values_off[i], test_values_wid[i]);
        $display("Run %2d done", i);
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
