//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Decoder Testbench
// File:            ama_riscv_decoder_tb.v
// Date created:    2021-07-16
// Author:          Aleksandar Lilic
// Description:     Test covers following scenarios:
//                      1.  Data check after reset
//                      2.  R-type checks direct
//                      3.  Load instructions checks direct
//                      4.  Store instructions checks direct
//                      5.  Branch instructions checks direct
//                      6.  JALR instruction check direct
//
// Version history:
//      2021-07-16  AL  0.1.0 - Initial - Reset and R-type (Add & Sub only)
//      2021-07-17  AL  0.2.0 - Add file reads, finish R-type tests
//      2021-07-17  AL  0.3.0 - Add I-type tests
//      2021-07-17  AL  0.4.0 - Add Load tests
//      2021-07-18  AL  0.5.0 - Add Store tests
//      2021-07-18  AL  0.6.0 - Add new 'run_test()' task, reorder old tasks
//      2021-07-18  AL  0.6.1 - Fix reset
//      2021-07-20  AL  0.7.0 - Rework environment
//                              Add datapath elements for stimuli generation
//                              Move all simulation to tasks
//                              Two threads are controlling entire simulation
//                              1. Main test thread uses sim time
//                              2. Reset thread listens to events from main
//      2021-08-03  AL  0.7.0 - Checkpoint, some features broken
//      2021-08-05  AL  0.8.0 - Align branch instructions
//      2021-08-09  AL  0.9.0 - Add branch tests complete
//      2021-08-10  AL 0.10.0 - Add JALR test
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
//`define CLOCK_FREQ    125_000_000
//`define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
`define RST_TEST                 1
`define R_TYPE_TESTS            10
`define I_TYPE_TESTS             9
`define LOAD_TESTS               5
`define STORE_TESTS              3
`define BRANCH_TESTS             6
`define JALR_TEST                1
`define BRANCH_TESTS_NOPS_PAD    4+1    // 4 nops + 1 branch back instruction
`define TEST_CASES               `RST_TEST + `R_TYPE_TESTS + `I_TYPE_TESTS + `LOAD_TESTS + `STORE_TESTS + `BRANCH_TESTS + `JALR_TEST + `BRANCH_TESTS_NOPS_PAD
`define LABEL_TGT                `TEST_CASES - 1 // 38 when branch tests were completed // location to which to branch

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
reg  [31:0] inst_ex   ; 
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
wire        pc_we      ;
wire        branch_inst;
wire        jump_inst  ;
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
reg         dut_m_stall_if      ;
reg         dut_m_clear_if      ;
reg         dut_m_clear_id      ;
reg         dut_m_clear_mem     ;
reg  [ 1:0] dut_m_pc_sel        ;
reg         dut_m_pc_we         ;
reg         dut_m_branch_inst   ;
reg         dut_m_jump_inst     ;
reg         dut_m_store_inst    ;
reg  [ 3:0] dut_m_alu_op_sel    ;
reg         dut_m_alu_a_sel     ;
reg         dut_m_alu_b_sel     ;
reg  [ 2:0] dut_m_ig_sel        ;
reg         dut_m_bc_uns        ;
reg         dut_m_dmem_en       ;
reg         dut_m_load_sm_en    ;
reg  [ 1:0] dut_m_wb_sel        ;
reg         dut_m_reg_we        ;
reg         dut_m_branch_taken  ;
reg         dut_m_branch_inst_ex;
reg         dut_m_jump_inst_ex  ;
reg         dut_m_jump_taken    ;

// DUT environment
reg  [31:0] dut_env_inst_id     ;
reg  [31:0] dut_env_inst_ex     ;
integer     dut_env_pc          ;
integer     dut_env_alu         ;
integer     dut_env_pc_mux_out  ;
integer     alu_return_address  ;
reg         dut_env_bc_a_eq_b   ;
reg         dut_env_bc_a_lt_b   ;

// Reset hold for
reg  [ 3:0] rst_pulses = 4'd3;

// Testbench variables
integer     i                   ;              // used for all loops
integer     run_test_pc_target  ;
integer     errors              ;
integer     warnings            ;

// file read
integer fd;
integer status;
reg  [24*7:0] str;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];
reg  [  31:0] test_values_inst_hex_nop;
reg  [24*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [24*7:0] test_values_inst_asm_nop;
reg  [24*7:0] dut_env_inst_id_asm;
reg  [24*7:0] dut_env_inst_ex_asm;

// events
event ev_rst    [1:0];
integer rst_done = 0;


//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_decoder DUT_ama_riscv_decoder_i (
    .clk         (clk         ),
    .rst         (rst         ),
    // inputs    
    .inst_id     (inst_id     ),
    .inst_ex     (inst_ex     ),
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
    .jump_inst   (jump_inst   ),
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
task print_test_results;
    begin
        $display("Instruction at PC# %2d done. ", dut_env_pc); 
        $write  ("ID stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_id, dut_env_inst_id_asm);
        $write  ("EX stage: HEX: 'h%8h, ASM: %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
    end
endtask

task tb_driver;
    input [31:0] task_inst_id;
    input [31:0] task_inst_ex;
    input        a_eq_b;
    input        a_lt_b;
    
    begin
        inst_id   = task_inst_id;
        inst_ex   = task_inst_ex;
        bc_a_eq_b = a_eq_b;
        bc_a_lt_b = a_lt_b;
    end
    
endtask

task tb_checker;
    begin    
        // pc_sel
        if (pc_sel !== dut_m_pc_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT pc_sel: 'b%2b, Model pc_sel: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, pc_sel, dut_m_pc_sel);
            errors = errors + 1;
        end
        
        // pc_we
        if (pc_we !== dut_m_pc_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT pc_we: 'b%2b, Model pc_we: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, pc_we, dut_m_pc_we);
            errors = errors + 1;
        end
        
        // branch_inst
        if (branch_inst !== dut_m_branch_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT branch_inst: 'b%1b, Model branch_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, branch_inst, dut_m_branch_inst);
            errors = errors + 1;
        end
        
         // jump_inst
        if (jump_inst !== dut_m_jump_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT jump_inst: 'b%1b, Model jump_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, jump_inst, dut_m_jump_inst);
            errors = errors + 1;
        end
        
        // store_inst
        if (store_inst !== dut_m_store_inst) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT store_inst: 'b%1b, Model store_inst: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, store_inst, dut_m_store_inst);
            errors = errors + 1;
        end
        
        // alu_op_sel
        if (alu_op_sel !== dut_m_alu_op_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_op_sel: 'b%4b, Model alu_op_sel: 'b%4b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_op_sel, dut_m_alu_op_sel);
            errors = errors + 1;
        end
        
        // alu_a_sel
        if (alu_a_sel !== dut_m_alu_a_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_a_sel: 'b%1b, Model alu_a_sel: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_a_sel, dut_m_alu_a_sel);
            errors = errors + 1;
        end
        
        // alu_b_sel
        if (alu_b_sel !== dut_m_alu_b_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT alu_b_sel: 'b%1b, Model alu_b_sel: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, alu_b_sel, dut_m_alu_b_sel);
            errors = errors + 1;
        end
        
        // ig_sel
        if (ig_sel !== dut_m_ig_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT ig_sel: 'b%3b, Model ig_sel: 'b%3b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, ig_sel, dut_m_ig_sel);
            errors = errors + 1;
        end
        
        // bc_uns
        if (bc_uns !== dut_m_bc_uns) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT bc_uns: 'b%1b, Model bc_uns: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, bc_uns, dut_m_bc_uns);
            errors = errors + 1;
        end
        
        // dmem_en
        if (dmem_en !== dut_m_dmem_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT dmem_en: 'b%1b, Model dmem_en: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, dmem_en, dut_m_dmem_en);
            errors = errors + 1;
        end
        
        // load_sm_en
        if (load_sm_en !== dut_m_load_sm_en) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT load_sm_en: 'b%1b, Model load_sm_en: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, load_sm_en, dut_m_load_sm_en);
            errors = errors + 1;
        end
        
        // wb_sel
        if (wb_sel !== dut_m_wb_sel) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT wb_sel: 'b%2b, Model wb_sel: 'b%2b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, wb_sel, dut_m_wb_sel);
            errors = errors + 1;
        end
        
        // reg_we
        if (reg_we !== dut_m_reg_we) begin
            $display("*ERROR @ %0t. Input inst: 'h%8h  %0s    DUT reg_we: 'b%1b, Model reg_we: 'b%1b ", 
            $time, dut_env_inst_id, dut_env_inst_id_asm, reg_we, dut_m_reg_we);
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
        test_values_inst_hex_nop = 'h0000_0013;
        
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
        test_values_inst_asm_nop = "addi  x0 x0 0 \n";
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

task dut_m_decode;
    input [31:0] inst_id;
    input [31:0] inst_ex;
    begin
        case (inst_id[6:0])
            'b011_0011: begin   // R-type instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = ({inst_id[30], inst_id[14:12]});
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
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = (inst_id[13:12] == 2'b01)  ? 
                                    {inst_id[30], inst_id[14:12]} : {1'b0, inst_id[14:12]};
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
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b1;
                dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b1;
            end
            
            'b010_0011: begin   // Store instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b1;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b1;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_S_TYPE;
                // dut_m_bc_uns      = 1'b0;
                dut_m_dmem_en     = 1'b1;
                dut_m_load_sm_en  = 1'b0;
                // dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b0;
            end
            
            'b110_0011: begin   // Branch instruction
                dut_m_pc_sel      = `PC_SEL_INC4;
                dut_m_pc_we       = 1'b0;
                dut_m_branch_inst = 1'b1;
                dut_m_jump_inst   = 1'b0;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_B_TYPE;
                dut_m_bc_uns      = inst_id[13];
                dut_m_dmem_en     = 1'b0;
                dut_m_load_sm_en  = 1'b0;
                // dut_m_wb_sel      = `WB_SEL_DMEM;
                dut_m_reg_we      = 1'b0;
            end
            
            'b110_0111: begin   // JALR instruction
                dut_m_pc_sel      = `PC_SEL_ALU;
                dut_m_pc_we       = 1'b0;
                dut_m_branch_inst = 1'b0;
                dut_m_jump_inst   = 1'b1;
                dut_m_store_inst  = 1'b0;
                dut_m_alu_op_sel  = 4'b0000;    // add
                dut_m_alu_a_sel   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel   = `ALU_B_SEL_IMM;
                dut_m_ig_sel      = `IG_I_TYPE;
                // dut_m_bc_uns      = *;
                dut_m_dmem_en     = 1'b0;
                // dut_m_load_sm_en  = *;
                dut_m_wb_sel      = `WB_SEL_INC4;
                dut_m_reg_we      = 1'b1;
            end
            
            default: begin
                $write("*WARNING @ %0t. Model 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_env_inst_id, dut_env_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
        
        // Override if rst == 1
        if (rst) begin
            dut_m_pc_sel      = 2'b11;
            dut_m_pc_we       = 1'b1;
            dut_m_branch_inst = 1'b0;
            dut_m_jump_inst   = 1'b0;
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
        
        // branch resolution
        case ({inst_ex[14],inst_ex[12]})
            2'b00:      // beq -> a == b
                dut_m_branch_taken = dut_env_bc_a_eq_b;
            
            2'b01:      // bne -> a != b
                dut_m_branch_taken = !dut_env_bc_a_eq_b;
            
            2'b10:      // blt -> a < b
                dut_m_branch_taken = dut_env_bc_a_lt_b;
            
            2'b11:      // bge -> a >= b
                dut_m_branch_taken = dut_env_bc_a_eq_b || !dut_env_bc_a_lt_b;
            
            default: begin
                $write("*WARNING @ %0t. Branch model 'default' case. Input inst_ex: 'h%8h  %0s",
                $time, dut_env_inst_ex, dut_env_inst_ex_asm);
                warnings = warnings + 1;
            end
            
        endcase
        
        // Override if rst == 1
        if (rst) dut_m_branch_taken = 1'b0;
        
        // if not branch instruction, it cannot be taken
        dut_m_branch_taken = dut_m_branch_taken && dut_m_branch_inst_ex;
        
        // jump?
        dut_m_jump_taken = dut_m_jump_inst_ex;
        
        if(dut_m_branch_taken || dut_m_jump_taken) dut_m_pc_sel = 2'b01; // alu input
        
        // $display("\nBranch used inst ex: %8h, branch_instr: %1b ", dut_env_inst_ex, dut_m_branch_inst_ex);
        
    end                  
endtask // dut_m_decode

task env_reset;
    begin
        dut_env_inst_id = 'h0;
        dut_env_inst_ex = 'h0;
        // dut_env_pc      = 0;
        dut_env_alu     = 'h1;  // temp, always return to second (idx=1) instruction
    end
endtask

task env_pc_mux_update;
    begin
        case (pc_sel)   // use DUT or model?
            2'd0: begin
                dut_env_pc_mux_out =  dut_env_pc + 1;
            end
            
            2'd1: begin
                dut_env_pc_mux_out =  dut_env_alu;
            end
            
            2'd2: begin
                $display("*WARNING @ %0t. pc_sel = 2 is not supported yet - TBD for prediction", $time);
                warnings = warnings + 1;
            end
            
            2'd3: begin
                dut_env_pc_mux_out =  'h0;  // start address
            end
            
            default: begin
                if(rst_done) begin
                    $display("*ERROR @ %0t. pc_sel not valid", $time);
                    errors = errors + 1;
                end 
                else /* !rst_done */ begin
                    $display("*WARNING @ %0t. pc_sel not valid", $time);
                    warnings = warnings + 1;
                end
            end
        endcase
    end
endtask

task env_inst_id_update;
    reg stall_if;
    begin
        stall_if = dut_m_branch_inst_ex || dut_m_jump_inst_ex;
        if (stall_if) begin    // stall_if, convert to nop
            dut_env_inst_id      = test_values_inst_hex_nop;
            dut_env_inst_id_asm  = test_values_inst_asm_nop;
        end
        else begin
            dut_env_inst_id      = test_values_inst_hex[dut_env_pc_mux_out];
            dut_env_inst_id_asm  = test_values_inst_asm[dut_env_pc_mux_out];
        end
    end
endtask

task env_pc_update;
    begin
        dut_env_pc = (!rst)         ? 
                     (dut_m_pc_we)  ? dut_env_pc_mux_out   :   // mux
                                      dut_env_pc           :   // pc_we = 0
                                      'h0;                     // rst = 1
    end
endtask

task env_inst_ex_update;
    begin
        // env update
        dut_env_inst_ex      = (!rst) ? dut_env_inst_id      : 'h0;
        dut_env_inst_ex_asm  = (!rst) ? dut_env_inst_id_asm  : 'h0;
        
        // but also model update
        dut_m_branch_inst_ex = (!rst) ? dut_m_branch_inst    : 'b0;
        dut_m_jump_inst_ex   = (!rst) ? dut_m_jump_inst      : 'b0;
    end
endtask

task env_branch_compare_update;
    input take_branch;
    begin
        // $display("env_branch_compare_update, take_branch: 'b%0b, input inst_ex: 'h%8h  %0s", take_branch, dut_env_inst_ex, dut_env_inst_ex_asm);
        case ({dut_env_inst_ex[14], dut_env_inst_ex[12]})
            2'b00: begin     // beq -> a == b
                dut_env_bc_a_eq_b = take_branch;
                dut_env_bc_a_lt_b = dut_env_bc_a_eq_b ? 1'b0 : $random;
                // $display("env_branch_compare_update, beq");
            end
            
            2'b01: begin     // bne -> a != b
                // $display("env_branch_compare_update, bne");
                dut_env_bc_a_eq_b = !take_branch;
                dut_env_bc_a_lt_b = $random;
            end
            
            2'b10: begin     // blt -> a < b
                // $display("env_branch_compare_update, blt");
                dut_env_bc_a_lt_b = take_branch;
                dut_env_bc_a_eq_b = dut_env_bc_a_lt_b ? 1'b0 : $random;
            end
            
            2'b11: begin     // bge -> a >= b
                // $display("env_branch_compare_update, bge");
                dut_env_bc_a_eq_b = ($random & take_branch);
                dut_env_bc_a_lt_b = dut_env_bc_a_eq_b ? 1'b0 : !take_branch;
            end
            
            default: begin
                $write("*WARNING @ %0t. env_branch_compare_update 'default' case. Input inst_ex: 'h%8h  %0s",
                $time, dut_env_inst_ex, dut_env_inst_ex_asm);
                warnings = warnings + 1;
            end
            
        endcase
    end
endtask

task env_alu_out_update;
    input [31:0] in_dut_env_alu;
    begin
        dut_env_alu = in_dut_env_alu;
    end
endtask

task env_update_seq;
    begin
        env_inst_ex_update();
        // $write("inst_ex - FF reg:    'h%8h    %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        env_inst_id_update();
        // $write("inst_id - IMEM read: 'h%8h    %0s", dut_env_inst_id, dut_env_inst_id_asm);
        env_pc_update();
        // $display("PC reg: %0d ", dut_env_pc);
    end
endtask

task env_update_comb;
    input [31:0] alu_out_update;
    input        branch_compare_update;
    begin
        env_branch_compare_update(branch_compare_update);
        // $display("Branch compare result - eq: %0b, lt: %0b ", dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        env_alu_out_update(alu_out_update);
        // $display("ALU out: %0d ", dut_env_alu);
        env_pc_mux_update();
        // $display("PC sel: %0d ", pc_sel);
        // $display("PC MUX: %0d ", dut_env_pc_mux_out);
    end
endtask

//-----------------------------------------------------------------------------
// Reset
initial begin
    // sync this thread with events from main thread
    @(ev_rst[0]); // #1;
    $display("\nReset Sequence start \n");    
    rst = 1'b0;
    
    @(ev_rst[0]); // @(posedge clk); #1;
    
    rst = 1'b1;
    repeat (rst_pulses) begin
        @(ev_rst[0]); //@(posedge clk); #1;          
    end
    rst = 1'b0;
    // @(ev_rst[0]); //@(posedge clk); #1;  
    // ->ev_rst_done;
    $display("\nReset Sequence end \n");
    rst_done = 1;
    
end

//-----------------------------------------------------------------------------
// Config
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    read_test_instructions();
    env_reset();
    errors   <= 0;
    warnings <= 0;
end

// Timestamp print
initial begin
    forever begin
        $display("\n\n\n --- Sim time : %0t ---\n", $time);
        @(posedge clk);
    end
end

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n----------------------- Simulation started -----------------------\n");
    
    // Test 0: Wait for reset
    $display("\nTest  0: Wait for reset: Start \n");
    @(posedge clk); #1;
    while (!rst_done) begin
        // $display("Reset not done, time: %0t \n", $time);
         ->ev_rst[0]; #1;
        
        // if still not done, wait for next clk else update env and exit
        if(!rst_done) begin @(posedge clk); #1; end

        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; env_update_comb('h0, 'b0);
    end
    $display("Reset done, time: %0t \n", $time);
    
    // wait for DUT to actually go out of reset
    @(posedge clk); #1; 
    $display("Checking reset exit, time: %0t \n", $time);
    env_update_seq();
    tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
    dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
    #1; tb_checker();
    print_test_results();
    env_update_comb('h0, 'b0);
    $display("\nTest  0: Wait for reset: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: R-type
    $display("\nTest  1: Hit specific case [R-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `R_TYPE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  1: Hit specific case [R-type]: Done \n");
     
    //-----------------------------------------------------------------------------
    // Test 2: I-type
    $display("\nTest  2: Hit specific case [I-type]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `I_TYPE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  2: Hit specific case [I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 3: Load
    $display("\nTest  3: Hit specific case [Load]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `LOAD_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  3: Hit specific case [Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 4: Store
    $display("\nTest  4: Hit specific case [Stores]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `STORE_TESTS;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
        #1; tb_checker();
        print_test_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  4: Hit specific case [Stores]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 5: Branch
    $display("\nTest  5: Hit specific cases [Branches]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `BRANCH_TESTS ;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_env_pc_mux_out + 1;
        // $display("\ndut_env_pc: %0d ",          dut_env_pc);
        // $display("\ndut_env_pc_mux_out: %0d ",  dut_env_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute branch instruction");
            
            env_update_seq();
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(`LABEL_TGT, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was branched to - Return instruction");
            
            env_update_seq();            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
    end // while(dut_env_pc_mux_out < run_test_pc_target)        
    $display("\nTest  5: Hit specific cases [Branches]: Done \n");    
    
    //-----------------------------------------------------------------------------
    // Test 6: JALR
    $display("\nTest  6: Hit specific case [JALR]: Start \n");
    run_test_pc_target  = dut_env_pc_mux_out + `JALR_TEST ;
    while(dut_env_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_env_pc_mux_out + 1;
        // $display("\ndut_env_pc: %0d ",          dut_env_pc);
        // $display("\ndut_env_pc_mux_out: %0d ",  dut_env_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute JALR instruction");
            
            env_update_seq();
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; tb_checker();
            print_test_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
            dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_env_pc_mux_out);
        end
        
    end // while(dut_env_pc_mux_out < run_test_pc_target)
    
    $display("\nTest  6b: Jump finishes properly? Execute next instruction to verify\n");
    @(posedge clk); #1;
    env_update_seq();
    tb_driver(dut_env_inst_id, dut_env_inst_ex, dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
    dut_m_decode(dut_env_inst_id, dut_env_inst_ex);
    #1; tb_checker();
    print_test_results();
    env_update_comb('h0, 'b0);
    
    $display("\nTest  6: Hit specific case [JALR]: Done \n");
    
    
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
