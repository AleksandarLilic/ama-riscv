//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Core Testbench
// File:            ama_riscv_core_tb.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     Testbench and model for ama_riscv_core module
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test covers following scenarios:
// 
// Version history:
//      2021-09-11  AL  0.1.0 - Initial - IF stage
//      2021-09-13  AL  0.2.0 - Add model - IF stage
//      2021-09-13  AL  0.3.0 - Add checker - IF stage
//      2021-09-14  AL  0.4.0 - WIP - Add model - ID stage
//      2021-09-15  AL  0.5.0 - WIP - Add imm_gen and decoder model - ID stage
//      2021-09-16  AL  0.6.0 - Add reset sequence
//      2021-09-17  AL  0.7.0 - Rework checkers
//      2021-09-17  AL  0.8.0 - Add ID/EX stage FF checkers
//      2021-09-18  AL  0.8.1 - Fix ID stage names
//      2021-09-18  AL  0.8.2 - Fix PC notation - match RTL
//      2021-09-18  AL  0.9.0 - Add ID/EX pipeline signals and Branch Compare model
//      2021-09-18  AL 0.10.0 - Add ALU and Branch Resolution models and checkers
//      2021-09-19  AL 0.11.0 - Add DMEM model and checkers
//      2021-09-20  AL 0.12.0 - Add core 0.1.0 test arrays
//      2021-09-21  AL 0.12.1 - Fix store_inst_ex
//      2021-09-21  AL 0.13.0 - Add EX/MEM pipeline signals
//      2021-09-21  AL 0.14.0 - Add MEM stage and Writeback
//      2021-09-22  AL 0.15.0 - Add RF forwarding - pending proper implementation
//      
//      note: implement 1:1 rf forwarding
//      note: add checker IDs, print on exit number of samples checked and results
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD               8
// `define CLOCK_FREQ    125_000_000
// `define SIM_TIME     `CLOCK_FREQ*0.0009 // 900us
// `define RST_TEST                 1
`define STARTUP_TESTS            4
`define R_TYPE_TESTS            10 + 1 // add the 'or' inst from previous hex
`define I_TYPE_TESTS             9
`define LOAD_TESTS               5
`define STORE_TESTS              3
`define BRANCH_TESTS             6
`define JALR_TEST                1
`define JAL_TEST                 1
`define LUI_TEST                 1
`define AUIPC_TEST               1
`define BRANCH_TESTS_NOPS_PAD    4+1    // 4 nops + 1 branch back instruction
`define TEST_CASES_DEC           /* `RST_TEST + */ `STARTUP_TESTS + `R_TYPE_TESTS + `I_TYPE_TESTS + `LOAD_TESTS + `STORE_TESTS + `BRANCH_TESTS + `JALR_TEST + `JAL_TEST + `LUI_TEST + `AUIPC_TEST + `BRANCH_TESTS_NOPS_PAD
// `define LABEL_TGT                `TEST_CASES_DEC - 1 // location to which to branch

`define NFND_TEST                5           // No Forwarding No Dependency
`define FDRT_TEST                12*2 + 3*2  // Forwarding with Dependency R-type
`define FDIT_TEST                12*2 + 3*2  // Forwarding with Dependency I-type
`define FDL_TEST                 12*2 + 3*2  // Forwarding with Dependency Load
`define NFX0_TEST                7*2         // No Forwarding with Dependency on x0
`define NFWE0_TEST               4*2         // No Forwarding with reg_we_ex = 0
`define TEST_CASES_FWD           `NFND_TEST + `FDRT_TEST + `FDIT_TEST + `FDL_TEST + `NFX0_TEST+ `NFWE0_TEST

`define TEST_CASES               `TEST_CASES_DEC + `TEST_CASES_FWD

// Reg File
`define RF_DATA_WIDTH         32
`define RF_NUM                32

// TB
`define CHECKER_ACTIVE        1'b1
`define CHECKER_INACTIVE      1'b0

// Expected dependencies in each of the dependency tests
`define FD_TEST_EXP_ALU_A      7  // for ALU A
`define FD_TEST_EXP_ALU_B      2  // for ALU B
`define FD_TEST_EXP_BC_A       2  // for BC A 
`define FD_TEST_EXP_BCS_B      4  // for BCS B

// MUX select signals
// PC select
`define PC_SEL_INC4         2'd0  // PC = PC + 4
`define PC_SEL_ALU          2'd1  // ALU output, used for jump/branch
`define PC_SEL_BP           2'd2  // PC = Branch prediction output
`define PC_SEL_START_ADDR   2'd3  // PC = Hardwired start address

// ALU A operand select
`define ALU_A_SEL_RS1       2'd0  // A = Reg[rs1]
`define ALU_A_SEL_PC        2'd1  // A = PC
`define ALU_A_SEL_FWD_ALU   2'd2  // A = ALU; forwarding from MEM stage

// ALU B operand select
`define ALU_B_SEL_RS2       2'd0  // B = Reg[rs2]
`define ALU_B_SEL_IMM       2'd1  // B = Immediate value; from Imm Gen
`define ALU_B_SEL_FWD_ALU   2'd2  // B = ALU; forwarding from MEM stage

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

`define DUT                 DUT_ama_riscv_core_i
`define DUT_DEC             DUT_ama_riscv_core_i.ama_riscv_control_i.ama_riscv_decoder_i

module ama_riscv_core_tb();

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O
reg         clk = 0;
reg         rst;

//-----------------------------------------------------------------------------
// Model

// Datapath
// IF stage
reg  [31:0] dut_m_pc                ;
reg  [31:0] dut_m_pc_mux_out        ;

// ID stage
// in
reg  [31:0] dut_m_inst_id           ;
reg  [ 4:0] dut_m_rs1_addr_id       ;
reg  [ 4:0] dut_m_rs2_addr_id       ;
reg  [ 4:0] dut_m_rd_addr_id        ;
reg  [24:0] dut_m_imm_gen_in        ;
reg  [`RF_DATA_WIDTH-1:0]  dut_m_rf32 [`RF_NUM-1:0];
// out
reg  [31:0] dut_m_rs1_data_id       ;
reg  [31:0] dut_m_rs2_data_id       ;
reg  [31:0] dut_m_imm_gen_out_id    ;

// EX stage
// in
reg  [31:0] dut_m_pc_ex             ;
reg  [31:0] dut_m_inst_ex           ;
reg  [31:0] dut_m_rs1_data_ex       ;
reg  [31:0] dut_m_rs2_data_ex       ;
reg  [ 4:0] dut_m_rd_addr_ex        ;
reg  [31:0] dut_m_imm_gen_out_ex    ;
// out
reg  [31:0] dut_m_alu_out           ;
reg  [ 1:0] dut_m_load_sm_offset_ex ;
reg  [13:0] dut_m_dmem_addr         ;
reg  [31:0] dut_m_dmem_write_data   ;
// to control
reg         dut_m_bc_a_eq_b         ;
reg         dut_m_bc_a_lt_b         ;
reg  [ 1:0] dut_m_store_mask_offset ;

// MEM stage
// in
reg  [31:0] dut_m_pc_mem            ;
reg  [31:0] dut_m_alu_out_mem       ;
reg  [31:0] dut_m_dmem_read_data_mem;
reg  [ 1:0] dut_m_load_sm_offset_mem;
reg  [31:0] dut_m_inst_mem          ;
reg  [ 4:0] dut_m_rd_addr_mem       ;
// out
reg  [31:0] dut_m_load_sm_data_out  ;
reg  [31:0] dut_m_writeback         ;


// Control Outputs - Pipeline Registers
reg         dut_m_stall_if      ;
reg         dut_m_stall_if_q1   ;
reg         dut_m_clear_if      ;
reg         dut_m_clear_id      ;
reg         dut_m_clear_ex      ;
reg         dut_m_clear_mem     ;


// Control Outputs
// for IF stage
reg  [ 1:0] dut_m_pc_sel_if         ;
reg         dut_m_pc_we_if          ;
// for ID stage 
reg         dut_m_store_inst_id     ;
reg         dut_m_branch_inst_id    ;
reg         dut_m_jump_inst_id      ;
reg  [ 3:0] dut_m_alu_op_sel_id     ;
reg  [ 2:0] dut_m_imm_gen_sel_id    ;
reg         dut_m_reg_we_id         ;
reg  [ 1:0] dut_m_alu_a_sel_fwd_id  ;
reg  [ 1:0] dut_m_alu_b_sel_fwd_id  ;
// for EX stage 
reg         dut_m_bc_uns_id         ;
reg         dut_m_dmem_en_id        ;
reg         dut_m_bc_a_sel_fwd_id   ;
reg         dut_m_bcs_b_sel_fwd_id  ;
reg  [ 3:0] dut_m_dmem_we_ex        ;
// for MEM stage    
reg         dut_m_load_sm_en_id     ;
reg  [ 1:0] dut_m_wb_sel_id         ;

// Control Outputs in datapath
// in EX stage
reg         dut_m_reg_we_ex         ;
reg         dut_m_bc_uns_ex         ;
reg         dut_m_bc_a_sel_fwd_ex   ;
reg         dut_m_bcs_b_sel_fwd_ex  ;
reg  [ 1:0] dut_m_alu_a_sel_fwd_ex  ;
reg  [ 1:0] dut_m_alu_b_sel_fwd_ex  ;
reg  [ 3:0] dut_m_alu_op_sel_ex     ;
reg         dut_m_dmem_en_ex        ;
reg         dut_m_load_sm_en_ex     ;
reg  [ 1:0] dut_m_wb_sel_ex         ;
// in MEM stage
reg         dut_m_reg_we_mem        ;
reg         dut_m_load_sm_en_mem    ;
reg  [ 1:0] dut_m_wb_sel_mem        ;



// Model internal signals
reg  [31:0] dut_m_pc_mux_out_div4       ;
reg  [31:0] dut_m_inst_id_read          ;
reg[30*7:0] dut_m_inst_id_read_asm      ;
reg  [31:0] dut_m_imm_gen_out_id_prev   ;
reg         dut_m_alu_a_sel_id          ;
reg         dut_m_alu_b_sel_id          ;
reg         dut_m_branch_taken          ;
reg         dut_m_jump_taken            ;
reg         dut_m_branch_inst_ex        ;
reg         dut_m_jump_inst_ex          ;
reg         dut_m_store_inst_ex         ;

reg  [31:0] dut_m_alu_in_a              ;
reg  [31:0] dut_m_alu_in_b              ;
reg  [ 4:0] dut_m_alu_shamt             ;

reg  [ 2:0] dut_m_load_sm_width         ;
reg  [31:0] dut_m_load_sm_data_out_prev ;

wire [31:0] dut_m_rd_data = dut_m_writeback ;

// RF named
// name: register_abi-name                   // Description
wire [31:0] dut_m_x0_zero = dut_m_rf32[0];   // hard-wired zero
wire [31:0] dut_m_x1_ra   = dut_m_rf32[1];   // return address
wire [31:0] dut_m_x2_sp   = dut_m_rf32[2];   // stack pointer 
wire [31:0] dut_m_x3_gp   = dut_m_rf32[3];   // global pointer
wire [31:0] dut_m_x4_tp   = dut_m_rf32[4];   // thread pointer
wire [31:0] dut_m_x5_t0   = dut_m_rf32[5];   // temporary/alternate link register
wire [31:0] dut_m_x6_t1   = dut_m_rf32[6];   // temporary
wire [31:0] dut_m_x7_t2   = dut_m_rf32[7];   // temporary
wire [31:0] dut_m_x8_s0   = dut_m_rf32[8];   // saved register/frame pointer
wire [31:0] dut_m_x9_s1   = dut_m_rf32[9];   // saved register
wire [31:0] dut_m_x10_a0  = dut_m_rf32[10];  // function argument/return value
wire [31:0] dut_m_x11_a1  = dut_m_rf32[11];  // function argument/return value
wire [31:0] dut_m_x12_a2  = dut_m_rf32[12];  // function argument
wire [31:0] dut_m_x13_a3  = dut_m_rf32[13];  // function argument
wire [31:0] dut_m_x14_a4  = dut_m_rf32[14];  // function argument
wire [31:0] dut_m_x15_a5  = dut_m_rf32[15];  // function argument
wire [31:0] dut_m_x16_a6  = dut_m_rf32[16];  // function argument
wire [31:0] dut_m_x17_a7  = dut_m_rf32[17];  // function argument
wire [31:0] dut_m_x18_s2  = dut_m_rf32[18];  // saved register
wire [31:0] dut_m_x19_s3  = dut_m_rf32[19];  // saved register
wire [31:0] dut_m_x20_s4  = dut_m_rf32[20];  // saved register
wire [31:0] dut_m_x21_s5  = dut_m_rf32[21];  // saved register
wire [31:0] dut_m_x22_s6  = dut_m_rf32[22];  // saved register
wire [31:0] dut_m_x23_s7  = dut_m_rf32[23];  // saved register
wire [31:0] dut_m_x24_s8  = dut_m_rf32[24];  // saved register
wire [31:0] dut_m_x25_s9  = dut_m_rf32[25];  // saved register
wire [31:0] dut_m_x26_s10 = dut_m_rf32[26];  // saved register
wire [31:0] dut_m_x27_s11 = dut_m_rf32[27];  // saved register
wire [31:0] dut_m_x28_t3  = dut_m_rf32[28];  // temporary
wire [31:0] dut_m_x29_t4  = dut_m_rf32[29];  // temporary
wire [31:0] dut_m_x30_t5  = dut_m_rf32[30];  // temporary
wire [31:0] dut_m_x31_t6  = dut_m_rf32[31];  // temporary

// DUT internals for checkers only
wire dut_internal_branch_taken = `DUT_DEC.branch_res && `DUT_DEC.branch_inst_ex;


//-----------------------------------------------------------------------------
// Testbench variables
integer       i                   ;              // used for all loops
integer       clocks_to_execute   ;
integer       run_test_pc_target  ;
integer       errors              ;
integer       warnings            ;
integer       pre_rst_warnings    ;

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// file read
integer       fd;
integer       status;
reg  [  31:0] test_values_inst_hex [`TEST_CASES-1:0];       // imem sim
reg  [  31:0] test_values_inst_hex_nop;
reg  [  31:0] test_values_dmem [`TEST_CASES-1:0];           // dmem sim
reg  [30*7:0] str;
reg  [30*7:0] test_values_inst_asm [`TEST_CASES-1:0];
reg  [30*7:0] test_values_inst_asm_nop  ;

reg  [30*7:0] dut_m_inst_id_asm       ;
reg  [30*7:0] dut_m_inst_ex_asm       ;
reg  [30*7:0] dut_m_inst_mem_asm      ;

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_core DUT_ama_riscv_core_i (
    .clk                (clk         ),
    .rst                (rst         )
);

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Testbench tasks
task print_test_status;
    begin
        $display("\n----------------------- Simulation results -----------------------");
        $display("Tests ran to completion");
        $write("Status: ");
        if(!errors)
            $display("Passed");
        else
            $display("Failed");
        $display("Pre RST Warnings: %2d", pre_rst_warnings);
        $display("Warnings:         %2d", warnings);
        $display("Errors:           %2d", errors);
        $display("--------------------- End of the simulation ----------------------\n");
    end
endtask

task print_single_instruction_results;
    integer last_pc;
    reg     stalled;
    begin
        stalled = (last_pc == dut_m_pc);
        $display("Instruction at PC# %2d %s ", dut_m_pc, stalled ? "stalled " : "executed"); 
        $write  ("ID  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_id,  dut_m_inst_id_asm );
        // $write  ("EX  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_ex,  dut_m_inst_ex_asm );
        // $write  ("MEM stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_mem, dut_m_inst_mem_asm);
        last_pc = dut_m_pc;
    end
endtask

task read_test_instructions;
    begin
        // Instructions HEX
        // Core test
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/core_inst_hex.txt"}, "r");    
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
        // Core test
        fd = $fopen({`PROJECT_PATH, "verif/direct_tb/inst/core_inst_asm.txt"}, "r");
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

task checker_t;
    input reg  [30*7:0] checker_name            ;
    input reg           checker_active          ;
    // input reg  [ 5:0]   checker_width           ;
    input reg  [31:0]   checker_dut_signal      ;
    input reg  [31:0]   checker_model_signal    ;
    
    begin
        if (checker_active == 1) begin
            if (checker_dut_signal !== checker_model_signal) begin
                $display("*ERROR @ %0t. Checker: \"%0s\"; DUT: %5d, Model: %5d ", 
                    $time, checker_name, checker_dut_signal, checker_model_signal);
                errors = errors + 1;
            end // checker compare
        end // checker valid
    end
endtask

task run_checkers;
    begin
        // Datapath        
        // IF_stage
        checker_t("pc",                 `CHECKER_ACTIVE,    `DUT.pc,                    dut_m_pc                );
        checker_t("pc_mux_out",         `CHECKER_ACTIVE,    `DUT.pc_mux_out,            dut_m_pc_mux_out        );
        // ID_Stage 
        checker_t("inst_id",            `CHECKER_ACTIVE,    `DUT.inst_id,               dut_m_inst_id           );
        checker_t("rs1_data_id",        `CHECKER_ACTIVE,    `DUT.rs1_data_id,           dut_m_rs1_data_id       );
        checker_t("rs2_data_id",        `CHECKER_ACTIVE,    `DUT.rs2_data_id,           dut_m_rs2_data_id       );
        checker_t("imm_gen_out_id",     `CHECKER_ACTIVE,    `DUT.imm_gen_out_id,        dut_m_imm_gen_out_id    );
        checker_t("clear_id",           `CHECKER_ACTIVE,    `DUT.clear_id,              dut_m_clear_id          );
        // EX_Stage 
        checker_t("inst_ex",            `CHECKER_ACTIVE,    `DUT.inst_ex,               dut_m_inst_ex           );
        checker_t("pc_ex",              `CHECKER_ACTIVE,    `DUT.pc_ex,                 dut_m_pc_ex             );
        checker_t("rs1_data_ex",        `CHECKER_ACTIVE,    `DUT.rs1_data_ex,           dut_m_rs1_data_ex       );
        checker_t("rs2_data_ex",        `CHECKER_ACTIVE,    `DUT.rs2_data_ex,           dut_m_rs2_data_ex       );
        checker_t("imm_gen_out_ex",     `CHECKER_ACTIVE,    `DUT.imm_gen_out_ex,        dut_m_imm_gen_out_ex    );
        checker_t("rd_addr_ex",         `CHECKER_ACTIVE,    `DUT.rd_addr_ex,            dut_m_rd_addr_ex        );
        checker_t("reg_we_ex",          `CHECKER_ACTIVE,    `DUT.reg_we_ex,             dut_m_reg_we_ex         );
            
        checker_t("bc_a_eq_b",          `CHECKER_ACTIVE,    `DUT.bc_out_a_eq_b,         dut_m_bc_a_eq_b         );
        checker_t("bc_a_lt_b",          `CHECKER_ACTIVE,    `DUT.bc_out_a_lt_b,         dut_m_bc_a_lt_b         );
        checker_t("alu_out",            `CHECKER_ACTIVE,    `DUT.alu_out,               dut_m_alu_out           );
            
        checker_t("clear_ex",           `CHECKER_ACTIVE,    `DUT.clear_ex,              dut_m_clear_ex          );
            
        checker_t("dmem_addr",          `CHECKER_ACTIVE,    `DUT.dmem_addr,             dut_m_dmem_addr         );
        checker_t("dmem_write_data",    `CHECKER_ACTIVE,    `DUT.dmem_write_data,       dut_m_dmem_write_data   );
        // MEM_Stage
        checker_t("dmem_read_data_mem", `CHECKER_ACTIVE,    `DUT.dmem_read_data_mem,    dut_m_dmem_read_data_mem);
        checker_t("writeback",          `CHECKER_ACTIVE,    `DUT.writeback,             dut_m_writeback         );
        
        
        
        // Decoder
        checker_t("pc_sel",             `CHECKER_ACTIVE,    `DUT.pc_sel_if,             dut_m_pc_sel_if         );
        checker_t("pc_we",              `CHECKER_ACTIVE,    `DUT.pc_we_if,              dut_m_pc_we_if          );
        checker_t("branch_inst_id",     `CHECKER_ACTIVE,    `DUT.branch_inst_id,        dut_m_branch_inst_id    );
        checker_t("jump_inst_id",       `CHECKER_ACTIVE,    `DUT.jump_inst_id,          dut_m_jump_inst_id      );
        checker_t("store_inst_id",      `CHECKER_ACTIVE,    `DUT.store_inst_id,         dut_m_store_inst_id     );
        checker_t("alu_op_sel",         `CHECKER_ACTIVE,    `DUT.alu_op_sel_id,         dut_m_alu_op_sel_id     );
        checker_t("imm_gen_sel",        `CHECKER_ACTIVE,    `DUT.imm_gen_sel_id,        dut_m_imm_gen_sel_id    );
        checker_t("bc_uns",             `CHECKER_ACTIVE,    `DUT.bc_uns_id,             dut_m_bc_uns_id         );
        checker_t("dmem_en",            `CHECKER_ACTIVE,    `DUT.dmem_en_id,            dut_m_dmem_en_id        );
        checker_t("load_sm_en",         `CHECKER_ACTIVE,    `DUT.load_sm_en_id,         dut_m_load_sm_en_id     );
        checker_t("wb_sel",             `CHECKER_ACTIVE,    `DUT.wb_sel_id,             dut_m_wb_sel_id         );
        checker_t("reg_we_id",          `CHECKER_ACTIVE,    `DUT.reg_we_id,             dut_m_reg_we_id         );
        checker_t("alu_a_sel_fwd",      `CHECKER_ACTIVE,    `DUT.alu_a_sel_fwd_id,      dut_m_alu_a_sel_fwd_id  );
        checker_t("alu_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT.alu_b_sel_fwd_id,      dut_m_alu_b_sel_fwd_id  );
        checker_t("bc_a_sel_fwd",       `CHECKER_ACTIVE,    `DUT.bc_a_sel_fwd_id,       dut_m_bc_a_sel_fwd_id   );
        checker_t("bcs_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT.bcs_b_sel_fwd_id,      dut_m_bcs_b_sel_fwd_id  );
        checker_t("dmem_we",            `CHECKER_ACTIVE,    `DUT.dmem_we_ex,            dut_m_dmem_we_ex        );
        // internal 
        checker_t("branch_taken",       `CHECKER_ACTIVE,    dut_internal_branch_taken,  dut_m_branch_taken      );
    
    end // main task body */
endtask // run_checkers

//-----------------------------------------------------------------------------
// DUT model tasks
task dut_m_decode;
    reg  [31:0] inst_id;
    reg  [31:0] inst_ex;
    reg  [ 2:0] funct3_ex;
    
    begin
    inst_id         = dut_m_inst_id;
    inst_ex         = dut_m_inst_ex;
    funct3_ex       = dut_m_inst_ex[14:12];
    
        case (inst_id[6:0])
            'b011_0011: begin   // R-type instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = ({inst_id[30], inst_id[14:12]});
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_RS2;
                dut_m_imm_gen_sel_id = `IG_DISABLED;
                // dut_m_bc_uns_id      = 1'b0;
                dut_m_dmem_en_id     = 1'b0;
                dut_m_load_sm_en_id  = 1'b0;
                dut_m_wb_sel_id      = `WB_SEL_ALU;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b001_0011: begin   // I-type instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = (inst_id[13:12] == 2'b01)  ? 
                                    {inst_id[30], inst_id[14:12]} : {1'b0, inst_id[14:12]};
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_I_TYPE;
                // dut_m_bc_uns_id      = 1'b0;
                dut_m_dmem_en_id     = 1'b0;
                dut_m_load_sm_en_id  = 1'b0;
                dut_m_wb_sel_id      = `WB_SEL_ALU;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b000_0011: begin   // Load instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_I_TYPE;
                // dut_m_bc_uns_id      = 1'b0;
                dut_m_dmem_en_id     = 1'b1;
                dut_m_load_sm_en_id  = 1'b1;
                dut_m_wb_sel_id      = `WB_SEL_DMEM;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b010_0011: begin   // Store instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b1;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_S_TYPE;
                // dut_m_bc_uns_id      = 1'b0;
                dut_m_dmem_en_id     = 1'b1;
                dut_m_load_sm_en_id  = 1'b0;
                // dut_m_wb_sel_id      = `WB_SEL_DMEM;
                dut_m_reg_we_id      = 1'b0;
            end
            
            'b110_0011: begin   // Branch instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b1;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_B_TYPE;
                dut_m_bc_uns_id      = inst_id[13];
                dut_m_dmem_en_id     = 1'b0;
                dut_m_load_sm_en_id  = 1'b0;
                // dut_m_wb_sel_id      = `WB_SEL_DMEM;
                dut_m_reg_we_id      = 1'b0;
            end
            
            'b110_0111: begin   // JALR instruction
                dut_m_pc_sel_if      = `PC_SEL_ALU;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b1;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_I_TYPE;
                // dut_m_bc_uns_id      = *;
                dut_m_dmem_en_id     = 1'b0;
                // dut_m_load_sm_en_id  = *;
                dut_m_wb_sel_id      = `WB_SEL_INC4;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b110_1111: begin   // JAL instruction
                dut_m_pc_sel_if      = `PC_SEL_ALU;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b1;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_J_TYPE;
                // dut_m_bc_uns_id      = *;
                dut_m_dmem_en_id     = 1'b0;
                // dut_m_load_sm_en_id  = *;
                dut_m_wb_sel_id      = `WB_SEL_INC4;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b011_0111: begin   // LUI instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b1111;    // pass b
                // dut_m_alu_a_sel_id   = *;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_U_TYPE;
                // dut_m_bc_uns_id      = *;
                dut_m_dmem_en_id     = 1'b0;
                // dut_m_load_sm_en_id  = *;
                dut_m_wb_sel_id      = `WB_SEL_ALU;
                dut_m_reg_we_id      = 1'b1;
            end
            
            'b001_0111: begin   // AUIPC instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_U_TYPE;
                // dut_m_bc_uns_id      = *;
                dut_m_dmem_en_id     = 1'b0;
                // dut_m_load_sm_en_id  = *;
                dut_m_wb_sel_id      = `WB_SEL_ALU;
                dut_m_reg_we_id      = 1'b1;
            end
            
            default: begin
                $display("*WARNING @ %0t. Decoder model 'default' case. Input inst_id: 'h%8h  %0s",
                $time, dut_m_inst_id, dut_m_inst_id_asm);
                warnings = warnings + 1;
            end
        endcase
        
        // Override if rst == 1
        if (rst) begin
            dut_m_pc_sel_if      = 2'b11;
            dut_m_pc_we_if       = 1'b1;
            dut_m_branch_inst_id = 1'b0;
            dut_m_jump_inst_id   = 1'b0;
            dut_m_store_inst_id  = 1'b0;
            dut_m_alu_op_sel_id  = 4'b0000;
            dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
            dut_m_alu_b_sel_id   = `ALU_B_SEL_RS2;
            dut_m_imm_gen_sel_id = `IG_DISABLED;
            dut_m_bc_uns_id      = 1'b0;
            dut_m_dmem_en_id     = 1'b0;
            dut_m_load_sm_en_id  = 1'b0;
            dut_m_wb_sel_id      = `WB_SEL_DMEM;
            dut_m_reg_we_id      = 1'b0;
        end
        
        // check if instruction will stall
        dut_m_stall_if = (dut_m_branch_inst_id || dut_m_jump_inst_id);
        
        // if it stalls, we = 0
        dut_m_pc_we_if = dut_m_pc_we_if && (!dut_m_stall_if);
        
        
        // Operand Forwarding
        // Operand A
        if ((dut_m_rs1_addr_id != `RF_X0_ZERO) && (dut_m_rs1_addr_id == dut_m_rd_addr_ex) && (dut_m_reg_we_ex) && (!dut_m_alu_a_sel_id))
            dut_m_alu_a_sel_fwd_id = `ALU_A_SEL_FWD_ALU;            // forward previous ALU result
        else
            dut_m_alu_a_sel_fwd_id = {1'b0, dut_m_alu_a_sel_id};    // don't forward
        
        // Operand B
        if ((dut_m_rs2_addr_id != `RF_X0_ZERO) && (dut_m_rs2_addr_id == dut_m_rd_addr_ex) && (dut_m_reg_we_ex) && (!dut_m_alu_b_sel_id))
            dut_m_alu_b_sel_fwd_id = `ALU_B_SEL_FWD_ALU;            // forward previous ALU result
        else
            dut_m_alu_b_sel_fwd_id = {1'b0, dut_m_alu_b_sel_id};    // don't forward
        
        // BC A
        dut_m_bc_a_sel_fwd_id  = ((dut_m_rs1_addr_id != `RF_X0_ZERO) && (dut_m_rs1_addr_id == dut_m_rd_addr_ex) && (dut_m_reg_we_ex) && (dut_m_branch_inst_id));
        
        // BC B / DMEM din
        dut_m_bcs_b_sel_fwd_id = ((dut_m_rs2_addr_id != `RF_X0_ZERO) && (dut_m_rs2_addr_id == dut_m_rd_addr_ex) && (dut_m_reg_we_ex) && (dut_m_store_inst_id || dut_m_branch_inst_id));
                
         
       // Store Mask
       dut_m_store_mask_offset = dut_m_alu_out[1:0];
        if(dut_m_store_inst_ex) begin                    // store mask enable
            case(funct3_ex[1:0])                            // store mask width
                5'd0:   // byte
                    case (dut_m_store_mask_offset)          // store mask offset, valid for byte and half
                        2'd0:
                            dut_m_dmem_we_ex = 4'b0001;
                        2'd1:
                            dut_m_dmem_we_ex = 4'b0010;
                        2'd2:
                            dut_m_dmem_we_ex = 4'b0100;
                        2'd3:
                            dut_m_dmem_we_ex = 4'b1000;
                        default: begin
                            $write("*WARNING @ %0t. Store Mask model offset 'default' case. Input inst_id: 'h%8h  %0s",
                            $time, dut_m_inst_id, dut_m_inst_id_asm);
                            warnings = warnings + 1;
                        end
                    endcase
                
                5'd1:   // half
                    case (dut_m_store_mask_offset)
                        2'd0:
                            dut_m_dmem_we_ex = 4'b0011;
                        2'd1:
                            dut_m_dmem_we_ex = 4'b0110;
                        2'd2:
                            dut_m_dmem_we_ex = 4'b1100;
                        2'd3: begin 
                            $write("*WARNING @ %0t. Store Mask model offset unaligned access - half. Input inst_id: 'h%8h  %0s",
                            $time, dut_m_inst_id, dut_m_inst_id_asm);
                            warnings = warnings + 1;
                            dut_m_dmem_we_ex = 4'b0000;
                        end
                        default: begin
                            $write("*WARNING @ %0t. Store Mask model offset 'default' case. Input inst_id: 'h%8h  %0s",
                            $time, dut_m_inst_id, dut_m_inst_id_asm);
                            warnings = warnings + 1;
                        end
                    endcase
               
                5'd2:   // word
                    case (dut_m_store_mask_offset)
                        2'd0:
                            dut_m_dmem_we_ex = 4'b1111;
                        2'd1,
                        2'd2,
                        2'd3: begin
                            $write("*WARNING @ %0t. Store Mask model offset unaligned access - word. Input inst_id: 'h%8h  %0s",
                            $time, dut_m_inst_id, dut_m_inst_id_asm);
                            warnings = warnings + 1;
                            dut_m_dmem_we_ex = 4'b0000;
                        end
                        default: begin
                            $write("*WARNING @ %0t. Store Mask model offset 'default' case. Input inst_id: 'h%8h  %0s",
                            $time, dut_m_inst_id, dut_m_inst_id_asm);
                            warnings = warnings + 1;
                        end
                    endcase
                
                default: begin
                    $write("*WARNING @ %0t. Store Mask model width 'default' case. Input inst_id: 'h%8h  %0s",
                    $time, dut_m_inst_id, dut_m_inst_id_asm);
                    warnings = warnings + 1;
                    dut_m_dmem_we_ex = 4'b0000;
                end
            endcase
        end
        else /*(!dut_m_store_inst_ex)*/ begin
            dut_m_dmem_we_ex = 4'b0000;
        end
        
        
       // branch resolution
        case ({dut_m_inst_ex[14], dut_m_inst_ex[12]})
            2'b00:      // beq -> a == b
                dut_m_branch_taken = dut_m_bc_a_eq_b;
            
            2'b01:      // bne -> a != b
                dut_m_branch_taken = !dut_m_bc_a_eq_b;
            
            2'b10:      // blt -> a < b
                dut_m_branch_taken = dut_m_bc_a_lt_b;
            
            2'b11:      // bge -> a >= b
                dut_m_branch_taken = dut_m_bc_a_eq_b || !dut_m_bc_a_lt_b;
            
            default: begin
                $display("*WARNING @ %0t. Branch Resolution model 'default' case. Input inst_ex: 'h%8h  %0s",
                $time, dut_m_inst_ex, dut_m_inst_ex_asm);
                warnings = warnings + 1;
            end
        endcase
        // Override if rst == 1
        if (rst) dut_m_branch_taken = 1'b0;
        // if not branch instruction, it cannot be taken
        dut_m_branch_taken = dut_m_branch_taken && dut_m_branch_inst_ex;
        
        // jump? if it's jump inst -> flow changes unconditionally
        dut_m_jump_taken = dut_m_jump_inst_ex;
        
        // flow change instructions use ALU out as destination address
        if(dut_m_branch_taken || dut_m_jump_taken) dut_m_pc_sel_if = `PC_SEL_ALU;
        
    end                  
endtask // dut_m_decode

task dut_m_pc_mux_update;
    begin
        case (dut_m_pc_sel_if)   // use DUT or model?
            2'd0: begin
                dut_m_pc_mux_out =  dut_m_pc + 4;
            end
            
            2'd1: begin
                dut_m_pc_mux_out =  dut_m_alu_out;
            end
            
            2'd2: begin
                $display("*WARNING @ %0t. pc_sel = 2 is not supported yet - TBD for prediction", $time);
                warnings = warnings + 1;
            end
            
            2'd3: begin
                dut_m_pc_mux_out =  'h0;  // start address
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
        // used for all accesses
        // arch is byte addressable, memory is word addressable
        dut_m_pc_mux_out_div4 = dut_m_pc_mux_out>>2;
    end
endtask

task dut_m_pc_update;
    begin
        dut_m_pc = (!rst)           ? 
                   (dut_m_pc_we_if) ? dut_m_pc_mux_out   :   // mux
                                      dut_m_pc           :   // pc_we = 0
                                      'h0;                   // rst = 1
    end
endtask

task dut_m_imem_update;
    begin
        dut_m_inst_id_read      = test_values_inst_hex[dut_m_pc_mux_out_div4];
        dut_m_inst_id_read_asm  = test_values_inst_asm[dut_m_pc_mux_out_div4];
    end
endtask

task dut_m_reg_file_read_update;
    begin
        // move to pipeline task
        dut_m_rs1_addr_id = dut_m_inst_id[19:15];
        dut_m_rs2_addr_id = dut_m_inst_id[24:20];
        dut_m_rd_addr_id  = dut_m_inst_id[11: 7];
        
        // this logic in decoder for forwarding
        //dut_m_rf32
        if ((dut_m_rs1_addr_id != `RF_X0_ZERO) && (dut_m_rs1_addr_id == dut_m_rd_addr_mem) && (dut_m_reg_we_mem) && (!dut_m_alu_a_sel_id))
            dut_m_rs1_data_id = dut_m_writeback;                    // forward previous ALU result
        else
            dut_m_rs1_data_id = dut_m_rf32[dut_m_rs1_addr_id];      // don't forward
        
        if ((dut_m_rs2_addr_id != `RF_X0_ZERO) && (dut_m_rs2_addr_id == dut_m_rd_addr_mem) && (dut_m_reg_we_mem) && (!dut_m_alu_b_sel_id))
            dut_m_rs2_data_id = dut_m_writeback;                    // forward previous ALU result
        else
            dut_m_rs2_data_id = dut_m_rf32[dut_m_rs2_addr_id];      // don't forward
        
        // here just read from rf
        // dut_m_rs1_data_id = dut_m_rf32[dut_m_rs1_addr_id];
        // dut_m_rs2_data_id = dut_m_rf32[dut_m_rs2_addr_id];
        
        // then also here add muxes for forwarding
        // this task needs to go after decoder -> has to be after forwarding logic
    end
endtask

task dut_m_reg_file_write_update;
    begin
        if (rst) begin
            for(i = 0; i < `RF_NUM; i = i + 1) begin
                dut_m_rf32[i] = 'h0;
            end
        end
        else if (dut_m_reg_we_mem && (dut_m_rd_addr_mem != 5'd0)) begin     // no writes to x0
            dut_m_rf32[dut_m_rd_addr_mem] = dut_m_rd_data;
        end
    end
endtask

task dut_m_imm_gen_update;
    reg    [11:0] imm_temp_12;
    reg    [12:0] imm_temp_13;
    reg    [20:0] imm_temp_21;
    
    begin
        dut_m_imm_gen_in = dut_m_inst_id[31: 7];
            case (dut_m_imm_gen_sel_id)
                `IG_I_TYPE: begin
                    imm_temp_12          = dut_m_inst_id[31:20];
                    dut_m_imm_gen_out_id = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
                end
                
                `IG_S_TYPE: begin
                    imm_temp_12          = {dut_m_inst_id[31:25], dut_m_inst_id[11: 7]};
                    dut_m_imm_gen_out_id = $signed({imm_temp_12, 20'h0}) >>> 20;    // shift 12 MSBs to 12 LSBs, keep sign
                end
                
                `IG_B_TYPE: begin
                    imm_temp_13          = {dut_m_inst_id[31], dut_m_inst_id[7], dut_m_inst_id[30:25], dut_m_inst_id[11: 8], 1'b0};
                    dut_m_imm_gen_out_id = $signed({imm_temp_13, 19'h0}) >>> 19;    // shift 13 MSBs to 13 LSBs, keep sign
                end
                
                `IG_J_TYPE: begin
                    imm_temp_21          = {dut_m_inst_id[31], dut_m_inst_id[19:12], dut_m_inst_id[20], dut_m_inst_id[30:21], 1'b0};
                    dut_m_imm_gen_out_id = $signed({imm_temp_21, 11'h0}) >>> 11;    // shift 21 MSBs to 21 LSBs, keep sign
                end
                
                `IG_U_TYPE: begin
                    imm_temp_21          = dut_m_inst_id[31:12];
                    dut_m_imm_gen_out_id = {imm_temp_21, 12'h0};                    // keep 21 MSBs, pad 11 bits with zeros
                end
                
                `IG_DISABLED: begin
                    dut_m_imm_gen_out_id = dut_m_imm_gen_out_id_prev;               // keep previous result
                end
                                
                default: begin  // invalid operation
                    $display("*WARNING @ %0t. Imm Gen model 'default' case. Input inst_id: 'h%8h  %0s",
                    $time, dut_m_inst_id, dut_m_inst_id_asm);
                    warnings = warnings + 1;
                end
                
            endcase
        
    end
endtask

task dut_m_imm_gen_seq_update;
    begin
        if (rst) 
            dut_m_imm_gen_out_id_prev = 'h0;
        else
            dut_m_imm_gen_out_id_prev = dut_m_imm_gen_out_id;
    end
endtask

task dut_m_bc_update;
    reg [31:0] bc_in_a;
    reg [31:0] bc_in_b;
    begin
        bc_in_a = dut_m_bc_a_sel_fwd_ex  ? dut_m_writeback : dut_m_rs1_data_ex;
        bc_in_b = dut_m_bcs_b_sel_fwd_ex ? dut_m_writeback : dut_m_rs2_data_ex;
        
        case (dut_m_bc_uns_ex)
            1'b0: begin     // signed
                dut_m_bc_a_eq_b = ($signed(bc_in_a) == $signed(bc_in_b));
                dut_m_bc_a_lt_b = ($signed(bc_in_a) <  $signed(bc_in_b));
            end
            
            1'b1: begin     // unsigned
                dut_m_bc_a_eq_b = (bc_in_a == bc_in_b);
                dut_m_bc_a_lt_b = (bc_in_a <  bc_in_b);
            end
            
            default: begin
                $display("*WARNING @ %0t. Branch Compare 'default' case. Input bc_uns: 'b%1b ",
                $time, dut_m_bc_uns_ex);
                warnings = warnings + 1;
                dut_m_bc_a_eq_b = 1'b0;
                dut_m_bc_a_lt_b = 1'b0;
            end
        endcase
    end
endtask

task dut_m_alu_update;
    
    begin
        dut_m_alu_in_a =  (dut_m_alu_a_sel_fwd_ex == 2'd0) ?    dut_m_rs1_data_ex     :
                          (dut_m_alu_a_sel_fwd_ex == 2'd1) ?    dut_m_pc_ex           :
                       /* (dut_m_alu_a_sel_fwd_ex == 2'd2) ? */ dut_m_writeback      ;
        
        dut_m_alu_in_b =  (dut_m_alu_b_sel_fwd_ex == 2'd0) ?    dut_m_rs2_data_ex     :
                          (dut_m_alu_b_sel_fwd_ex == 2'd1) ?    dut_m_imm_gen_out_ex  :
                       /* (dut_m_alu_b_sel_fwd_ex == 2'd2) ? */ dut_m_writeback      ;
        
        dut_m_alu_shamt = dut_m_alu_in_b[4:0];
        
        case (dut_m_alu_op_sel_ex)
            `ALU_ADD: begin
                dut_m_alu_out = dut_m_alu_in_a + dut_m_alu_in_b;
            end
            
            `ALU_SUB: begin
                dut_m_alu_out = dut_m_alu_in_a - dut_m_alu_in_b;
            end
            
            `ALU_SLL: begin
                dut_m_alu_out = dut_m_alu_in_a << dut_m_alu_shamt;
            end
            
            `ALU_SRL: begin
                dut_m_alu_out = dut_m_alu_in_a >> dut_m_alu_shamt;
            end
            
            `ALU_SRA: begin
                dut_m_alu_out = $signed(dut_m_alu_in_a) >>> dut_m_alu_shamt;
            end
            
            `ALU_SLT: begin
                dut_m_alu_out = ($signed(dut_m_alu_in_a) < $signed(dut_m_alu_in_b)) ? 32'h0001 : 32'h0000;
            end
            
            `ALU_SLTU: begin
                dut_m_alu_out = (dut_m_alu_in_a < dut_m_alu_in_b) ? 32'h0001 : 32'h0000;
            end
            
            `ALU_XOR: begin
                dut_m_alu_out = dut_m_alu_in_a ^ dut_m_alu_in_b;
            end
            
            `ALU_OR: begin
                dut_m_alu_out = dut_m_alu_in_a | dut_m_alu_in_b;
            end
            
            `ALU_AND: begin
                dut_m_alu_out = dut_m_alu_in_a & dut_m_alu_in_b;
            end
            
            `ALU_PASS_B: begin
                dut_m_alu_out = dut_m_alu_in_b;
            end
            
            default: begin  // invalid operation
                $display("*WARNING @ %0t. ALU op sel 'default' case. Input alu_op_sel_ex: %0d ",
                $time, dut_m_alu_op_sel_ex);
                warnings = warnings + 1;
                dut_m_alu_out = 32'h0000;
            end
        endcase
    end
endtask

task dut_m_dmem_inputs_update;
    begin
        dut_m_dmem_write_data   = dut_m_bcs_b_sel_fwd_id ? dut_m_writeback : dut_m_rs2_data_ex;
        dut_m_dmem_addr         = dut_m_alu_out[15:2];
        dut_m_load_sm_offset_ex = dut_m_alu_out[1:0];
    end
endtask

task dut_m_dmem_update;
    begin
        if(dut_m_dmem_en_ex) begin
            dut_m_dmem_read_data_mem = test_values_dmem[dut_m_dmem_addr];
            if(dut_m_dmem_we_ex[0]) test_values_dmem[dut_m_dmem_addr][ 7: 0] = dut_m_dmem_write_data[ 7: 0];
            if(dut_m_dmem_we_ex[1]) test_values_dmem[dut_m_dmem_addr][15: 8] = dut_m_dmem_write_data[15: 8];
            if(dut_m_dmem_we_ex[2]) test_values_dmem[dut_m_dmem_addr][23:16] = dut_m_dmem_write_data[23:16];
            if(dut_m_dmem_we_ex[3]) test_values_dmem[dut_m_dmem_addr][31:24] = dut_m_dmem_write_data[31:24];
        end
    end
endtask

task dut_m_load_sm_update;
    reg [31:0] task_din;
    reg [ 0:0] task_sign_bit;
    begin
        task_din            = dut_m_dmem_read_data_mem;
        dut_m_load_sm_width = dut_m_inst_mem[14:12];
        task_sign_bit       = dut_m_load_sm_width[2];
        
        if (dut_m_load_sm_en_mem) begin
            case (dut_m_load_sm_width[1:0])
            2'd0:   // byte
                case (dut_m_load_sm_offset_mem)
                2'd0:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[ 7: 0]} : 
                                                             {{24{task_din[ 7]}}, task_din[ 7: 0]};
                2'd1:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[15: 8]} : 
                                                             {{24{task_din[15]}}, task_din[15: 8]};
                2'd2:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[23:16]} : 
                                                             {{24{task_din[23]}}, task_din[23:16]};
                2'd3:
                    dut_m_load_sm_data_out = task_sign_bit ? {{24{       1'b0 }}, task_din[31:24]} : 
                                                             {{24{task_din[31]}}, task_din[31:24]};
                // default: 
                    // $display("Offset input not valid");
                endcase
            
            2'd1:   // half
                case (dut_m_load_sm_offset_mem)
                 2'd0:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[15: 0]} : 
                                                             {{16{task_din[15]}}, task_din[15: 0]};
                2'd1:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[23: 8]} : 
                                                             {{16{task_din[23]}}, task_din[23: 8]};
                2'd2:
                    dut_m_load_sm_data_out = task_sign_bit ? {{16{       1'b0 }}, task_din[31:16]} : 
                                                             {{16{task_din[31]}}, task_din[31:16]};
                2'd3: 
                begin
                    // $display("Unaligned access not supported");
                    dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
                end
                // default: 
                    // $display("Offset input not valid");
                endcase
           
            2'd2:   // word
                case (dut_m_load_sm_offset_mem)
                2'd0:
                    dut_m_load_sm_data_out = task_din;
                2'd1,
                2'd2,
                2'd3:
                begin
                    // $display("Unaligned access not supported");
                    dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
                end
                // default: 
                    // $display("Offset input not valid");
                endcase
            
            default: 
            begin
                // $display("Width input not valid");
                dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
            end
            endcase
        end
        else /*dut_m_load_sm_en_mem = 0*/ begin
            dut_m_load_sm_data_out = dut_m_load_sm_data_out_prev;
        end
    end
endtask

task dut_m_load_sm_seq_update;
    begin
        if (rst) 
            dut_m_load_sm_data_out_prev = 'h0;
        else
            dut_m_load_sm_data_out_prev = dut_m_load_sm_data_out;
    end
endtask

task dut_m_writeback_update;
    begin
        dut_m_writeback = (dut_m_wb_sel_mem == `WB_SEL_DMEM) ?    dut_m_load_sm_data_out  :
                          (dut_m_wb_sel_mem == `WB_SEL_ALU ) ?    dut_m_alu_out_mem       :
                       /* (dut_m_wb_sel_mem == `WB_SEL_INC4) ? */ dut_m_pc_mem + 32'd4   ;
    end
endtask

task dut_m_nop_id_update;
    begin
        dut_m_inst_id           = (dut_m_stall_if_q1) ? test_values_inst_hex_nop : dut_m_inst_id_read;
        dut_m_inst_id_asm       = (dut_m_stall_if_q1) ? test_values_inst_asm_nop : dut_m_inst_id_read_asm;
    end
endtask

task dut_m_if_pipeline_update;
    begin
        dut_m_stall_if_q1       = (!rst) ? dut_m_stall_if : 'b0;
    end
endtask

task dut_m_id_ex_pipeline_update;
    begin
        // instruction update
        // datapath
        dut_m_pc_ex             = (!rst && !dut_m_clear_id) ? dut_m_pc                  : 'h0;
        dut_m_rd_addr_ex        = (!rst && !dut_m_clear_id) ? dut_m_rd_addr_id          : 'h0;
        dut_m_rs1_data_ex       = (!rst && !dut_m_clear_id) ? dut_m_rs1_data_id         : 'h0;
        dut_m_rs2_data_ex       = (!rst && !dut_m_clear_id) ? dut_m_rs2_data_id         : 'h0;
        dut_m_imm_gen_out_ex    = (!rst && !dut_m_clear_id) ? dut_m_imm_gen_out_id      : 'h0;
        dut_m_inst_ex           = (!rst && !dut_m_clear_id) ? dut_m_inst_id             : 'h0;
        dut_m_inst_ex_asm       = (!rst && !dut_m_clear_id) ? dut_m_inst_id_asm         : 'h0;
        // control
        dut_m_bc_uns_ex         = (!rst && !dut_m_clear_id) ? dut_m_bc_uns_id           : 'b0;
        dut_m_bc_a_sel_fwd_ex   = (!rst && !dut_m_clear_id) ? dut_m_bc_a_sel_fwd_id     : 'b0;
        dut_m_bcs_b_sel_fwd_ex  = (!rst && !dut_m_clear_id) ? dut_m_bcs_b_sel_fwd_ex    : 'b0;
        dut_m_alu_a_sel_fwd_ex  = (!rst && !dut_m_clear_id) ? dut_m_alu_a_sel_fwd_id    : 'h0;
        dut_m_alu_b_sel_fwd_ex  = (!rst && !dut_m_clear_id) ? dut_m_alu_b_sel_fwd_id    : 'h0;
        dut_m_alu_op_sel_ex     = (!rst && !dut_m_clear_id) ? dut_m_alu_op_sel_id       : 'h0;
        dut_m_dmem_en_ex        = (!rst && !dut_m_clear_id) ? dut_m_dmem_en_id          : 'b0;
        dut_m_load_sm_en_ex     = (!rst && !dut_m_clear_id) ? dut_m_load_sm_en_id       : 'b0;
        dut_m_wb_sel_ex         = (!rst && !dut_m_clear_id) ? dut_m_wb_sel_id           : 'h0;
        dut_m_reg_we_ex         = (!rst && !dut_m_clear_id) ? dut_m_reg_we_id           : 'b0;
        
        // internal only
        dut_m_store_inst_ex     = (!rst && !dut_m_clear_id) ? dut_m_store_inst_id       : 'b0;
        dut_m_branch_inst_ex    = (!rst && !dut_m_clear_id) ? dut_m_branch_inst_id      : 'b0;
        dut_m_jump_inst_ex      = (!rst && !dut_m_clear_id) ? dut_m_jump_inst_id        : 'b0;
    end
endtask

task dut_m_ex_mem_pipeline_update;
    begin
        dut_m_pc_mem             = (!rst && !dut_m_clear_ex) ? dut_m_pc_ex              : 'h0;
        dut_m_alu_out_mem        = (!rst && !dut_m_clear_ex) ? dut_m_alu_out            : 'h0;
        dut_m_dmem_update();
        dut_m_load_sm_offset_mem = (!rst && !dut_m_clear_ex) ? dut_m_load_sm_offset_ex  : 'h0;
        dut_m_inst_mem           = (!rst && !dut_m_clear_ex) ? dut_m_inst_ex            : 'h0;
        dut_m_inst_mem_asm       = (!rst && !dut_m_clear_ex) ? dut_m_inst_ex_asm        : 'h0;
        dut_m_rd_addr_mem        = (!rst && !dut_m_clear_ex) ? dut_m_rd_addr_ex         : 'h0;
        dut_m_load_sm_en_mem     = (!rst && !dut_m_clear_ex) ? dut_m_load_sm_en_ex      : 'b0;
        dut_m_wb_sel_mem         = (!rst && !dut_m_clear_ex) ? dut_m_wb_sel_ex          : 'h0;
        dut_m_reg_we_mem         = (!rst && !dut_m_clear_ex) ? dut_m_reg_we_ex          : 'b0;
        
    end
endtask

task dut_m_rst_sequence_update;
    reg   [ 2:0] reset_seq  ;
    reg          rst_seq_id ;
    reg          rst_seq_ex ;
    reg          rst_seq_mem;
    begin
        reset_seq       = (!rst) ? {reset_seq[1:0],1'b0} : 3'b111;
        rst_seq_id      = reset_seq[0];
        rst_seq_ex      = reset_seq[1];
        rst_seq_mem     = reset_seq[2];
        
        dut_m_clear_id  = rst_seq_id   ;
        dut_m_clear_ex  = rst_seq_ex   ;
        dut_m_clear_mem = rst_seq_mem  ;
        
    end
endtask

task dut_m_seq_update;
    begin
        //----- MEM/WB stage updates
        dut_m_reg_file_write_update();
                
        //----- EX/MEM stage updates
        dut_m_load_sm_seq_update();
        dut_m_ex_mem_pipeline_update();
        // $write  ("inst_ex - FF :     'h%8h    %0s", dut_env_inst_ex, dut_env_inst_ex_asm);
        // $display("dut_env_rd_ex:       %0d", dut_env_rd_ex     );
        // $display("dut_env_reg_we_ex: 'b%0b", dut_env_reg_we_ex );
        
        //----- ID/EX stage updates
        dut_m_imm_gen_seq_update();
        dut_m_id_ex_pipeline_update();
        dut_m_rst_sequence_update();
        // $write("inst_id - IMEM read: 'h%8h    %0s", dut_m_inst_id, dut_m_inst_id_asm);
        
        //----- IF/ID stage updates
        dut_m_imem_update();
        dut_m_pc_update();
        dut_m_if_pipeline_update();
        // $display("PC reg: %0d ", dut_env_pc);
    end
endtask

task dut_m_comb_update;
    // input [31:0] alu_out_update;
    // input        branch_compare_update;
    begin
        // env_branch_compare_update(branch_compare_update);
        // $display("Branch compare result - eq: %0b, lt: %0b ", dut_env_bc_a_eq_b, dut_env_bc_a_lt_b);
        // env_alu_out_update(alu_out_update);
        // $display("ALU out: %0d ", dut_env_alu);
        
        //----- MEM stage updates
        dut_m_load_sm_update();
        dut_m_writeback_update();
        
        //----- EX stage updates
        dut_m_bc_update();
        dut_m_alu_update();
        dut_m_dmem_inputs_update();
        
        //----- ID stage updates
        dut_m_nop_id_update();
        dut_m_reg_file_read_update();
        dut_m_decode();
        dut_m_imm_gen_update();
        
        //----- IF stage updates
        dut_m_pc_mux_update();
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

// Initial setup
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    // load IMEM
    $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/core_inst_hex.txt"}, DUT_ama_riscv_core_i.ama_riscv_imem_i.mem, 0, 4095);
    read_test_instructions();
    errors            = 0;
    warnings          = 0;
    // clear_forwarding_counters();
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
        
        // if still not done, wait for next clk else exit
        if(!rst_done) begin 
            @(posedge clk); #1; 
            dut_m_seq_update();
            dut_m_comb_update();
            // dut_m_decode();
        end
    end
    $display("Reset done, time: %0t \n", $time);
    
    pre_rst_warnings = warnings;
    
    //-----------------------------------------------------------------------------
    // Test All:
    $display("\nTest  All: Start \n");
    // run_test_pc_target  = (dut_m_pc_mux_out_div4) + `STARTUP_TESTS;
    // while(dut_m_pc_mux_out_div4 < run_test_pc_target) begin
    repeat(100) begin
        @(posedge clk); #1;
        dut_m_seq_update();
        dut_m_comb_update();
        // dut_m_decode();
        run_checkers();
        print_single_instruction_results();
    end
    $display("\nTnTest  All: Done \n");
    
    
    
    /*
    //-----------------------------------------------------------------------------
    // Test 0: Start-up
    $display("\nTest  0: [Start-up]: Start \n");
    run_test_pc_target  = (dut_m_pc_mux_out_div4) + `STARTUP_TESTS;
    while(dut_m_pc_mux_out_div4 < run_test_pc_target) begin
        @(posedge clk); #1;
        dut_m_seq_update();
        dut_m_comb_update();
        // dut_m_decode();
        run_checkers();
        print_single_instruction_results();
    end
    $display("\nTest  0: [Start-up]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 1: R-type
    $display("\nTest  1: Hit specific case [R-type]: Start \n");
    run_test_pc_target  = (dut_m_pc_mux_out_div4) + `R_TYPE_TESTS;
    while(dut_m_pc_mux_out_div4 < run_test_pc_target) begin
        @(posedge clk); #1;
        dut_m_seq_update();
        dut_m_comb_update();
        // dut_m_decode();
        run_checkers();
        print_single_instruction_results();
    end
    $display("\nTest  1: Hit specific case [R-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 2: I-type
    $display("\nTest  2: Hit specific case [I-type]: Start \n");
    run_test_pc_target  = (dut_m_pc_mux_out_div4) + `I_TYPE_TESTS;
    while(dut_m_pc_mux_out_div4 < run_test_pc_target) begin
        @(posedge clk); #1;
        dut_m_seq_update();
        dut_m_comb_update();
        // dut_m_decode();
        run_checkers();
        print_single_instruction_results();
    end
    $display("\nTest  2: Hit specific case [I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 3: Load
    $display("\nTest  3: Hit specific case [Load]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `LOAD_TESTS;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  3: Hit specific case [Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 4: Store
    $display("\nTest  4: Hit specific case [Stores]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `STORE_TESTS;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    $display("\nTest  4: Hit specific case [Stores]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 5: Branch
    $display("\nTest  5: Hit specific cases [Branches]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `BRANCH_TESTS ;    
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_m_pc_mux_out + 1;
        // $display("\ndut_m_pc: %0d ",          dut_m_pc);
        // $display("\ndut_m_pc_mux_out: %0d ",  dut_m_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute branch instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(`LABEL_TGT, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was branched to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
    end // while(dut_m_pc_mux_out < run_test_pc_target)
    $display("\nTest  5: Hit specific cases [Branches]: Done \n");    
    
    //-----------------------------------------------------------------------------
    // Test 6: JALR
    $display("\nTest  6: Hit specific case [JALR]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `JALR_TEST ;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_m_pc_mux_out + 1;
        // $display("\ndut_m_pc: %0d ",          dut_m_pc);
        // $display("\ndut_m_pc_mux_out: %0d ",  dut_m_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute JALR instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
    end // while(dut_m_pc_mux_out < run_test_pc_target)
    $display("\nTest  6: Hit specific case [JALR]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 7: JALR
    $display("\nTest  7: Hit specific case [JAL]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `JAL_TEST ;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_m_pc_mux_out + 1;
        // $display("\ndut_m_pc: %0d ",          dut_m_pc);
        // $display("\ndut_m_pc_mux_out: %0d ",  dut_m_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute JAL instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Jump inst_ex: %1b ", dut_m_jump_inst_ex);
            env_update_comb(`LABEL_TGT, 1'b0);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute instruction that was jumped to - Return instruction");
            
            env_update_seq();            
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb(alu_return_address, dut_m_branch_inst_ex & 1'b1);
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 2: PC sel: %0d ", pc_sel);
            // $display("loop 2: PC MUX: %0d ", dut_m_pc_mux_out);
        end
        
    end // while(dut_m_pc_mux_out < run_test_pc_target)
    $display("\nTest  7: Hit specific case [JAL]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 8: LUI
    $display("\nTest  8: Hit specific case [LUI]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `LUI_TEST;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        env_update_comb('hA, 'b0);  // ALU is actually used for write to RF, but data is not relevant to this TB, only control signals in checker
    end
    $display("\nTest  8: Hit specific case [LUI]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 9: AUIPC
    $display("\nTest  9: Hit specific case [AUIPC]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `AUIPC_TEST;
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        env_update_comb('hE, 'b0);  // ALU is actually used for write to RF, but data is not relevant to this TB, only control signals in checker
    end
    $display("\nTest  9: Hit specific case [AUIPC]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 10: NOPs
    $display("\nTest 10: Execute NOPs: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `BRANCH_TESTS_NOPS_PAD - 1;  // without last beq
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        env_update_comb('h0, 'b0);
    end
    
    run_test_pc_target  = dut_m_pc_mux_out + 1;  // beq
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        alu_return_address = dut_m_pc_mux_out + 1;
        // $display("\ndut_m_pc: %0d ",          dut_m_pc);
        // $display("\ndut_m_pc_mux_out: %0d ",  dut_m_pc_mux_out);
        // $display("\run_test_pc_target: %0d ",   run_test_pc_target);
        
        // takes 2 cycles to resolve branch/jump + 1 to execute branched instruction (or 2 if  the branched instruction is a branch/jump instruction itself, like it's below)
        repeat(2) begin
            @(posedge clk); #1;
            $display("Execute branch instruction");
            
            env_update_seq();
            tb_driver();
            dut_m_decode();
            
            #1; run_checkers();
            print_single_instruction_results();
            
            // $display("Branch inst_ex: %1b ", dut_m_branch_inst_ex);
            env_update_comb('h0, 'b0);  // don't branch
            
            tb_driver();
            dut_m_decode();
            
            #1; // takes time for dut to react to branch compare and alu changes
            env_pc_mux_update();
            
            // $display("\nBranch taken: %1b ", dut_m_branch_taken);
            // $display("loop 1: PC sel: %0d ", pc_sel);
            // $display("loop 1: PC MUX: %0d ", dut_m_pc_mux_out);
        end
    end
    
    $display("\nTest 10: Execute NOPs: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 11: No Forwarding No Dependency
    $display("\nTest 11: Hit specific case [No Forwarding No Dependency]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `NFND_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        @(posedge clk); #1;
        env_update_seq();
        tb_driver();
        dut_m_decode();
        #1; run_checkers();
        print_single_instruction_results();
        dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
    end
    dependency_checker();
    $display("\nTest 11: Hit specific case [No Forwarding No Dependency]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12a: Forwarding with Dependency R-type
    $display("\nTest 12a: Hit specific case [Forwarding with Dependency R-type]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `FDRT_TEST;
    expected_dependencies(`FD_TEST_EXP_ALU_A, 
                          `FD_TEST_EXP_ALU_B, 
                          `FD_TEST_EXP_BC_A, 
                          `FD_TEST_EXP_BCS_B);
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; run_checkers();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12a: Hit specific case [Forwarding with Dependency R-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12b: Forwarding with Dependency I-type
    $display("\nTest 12b: Hit specific case [Forwarding with Dependency I-type]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `FDIT_TEST;
    // expected_dependencies are the same as R-type
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; run_checkers();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12b: Hit specific case [Forwarding with Dependency I-type]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 12c: Forwarding with Dependency Load
    $display("\nTest 12c: Hit specific case [Forwarding with Dependency Load]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `FDL_TEST;
    // expected_dependencies are the same as R-type and I-type
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; run_checkers();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 12c: Hit specific case [Forwarding with Dependency Load]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 13: No forwarding false dependency - writes to x0
    $display("\nTest 13: Hit specific case [No forwarding false dependency - writes to x0]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `NFX0_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; run_checkers();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 13: Hit specific case [No forwarding false dependency - writes to x0]: Done \n");
    
    //-----------------------------------------------------------------------------
    // Test 14: No forwarding false dependency - reg_we_ex = 0
    $display("\nTest 14: Hit specific case [No forwarding false dependency - reg_we_ex = 0]: Start \n");
    run_test_pc_target  = dut_m_pc_mux_out + `NFWE0_TEST;
    expected_dependencies(0, 0, 0, 0);
    while(dut_m_pc_mux_out < run_test_pc_target) begin
        clocks_to_execute = 1;   // by default, 1 clock needed for instruction execution
        while(clocks_to_execute != 0) begin
            clocks_to_execute = 0;   // instruction executed
            @(posedge clk); #1;
            env_update_seq();
            tb_driver();
            dut_m_decode();
            #1; run_checkers();
            print_single_instruction_results();
            if(branch_inst || jump_inst) clocks_to_execute = 1;   // add one more 1 clock for branch/jump
            if(clocks_to_execute == 0) dut_m_pc_mux_out = dut_m_pc_mux_out + 1;
        end
    end
    dependency_checker();
    $display("\nTest 14: Hit specific case [No forwarding false dependency - reg_we_ex = 0]: Done \n");
    */
    //-----------------------------------------------------------------------------
    repeat (1) @(posedge clk);
    print_test_status();
    $finish();
    
end // test

endmodule
