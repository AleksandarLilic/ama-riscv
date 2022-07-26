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
//      2022-07-22  AL 0.28.0 - Remove DUT to use TB with model only
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
`define SINGLE_TEST         0
`define TEST_NAME           add.hex

`define VERBOSITY           3           // TODO: keep up to 5, add list of choices?, dbg & perf levels?
`define NUMBER_OF_TESTS     38

// TB
`define CHECKER_ACTIVE      1'b0        // TODO: Consider moving checkers to different file
`define CHECKER_INACTIVE    1'b0
`define CHECK_D             1
`define TIMEOUT_CLOCKS      5000

//`define PROJECT_PATH        "C:/dev/ama-riscv/"
// /home/aleksandar/Documents/xilinx/ama-riscv/"
//`define INST_PATH           "verif/direct_tb/inst/"
`define INST_PATH           "/"
`define PROJECT_PATH "C:/dev/ama-riscv-sim/riscv-tests/riscv-isa-tests"

`define DUT                 DUT_ama_riscv_core_i
`define DUT_IMEM            DUT_ama_riscv_core_i.ama_riscv_imem_i.mem
`define DUT_DMEM            DUT_ama_riscv_core_i.ama_riscv_dmem_i.mem
`define DUT_DEC             DUT_ama_riscv_core_i.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF              DUT_ama_riscv_core_i.ama_riscv_reg_file_i

`define TOHOST_PASS         32'd1

`define MEM_SIZE            16384

// Macro functions
`define STRINGIFY(x)        `"x`"
// has to be enclosed with begin/end when called
`define load_memories_m(name)                                                          \
    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, dut_m_imem,   0, `MEM_SIZE-1);    \
    $readmemh({`PROJECT_PATH, `INST_PATH, `"name`"}, dut_m_dmem,   0, `MEM_SIZE-1);    \

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

module ama_riscv_core_tb();

//-----------------------------------------------------------------------------
// Model
`include "ama_riscv_core_dut_m.v"

//-----------------------------------------------------------------------------
// Signals

//-----------------------------------------------------------------------------
// DUT I/O
reg          clk = 0;

//-----------------------------------------------------------------------------
// Testbench variables
integer       i                     ;   // used for all loops
integer       done                  ;
integer       isa_passed_model      ;
wire          tohost_source         ;
integer       regr_num = (`SINGLE_TEST) ? 1 : `NUMBER_OF_TESTS;
// regr flags
reg           model_regr_status     ;
reg  [12*7:0] model_regr_array [`NUMBER_OF_TESTS-1:0];
integer       isa_failed_model_cnt  ;
// performance counters

// Reset hold for
reg    [ 3:0] rst_pulses = 4'd3;

// for printing current test name
reg [12*7:0]  current_test_string   ;

// events
event         ev_rst    [1:0];
integer       rst_done = 0;

//-----------------------------------------------------------------------------
// Clock gen: 125 MHz
always #(`CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Testbench tasks
task load_single_test;
    begin
        `load_memories_m(`TEST_NAME) current_test_string = `STRINGIFY(`TEST_NAME);
    end
endtask

task load_test;
    input integer t_in_test_num;
    begin
        case(t_in_test_num)
            0 : begin  `load_memories_m(`TEST_SIMPLE)  current_test_string = "SIMPLE";  end
            1 : begin  `load_memories_m(`TEST_ADD   )  current_test_string = "ADD   ";  end
            2 : begin  `load_memories_m(`TEST_SUB   )  current_test_string = "SUB   ";  end
            3 : begin  `load_memories_m(`TEST_SLL   )  current_test_string = "SLL   ";  end
            4 : begin  `load_memories_m(`TEST_SLT   )  current_test_string = "SLT   ";  end
            5 : begin  `load_memories_m(`TEST_SLTU  )  current_test_string = "SLTU  ";  end
            6 : begin  `load_memories_m(`TEST_XOR   )  current_test_string = "XOR   ";  end
            7 : begin  `load_memories_m(`TEST_SRL   )  current_test_string = "SRL   ";  end
            8 : begin  `load_memories_m(`TEST_SRA   )  current_test_string = "SRA   ";  end
            9 : begin  `load_memories_m(`TEST_OR    )  current_test_string = "OR    ";  end
            10: begin  `load_memories_m(`TEST_AND   )  current_test_string = "AND   ";  end
            11: begin  `load_memories_m(`TEST_ADDI  )  current_test_string = "ADDI  ";  end
            12: begin  `load_memories_m(`TEST_SLTI  )  current_test_string = "SLTI  ";  end
            13: begin  `load_memories_m(`TEST_SLTIU )  current_test_string = "SLTIU ";  end
            14: begin  `load_memories_m(`TEST_XORI  )  current_test_string = "XORI  ";  end
            15: begin  `load_memories_m(`TEST_ORI   )  current_test_string = "ORI   ";  end
            16: begin  `load_memories_m(`TEST_ANDI  )  current_test_string = "ANDI  ";  end
            17: begin  `load_memories_m(`TEST_SLLI  )  current_test_string = "SLLI  ";  end
            18: begin  `load_memories_m(`TEST_SRLI  )  current_test_string = "SRLI  ";  end
            19: begin  `load_memories_m(`TEST_SRAI  )  current_test_string = "SRAI  ";  end
            20: begin  `load_memories_m(`TEST_LB    )  current_test_string = "LB    ";  end
            21: begin  `load_memories_m(`TEST_LH    )  current_test_string = "LH    ";  end
            22: begin  `load_memories_m(`TEST_LW    )  current_test_string = "LW    ";  end
            23: begin  `load_memories_m(`TEST_LBU   )  current_test_string = "LBU   ";  end
            24: begin  `load_memories_m(`TEST_LHU   )  current_test_string = "LHU   ";  end
            25: begin  `load_memories_m(`TEST_SB    )  current_test_string = "SB    ";  end
            26: begin  `load_memories_m(`TEST_SH    )  current_test_string = "SH    ";  end
            27: begin  `load_memories_m(`TEST_SW    )  current_test_string = "SW    ";  end
            28: begin  `load_memories_m(`TEST_BEQ   )  current_test_string = "BEQ   ";  end
            29: begin  `load_memories_m(`TEST_BNE   )  current_test_string = "BNE   ";  end
            30: begin  `load_memories_m(`TEST_BLT   )  current_test_string = "BLT   ";  end
            31: begin  `load_memories_m(`TEST_BGE   )  current_test_string = "BGE   ";  end
            32: begin  `load_memories_m(`TEST_BLTU  )  current_test_string = "BLTU  ";  end
            33: begin  `load_memories_m(`TEST_BGEU  )  current_test_string = "BGEU  ";  end
            34: begin  `load_memories_m(`TEST_JALR  )  current_test_string = "JALR  ";  end
            35: begin  `load_memories_m(`TEST_JAL   )  current_test_string = "JAL   ";  end
            36: begin  `load_memories_m(`TEST_LUI   )  current_test_string = "LUI   ";  end
            37: begin  `load_memories_m(`TEST_AUIPC )  current_test_string = "AUIPC ";  end
        endcase
    end
endtask

task print_test_status;
    input test_run_success;
    begin
        $display("\n----------------------- Simulation results -----------------------");
        if (!test_run_success) begin
            $display("\nTest timed out");
        end
        else begin 
            $display("\nTest ran to completion");
            
            $display("\nStatus - Model-ISA: ");
            if(isa_passed_model == 1) begin
                $display("    Passed");
            end
            else begin
                $display("    Failed");
                $display("    Failed test # : %0d", dut_m_tohost[31:1]);
            end
            
            if(`VERBOSITY >= 2) begin
                $display("\n\n----------------------- Model Performance ------------------------\n");
                $display("Cycle counter: %0d", dut_m_cnt_cycle);
                $display("Instr counter: %0d", dut_m_cnt_instr);
                $display("Empty cycles:  %0d", dut_m_cnt_cycle - dut_m_cnt_instr);
                $display("          CPI: %0.3f", real(dut_m_cnt_cycle)/real(dut_m_cnt_instr));
                $display("  HW only CPI: %0.3f", real(dut_m_cnt_cycle - (dut_m_cnt_all_nop_or_clear - dut_m_cnt_hw_inserted_nop_or_clear))/real(dut_m_cnt_instr));
                $display("\nHW Inserted NOPs and Clears: %0d", dut_m_cnt_hw_inserted_nop_or_clear);
                $display(  "All NOPs and Clears:         %0d", dut_m_cnt_all_nop_or_clear);
                $display(  "Compiler Inserted NOPs:      %0d", dut_m_cnt_all_nop_or_clear - dut_m_cnt_hw_inserted_nop_or_clear);
            end
        end
        $display("\n--------------------- End of the simulation ----------------------\n");
    end
endtask

task print_perf_status_model;
    begin
        $display("\n\n-------------------- Model Performance regr ----------------------\n");
        $display("Cycle counter: %0d", dut_m_perf_cnt_cycle);
        $display("Instr counter: %0d", dut_m_perf_cnt_instr);
        $display("Empty cycles:  %0d", dut_m_perf_cnt_empty_cycles);
        $display("          CPI: %0.3f", real(dut_m_perf_cnt_cycle)/real(dut_m_perf_cnt_instr));
        $display("  HW only CPI: %0.3f", real(dut_m_perf_cnt_cycle - dut_m_perf_cnt_compiler_nops)/real(dut_m_perf_cnt_instr));
        $display("\nHW Inserted NOPs and Clears: %0d", dut_m_perf_cnt_hw_nops);
        $display(  "All NOPs and Clears:         %0d", dut_m_perf_cnt_all_nops);
        $display(  "Compiler Inserted NOPs:      %0d", dut_m_perf_cnt_compiler_nops);
        $display("\n--------------------- End of the simulation ----------------------\n");
    end
endtask

task print_regr_status;
    integer cnt;
    begin
        $display("\n\n------------------------- Regr status ----------------------------\n");
        
        $display("\nModel regr status: %0s", model_regr_status ? "Passed" : "Failed");
        if(!model_regr_status) begin
            for(cnt = 0; cnt < isa_failed_model_cnt; cnt = cnt + 1)
                $display("    Model failed test #%0d, %0s", cnt, model_regr_array[cnt]);
        end

        $display("\n-------------------- End of the Regr status ----------------------\n");
    end
endtask

task store_perf_counters;
    begin
        dut_m_perf_cnt_cycle          = dut_m_perf_cnt_cycle + dut_m_cnt_cycle;
        dut_m_perf_cnt_instr          = dut_m_perf_cnt_instr + dut_m_cnt_instr;
        
        dut_m_perf_cnt_empty_cycles   = dut_m_perf_cnt_empty_cycles + (dut_m_cnt_cycle - dut_m_cnt_instr);
        
        dut_m_perf_cnt_all_nops       = dut_m_perf_cnt_all_nops + dut_m_cnt_all_nop_or_clear;
        dut_m_perf_cnt_hw_nops        = dut_m_perf_cnt_hw_nops + dut_m_cnt_hw_inserted_nop_or_clear;
        dut_m_perf_cnt_compiler_nops  = dut_m_perf_cnt_compiler_nops + (dut_m_cnt_all_nop_or_clear - dut_m_cnt_hw_inserted_nop_or_clear);
        
    end
endtask

task print_single_instruction_results;
    integer last_pc;
    reg     stalled;
    begin
        if(`VERBOSITY >= 3) begin
            stalled = (last_pc == dut_m_pc);
            $display("Instruction at PC# %2d, 0x%4h,  %s ", dut_m_pc, dut_m_pc, stalled ? "stalled " : "executed"); 
            $display("ID  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_id , dut_m_inst_id_asm );
            $display("EX  stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_ex , dut_m_inst_ex_asm );
            $display("MEM stage: HEX: 'h%8h, ASM: %0s", dut_m_inst_mem, dut_m_inst_mem_asm);
            last_pc = dut_m_pc;
        end
    end
endtask

task reset_tb_vars;
    begin
        rst_done            = 0;
        done                = 0;
        isa_passed_model    = 0;
    end
endtask

task print_system_time;
    begin
        $system("echo %time%");
    end
endtask

//-----------------------------------------------------------------------------
// Reset
initial begin
    // sync this thread with events from main thread
    // each time new test is loaded
    repeat(regr_num) begin
        @(ev_rst[0]); // #1;
        // $display("\nReset Sequence start \n");    
        dut_m_rst = 1'b0;
        
        @(ev_rst[0]); // @(posedge clk); #1;
        
        dut_m_rst = 1'b1;
        repeat (rst_pulses) begin
            @(ev_rst[0]); //@(posedge clk); #1;          
        end
        dut_m_rst = 1'b0;
        // @(ev_rst[0]); //@(posedge clk); #1;  
        // ->ev_rst_done;
        // $display("\nReset Sequence end \n");
        rst_done = 1;
    end
end

//-----------------------------------------------------------------------------
// Config

// Initial setup
initial begin
    //Prints %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    i = 0;
    dut_m_perf_cnt_cycle         = 0;
    dut_m_perf_cnt_instr         = 0;
    dut_m_perf_cnt_empty_cycles  = 0;
    dut_m_perf_cnt_all_nops      = 0;
    dut_m_perf_cnt_hw_nops       = 0;
    dut_m_perf_cnt_compiler_nops = 0;
    model_regr_status      = 1'b1;
    isa_failed_model_cnt   = 0;
    reset_tb_vars();
end

// Timestamp print
// initial begin
//     forever begin
//         $display("\n\n\n --- Sim time : %0t ---\n", $time);
//         @(posedge clk);
//     end
// end

initial begin
    forever begin
        // wait for reset done, reset handled in rst thread
        while (!rst_done) begin
            @(posedge clk);
            if(rst_done) dut_m_update();    // handle first case when going out of reset
        end

        // run model at every clk
        while (rst_done) begin
            @(posedge clk); 
            dut_m_update();
        end
    end
end

// choose which tohost CSR to use for simulation end
assign tohost_source = dut_m_tohost[0];

//-----------------------------------------------------------------------------
// Test
initial begin
    $display("\n----------------------- Simulation started -----------------------\n");
    $display("Simulation time start:");
    print_system_time();

    while(i < regr_num) begin
        if (regr_num == 1) load_single_test();
        else load_test(i);

        i = i + 1;
    
        // Test 0: Wait for reset
        // $display("\n Resetting DUT... \n");
        @(posedge clk); #1;
        while (!rst_done) begin
            // $display("Reset not done, time: %0t \n", $time);
             ->ev_rst[0]; #1;
            
            // if still not done, wait for next clk else exit
            if(!rst_done) begin 
                @(posedge clk); #1; 
                dut_m_update();
            end
        end
        //$display("Reset done, time: %0t \n", $time);
        
        //-----------------------------------------------------------------------------
        // Test
        $display("\n\n\nTest Start: %0s ", current_test_string);

        // catch timeout
        fork
            begin
                while (tohost_source !== 1'b1) begin
                    @(posedge clk);
                    print_single_instruction_results();
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
        
        // Model passed ISA?
        if (dut_m_tohost === `TOHOST_PASS) begin
            isa_passed_model = 1;
        end
        else begin
            isa_passed_model = 0;
            model_regr_array[isa_failed_model_cnt] = current_test_string;
            isa_failed_model_cnt = isa_failed_model_cnt + 1;
        end

        // store regr flags
        model_regr_status   = model_regr_status && isa_passed_model;
        repeat (6) begin 
            @(posedge clk);
            print_single_instruction_results();
        end

        print_test_status(done);

        $display("Test Done: %0s ", current_test_string); 
        
        store_perf_counters();
        
        reset_tb_vars();
        
    end // end looping thru tests
    
    if (`SINGLE_TEST == 0) begin
        $display("\n-------------------------- Regr Done -----------------------------\n");
        print_regr_status();
        // CPI print
        print_perf_status_model();
    end
    else begin
        $display("\n-------------------------- Test Done -----------------------------\n");
    end
    
    $display("Simulation time end:");
    print_system_time();
    $finish();
    
end // test

endmodule

