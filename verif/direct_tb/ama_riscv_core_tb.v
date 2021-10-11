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
//      2021-09-27  AL 0.16.0 - Add RF forwarding and checkers
//      2021-10-02  AL 0.17.0 - Add CSRRW and CSRRWI
//                              Fix RF forwarding for Branch and Store
//                              Fix Store Mask for sb and sh
//                              Fix bcs_fwd in ID/EX FF
//                              Add RF checkers
//                              Add tohost checker
//      2021-10-09  AL 0.18.0 - Add load_inst_ex
//      2021-10-10  AL 0.19.0 - Add inst and cycle counters, performance evaluation
//
//      To Do list:
//       - add basic disassembler to convert back instructions to asm format
//       - add checker IDs, print on exit number of samples checked and results
//       - add counters in model
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`define CLK_PERIOD          8
`define TEST_NAME           "sh.hex"

// Memories
`define MEM_SIZE            16384

// Reg File
`define RF_WID              32
`define RF_NUM              32

// TB
`define CHECKER_ACTIVE      1'b1
`define CHECKER_INACTIVE    1'b0
`define CHECK_D             1
`define TIMEOUT_CLOCKS      5000

// Expected dependencies in each of the dependency tests
`define FD_TEST_EXP_ALU_A   7  // for ALU A
`define FD_TEST_EXP_ALU_B   2  // for ALU B
`define FD_TEST_EXP_BC_A    2  // for BC A 
`define FD_TEST_EXP_BCS_B   4  // for BCS B

// Opcodes
`define OPC7_R_TYPE         7'b011_0011     // R-type
`define OPC7_I_TYPE         7'b001_0011     // I-type
`define OPC7_LOAD           7'b000_0011     // I-type
`define OPC7_STORE          7'b010_0011     // S-type
`define OPC7_BRANCH         7'b110_0011     // B-type
`define OPC7_JALR           7'b110_0111     // J-type, I-format
`define OPC7_JAL            7'b110_1111     // J-type
`define OPC7_LUI            7'b011_0111     // U-type
`define OPC7_AUIPC          7'b001_0111     // U-type
`define OPC7_SYSTEM         7'b111_0011     // System, I-format

// CSR addresses
`define CSR_TOHOST          12'h51E

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
`define WB_SEL_CSR          2'd3  // Reg[rd] = CSR data

// Imm Gen
`define IG_DISABLED         3'b000
`define IG_I_TYPE           3'b001
`define IG_S_TYPE           3'b010
`define IG_B_TYPE           3'b011
`define IG_J_TYPE           3'b100
`define IG_U_TYPE           3'b101

`define PROJECT_PATH        "C:/Users/Aleksandar/Documents/xilinx/ama-riscv/"

`define DUT                 DUT_ama_riscv_core_i
`define DUT_DEC             DUT_ama_riscv_core_i.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF              DUT_ama_riscv_core_i.ama_riscv_reg_file_i

`define TOHOST_PASS         32'd1

module ama_riscv_core_tb();

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O
reg          clk = 0;
reg          rst;
wire         inst_wb_nop_or_clear   ;
wire         mmio_reset_cnt         ;

//-----------------------------------------------------------------------------
// Model

// Datapath
// IF stage
reg  [31:0] dut_m_pc                ;
reg  [31:0] dut_m_pc_mux_out        ;

// Reg File
reg  [`RF_WID-1:0] dut_m_rf32 [`RF_NUM-1:0];
// ID stage
// in
reg  [31:0] dut_m_inst_id           ;
reg  [ 4:0] dut_m_rs1_addr_id       ;
reg  [ 4:0] dut_m_rs2_addr_id       ;
reg  [ 4:0] dut_m_rd_addr_id        ;
reg  [24:0] dut_m_imm_gen_in        ;
reg  [31:0] dut_m_tohost            ;
reg  [31:0] dut_m_csr_data_id       ;
// out
reg  [31:0] dut_m_rs1_data_id       ;
reg  [31:0] dut_m_rs2_data_id       ;
reg  [31:0] dut_m_imm_gen_out_id    ;

// EX stage
// in
reg  [31:0] dut_m_pc_ex             ;
reg  [31:0] dut_m_inst_ex           ;
reg  [ 4:0] dut_m_rs1_addr_ex       ;
reg  [31:0] dut_m_rs1_data_ex       ;
reg  [31:0] dut_m_rs2_data_ex       ;
reg  [ 4:0] dut_m_rd_addr_ex        ;
reg  [31:0] dut_m_imm_gen_out_ex    ;
reg  [31:0] dut_m_csr_data_ex       ;
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
reg  [31:0] dut_m_alu_in_a_mem      ;
reg  [31:0] dut_m_dmem_read_data_mem;
reg  [ 1:0] dut_m_load_sm_offset_mem;
reg  [31:0] dut_m_inst_mem          ;
reg  [ 4:0] dut_m_rs1_addr_mem      ;
reg  [ 4:0] dut_m_rd_addr_mem       ;
reg  [31:0] dut_m_csr_data_mem      ;
// out
reg  [31:0] dut_m_load_sm_data_out  ;
reg  [31:0] dut_m_writeback         ;


// Control Outputs - Pipeline Registers
reg         dut_m_stall_if          ;
reg         dut_m_stall_if_q1       ;
reg         dut_m_clear_if          ;
reg         dut_m_clear_id          ;
reg         dut_m_clear_ex          ;
reg         dut_m_clear_mem         ;


// Control Outputs
// for IF stage
reg  [ 1:0] dut_m_pc_sel_if         ;
reg         dut_m_pc_we_if          ;
// for ID stage 
reg         dut_m_store_inst_id     ;
reg         dut_m_load_inst_id      ;
reg         dut_m_branch_inst_id    ;
reg         dut_m_jump_inst_id      ;
reg         dut_m_csr_en_id         ;
reg         dut_m_csr_we_id         ;
reg         dut_m_csr_ui_id         ;
reg  [11:0] dut_m_csr_addr          ;
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
reg         dut_m_rf_a_sel_fwd_id   ;
reg         dut_m_rf_b_sel_fwd_id   ;
reg  [ 3:0] dut_m_dmem_we_ex        ;
// for MEM stage    
reg         dut_m_load_sm_en_id     ;
reg  [ 1:0] dut_m_wb_sel_id         ;

// Control Outputs in datapath
// in EX stage
reg         dut_m_reg_we_ex         ;
reg         dut_m_csr_en_ex         ;
reg         dut_m_csr_we_ex         ;
reg         dut_m_csr_ui_ex         ;
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
reg         dut_m_csr_en_mem        ;
reg         dut_m_csr_we_mem        ;
reg         dut_m_csr_ui_mem        ;
reg         dut_m_load_sm_en_mem    ;
reg  [ 1:0] dut_m_wb_sel_mem        ;



// Model internal signals
reg  [31:0] dut_m_pc_mux_out_div4       ;
reg  [31:0] dut_m_inst_id_read          ;
reg[30*7:0] dut_m_inst_id_read_asm      ;
reg  [31:0] dut_m_imm_gen_out_id_prev   ;
reg  [31:0] dut_m_csr_din_imm           ;
reg         dut_m_alu_a_sel_id          ;
reg         dut_m_alu_b_sel_id          ;
reg         dut_m_branch_taken          ;
reg         dut_m_jump_taken            ;
reg         dut_m_branch_inst_ex        ;
reg         dut_m_jump_inst_ex          ;
reg         dut_m_store_inst_ex         ;
reg         dut_m_load_inst_ex          ;

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
integer       i                     ;              // used for all loops
integer       done                  ;
integer       isa_passed_dut        ;
integer       isa_passed_model      ;
integer       clocks_to_execute     ;
integer       run_test_pc_target    ;
integer       errors                ;
integer       warnings              ;
integer       pre_rst_warnings      ;

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// file read
integer       fd;
integer       status;
reg  [  31:0] test_values_inst_hex [`MEM_SIZE-1:0];       // imem sim
reg  [  31:0] test_values_inst_hex_nop = 'h0000_0013;
reg  [  31:0] test_values_dmem [`MEM_SIZE-1:0];           // dmem sim
reg  [30*7:0] str;
reg  [30*7:0] test_values_inst_asm [`MEM_SIZE-1:0];     // not in use, left in for compatibility
reg  [30*7:0] test_values_inst_asm_nop  = 'h0  ;        // not in use, print zero

reg  [30*7:0] dut_m_inst_id_asm         = 'h0  ;        // not in use, print zero
reg  [30*7:0] dut_m_inst_ex_asm         = 'h0  ;        // not in use, print zero
reg  [30*7:0] dut_m_inst_mem_asm        = 'h0  ;        // not in use, print zero

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_core DUT_ama_riscv_core_i (
    .clk    (clk    ),
    .rst    (rst    ),
    // outputs
    .inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
    .mmio_reset_cnt         (mmio_reset_cnt         )
);

//-----------------------------------------------------------------------------
// Cycle counter
reg   [31:0] mmio_cycle_cnt         ;
always @ (posedge clk) begin
    if (rst)
        mmio_cycle_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        mmio_cycle_cnt <= 32'd0;
    else
        mmio_cycle_cnt <= mmio_cycle_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Instruction counter
reg   [31:0] mmio_instr_cnt         ;
always @ (posedge clk) begin
    if (rst)
        mmio_instr_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        mmio_instr_cnt <= 32'd0;
    else if (!inst_wb_nop_or_clear)        // prevent counting nop and pipe clear
        mmio_instr_cnt <= mmio_instr_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Count inserted Clears and NOPs
reg   [31:0] hw_inserted_nop_or_clear_cnt         ;
always @ (posedge clk) begin
    if (rst)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (`DUT.stall_if_q1 || `DUT.clear_mem)    // clear_mem is enough in this implementation, predictor may change this
        hw_inserted_nop_or_clear_cnt <= hw_inserted_nop_or_clear_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Count all Clears and NOPs
reg   [31:0] hw_all_nop_or_clear_cnt         ;
always @ (posedge clk) begin
    if (rst)
        hw_all_nop_or_clear_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        hw_all_nop_or_clear_cnt <= 32'd0;
    else if (inst_wb_nop_or_clear)
        hw_all_nop_or_clear_cnt <= hw_all_nop_or_clear_cnt + 32'd1;
end

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Testbench tasks
task print_test_status;
    input test_run_success;
    begin
        $display("\n----------------------- Simulation results -----------------------");
        if (!test_run_success) begin
            $display("\nTest timed out");
        end
        else begin 
            $display("\nTest ran to completion");
            
            $display("\nStatus - DUT-ISA: ");
            if(isa_passed_dut == 1) begin
                $display("    Passed");
            end
            else begin
                $display("    Failed");
                $display("    Failed test # : %0d", `DUT.tohost[31:1]);
            end
            
            $display("\nStatus - Model-ISA: ");
            if(isa_passed_model == 1) begin
                $display("    Passed");
            end
            else begin
                $display("    Failed");
                $display("    Failed test # : %0d", dut_m_tohost[31:1]);
            end
            
            $display("\nStatus - DUT-Model:");
            if(!errors)
                $display("    Passed");
            else
                $display("    Failed");
            
            // $display("    Pre RST Warnings: %2d", pre_rst_warnings);
            $display("    Warnings: %2d", warnings - pre_rst_warnings);
            $display("    Errors:   %2d", errors);
            
            $display("\n\n-------------------------- Performance ---------------------------\n");
            $display("Cycle counter: %0d", mmio_cycle_cnt);
            $display("Instr counter: %0d", mmio_instr_cnt);
            $display("Empty cycles:  %0d", mmio_cycle_cnt - mmio_instr_cnt);
            $display("          CPI: %0.3f", real(mmio_cycle_cnt)/real(mmio_instr_cnt));
            $display("\nHW Inserted NOPs and Clears: %0d", hw_inserted_nop_or_clear_cnt);
            $display(  "All NOPs and Clears:         %0d", hw_all_nop_or_clear_cnt);
            $display(  "Compiler Inserted NOPs:      %0d", hw_all_nop_or_clear_cnt - hw_inserted_nop_or_clear_cnt);
        end
        $display("\n--------------------- End of the simulation ----------------------\n");
    end
endtask

task print_single_instruction_results;
    integer last_pc;
    reg     stalled;
    begin
        stalled = (last_pc == dut_m_pc);
        $display("Instruction at PC# %2d %s ", dut_m_pc, stalled ? "stalled " : "executed"); 
        // $write  ("ID  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_id , dut_m_inst_id_asm );
        // $write  ("EX  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_ex , dut_m_inst_ex_asm );
        // $write  ("MEM stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_mem, dut_m_inst_mem_asm);
        $display  ("ID  stage: HEX: 'h%8h", dut_m_inst_id);
        $display  ("EX  stage: HEX: 'h%8h", dut_m_inst_ex);
        $display  ("MEM stage: HEX: 'h%8h", dut_m_inst_mem);
        last_pc = dut_m_pc;
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
                    $time-`CHECK_D, checker_name, checker_dut_signal, checker_model_signal);
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
        checker_t("dmem_en_mmio",            `CHECKER_ACTIVE,    `DUT.dmem_en,            dut_m_dmem_en_ex        );
        checker_t("load_sm_en",         `CHECKER_ACTIVE,    `DUT.load_sm_en_id,         dut_m_load_sm_en_id     );
        checker_t("wb_sel",             `CHECKER_ACTIVE,    `DUT.wb_sel_id,             dut_m_wb_sel_id         );
        checker_t("reg_we_id",          `CHECKER_ACTIVE,    `DUT.reg_we_id,             dut_m_reg_we_id         );
        checker_t("alu_a_sel_fwd",      `CHECKER_ACTIVE,    `DUT.alu_a_sel_fwd_id,      dut_m_alu_a_sel_fwd_id  );
        checker_t("alu_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT.alu_b_sel_fwd_id,      dut_m_alu_b_sel_fwd_id  );
        checker_t("bc_a_sel_fwd",       `CHECKER_ACTIVE,    `DUT.bc_a_sel_fwd_id,       dut_m_bc_a_sel_fwd_id   );
        checker_t("bcs_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT.bcs_b_sel_fwd_id,      dut_m_bcs_b_sel_fwd_id  );
        checker_t("rf_a_sel_fwd",       `CHECKER_ACTIVE,    `DUT.rf_a_sel_fwd_id,       dut_m_rf_a_sel_fwd_id   );
        checker_t("rf_b_sel_fwd",       `CHECKER_ACTIVE,    `DUT.rf_b_sel_fwd_id,       dut_m_rf_b_sel_fwd_id   );
        checker_t("dmem_we",            `CHECKER_ACTIVE,    `DUT.dmem_we_ex,            dut_m_dmem_we_ex        );
        checker_t("dmem_we_mmio",            `CHECKER_ACTIVE,    `DUT.dmem_we,            dut_m_dmem_we_ex        );
        // in ex stage
        checker_t("load_inst_ex",       `CHECKER_ACTIVE,    `DUT.load_inst_ex,          dut_m_load_inst_ex      );
        // internal 
        checker_t("branch_taken",       `CHECKER_ACTIVE,    dut_internal_branch_taken,  dut_m_branch_taken      );
        
        // RF
        checker_t("x0_zero",            `CHECKER_ACTIVE,    `DUT_RF.x0_zero,            dut_m_x0_zero           );
        checker_t("x1_ra  ",            `CHECKER_ACTIVE,    `DUT_RF.x1_ra  ,            dut_m_x1_ra             );
        checker_t("x2_sp  ",            `CHECKER_ACTIVE,    `DUT_RF.x2_sp  ,            dut_m_x2_sp             );
        checker_t("x3_gp  ",            `CHECKER_ACTIVE,    `DUT_RF.x3_gp  ,            dut_m_x3_gp             );
        checker_t("x4_tp  ",            `CHECKER_ACTIVE,    `DUT_RF.x4_tp  ,            dut_m_x4_tp             );
        checker_t("x5_t0  ",            `CHECKER_ACTIVE,    `DUT_RF.x5_t0  ,            dut_m_x5_t0             );
        checker_t("x6_t1  ",            `CHECKER_ACTIVE,    `DUT_RF.x6_t1  ,            dut_m_x6_t1             );
        checker_t("x7_t2  ",            `CHECKER_ACTIVE,    `DUT_RF.x7_t2  ,            dut_m_x7_t2             );
        checker_t("x8_s0  ",            `CHECKER_ACTIVE,    `DUT_RF.x8_s0  ,            dut_m_x8_s0             );
        checker_t("x9_s1  ",            `CHECKER_ACTIVE,    `DUT_RF.x9_s1  ,            dut_m_x9_s1             );
        checker_t("x10_a0 ",            `CHECKER_ACTIVE,    `DUT_RF.x10_a0 ,            dut_m_x10_a0            );
        checker_t("x11_a1 ",            `CHECKER_ACTIVE,    `DUT_RF.x11_a1 ,            dut_m_x11_a1            );
        checker_t("x12_a2 ",            `CHECKER_ACTIVE,    `DUT_RF.x12_a2 ,            dut_m_x12_a2            );
        checker_t("x13_a3 ",            `CHECKER_ACTIVE,    `DUT_RF.x13_a3 ,            dut_m_x13_a3            );
        checker_t("x14_a4 ",            `CHECKER_ACTIVE,    `DUT_RF.x14_a4 ,            dut_m_x14_a4            );
        checker_t("x15_a5 ",            `CHECKER_ACTIVE,    `DUT_RF.x15_a5 ,            dut_m_x15_a5            );
        checker_t("x16_a6 ",            `CHECKER_ACTIVE,    `DUT_RF.x16_a6 ,            dut_m_x16_a6            );
        checker_t("x17_a7 ",            `CHECKER_ACTIVE,    `DUT_RF.x17_a7 ,            dut_m_x17_a7            );
        checker_t("x18_s2 ",            `CHECKER_ACTIVE,    `DUT_RF.x18_s2 ,            dut_m_x18_s2            );
        checker_t("x19_s3 ",            `CHECKER_ACTIVE,    `DUT_RF.x19_s3 ,            dut_m_x19_s3            );
        checker_t("x20_s4 ",            `CHECKER_ACTIVE,    `DUT_RF.x20_s4 ,            dut_m_x20_s4            );
        checker_t("x21_s5 ",            `CHECKER_ACTIVE,    `DUT_RF.x21_s5 ,            dut_m_x21_s5            );
        checker_t("x22_s6 ",            `CHECKER_ACTIVE,    `DUT_RF.x22_s6 ,            dut_m_x22_s6            );
        checker_t("x23_s7 ",            `CHECKER_ACTIVE,    `DUT_RF.x23_s7 ,            dut_m_x23_s7            );
        checker_t("x24_s8 ",            `CHECKER_ACTIVE,    `DUT_RF.x24_s8 ,            dut_m_x24_s8            );
        checker_t("x25_s9 ",            `CHECKER_ACTIVE,    `DUT_RF.x25_s9 ,            dut_m_x25_s9            );
        checker_t("x26_s10",            `CHECKER_ACTIVE,    `DUT_RF.x26_s10,            dut_m_x26_s10           );
        checker_t("x27_s11",            `CHECKER_ACTIVE,    `DUT_RF.x27_s11,            dut_m_x27_s11           );
        checker_t("x28_t3 ",            `CHECKER_ACTIVE,    `DUT_RF.x28_t3 ,            dut_m_x28_t3            );
        checker_t("x29_t4 ",            `CHECKER_ACTIVE,    `DUT_RF.x29_t4 ,            dut_m_x29_t4            );
        checker_t("x30_t5 ",            `CHECKER_ACTIVE,    `DUT_RF.x30_t5 ,            dut_m_x30_t5            );
        checker_t("x31_t6 ",            `CHECKER_ACTIVE,    `DUT_RF.x31_t6 ,            dut_m_x31_t6            );
        
        checker_t("tohost",             `CHECKER_ACTIVE,    `DUT.tohost,                dut_m_tohost            );
    
    end // main task body */
endtask // run_checkers

//-----------------------------------------------------------------------------
// DUT model tasks
task dut_m_read_test_instructions;
    begin
        $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/", `TEST_NAME}, test_values_inst_hex, 0, 16384-1);
        $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/", `TEST_NAME}, test_values_dmem,     0, 16384-1);
    end
endtask

task dut_m_decode;
    reg  [31:0] inst_id;
    reg  [31:0] inst_ex;
    reg  [ 2:0] funct3_ex;
    
    begin
    inst_id         = dut_m_inst_id;
    inst_ex         = dut_m_inst_ex;
    funct3_ex       = dut_m_inst_ex[14:12];
    dut_m_csr_addr  = dut_m_inst_id[31:20];
    
        case (inst_id[6:0])
            `OPC7_R_TYPE: begin   // R-type instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_I_TYPE: begin   // I-type instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_LOAD: begin   // Load instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b1;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_STORE: begin   // Store instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b1;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_BRANCH: begin   // Branch instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b1;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
                dut_m_alu_op_sel_id  = 4'b0000;    // add
                dut_m_alu_a_sel_id   = `ALU_A_SEL_PC;
                dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                dut_m_imm_gen_sel_id = `IG_B_TYPE;
                dut_m_bc_uns_id      = inst_id[13];     // funct3[1]
                dut_m_dmem_en_id     = 1'b0;
                dut_m_load_sm_en_id  = 1'b0;
                // dut_m_wb_sel_id      = `WB_SEL_DMEM;
                dut_m_reg_we_id      = 1'b0;
            end
            
            `OPC7_JALR: begin   // JALR instruction
                dut_m_pc_sel_if      = `PC_SEL_ALU;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b1;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_JAL: begin   // JAL instruction
                dut_m_pc_sel_if      = `PC_SEL_ALU;
                dut_m_pc_we_if       = 1'b0;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b1;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_LUI: begin   // LUI instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_AUIPC: begin   // AUIPC instruction
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = 1'b0;
                dut_m_csr_we_id      = 1'b0;
                dut_m_csr_ui_id      = 1'b0;
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
            
            `OPC7_SYSTEM: begin   // only CSRRW and CSRRWI
                dut_m_pc_sel_if      = `PC_SEL_INC4;
                dut_m_pc_we_if       = 1'b1;
                dut_m_branch_inst_id = 1'b0;
                dut_m_jump_inst_id   = 1'b0;
                dut_m_store_inst_id  = 1'b0;
                dut_m_load_inst_id   = 1'b0;
                dut_m_csr_en_id      = (dut_m_csr_addr == `CSR_TOHOST) && (dut_m_rs1_addr_id != `RF_X0_ZERO);
                dut_m_csr_we_id      = 1'b1;
                dut_m_csr_ui_id      = inst_id[13];     // funct3[2]
                // dut_m_alu_op_sel_id  = 4'b0000;    
                dut_m_alu_a_sel_id   = `ALU_A_SEL_RS1;
                // dut_m_alu_b_sel_id   = `ALU_B_SEL_IMM;
                // dut_m_imm_gen_sel_id = `IG_U_TYPE;
                // dut_m_bc_uns_id      = *;
                dut_m_dmem_en_id     = 1'b0;
                // dut_m_load_sm_en_id  = *;
                dut_m_wb_sel_id      = `WB_SEL_CSR;
                dut_m_reg_we_id      = (dut_m_rs1_addr_id != `RF_X0_ZERO);
            end
            
            default: begin
                $display("*WARNING @ %0t. Decoder model 'default' case. Input inst_id: 'h%8h", // %0s",
                $time, dut_m_inst_id, /* dut_m_inst_id_asm */);
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
            dut_m_load_inst_id   = 1'b0;
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
        
        // RF A
        dut_m_rf_a_sel_fwd_id = ((dut_m_rs1_addr_id != `RF_X0_ZERO) && (dut_m_rs1_addr_id == dut_m_rd_addr_mem) && (dut_m_reg_we_mem) && 
                                 ((!dut_m_alu_a_sel_id) || (dut_m_branch_inst_id))                                                          );
        
        // RF B
        dut_m_rf_b_sel_fwd_id = ((dut_m_rs2_addr_id != `RF_X0_ZERO) && (dut_m_rs2_addr_id == dut_m_rd_addr_mem) && (dut_m_reg_we_mem) && 
                                 ((!dut_m_alu_b_sel_id) || (dut_m_branch_inst_id) || (dut_m_store_inst_id))                                 );
         
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
        case (dut_m_pc_sel_if)
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
        
        dut_m_rs1_data_id = dut_m_rf32[dut_m_rs1_addr_id];
        dut_m_rs2_data_id = dut_m_rf32[dut_m_rs2_addr_id];
        
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

task dut_m_csr_read_update;
    begin
        if (dut_m_csr_en_id)
            dut_m_csr_data_id = dut_m_tohost;
        else
            dut_m_csr_data_id = 'h0;
    end
endtask

task dut_m_csr_write_update;
    begin
        // zero-extend uimm
        dut_m_csr_din_imm = {27'h0, dut_m_rs1_addr_mem};
        
        if (rst) begin
            dut_m_tohost = 'h0;
        end
        else if (dut_m_csr_we_mem) begin
            dut_m_tohost = dut_m_csr_ui_mem ? dut_m_csr_din_imm : dut_m_alu_in_a_mem;
        end
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
        dut_m_dmem_addr         = dut_m_alu_out[15:2];
        dut_m_load_sm_offset_ex = dut_m_alu_out[1:0];                                           // byte offset
        dut_m_dmem_write_data   = dut_m_bcs_b_sel_fwd_id ? dut_m_writeback : dut_m_rs2_data_ex;
        dut_m_dmem_write_data   = dut_m_dmem_write_data << (dut_m_load_sm_offset_ex*8);         // byte shift left 0, 1, 2 or 3 times
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
        dut_m_writeback = (dut_m_wb_sel_mem == `WB_SEL_DMEM) ?    dut_m_load_sm_data_out    :
                          (dut_m_wb_sel_mem == `WB_SEL_ALU ) ?    dut_m_alu_out_mem         :
                          (dut_m_wb_sel_mem == `WB_SEL_INC4) ?    dut_m_pc_mem + 32'd4      :
                       /* (dut_m_wb_sel_mem == `WB_SEL_CSR ) ? */ dut_m_csr_data_mem       ;
    end
endtask

task dut_m_nop_id_update;
    begin
        dut_m_inst_id           = (dut_m_stall_if_q1) ? test_values_inst_hex_nop : dut_m_inst_id_read;
        // dut_m_inst_id_asm       = (dut_m_stall_if_q1) ? test_values_inst_asm_nop : dut_m_inst_id_read_asm;
        dut_m_inst_id_asm       = (dut_m_stall_if_q1) ? test_values_inst_hex_nop : dut_m_inst_id_read;          // fix, w/o asm strings
    end
endtask

task dut_m_if_pipeline_update;
    begin
        dut_m_stall_if_q1       = (!rst) ? dut_m_stall_if : 'b1;
    end
endtask

task dut_m_id_ex_pipeline_update;
    begin
        // instruction update
        // datapath
        dut_m_pc_ex              = (!rst && !dut_m_clear_id) ? dut_m_pc                  : 'h0;
        dut_m_rd_addr_ex         = (!rst && !dut_m_clear_id) ? dut_m_rd_addr_id          : 'h0;        
        dut_m_rs1_addr_ex        = (!rst && !dut_m_clear_id) ? dut_m_rs1_addr_id         : 'h0;        
        dut_m_rs1_data_ex        = (!rst && !dut_m_clear_id) ? 
                                    dut_m_rf_a_sel_fwd_id    ? dut_m_writeback           : 
                                                               dut_m_rs1_data_id         : 
                                             /*rst or clear*/  'h0                            ;
        dut_m_rs2_data_ex        = (!rst && !dut_m_clear_id) ? 
                                    dut_m_rf_b_sel_fwd_id    ? dut_m_writeback           : 
                                                               dut_m_rs2_data_id         : 
                                             /*rst or clear*/  'h0                            ;        
        dut_m_imm_gen_out_ex     = (!rst && !dut_m_clear_id) ? dut_m_imm_gen_out_id      : 'h0;
        dut_m_csr_data_ex        = (!rst && !dut_m_clear_id) ? dut_m_csr_data_id         : 'h0;
        dut_m_inst_ex            = (!rst && !dut_m_clear_id) ? dut_m_inst_id             : 'h0;
        dut_m_inst_ex_asm        = (!rst && !dut_m_clear_id) ? dut_m_inst_id_asm         : 'h0;
        
        // control
        dut_m_bc_uns_ex          = (!rst && !dut_m_clear_id) ? dut_m_bc_uns_id           : 'b0;
        dut_m_bc_a_sel_fwd_ex    = (!rst && !dut_m_clear_id) ? dut_m_bc_a_sel_fwd_id     : 'b0;
        dut_m_bcs_b_sel_fwd_ex   = (!rst && !dut_m_clear_id) ? dut_m_bcs_b_sel_fwd_id    : 'b0;
        dut_m_alu_a_sel_fwd_ex   = (!rst && !dut_m_clear_id) ? dut_m_alu_a_sel_fwd_id    : 'h0;
        dut_m_alu_b_sel_fwd_ex   = (!rst && !dut_m_clear_id) ? dut_m_alu_b_sel_fwd_id    : 'h0;
        dut_m_alu_op_sel_ex      = (!rst && !dut_m_clear_id) ? dut_m_alu_op_sel_id       : 'h0;
        dut_m_dmem_en_ex         = (!rst && !dut_m_clear_id) ? dut_m_dmem_en_id          : 'b0;
        dut_m_load_sm_en_ex      = (!rst && !dut_m_clear_id) ? dut_m_load_sm_en_id       : 'b0;
        dut_m_wb_sel_ex          = (!rst && !dut_m_clear_id) ? dut_m_wb_sel_id           : 'h0;
        dut_m_reg_we_ex          = (!rst && !dut_m_clear_id) ? dut_m_reg_we_id           : 'b0;
        dut_m_csr_we_ex          = (!rst && !dut_m_clear_id) ? dut_m_csr_we_id           : 'b0;
        dut_m_csr_ui_ex          = (!rst && !dut_m_clear_id) ? dut_m_csr_ui_id           : 'b0;
        
        // internal only
        dut_m_store_inst_ex      = (!rst && !dut_m_clear_id) ? dut_m_store_inst_id       : 'b0;
        dut_m_load_inst_ex       = (!rst && !dut_m_clear_id) ? dut_m_load_inst_id        : 'b0;
        dut_m_branch_inst_ex     = (!rst && !dut_m_clear_id) ? dut_m_branch_inst_id      : 'b0;
        dut_m_jump_inst_ex       = (!rst && !dut_m_clear_id) ? dut_m_jump_inst_id        : 'b0;
    end
endtask

task dut_m_ex_mem_pipeline_update;
    begin
        dut_m_pc_mem             = (!rst && !dut_m_clear_ex) ? dut_m_pc_ex              : 'h0;
        dut_m_alu_out_mem        = (!rst && !dut_m_clear_ex) ? dut_m_alu_out            : 'h0;
        dut_m_alu_in_a_mem       = (!rst && !dut_m_clear_ex) ? dut_m_alu_in_a           : 'h0;
        dut_m_dmem_update();
        dut_m_load_sm_offset_mem = (!rst && !dut_m_clear_ex) ? dut_m_load_sm_offset_ex  : 'h0;
        dut_m_inst_mem           = (!rst && !dut_m_clear_ex) ? dut_m_inst_ex            : 'h0;
        dut_m_inst_mem_asm       = (!rst && !dut_m_clear_ex) ? dut_m_inst_ex_asm        : 'h0;
        dut_m_rd_addr_mem        = (!rst && !dut_m_clear_ex) ? dut_m_rd_addr_ex         : 'h0;
        dut_m_rs1_addr_mem       = (!rst && !dut_m_clear_ex) ? dut_m_rs1_addr_ex        : 'h0;
        dut_m_csr_data_mem       = (!rst && !dut_m_clear_ex) ? dut_m_csr_data_ex        : 'h0;
        dut_m_load_sm_en_mem     = (!rst && !dut_m_clear_ex) ? dut_m_load_sm_en_ex      : 'b0;
        dut_m_wb_sel_mem         = (!rst && !dut_m_clear_ex) ? dut_m_wb_sel_ex          : 'h0;
        dut_m_reg_we_mem         = (!rst && !dut_m_clear_ex) ? dut_m_reg_we_ex          : 'b0;
        dut_m_csr_we_mem         = (!rst && !dut_m_clear_id) ? dut_m_csr_we_ex          : 'b0;
        dut_m_csr_ui_mem         = (!rst && !dut_m_clear_id) ? dut_m_csr_ui_ex          : 'b0;
        
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
        dut_m_csr_write_update();
                
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
        dut_m_csr_read_update();
        
        //----- IF stage updates
        dut_m_pc_mux_update();
        // $display("PC sel: %0d ", pc_sel);
        // $display("PC MUX: %0d ", dut_env_pc_mux_out);
    end
endtask

task load_memories;
    begin
        $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/", `TEST_NAME}, DUT_ama_riscv_core_i.ama_riscv_imem_i.mem, 0, 16384-1);
        $readmemh({`PROJECT_PATH, "verif/direct_tb/inst/", `TEST_NAME}, DUT_ama_riscv_core_i.ama_riscv_dmem_i.mem, 0, 16384-1);
    end
endtask
//-----------------------------------------------------------------------------
// Reset
initial begin
    // sync this thread with events from main thread
    @(ev_rst[0]); // #1;
    // $display("\nReset Sequence start \n");    
    rst = 1'b0;
    
    @(ev_rst[0]); // @(posedge clk); #1;
    
    rst = 1'b1;
    repeat (rst_pulses) begin
        @(ev_rst[0]); //@(posedge clk); #1;          
    end
    rst = 1'b0;
    // @(ev_rst[0]); //@(posedge clk); #1;  
    // ->ev_rst_done;
    // $display("\nReset Sequence end \n");
    rst_done = 1;
    
end

//-----------------------------------------------------------------------------
// Config

// Initial setup
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    dut_m_read_test_instructions();
    errors              = 0;
    warnings            = 0;
    done                = 0;
    isa_passed_dut      = 0;
    isa_passed_model    = 0;
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
    load_memories();
    // Test 0: Wait for reset
    $display("\n Resetting DUT... \n");
    @(posedge clk); #1;
    while (!rst_done) begin
        // $display("Reset not done, time: %0t \n", $time);
         ->ev_rst[0]; #1;
        
        // if still not done, wait for next clk else exit
        if(!rst_done) begin 
            @(posedge clk); #1; 
            dut_m_seq_update();
            dut_m_comb_update();
        end
    end
    $display("Reset done, time: %0t \n", $time);
    
    pre_rst_warnings = warnings;
    
    //-----------------------------------------------------------------------------
    // Test
    $display("\nTest Start \n");
    
    // catch timeout
    fork
        begin
            while (`DUT.tohost[0] !== 1'b1) begin
                @(posedge clk);
                dut_m_seq_update();
                dut_m_comb_update(); 
                #`CHECK_D; run_checkers();
                print_single_instruction_results();
            end
            done = 1;
        end
        begin
            repeat(`TIMEOUT_CLOCKS) begin
                if (!done) @(posedge clk);
            end
            if (!done) begin
                print_test_status(done);
                $finish();
            end
        end
    join
    
    // DUT passed ISA?
    if (`DUT.tohost === `TOHOST_PASS)
        isa_passed_dut = 1;
    else
        isa_passed_dut = 0;
    
    // Model passed ISA?
    if (dut_m_tohost === `TOHOST_PASS)
        isa_passed_model = 1;
    else
        isa_passed_model = 0;
    
    
    $display("\n\nTest Done \n");
    
    repeat (1) @(posedge clk);
    print_test_status(done);
    $finish();
    
end // test

endmodule
