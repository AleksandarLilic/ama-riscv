//-----------------------------------------------------------------------------
// Project:         AMA-RISCV
// Module:          Core Testbench
// File:            ama_riscv_core_top_tb.v
// Date created:    2021-09-11
// Author:          Aleksandar Lilic
// Description:     Testbench and model for ama_riscv_core_top module
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
//      2021-10-11  AL 0.20.0 - Add Branch Compare inputs as global signals
//      2021-10-26  AL 0.21.0 - Add model as include
//      2021-10-29  AL 0.22.0 - WIP - Add disassembler - R-type
//      2021-10-30  AL        - WIP - DASM - add I-type
//      2021-10-31  AL        - WIP - DASM - add Load, S-type, B-type
//      2021-11-01  AL 0.22.1 - Fix model calls - separate block
//      2021-11-04  AL 0.23.0 - Add stall on forwarding from load
//      2021-11-04  AL 0.24.0 - Add regr for all ISA tests
//      2021-11-04  AL 0.25.0 - Add single test option
//      2021-11-05  AL 0.26.0 - Add regr test status arrays, verbosity switch
//      2021-11-09  AL 0.27.0 - Add model performance counters
//
//      TODO list:
//       - add basic disassembler to convert back instructions to asm format
//          - handling pseudo ops? other than NOP
//       - add switch for groups (r-type, i-type, branches, etc)
//       - add checker IDs, print on exit number of samples checked and results
//       - add counters in model
//       - split regr performance per instruction type (r-type, i-type, load, store, branch, jump etc)
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ps
`include "../../src/ama_riscv_defines.v"

`define CLK_PERIOD          8
`define SINGLE_TEST         1
`define TEST_NAME           add.hex
`define STANDALONE

`define VERBOSITY           2           // TODO: keep up to 5, add list of choices?, dbg & perf levels?
`define NUMBER_OF_TESTS     38

// TB
`define CHECKER_ACTIVE      1'b0        // TODO: Consider moving checkers to different file
`define CHECKER_INACTIVE    1'b0
`define CHECK_D             1
`define TIMEOUT_CLOCKS      5000

`define INST_PATH "/"
`define PROJECT_PATH "C:/dev/ama-riscv-sim/riscv-tests/riscv-isa-tests"
`define LOG_PATH "C:/dev/ama-riscv/simlogs/"
`define STIM_PATH "C:/dev/ama-riscv-sim/SW/out/build/ama-riscv-sim/src"

`define DUT                 DUT_ama_riscv_core_top_i
`define DUT_IMEM            `DUT.ama_riscv_imem_i.mem
`define DUT_DMEM            `DUT.ama_riscv_dmem_i.mem
`define DUT_CORE            `DUT.ama_riscv_core_i
`define DUT_DEC             `DUT_CORE.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF              `DUT_CORE.ama_riscv_reg_file_i

`define TOHOST_PASS         32'd1

`define MEM_SIZE            16384

// Macro functions
`define STRINGIFY(x)        `"x`"
// has to be enclosed with begin/end when called
`define load_memories_m(name)                                                          \
    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, `DUT_IMEM,    0, `MEM_SIZE-1);    \
    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, `DUT_DMEM,    0, `MEM_SIZE-1);    //\
//    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, dut_m_imem,   0, `MEM_SIZE-1);    \
//    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, dut_m_dmem,   0, `MEM_SIZE-1);    \

// Test names
`define TEST_SIMPLE         simple.hex
`define TEST_ADD            add.hex
`define TEST_SUB            sub.hex
`define TEST_SLL            sll.hex
`define TEST_SLT            slt.hex
`define TEST_SLTU           sltu.hex
`define TEST_XOR            xor.hex
`define TEST_SRL            srl.hex
`define TEST_SRA            sra.hex
`define TEST_OR             or.hex
`define TEST_AND            and.hex
`define TEST_ADDI           addi.hex
`define TEST_SLTI           slti.hex
`define TEST_SLTIU          sltiu.hex
`define TEST_XORI           xori.hex
`define TEST_ORI            ori.hex
`define TEST_ANDI           andi.hex
`define TEST_SLLI           slli.hex
`define TEST_SRLI           srli.hex
`define TEST_SRAI           srai.hex
`define TEST_LB             lb.hex
`define TEST_LH             lh.hex
`define TEST_LW             lw.hex
`define TEST_LBU            lbu.hex
`define TEST_LHU            lhu.hex
`define TEST_SB             sb.hex
`define TEST_SH             sh.hex
`define TEST_SW             sw.hex
`define TEST_BEQ            beq.hex
`define TEST_BNE            bne.hex
`define TEST_BLT            blt.hex
`define TEST_BGE            bge.hex
`define TEST_BLTU           bltu.hex
`define TEST_BGEU           bgeu.hex
`define TEST_JALR           jalr.hex
`define TEST_JAL            jal.hex
`define TEST_LUI            lui.hex
`define TEST_AUIPC          auipc.hex

module ama_riscv_core_top_tb();

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O
reg          clk = 0;
reg          rst;
wire         inst_wb_nop_or_clear   ;
wire         mmio_reset_cnt         ;

//-----------------------------------------------------------------------------
// DUT internals for checkers only
wire dut_internal_branch_taken = `DUT_DEC.branch_res && `DUT_DEC.branch_inst_ex;

//-----------------------------------------------------------------------------
// Testbench variables
integer       i                     ;   // used for all loops
integer       done                  ;
integer       isa_passed_dut        ;
integer       errors                ;
integer       warnings              ;
integer       pre_rst_warnings      ;
reg           errors_for_wave       ;
wire          tohost_source         ;
integer       regr_num = (`SINGLE_TEST) ? 1 : `NUMBER_OF_TESTS;
// regr flags
reg           dut_regr_status       ;
reg  [12*7:0] dut_regr_array [`NUMBER_OF_TESTS-1:0];
integer       isa_failed_dut_cnt    ;
// performance counters
// integer       perf_cnt_cycle        ;
// integer       perf_cnt_instr        ;
// integer       perf_cnt_empty_cycles ;
// integer       perf_cnt_all_nops     ;
// integer       perf_cnt_hw_nops      ;
// integer       perf_cnt_compiler_nops;

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// for printing current test name
reg [12*7:0]  current_test_string   ;

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// DUT instance
ama_riscv_core_top DUT_ama_riscv_core_top_i (
    .clk    (clk    ),
    .rst    (rst    ),
    // outputs
    .inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
    .mmio_reset_cnt         (mmio_reset_cnt         )
);

//-----------------------------------------------------------------------------
// Performance counters - HW

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

// Count inserted Clears and NOPs
reg   [31:0] hw_inserted_nop_or_clear_cnt         ;
always @ (posedge clk) begin
    if (rst)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (mmio_reset_cnt)
        hw_inserted_nop_or_clear_cnt <= 32'd0;
    else if (`DUT_CORE.stall_if_q1 || `DUT_CORE.clear_mem)    // clear_mem is enough in this implementation, predictor may change this
        hw_inserted_nop_or_clear_cnt <= hw_inserted_nop_or_clear_cnt + 32'd1;
end

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
// always #(`CLK_PERIOD/2) clk = ~clk;
integer fd_clk, fd_clk_repl;
reg [15:0] str_read_clk;
reg [15:0] str_read_clk_wave;

initial begin
    fd_clk = $fopen({`STIM_PATH, `"/stim_clk.txt`"}, "r");
    if (fd_clk) $display("File opened: %0d", fd_clk);
    else $display("File could not be opened: %0d", fd_clk);
    
    // debug
    fd_clk_repl = $fopen({`LOG_PATH, `"stim_clk_repl.txt`"}, "w");
    if (fd_clk_repl) $display("File opened: %0d", fd_clk_repl);
    else $display("File could not be opened: %0d", fd_clk_repl);
    // end of debug

    while (! $feof(fd_clk)) begin
        $fgets(str_read_clk, fd_clk);
        str_read_clk_wave = str_read_clk;
        $fdisplay(fd_clk_repl, str_read_clk[8]);
        clk = str_read_clk[15:8];
        #(`CLK_PERIOD/2);
    end
    $display("Finish called from stim_clk process");
    $finish();
end

// Reset gen
integer fd_rst;
reg [15:0] str_read_rst;
reg [15:0] str_read_rst_wave;

initial begin
    fd_rst = $fopen({`STIM_PATH, `"/stim_rst.txt`"}, "r");
    if (fd_rst) $display("File opened: %0d", fd_rst);
    else $display("File could not be opened: %0d", fd_rst);
    
    while (! $feof(fd_rst)) begin
        $fgets(str_read_rst, fd_rst);
        str_read_rst_wave = str_read_rst;
        rst = #1 str_read_rst[15:8];
        @(posedge clk); 
    end
    $display("Reset signal done");
end

//-----------------------------------------------------------------------------
// Testbench tasks
task load_single_test;
    begin
        `load_memories_m(`TEST_NAME); current_test_string = `STRINGIFY(`TEST_NAME);
    end
endtask

task load_test;
    input integer t_in_test_num;
    begin
        case(t_in_test_num)
            0 : begin  `load_memories_m(`TEST_SIMPLE);  current_test_string = "SIMPLE";  end
            1 : begin  `load_memories_m(`TEST_ADD   );  current_test_string = "ADD   ";  end
            2 : begin  `load_memories_m(`TEST_SUB   );  current_test_string = "SUB   ";  end
            3 : begin  `load_memories_m(`TEST_SLL   );  current_test_string = "SLL   ";  end
            4 : begin  `load_memories_m(`TEST_SLT   );  current_test_string = "SLT   ";  end
            5 : begin  `load_memories_m(`TEST_SLTU  );  current_test_string = "SLTU  ";  end
            6 : begin  `load_memories_m(`TEST_XOR   );  current_test_string = "XOR   ";  end
            7 : begin  `load_memories_m(`TEST_SRL   );  current_test_string = "SRL   ";  end
            8 : begin  `load_memories_m(`TEST_SRA   );  current_test_string = "SRA   ";  end
            9 : begin  `load_memories_m(`TEST_OR    );  current_test_string = "OR    ";  end
            10: begin  `load_memories_m(`TEST_AND   );  current_test_string = "AND   ";  end
            11: begin  `load_memories_m(`TEST_ADDI  );  current_test_string = "ADDI  ";  end
            12: begin  `load_memories_m(`TEST_SLTI  );  current_test_string = "SLTI  ";  end
            13: begin  `load_memories_m(`TEST_SLTIU );  current_test_string = "SLTIU ";  end
            14: begin  `load_memories_m(`TEST_XORI  );  current_test_string = "XORI  ";  end
            15: begin  `load_memories_m(`TEST_ORI   );  current_test_string = "ORI   ";  end
            16: begin  `load_memories_m(`TEST_ANDI  );  current_test_string = "ANDI  ";  end
            17: begin  `load_memories_m(`TEST_SLLI  );  current_test_string = "SLLI  ";  end
            18: begin  `load_memories_m(`TEST_SRLI  );  current_test_string = "SRLI  ";  end
            19: begin  `load_memories_m(`TEST_SRAI  );  current_test_string = "SRAI  ";  end
            20: begin  `load_memories_m(`TEST_LB    );  current_test_string = "LB    ";  end
            21: begin  `load_memories_m(`TEST_LH    );  current_test_string = "LH    ";  end
            22: begin  `load_memories_m(`TEST_LW    );  current_test_string = "LW    ";  end
            23: begin  `load_memories_m(`TEST_LBU   );  current_test_string = "LBU   ";  end
            24: begin  `load_memories_m(`TEST_LHU   );  current_test_string = "LHU   ";  end
            25: begin  `load_memories_m(`TEST_SB    );  current_test_string = "SB    ";  end
            26: begin  `load_memories_m(`TEST_SH    );  current_test_string = "SH    ";  end
            27: begin  `load_memories_m(`TEST_SW    );  current_test_string = "SW    ";  end
            28: begin  `load_memories_m(`TEST_BEQ   );  current_test_string = "BEQ   ";  end
            29: begin  `load_memories_m(`TEST_BNE   );  current_test_string = "BNE   ";  end
            30: begin  `load_memories_m(`TEST_BLT   );  current_test_string = "BLT   ";  end
            31: begin  `load_memories_m(`TEST_BGE   );  current_test_string = "BGE   ";  end
            32: begin  `load_memories_m(`TEST_BLTU  );  current_test_string = "BLTU  ";  end
            33: begin  `load_memories_m(`TEST_BGEU  );  current_test_string = "BGEU  ";  end
            34: begin  `load_memories_m(`TEST_JALR  );  current_test_string = "JALR  ";  end
            35: begin  `load_memories_m(`TEST_JAL   );  current_test_string = "JAL   ";  end
            36: begin  `load_memories_m(`TEST_LUI   );  current_test_string = "LUI   ";  end
            37: begin  `load_memories_m(`TEST_AUIPC );  current_test_string = "AUIPC ";  end
        endcase
    end
endtask

task print_test_status;
    input test_run_success;
    begin
        $display("\n----------------------- Test results -----------------------");
        if (!test_run_success) begin
            $display("\nTest timed out");
        end
        else begin 
            $display("\nTest ran to completion");
`ifdef STANDALONE      
            $display("\nStatus - DUT-ISA: ");
            if(isa_passed_dut == 1) begin
                $display("    Passed");
            end
            else begin
                $display("    Failed");
                $display("    Failed test # : %0d", `DUT_CORE.tohost[31:1]);
            end
`else // compare against vectors
            $display("\nStatus - DUT-Model:");
            if(!errors)
                $display("    Passed");
            else
                $display("    Failed");
`endif            
            // $display("    Pre RST Warnings: %2d", pre_rst_warnings);
            $display("    Warnings: %2d", warnings - pre_rst_warnings);
            $display("    Errors:   %2d", errors);
            
//            if(`VERBOSITY >= 2) begin
//                $display("\n\n------------------------ HW Performance --------------------------\n");
//                $display("Cycle counter: %0d", mmio_cycle_cnt);
//                $display("Instr counter: %0d", mmio_instr_cnt);
//                $display("Empty cycles:  %0d", mmio_cycle_cnt - mmio_instr_cnt);
//                $display("          CPI: %0.3f", real(mmio_cycle_cnt)/real(mmio_instr_cnt));
//                $display("  HW only CPI: %0.3f", real(mmio_cycle_cnt - (hw_all_nop_or_clear_cnt - hw_inserted_nop_or_clear_cnt))/real(mmio_instr_cnt));
//                $display("\nHW Inserted NOPs and Clears: %0d", hw_inserted_nop_or_clear_cnt);
//                $display(  "All NOPs and Clears:         %0d", hw_all_nop_or_clear_cnt);
//                $display(  "Compiler Inserted NOPs:      %0d", hw_all_nop_or_clear_cnt - hw_inserted_nop_or_clear_cnt);
//            end
        end
        $display("\n--------------------- End of the test results ----------------------\n");
    end
endtask

// task print_perf_status_hw;
//     begin
//         $display("\n\n--------------------- Regression Performace stats ------------------------\n");
//         $display("Cycle counter: %0d", perf_cnt_cycle);
//         $display("Instr counter: %0d", perf_cnt_instr);
//         $display("Empty cycles:  %0d", perf_cnt_empty_cycles);
//         $display("          CPI: %0.3f", real(perf_cnt_cycle)/real(perf_cnt_instr));
//         $display("  HW only CPI: %0.3f", real(perf_cnt_cycle - perf_cnt_compiler_nops)/real(perf_cnt_instr));
//         $display("\nHW Inserted NOPs and Clears: %0d", perf_cnt_hw_nops);
//         $display(  "All NOPs and Clears:         %0d", perf_cnt_all_nops);
//         $display(  "Compiler Inserted NOPs:      %0d", perf_cnt_compiler_nops);
//         $display("\n--------------------- End of the regression performance stats ----------------------\n");
//     end
// endtask

task print_regr_status;
    integer cnt;
    begin
        $display("\n\n------------------------- Regression PASS/FAIL status ----------------------------\n");
        
        $display("DUT regr status:   %0s", dut_regr_status   ? "Passed" : "Failed");
        if(!dut_regr_status) begin
            for(cnt = 0; cnt < isa_failed_dut_cnt; cnt = cnt + 1)
                $display("    DUT failed test #%0d, %0s", cnt, dut_regr_array[cnt]);
        end

        $display("\n-------------------- End of the Regression status ----------------------\n");
    end
endtask

// task store_perf_counters;
//     begin
//         perf_cnt_cycle          = perf_cnt_cycle + mmio_cycle_cnt;
//         perf_cnt_instr          = perf_cnt_instr + mmio_instr_cnt;
//         
//         perf_cnt_empty_cycles   = perf_cnt_empty_cycles + (mmio_cycle_cnt - mmio_instr_cnt);
//         
//         perf_cnt_all_nops       = perf_cnt_all_nops + hw_all_nop_or_clear_cnt;
//         perf_cnt_hw_nops        = perf_cnt_hw_nops + hw_inserted_nop_or_clear_cnt;
//         perf_cnt_compiler_nops  = perf_cnt_compiler_nops + (hw_all_nop_or_clear_cnt - hw_inserted_nop_or_clear_cnt);
//         
//     end
// endtask

// task print_single_instruction_results;
//     integer last_pc;
//     reg     stalled;
//     begin
//         if(`VERBOSITY >= 3) begin
//             stalled = (last_pc == dut_m_pc);
//             $display("Instruction at PC# %2d, 0x%4h,  %s ", dut_m_pc, dut_m_pc, stalled ? "stalled " : "executed"); 
//             $display("ID  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_id , dut_m_inst_id_asm );
//             $display("EX  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_ex , dut_m_inst_ex_asm );
//             $display("MEM stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_mem, dut_m_inst_mem_asm);
//             last_pc = dut_m_pc;
//         end
//     end
// endtask

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

// task run_checkers;
//     integer checker_errors_prev;
//     begin
//         checker_errors_prev = errors;
// 
//         // Datapath        
//         // IF_stage
//         checker_t("pc",                 `CHECKER_ACTIVE,    `DUT_CORE.pc,                    dut_m_pc                );
//         checker_t("pc_mux_out",         `CHECKER_ACTIVE,    `DUT_CORE.pc_mux_out,            dut_m_pc_mux_out        );
//         // ID_Stage 
//         checker_t("inst_id",            `CHECKER_ACTIVE,    `DUT_CORE.inst_id,               dut_m_inst_id           );
//         checker_t("rs1_data_id",        `CHECKER_ACTIVE,    `DUT_CORE.rs1_data_id,           dut_m_rs1_data_id       );
//         checker_t("rs2_data_id",        `CHECKER_ACTIVE,    `DUT_CORE.rs2_data_id,           dut_m_rs2_data_id       );
//         checker_t("imm_gen_out_id",     `CHECKER_ACTIVE,    `DUT_CORE.imm_gen_out_id,        dut_m_imm_gen_out_id    );
//         checker_t("clear_id",           `CHECKER_ACTIVE,    `DUT_CORE.clear_id,              dut_m_clear_id          );
//         // EX_Stage 
//         checker_t("inst_ex",            `CHECKER_ACTIVE,    `DUT_CORE.inst_ex,               dut_m_inst_ex           );
//         checker_t("pc_ex",              `CHECKER_ACTIVE,    `DUT_CORE.pc_ex,                 dut_m_pc_ex             );
//         checker_t("rs1_data_ex",        `CHECKER_ACTIVE,    `DUT_CORE.rs1_data_ex,           dut_m_rs1_data_ex       );
//         checker_t("rs2_data_ex",        `CHECKER_ACTIVE,    `DUT_CORE.rs2_data_ex,           dut_m_rs2_data_ex       );
//         checker_t("imm_gen_out_ex",     `CHECKER_ACTIVE,    `DUT_CORE.imm_gen_out_ex,        dut_m_imm_gen_out_ex    );
//         checker_t("rd_addr_ex",         `CHECKER_ACTIVE,    `DUT_CORE.rd_addr_ex,            dut_m_rd_addr_ex        );
//         checker_t("reg_we_ex",          `CHECKER_ACTIVE,    `DUT_CORE.reg_we_ex,             dut_m_reg_we_ex         );
//             
//         checker_t("bc_a_eq_b",          `CHECKER_ACTIVE,    `DUT_CORE.bc_out_a_eq_b,         dut_m_bc_a_eq_b         );
//         checker_t("bc_a_lt_b",          `CHECKER_ACTIVE,    `DUT_CORE.bc_out_a_lt_b,         dut_m_bc_a_lt_b         );
//         checker_t("alu_out",            `CHECKER_ACTIVE,    `DUT_CORE.alu_out,               dut_m_alu_out           );
//             
//         checker_t("clear_ex",           `CHECKER_ACTIVE,    `DUT_CORE.clear_ex,              dut_m_clear_ex          );
//             
//         checker_t("dmem_addr",          `CHECKER_ACTIVE,    `DUT_CORE.dmem_addr,             dut_m_dmem_addr         );
//         checker_t("dmem_write_data",    `CHECKER_ACTIVE,    `DUT_CORE.dmem_write_data,       dut_m_dmem_write_data   );
//         
//         // MEM_Stage
//         checker_t("dmem_read_data_mem", `CHECKER_ACTIVE,    `DUT_CORE.dmem_read_data_mem,    dut_m_dmem_read_data_mem);
//         checker_t("writeback",          `CHECKER_ACTIVE,    `DUT_CORE.writeback,             dut_m_writeback         );        
//         
//         
//         // Decoder
//         checker_t("pc_sel",             `CHECKER_ACTIVE,    `DUT_CORE.pc_sel_if,             dut_m_pc_sel_if         );
//         checker_t("pc_we",              `CHECKER_ACTIVE,    `DUT_CORE.pc_we_if,              dut_m_pc_we_if          );
//         checker_t("branch_inst_id",     `CHECKER_ACTIVE,    `DUT_CORE.branch_inst_id,        dut_m_branch_inst_id    );
//         checker_t("jump_inst_id",       `CHECKER_ACTIVE,    `DUT_CORE.jump_inst_id,          dut_m_jump_inst_id      );
//         checker_t("store_inst_id",      `CHECKER_ACTIVE,    `DUT_CORE.store_inst_id,         dut_m_store_inst_id     );
//         checker_t("alu_op_sel",         `CHECKER_ACTIVE,    `DUT_CORE.alu_op_sel_id,         dut_m_alu_op_sel_id     );
//         checker_t("imm_gen_sel",        `CHECKER_ACTIVE,    `DUT_CORE.imm_gen_sel_id,        dut_m_imm_gen_sel_id    );
//         checker_t("bc_uns",             `CHECKER_ACTIVE,    `DUT_CORE.bc_uns_id,             dut_m_bc_uns_id         );
//         checker_t("dmem_en",            `CHECKER_ACTIVE,    `DUT_CORE.dmem_en_id,            dut_m_dmem_en_id        );
//         checker_t("dmem_en_mmio",            `CHECKER_ACTIVE,    `DUT_CORE.dmem_en,            dut_m_dmem_en_ex        );
//         checker_t("load_sm_en",         `CHECKER_ACTIVE,    `DUT_CORE.load_sm_en_id,         dut_m_load_sm_en_id     );
//         checker_t("wb_sel",             `CHECKER_ACTIVE,    `DUT_CORE.wb_sel_id,             dut_m_wb_sel_id         );
//         checker_t("reg_we_id",          `CHECKER_ACTIVE,    `DUT_CORE.reg_we_id,             dut_m_reg_we_id         );
//         checker_t("alu_a_sel_fwd",      `CHECKER_ACTIVE,    `DUT_CORE.alu_a_sel_fwd_id,      dut_m_alu_a_sel_fwd_id  );
//         checker_t("alu_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT_CORE.alu_b_sel_fwd_id,      dut_m_alu_b_sel_fwd_id  );
//         checker_t("bc_a_sel_fwd",       `CHECKER_ACTIVE,    `DUT_CORE.bc_a_sel_fwd_id,       dut_m_bc_a_sel_fwd_id   );
//         checker_t("bcs_b_sel_fwd",      `CHECKER_ACTIVE,    `DUT_CORE.bcs_b_sel_fwd_id,      dut_m_bcs_b_sel_fwd_id  );
//         checker_t("rf_a_sel_fwd",       `CHECKER_ACTIVE,    `DUT_CORE.rf_a_sel_fwd_id,       dut_m_rf_a_sel_fwd_id   );
//         checker_t("rf_b_sel_fwd",       `CHECKER_ACTIVE,    `DUT_CORE.rf_b_sel_fwd_id,       dut_m_rf_b_sel_fwd_id   );
//         checker_t("dmem_we",            `CHECKER_ACTIVE,    `DUT_CORE.dmem_we_ex,            dut_m_dmem_we_ex        );
//         checker_t("dmem_we_mmio",            `CHECKER_ACTIVE,    `DUT_CORE.dmem_we,            dut_m_dmem_we_ex        );
//         // in ex stage
//         checker_t("load_inst_ex",       `CHECKER_ACTIVE,    `DUT_CORE.load_inst_ex,          dut_m_load_inst_ex      );
//         // internal 
//         checker_t("branch_taken",       `CHECKER_ACTIVE,    dut_internal_branch_taken,  dut_m_branch_taken      );
//         
//         // RF
//         checker_t("x0_zero",            `CHECKER_ACTIVE,    `DUT_RF.x0_zero,            dut_m_x0_zero           );
//         checker_t("x1_ra  ",            `CHECKER_ACTIVE,    `DUT_RF.x1_ra  ,            dut_m_x1_ra             );
//         checker_t("x2_sp  ",            `CHECKER_ACTIVE,    `DUT_RF.x2_sp  ,            dut_m_x2_sp             );
//         checker_t("x3_gp  ",            `CHECKER_ACTIVE,    `DUT_RF.x3_gp  ,            dut_m_x3_gp             );
//         checker_t("x4_tp  ",            `CHECKER_ACTIVE,    `DUT_RF.x4_tp  ,            dut_m_x4_tp             );
//         checker_t("x5_t0  ",            `CHECKER_ACTIVE,    `DUT_RF.x5_t0  ,            dut_m_x5_t0             );
//         checker_t("x6_t1  ",            `CHECKER_ACTIVE,    `DUT_RF.x6_t1  ,            dut_m_x6_t1             );
//         checker_t("x7_t2  ",            `CHECKER_ACTIVE,    `DUT_RF.x7_t2  ,            dut_m_x7_t2             );
//         checker_t("x8_s0  ",            `CHECKER_ACTIVE,    `DUT_RF.x8_s0  ,            dut_m_x8_s0             );
//         checker_t("x9_s1  ",            `CHECKER_ACTIVE,    `DUT_RF.x9_s1  ,            dut_m_x9_s1             );
//         checker_t("x10_a0 ",            `CHECKER_ACTIVE,    `DUT_RF.x10_a0 ,            dut_m_x10_a0            );
//         checker_t("x11_a1 ",            `CHECKER_ACTIVE,    `DUT_RF.x11_a1 ,            dut_m_x11_a1            );
//         checker_t("x12_a2 ",            `CHECKER_ACTIVE,    `DUT_RF.x12_a2 ,            dut_m_x12_a2            );
//         checker_t("x13_a3 ",            `CHECKER_ACTIVE,    `DUT_RF.x13_a3 ,            dut_m_x13_a3            );
//         checker_t("x14_a4 ",            `CHECKER_ACTIVE,    `DUT_RF.x14_a4 ,            dut_m_x14_a4            );
//         checker_t("x15_a5 ",            `CHECKER_ACTIVE,    `DUT_RF.x15_a5 ,            dut_m_x15_a5            );
//         checker_t("x16_a6 ",            `CHECKER_ACTIVE,    `DUT_RF.x16_a6 ,            dut_m_x16_a6            );
//         checker_t("x17_a7 ",            `CHECKER_ACTIVE,    `DUT_RF.x17_a7 ,            dut_m_x17_a7            );
//         checker_t("x18_s2 ",            `CHECKER_ACTIVE,    `DUT_RF.x18_s2 ,            dut_m_x18_s2            );
//         checker_t("x19_s3 ",            `CHECKER_ACTIVE,    `DUT_RF.x19_s3 ,            dut_m_x19_s3            );
//         checker_t("x20_s4 ",            `CHECKER_ACTIVE,    `DUT_RF.x20_s4 ,            dut_m_x20_s4            );
//         checker_t("x21_s5 ",            `CHECKER_ACTIVE,    `DUT_RF.x21_s5 ,            dut_m_x21_s5            );
//         checker_t("x22_s6 ",            `CHECKER_ACTIVE,    `DUT_RF.x22_s6 ,            dut_m_x22_s6            );
//         checker_t("x23_s7 ",            `CHECKER_ACTIVE,    `DUT_RF.x23_s7 ,            dut_m_x23_s7            );
//         checker_t("x24_s8 ",            `CHECKER_ACTIVE,    `DUT_RF.x24_s8 ,            dut_m_x24_s8            );
//         checker_t("x25_s9 ",            `CHECKER_ACTIVE,    `DUT_RF.x25_s9 ,            dut_m_x25_s9            );
//         checker_t("x26_s10",            `CHECKER_ACTIVE,    `DUT_RF.x26_s10,            dut_m_x26_s10           );
//         checker_t("x27_s11",            `CHECKER_ACTIVE,    `DUT_RF.x27_s11,            dut_m_x27_s11           );
//         checker_t("x28_t3 ",            `CHECKER_ACTIVE,    `DUT_RF.x28_t3 ,            dut_m_x28_t3            );
//         checker_t("x29_t4 ",            `CHECKER_ACTIVE,    `DUT_RF.x29_t4 ,            dut_m_x29_t4            );
//         checker_t("x30_t5 ",            `CHECKER_ACTIVE,    `DUT_RF.x30_t5 ,            dut_m_x30_t5            );
//         checker_t("x31_t6 ",            `CHECKER_ACTIVE,    `DUT_RF.x31_t6 ,            dut_m_x31_t6            );
//         
//         checker_t("tohost",             `CHECKER_ACTIVE,    `DUT_CORE.tohost,                dut_m_tohost            );
//         
//         errors_for_wave = (errors != checker_errors_prev);
// 
//     end // main task body */
// endtask // run_checkers

task reset_tb_vars;
    begin
        rst_done            = 0;
        errors              = 0;
        errors_for_wave     = 1'b0;
        warnings            = 0;
        done                = 0;
        isa_passed_dut      = 0;
    end
endtask

//-----------------------------------------------------------------------------
// Reset
// initial begin
//     // sync this thread with events from main thread
//     // each time new test is loaded
//     repeat(regr_num) begin
//         @(ev_rst[0]); // #1;
//         // $display("\nReset Sequence start \n");    
//         rst = 1'b0;
// //        dut_m_rst = 1'b0;
//         
//         @(ev_rst[0]); // @(posedge clk); #1;
//         
//         rst = 1'b1;
// //        dut_m_rst = 1'b1;
//         repeat (rst_pulses) begin
//             @(ev_rst[0]); //@(posedge clk); #1;          
//         end
//         rst = 1'b0;
// //        dut_m_rst = 1'b0;
//         // @(ev_rst[0]); //@(posedge clk); #1;  
//         // ->ev_rst_done;
//         // $display("\nReset Sequence end \n");
//         rst_done = 1;
//     end
// end

//-----------------------------------------------------------------------------
// Config

integer fd;
initial begin
    fd = $fopen({`LOG_PATH, `"log.txt`"}, "w");
    if (fd) $display("File opened: %0d", fd);
    else $display("File could not be opened: %0d", fd);
end

integer lclk_cnt = 0;

initial begin
    forever begin
        @(posedge clk);
        #1;
        lclk_cnt = lclk_cnt + 1;
        $fwrite(fd, "clk: ");
        $fwrite(fd, "%0d", lclk_cnt);
        $fwrite(fd, "; Inst WB: ");
        $fdisplay(fd, "%8x", `DUT_CORE.inst_wb );
    end
end

// Initial setup
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
//    perf_cnt_cycle         = 0;
//    perf_cnt_instr         = 0;
//    perf_cnt_empty_cycles  = 0;
//    perf_cnt_all_nops      = 0;
//    perf_cnt_hw_nops       = 0;
//    perf_cnt_compiler_nops = 0;
    dut_regr_status        = 1'b1; 
    isa_failed_dut_cnt     = 0;     
    reset_tb_vars();
    for (i = 0; i < `NUMBER_OF_TESTS; i = i + 1) begin
        dut_regr_array[i] = "N/A";
    end
    i = 0;
end

// Timestamp print
// initial begin
//     forever begin
//         $display("\n\n\n --- Sim time : %0t ---\n", $time);
//         @(posedge clk);
//     end
// end

// initial begin
//     forever begin
//         // wait for reset done, reset handled in rst thread
//         while (!rst_done) begin
//             @(posedge clk);
//             if(rst_done) dut_m_update();    // handle first case when going out of reset
//         end
// 
//         // run model at every clk
//         while (rst_done) begin
//             @(posedge clk); 
//             dut_m_update();
//         end
//     end
// end

assign tohost_source = `DUT_CORE.tohost[0];

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n----------------------- Simulation started -----------------------\n");
    
    while(i < regr_num) begin
        if (regr_num == 1) load_single_test();
        else load_test(i);

        i = i + 1;
    
        // Test 0: Wait for reset
        // $display("\n Resetting DUT... \n");
//         @(posedge clk); #1;
//         while (!rst_done) begin
//             // $display("Reset not done, time: %0t \n", $time);
//              ->ev_rst[0]; #1;
//             
//             // if still not done, wait for next clk else exit
//             if(!rst_done) begin 
//                 @(posedge clk); #1; 
// //                dut_m_update();
//             end
//         end
        //$display("Reset done, time: %0t \n", $time);
//        while (!rst_done) @(posedge clk);
//        pre_rst_warnings = warnings;
        
        //-----------------------------------------------------------------------------
        // Test
        $display("\n\n\nTest Start: %0s ", current_test_string);

        // catch timeout
        fork
            begin
                while (tohost_source !== 1'b1) begin
                    @(posedge clk);
                    // #`CHECK_D; run_checkers();
                    //print_single_instruction_results();
                end
                done = 1;
            end
            begin
                repeat(`TIMEOUT_CLOCKS) begin
                    if (!done) @(posedge clk);
                end
                if (!done) begin    // timed-out
                    print_test_status(done);
                    $finish();
                end
            end
        join
        
        // DUT passed ISA?
        if (`DUT_CORE.tohost === `TOHOST_PASS) begin
            isa_passed_dut = 1;
        end
        else begin
            isa_passed_dut = 0;
            dut_regr_array[isa_failed_dut_cnt] = current_test_string;
            isa_failed_dut_cnt = isa_failed_dut_cnt + 1;
        end
        
        // store regr flags
        dut_regr_status = dut_regr_status && isa_passed_dut  ;

        repeat (6) begin 
            @(posedge clk);
//            #`CHECK_D; run_checkers();
//            print_single_instruction_results();
        end

        print_test_status(done);

        $display("Test Done: %0s ", current_test_string); 
        
//        store_perf_counters();
        
        reset_tb_vars();
        
    end // end looping thru tests
    
    if (`SINGLE_TEST == 0) begin
        $display("\n-------------------------- Regr Done -----------------------------\n");
        print_regr_status();
        // CPI print
//        print_perf_status_hw();
    end
    else begin
        $display("\n-------------------------- Test Done -----------------------------\n");
    end
    
    $display("\n--------------------- End of the simulation ----------------------\n");
    $finish();
    
end // test

endmodule

