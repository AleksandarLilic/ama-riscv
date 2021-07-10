//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Load Shift Mask Testbench
// File:            ama_riscv_load_shift_mask_tb.v
// Date created:    2021-07-10
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Randomized: width from 0 to 7, offset from 0 to 3
//                      2.  Word access with !en
//
// Version history:
//      2021-07-10  AL  0.1.0 - Initial
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD              8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES             64

module ama_riscv_load_shift_mask_tb();

//-----------------------------------------------------------------------------
// Signals
// DUT I/O 
reg         clk = 0;
reg         rst;
// inputs
reg         en      ; 
reg  [ 1:0] offset  ;
reg  [ 2:0] width   ;
reg  [31:0] data_in ; 
// outputs
wire [31:0] data_out;

// Testbench variables
//reg         done;
integer    i;
integer    errors;
reg        test_values_en  [`TEST_CASES-1:0];
reg [ 1:0] test_values_off [`TEST_CASES-1:0];
reg [ 2:0] test_values_wid [`TEST_CASES-1:0];
reg [31:0] test_data       [`TEST_CASES-1:0];
reg [31:0] received_data   [`TEST_CASES-1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_load_shift_mask DUT_ama_riscv_load_shift_mask_i (
    .clk      (clk    ),
    .rst      (rst    ),
    // inputs         
    .en       (en     ),
    .offset   (offset ),
    .width    (width  ),
    .data_in  (data_in),
    // outputs
    .data_out (data_out)   
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task check;
    input         task_en;
    input  [ 1:0] task_offset;
    input  [ 2:0] task_width;
    input  [31:0] task_din;
    input  [31:0] task_dout_prev;
    
    output [31:0] task_dout;
    
    reg           sign_bit;
    reg    [31:0] expected_data;
    
    begin
    sign_bit = task_width[2];
        begin   // drive inputs
            en      <= task_en; 
            offset  <= task_offset;
            width   <= task_width;
            data_in <= task_din;
            // Wait for DUT to react to input changes
            @(posedge clk); //#1;
            task_dout  <= data_out;
            #1;
        end     // drive inputs
        
        begin   // check outputs
            if (task_en) begin
                case (task_width[1:0])
                2'd0:   // byte
                    case (task_offset)
                    2'd0:
                        expected_data = sign_bit ? {{24{       1'b0 }}, task_din[ 7: 0]} : 
                                                   {{24{task_din[ 7]}}, task_din[ 7: 0]};
                    2'd1:
                        expected_data = sign_bit ? {{24{       1'b0 }}, task_din[15: 7]} : 
                                                   {{24{task_din[15]}}, task_din[15: 7]};
                    2'd2:
                        expected_data = sign_bit ? {{24{       1'b0 }}, task_din[23:16]} : 
                                                   {{24{task_din[23]}}, task_din[23:16]};
                    2'd3:
                        expected_data = sign_bit ? {{24{       1'b0 }}, task_din[31:24]} : 
                                                   {{24{task_din[31]}}, task_din[31:24]};
                    default: 
                        $display("Offset input not valid");
                    endcase
                
                2'd1:   // half
                    case (task_offset)
                     2'd0:
                        expected_data = sign_bit ? {{16{       1'b0 }}, task_din[15: 0]} : 
                                                   {{16{task_din[15]}}, task_din[15: 0]};
                    2'd1:
                        expected_data = sign_bit ? {{16{       1'b0 }}, task_din[23: 8]} : 
                                                   {{16{task_din[23]}}, task_din[23: 8]};
                    2'd2:
                        expected_data = sign_bit ? {{16{       1'b0 }}, task_din[31:16]} : 
                                                   {{16{task_din[31]}}, task_din[31:16]};
                    2'd3: 
                    begin
                        $display("Unaligned access not supported");
                        expected_data = task_dout_prev;
                    end
                    default: 
                        $display("Offset input not valid");
                    endcase
               
                2'd2:   // word
                    case (task_offset)
                    2'd0:
                        expected_data = task_din;
                    2'd1,
                    2'd2,
                    2'd3:
                    begin
                        $display("Unaligned access not supported");
                        expected_data = task_dout_prev;
                    end
                    default: 
                        $display("Offset input not valid");
                    endcase
                
                default: 
                begin
                    $display("Width input not valid");
                    expected_data = task_dout_prev;
                end
                endcase
            end
            else /*en = 0*/ begin
                expected_data = task_dout_prev;
            end
        end // check outputs
        
        if (expected_data != data_out) begin    // print status
            $display("*ERROR @ %0t. Input sign: %1b, width: %2d, Input offset: %2d, Input data:  'h%8h, Expected data: 'h%8h, Received data: 'h%8h", 
            $time, task_width[2], task_width[1:0], task_offset, task_din, expected_data, data_out);
            errors = errors + 1;
        end     // print status
    
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
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        test_values_en[i]  <= $random;
        test_values_off[i] <= $random;
        test_values_wid[i] <= $random;
        test_data[i]       <= $random;
    end
endtask    

task initialize_receive_arrays;
    for (i = 0; i < `TEST_CASES; i = i + 1) begin
        received_data[i] <= i;  // array has value 0 at 0 index, important for task check
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
    reset(4'd3);
    
    //-----------------------------------------------------------------------------
    // Test 1: Hit specific cases
    $display("Test  1: Hit specific cases ...");
    
    $display("Run 1: off: 2'b00, funct3: lb");
    check(1'b1, 2'b00, 3'b000, test_data[1], received_data[0], received_data[1]);
    // #1;
    
    $display("Run 2: off: 2'b11, funct3: lbu");
    check(1'b1, 2'b11, 3'b100, test_data[2], received_data[1], received_data[2]);
    // #1;
    
    $display("Run 3: off: 2'b11, funct3: lh");
    check(1'b1, 2'b11, 3'b001, test_data[3], received_data[2], received_data[3]);
    // #1;
    
    $display("Test  1: Checking specific cases done\n");
    @(posedge clk); #1;
     
    //-----------------------------------------------------------------------------
    // Test 2: Random hits (incl. unaligned access)
    $display("Test  2: Random hits ...");
    for (i = 4; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        // check(1'b1, test_values_off[i], test_values_wid[i]);
        check(1'b1, test_values_off[i], test_values_wid[i], test_data[i], received_data[i-1], received_data[i]);
        // $display("Run %2d done", i);
        // #1;
    end
    $display("Test  2: Checking random hits done\n");
    @(posedge clk); #1;
    /* 
    //-----------------------------------------------------------------------------
    // Test 3: Random hits (incl. unaligned access), random enable
    $display("Test  3: Random hits with random enable ...");
    for (i = 1; i < `TEST_CASES; i = i + 1) begin
        // $display("Run  %2d ...", i);
        check(test_values_en[i], test_values_off[i], test_values_wid[i]);
        // $display("Run %2d done", i);
        #1;
    end
    $display("Test  3: Checking random hits with random enable done\n");
    @(posedge clk); #1;
     */
    
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
