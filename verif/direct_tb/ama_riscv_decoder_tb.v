//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Decoder Testbench
// File:            ama_riscv_decoder_tb.v
// Date created:    2021-07-16
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Data check after reset
//                      2.  R-type checks direct
//
// Version history:
//      2021-07-16  AL  0.1.0 - Initial - Reset and R-types (Add & Sub only)
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define TEST_CASES              64

// MUX select signals
// PC select
`define PC_SEL_INC4         2'd0  // PC = PC + 4
`define PC_SEL_ALU          2'd1  // ALU output, used for jump/branch
`define PC_SEL_BP           2'd2  // PC = Branch prediction output
`define PC_SEL_START_ADDR   2'd3  // PC = Hardwired start address

// ALU A operand select
`define ALU_A_SEL_RS1       2'd0  // A = Reg[rs1]
`define ALU_A_SEL_PC        2'd1  // A = PC
`define ALU_A_SEL_FW_ALU    2'd2  // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_RS2       2'd0  // B = Reg[rs2]
`define ALU_B_SEL_IMM       2'd1  // B = Immediate value; from Imm Gen
`define ALU_B_SEL_FW_ALU    2'd2  // B = ALU; forwarding from MEM stage

// Write back select
`define WB_SEL_DMEM         2'd0  // Reg[rd] = DMEM[ALU]
`define WB_SEL_ALU          2'd1  // Reg[rd] = ALU
`define WB_SEL_INC4         2'd2  // Reg[rd] = PC + 4

module ama_riscv_decoder_tb();

//-----------------------------------------------------------------------------
// Signals

// DUT I/O 
reg         clk = 0;
reg         rst;
// inputs
reg  [31:0] inst_id   ; 
reg         bc_a_eq_b ;
reg         bc_a_lt_b ;
reg         bp_taken  ;
reg         bp_clear  ;
// outputs
wire        stall_if   ;
wire        clear_if   ;
wire        clear_id   ;
wire        clear_mem  ;
wire [ 1:0] pc_sel     ;
wire [ 1:0] pc_we      ;
wire        imem_en    ;
wire        branch_inst;
wire        store_inst ;
wire [ 3:0] alu_op_sel ;
wire        alu_a_sel  ;
wire        alu_b_sel  ;
wire [ 2:0] ig_sel     ;
wire        bc_uns     ;
wire        dmem_en    ;
wire        load_sm_en ;
wire [ 1:0] wb_sel     ;
wire        reg_we     ;

// DUT model Outputs
reg         dut_m_stall_if   ;
reg         dut_m_clear_if   ;
reg         dut_m_clear_id   ;
reg         dut_m_clear_mem  ;
reg  [ 1:0] dut_m_pc_sel     ;
reg  [ 1:0] dut_m_pc_we      ;
reg         dut_m_imem_en    ;
reg         dut_m_branch_inst;
reg         dut_m_store_inst ;
reg  [ 3:0] dut_m_alu_op_sel ;
reg         dut_m_alu_a_sel  ;
reg         dut_m_alu_b_sel  ;
reg  [ 2:0] dut_m_ig_sel     ;
reg         dut_m_bc_uns     ;
reg         dut_m_dmem_en    ;
reg         dut_m_load_sm_en ;
reg  [ 1:0] dut_m_wb_sel     ;
reg         dut_m_reg_we     ;

// Testbench variables
//reg         done;
integer     i;              // used for all loops
integer     inst_ii = 0;    // used for instruction array access only
integer     errors;
reg  [31:0] test_values_inst   [`TEST_CASES-1:0];
// reg  [ 4:0] test_values_op_sel [`TEST_CASES-1:0];
// reg  [31:0] test_values_in_b   [`TEST_CASES-1:0];
// reg  [ 3:0] received_values    [`TEST_CASES-1:0];
event ev_rst    [1:0];
event ev_decode [1:0];

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_decoder DUT_ama_riscv_decoder_i (
    .clk         (clk         ),
    .rst         (rst         ),
    // inputs    
    .inst_id     (inst_id     ),
    .bc_a_eq_b   (bc_a_eq_b   ),
    .bc_a_lt_b   (bc_a_lt_b   ),
    .bp_taken    (bp_taken    ),
    .bp_clear    (bp_clear    ),
    // outputs   
    .stall_if    (stall_if    ),
    .clear_if    (clear_if    ),
    .clear_id    (clear_id    ),
    .clear_mem   (clear_mem   ),
    .pc_sel      (pc_sel      ),
    .pc_we       (pc_we       ),
    .imem_en     (imem_en     ),
    .branch_inst (branch_inst ),
    .store_inst  (store_inst  ),
    .alu_op_sel  (alu_op_sel  ),
    .alu_a_sel   (alu_a_sel   ),
    .alu_b_sel   (alu_b_sel   ),
    .ig_sel      (ig_sel      ),
    .bc_uns      (bc_uns      ),
    .dmem_en     (dmem_en     ),
    .load_sm_en  (load_sm_en  ),
    .wb_sel      (wb_sel      ),
    .reg_we      (reg_we      )    
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Tasks
task task_driver;
    input [31:0] inst;
    begin
        inst_id = inst;
        
    end
endtask

task task_checker;
    begin    
        // pc_sel
        if (pc_sel != dut_m_pc_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT pc_sel: 'b%2b, Model pc_sel: 'b%2b,", $time, test_values_inst[inst_ii], inst_ii, pc_sel, dut_m_pc_sel);
            errors = errors + 1;
        end
        
        // pc_we
        if (pc_we != dut_m_pc_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT pc_we: 'b%2b, Model pc_we: 'b%2b,", $time, test_values_inst[inst_ii], inst_ii, pc_we, dut_m_pc_we);
            errors = errors + 1;
        end
        
        // imem_en
        if (imem_en != dut_m_imem_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT imem_en: 'b%1b, Model imem_en: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, imem_en, dut_m_imem_en);
            errors = errors + 1;
        end
        
        // branch_inst
        if (branch_inst != dut_m_branch_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT branch_inst: 'b%1b, Model branch_inst: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, branch_inst, dut_m_branch_inst);
            errors = errors + 1;
        end
        
        // store_inst
        if (store_inst != dut_m_store_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT store_inst: 'b%1b, Model store_inst: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, store_inst, dut_m_store_inst);
            errors = errors + 1;
        end
        
        // alu_op_sel
        if (alu_op_sel != dut_m_alu_op_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT alu_op_sel: 'b%4b, Model alu_op_sel: 'b%4b,", $time, test_values_inst[inst_ii], inst_ii, alu_op_sel, dut_m_alu_op_sel);
            errors = errors + 1;
        end
        
        // alu_a_sel
        if (alu_a_sel != dut_m_alu_a_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT alu_a_sel: 'b%1b, Model alu_a_sel: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, alu_a_sel, dut_m_alu_a_sel);
            errors = errors + 1;
        end
        
        // alu_b_sel
        if (alu_b_sel != dut_m_alu_b_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT alu_b_sel: 'b%1b, Model alu_b_sel: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, alu_b_sel, dut_m_alu_b_sel);
            errors = errors + 1;
        end
        
        // ig_sel
        if (ig_sel != dut_m_ig_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT ig_sel: 'b%3b, Model ig_sel: 'b%3b,", $time, test_values_inst[inst_ii], inst_ii, ig_sel, dut_m_ig_sel);
            errors = errors + 1;
        end
        
        // bc_uns
        if (bc_uns != dut_m_bc_uns) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT bc_uns: 'b%1b, Model bc_uns: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, bc_uns, dut_m_bc_uns);
            errors = errors + 1;
        end
        
        // dmem_en
        if (dmem_en != dut_m_dmem_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT dmem_en: 'b%1b, Model dmem_en: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, dmem_en, dut_m_dmem_en);
            errors = errors + 1;
        end
        
        // load_sm_en
        if (load_sm_en != dut_m_load_sm_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT load_sm_en: 'b%1b, Model load_sm_en: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, load_sm_en, dut_m_load_sm_en);
            errors = errors + 1;
        end
        
        // wb_sel
        if (wb_sel != dut_m_wb_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT wb_sel: 'b%2b, Model wb_sel: 'b%2b,", $time, test_values_inst[inst_ii], inst_ii, wb_sel, dut_m_wb_sel);
            errors = errors + 1;
        end
        
        // reg_we
        if (reg_we != dut_m_reg_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h (#%0d), DUT reg_we: 'b%1b, Model reg_we: 'b%1b,", $time, test_values_inst[inst_ii], inst_ii, reg_we, dut_m_reg_we);
            errors = errors + 1;
        end
    
    end // main task body */
endtask

task generate_test_array_values;
    begin
        // non random part:
        test_values_inst[0] = 'h003100b3;   // add  x1 x2 x3
        test_values_inst[1] = 'h403100b3;   // sub  x1 x2 x3
        test_values_inst[2] = 'h003110b3;   // sll  x1 x2 x3
        test_values_inst[3] = 'h003120b3;   // slt  x1 x2 x3
        test_values_inst[4] = 'h003130b3;   // sltu x1 x2 x3
        test_values_inst[5] = 'h003140b3;   // xor  x1 x2 x3
        test_values_inst[6] = 'h003150b3;   // srl  x1 x2 x3
        test_values_inst[7] = 'h403150b3;   // sra  x1 x2 x3
        test_values_inst[8] = 'h003160b3;   // or   x1 x2 x3
        test_values_inst[9] = 'h003170b3;   // and  x1 x2 x3
        
        /* // random part:
        for (i = 0; i < `TEST_CASES; i = i + 1) begin
           test_values_op_sel[i]  <= $random;
           test_values_inst  [i]  <= $random;
           test_values_in_b  [i]  <= $random;
         end */
    end
endtask

task dut_m_task_reset;
    begin
        // dut_m_stall_if   
        // dut_m_clear_if   
        // dut_m_clear_id   
        // dut_m_clear_mem  
        dut_m_pc_sel      = `PC_SEL_START_ADDR;
        dut_m_pc_we       = 1'b1;
        dut_m_imem_en     = 1'b1;
        dut_m_branch_inst = 1'b0;
        dut_m_store_inst  = 1'b0;
        dut_m_alu_op_sel  = 4'b0000;
        dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
        dut_m_alu_b_sel   = `ALU_B_SEL_RS2;
        dut_m_ig_sel      = `IG_DISABLED;
        dut_m_bc_uns      = 1'b0;
        dut_m_dmem_en     = 1'b0;
        dut_m_load_sm_en  = 1'b0;
        dut_m_wb_sel      = `WB_SEL_DMEM;
        dut_m_reg_we      = 1'b0;
    end                  
endtask

task dut_m_task_decode;
    input [31:0] inst;
    begin
        case (inst[6:0])
            'b011_0011: begin   // R-type instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_imem_en     = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = ({inst[30],inst[14:12]});
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_RS2;
                dut_m_ig_sel      = `IG_DISABLED;
                dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
        endcase
    end                  
endtask

task reset;
    input [3:0] clk_pulses_on;
    
    begin
        rst = 1'b0;
        @(posedge clk); #1;
        rst = 1'b1;
        repeat (clk_pulses_on) begin
            @(posedge clk); #1;
            ->ev_rst[0];
            ->ev_rst[1];            
        end
        rst = 1'b0;
        // @(posedge clk); #1;
    end
    
endtask

//-----------------------------------------------------------------------------
// DUT model
initial begin
    @(ev_rst[0]);
    dut_m_task_reset();
    forever begin
        @(ev_decode[0])
        dut_m_task_decode(test_values_inst[inst_ii]);
    end
    
end

//-----------------------------------------------------------------------------
// Checker
initial begin
    @(ev_rst[1]);
    task_checker();
    forever begin
        @(ev_decode[1])
        task_checker();
    end
    
end

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    
    generate_test_array_values();
    
    //done   <= 0;
    errors <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n------------------------ Testing started -------------------------\n\n");
    reset(4'd2);
    
    //-----------------------------------------------------------------------------
    // Test 1: Hit specific cases
    $display("Test  1: Hit specific cases ...");
    
    // $display("Run 1: add  x1 x2 x3");
    task_driver(test_values_inst[inst_ii]);
    @(posedge clk); #1;
    ->ev_decode[0];
    ->ev_decode[1];
    #1;
    
    // $display("Run 2: sub  x1 x2 x3");
    inst_ii = inst_ii + 1;
    task_driver(test_values_inst[inst_ii]);
    @(posedge clk); #1;
    ->ev_decode[0];
    ->ev_decode[1];
    #1;
    
    /* 
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
