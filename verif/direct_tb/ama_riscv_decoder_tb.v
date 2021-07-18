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
//      2021-07-16  AL  0.1.0 - Initial - Reset and R-type (Add & Sub only)
//      2021-07-17  AL  0.2.0 - Add file reads, finish R-type tests
//      2021-07-17  AL  0.3.0 - Add I-type tests
//      2021-07-17  AL  0.4.0 - Add Load tests
//      2021-07-18  AL  0.5.0 - Add Store tests
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define R_TYPE_TESTS            10
`define I_TYPE_TESTS             9
`define LOAD_TESTS               5
`define STORE_TESTS              3
`define TEST_CASES              `R_TYPE_TESTS + `I_TYPE_TESTS + `LOAD_TESTS + `STORE_TESTS

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

// Imm Gen
`define IG_DISABLED 3'b000
`define IG_I_TYPE   3'b001
`define IG_S_TYPE   3'b010
`define IG_B_TYPE   3'b011
`define IG_J_TYPE   3'b100
`define IG_U_TYPE   3'b101

`define PROJECT_PATH        "C:/Users/Aleksandar/Documents/xilinx/ama-riscv/"

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
integer     i;              // used for all loops
integer     inst_ii = 0;    // used for instruction array access only
integer     errors;
integer     warnings;
// file read
integer fd;
integer status;
reg  [20*7:0] str;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [20*7:0] test_values_inst_asm [`TEST_CASES-1:0];
// events
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
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT pc_sel: 'b%2b, Model pc_sel: 'b%2b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], pc_sel, dut_m_pc_sel);
            errors = errors + 1;
        end
        
        // pc_we
        if (pc_we != dut_m_pc_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT pc_we: 'b%2b, Model pc_we: 'b%2b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], pc_we, dut_m_pc_we);
            errors = errors + 1;
        end
        
        // branch_inst
        if (branch_inst != dut_m_branch_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT branch_inst: 'b%1b, Model branch_inst: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], branch_inst, dut_m_branch_inst);
            errors = errors + 1;
        end
        
        // store_inst
        if (store_inst != dut_m_store_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT store_inst: 'b%1b, Model store_inst: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], store_inst, dut_m_store_inst);
            errors = errors + 1;
        end
        
        // alu_op_sel
        if (alu_op_sel != dut_m_alu_op_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT alu_op_sel: 'b%4b, Model alu_op_sel: 'b%4b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], alu_op_sel, dut_m_alu_op_sel);
            errors = errors + 1;
        end
        
        // alu_a_sel
        if (alu_a_sel != dut_m_alu_a_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT alu_a_sel: 'b%1b, Model alu_a_sel: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], alu_a_sel, dut_m_alu_a_sel);
            errors = errors + 1;
        end
        
        // alu_b_sel
        if (alu_b_sel != dut_m_alu_b_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT alu_b_sel: 'b%1b, Model alu_b_sel: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], alu_b_sel, dut_m_alu_b_sel);
            errors = errors + 1;
        end
        
        // ig_sel
        if (ig_sel != dut_m_ig_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT ig_sel: 'b%3b, Model ig_sel: 'b%3b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], ig_sel, dut_m_ig_sel);
            errors = errors + 1;
        end
        
        // bc_uns
        if (bc_uns != dut_m_bc_uns) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT bc_uns: 'b%1b, Model bc_uns: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], bc_uns, dut_m_bc_uns);
            errors = errors + 1;
        end
        
        // dmem_en
        if (dmem_en != dut_m_dmem_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT dmem_en: 'b%1b, Model dmem_en: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], dmem_en, dut_m_dmem_en);
            errors = errors + 1;
        end
        
        // load_sm_en
        if (load_sm_en != dut_m_load_sm_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT load_sm_en: 'b%1b, Model load_sm_en: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], load_sm_en, dut_m_load_sm_en);
            errors = errors + 1;
        end
        
        // wb_sel
        if (wb_sel != dut_m_wb_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT wb_sel: 'b%2b, Model wb_sel: 'b%2b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], wb_sel, dut_m_wb_sel);
            errors = errors + 1;
        end
        
        // reg_we
        if (reg_we != dut_m_reg_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s, DUT reg_we: 'b%1b, Model reg_we: 'b%1b,", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii], reg_we, dut_m_reg_we);
            errors = errors + 1;
        end
    
    end // main task body */
endtask

task read_test_instructions;
    begin
        // Instructions HEX
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/decoder_inst_hex.txt"}, "r");
    
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end
    
        i = 0;
        while(!$feof(fd)) begin
            $fscanf (fd, "%h", test_values_inst_hex[i]);
            // $display("'h%h", test_values_inst_hex[i]);
            i = i + 1;
        end
        $fclose(fd);
        
        // Instructions ASM
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/decoder_inst_asm.txt"}, "r");
        
        if (fd == 0) begin
            $display("fd handle was NULL");        
        end
                
        i = 0;
        while(!$feof(fd)) begin
            status = $fgets(str, fd);
            // $write("%0s", str);
            test_values_inst_asm[i] = str;
            // $write("%0s", test_values_inst_asm[i]);
            i = i + 1;
        end
        $fclose(fd);
    end
endtask

task randomize_instructions;
    begin
        
    // detect instruction
    //      randomize fields that given instruction can
    //      asm text file will no longer be valid -> pass thru disassembler if inst fails
    //      remove printing asm text when randomizing
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
                dut_m_branch_inst = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = ({inst[30], inst[14:12]});
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_RS2;
                dut_m_ig_sel      = `IG_DISABLED;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            'b001_0011: begin   // I-type instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = (inst[13:12] == 2'b01)  ? 
                                    {inst[30], inst[14:12]} : {1'b0, inst[14:12]};
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                dut_m_wb_sel      = `WB_SEL_ALU;
                dut_m_reg_we      = 1'b1;
            end
            
            'b000_0011: begin   // Load instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b1;
                dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b1;
            end
            
            'b010_0011: begin   // Load instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_store_inst  = 1'b1;
                dut_m_alu_op_sel  = 4'b0000;
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_S_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b0;
                // dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b0;
            end
            
            default: begin
                $write("*WARNING @ %0t. Instruction unsupported. Input inst: 'h%8h  %0s", 
            $time, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii]);
                warnings = warnings + 1;
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
    end
    
endtask

//-----------------------------------------------------------------------------
// DUT model
initial begin
    @(ev_rst[0]);
    dut_m_task_reset();
    
    forever begin
        @(ev_decode[0])
        dut_m_task_decode(test_values_inst_hex[inst_ii]);
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
    read_test_instructions();
    errors  <= 0;
    warnings <= 0;
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n----------------------- Simulation started -----------------------\n");
    reset(4'd2);
    
    //-----------------------------------------------------------------------------
    // Test 1: R-type
    $display("\nTest  1: Hit specific cases R-type ... \n");
    
    repeat(`R_TYPE_TESTS) begin
        task_driver(test_values_inst_hex[inst_ii]);
        @(posedge clk); #1;
        ->ev_decode[0];
        ->ev_decode[1];
        #1;
        $write("Run %2d done. Instruction: 'h%8h   %0s", 
        inst_ii, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii]);
        inst_ii = inst_ii + 1;
    end
    
    $display("\nTest  1: Checking specific cases R-type done \n");
    
    //-----------------------------------------------------------------------------
    // Test 2: I-type
    $display("\nTest  2: Hit specific cases I-type ... \n");
    
    repeat(`I_TYPE_TESTS) begin
        task_driver(test_values_inst_hex[inst_ii]);
        @(posedge clk); #1;
        ->ev_decode[0];
        ->ev_decode[1];
        #1;
        $write("Run %2d done. Instruction: 'h%8h   %0s", 
        inst_ii, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii]);
        inst_ii = inst_ii + 1;
    end
    
    $display("\nTest  2: Checking specific cases I-type done \n");
    
    //-----------------------------------------------------------------------------
    // Test 3: Load
    $display("\nTest  3: Hit specific cases Load ... \n");
    
    repeat(`LOAD_TESTS) begin
        task_driver(test_values_inst_hex[inst_ii]);
        @(posedge clk); #1;
        ->ev_decode[0];
        ->ev_decode[1];
        #1;
        $write("Run %2d done. Instruction: 'h%8h   %0s", 
        inst_ii, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii]);
        inst_ii = inst_ii + 1;
    end
    
    $display("\nTest  3: Checking specific cases Load done \n");
    
    //-----------------------------------------------------------------------------
    // Test 4: Store
    $display("\nTest  4: Hit specific cases Store ... \n");
    
    repeat(`STORE_TESTS) begin
        task_driver(test_values_inst_hex[inst_ii]);
        @(posedge clk); #1;
        ->ev_decode[0];
        ->ev_decode[1];
        #1;
        $write("Run %2d done. Instruction: 'h%8h   %0s", 
        inst_ii, test_values_inst_hex[inst_ii], test_values_inst_asm[inst_ii]);
        inst_ii = inst_ii + 1;
    end
    
    $display("\nTest  4: Checking specific cases Store done \n");
    
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    $display("\n----------------------- Simulation results -----------------------");
    $display("Tests ran to completion");
    $write("Status: ");
    if(!errors)
        $display("Passed");
    else
        $display("Failed");
    $display("Warnings: %2d", warnings);
    $display("Errors:   %2d", errors);
    $display("--------------------- End of the simulation ----------------------\n");
    $finish();
end

endmodule
