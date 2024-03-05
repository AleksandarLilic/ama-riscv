`timescale 1ns/1ps

`include "ama_riscv_defines.v"
`include "ama_riscv_perf.svh"

import "DPI-C" function void emu_setup(string test_bin, int unsigned base_address);
import "DPI-C" function void emu_exec();
import "DPI-C" function void emu_dump();

`define CLK_PERIOD 8
//`define STANDALONE

// TODO: keep up to 5 verbosity levels, add list of choices?, dbg & perf levels?
`define VERBOSITY 2           
`define LOG_MINIMAL
`define DELIM "-----------------------"

// TB
//`define CHECKER_ACTIVE 1'b1
//`define CHECKER_INACTIVE 1'b0
//`define CHECK_DELAY 1
`define TIMEOUT_CLOCKS 5_000_000 // TODO: make it a plus arg parameter

`ifdef LOG_MINIMAL
    `define LOG(x) 
`else
    `define LOG(x) $display("%0s", $sformatf x )
`endif

`define SINGLE_TEST 1
`define CORE_ONLY

`ifdef CORE_ONLY
    `define DUT DUT_ama_riscv_core_i
    `define DUT_IMEM imem_tb.mem
    `define DUT_DMEM dmem_tb.mem
    `define DUT_CORE `DUT
`else // CORE_TOP
    `define DUT DUT_ama_riscv_core_top_i
    `define DUT_IMEM `DUT.ama_riscv_imem_i.mem
    `define DUT_DMEM `DUT.ama_riscv_dmem_i.mem
    `define DUT_CORE `DUT.ama_riscv_core_i
`endif

`define DUT_DEC `DUT_CORE.ama_riscv_control_i.ama_riscv_decoder_i
`define DUT_RF `DUT_CORE.ama_riscv_reg_file_i

`define TOHOST_PASS 32'd1

`define MEM_SIZE 16384

module ama_riscv_core_top_tb();

//------------------------------------------------------------------------------
// Testbench variables
string test_path;

// Test names
string riscv_regr_tests[] = {
    "simple", "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or",
    "and", "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli",
    "srai", "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw", "beq", "bne",
    "blt", "bge", "bltu", "bgeu", "jalr", "jal", "lui", "auipc" };

int number_of_tests = riscv_regr_tests.size; 
int regr_num;

integer i; // used for all loops
integer done;
integer isa_passed_dut;
integer errors;
integer warnings;
wire tohost_source;

// events
event ev_rst [1:0];
event ev_load_stim;
event ev_load_vector;
event ev_load_vector_done;
event go_in_reset;
event reset_end;
int rst_pulses = 1;

//------------------------------------------------------------------------------
// DUT I/O
reg clk = 0;
reg rst;
//wire mmio_instr_cnt;
//wire mmio_cycle_cnt;
wire inst_wb_nop_or_clear;
wire mmio_reset_cnt;

//------------------------------------------------------------------------------
// DUT internals for checkers only
//wire dut_internal_branch_taken = `DUT_DEC.branch_res && `DUT_DEC.branch_inst_ex;

//------------------------------------------------------------------------------
// DUT instance
`ifdef CORE_ONLY
    // IMEM
    wire [31:0] inst_id_read;
    wire [13:0] imem_addr;
    // DMEM
    wire [31:0] dmem_write_data;
    wire [13:0] dmem_addr;
    wire        dmem_en;
    wire [ 3:0] dmem_we;
    wire [31:0] dmem_read_data_mem;

    // core
    ama_riscv_core DUT_ama_riscv_core_i(
        .clk                (clk               ),
        .rst                (rst               ),
        // mem in
        .inst_id_read       (inst_id_read      ),
        .dmem_read_data_mem (dmem_read_data_mem),
        // mem out
        .imem_addr          (imem_addr         ),
        .dmem_write_data    (dmem_write_data   ),
        .dmem_addr          (dmem_addr         ),
        .dmem_en            (dmem_en           ),
        .dmem_we            (dmem_we           )
        // mmio in   
        //.mmio_instr_cnt         (mmio_instr_cnt         ),
        //.mmio_cycle_cnt         (mmio_cycle_cnt         )
        //.mmio_uart_data_out     (mmio_uart_data_out     ),
        //.mmio_data_out_valid    (mmio_data_out_valid    ),
        //.mmio_data_in_ready     (mmio_data_in_ready     ),
        //// mmio out
        //.store_to_uart          (store_to_uart          ),
        //.load_from_uart         (load_from_uart         ),
        //.inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
        //.mmio_reset_cnt         (mmio_reset_cnt         ),
        //.mmio_uart_data_in      (mmio_uart_data_in      )
    );
    // IMEM
    ama_riscv_imem imem_tb (
        .clk   (clk         ),
        .addrb (imem_addr   ),
        .doutb (inst_id_read)
    );
    // DMEM
    ama_riscv_dmem dmem_tb (
        .clk    (clk                ),
        .en     (dmem_en            ),
        .we     (dmem_we            ),
        .addr   (dmem_addr          ),
        .din    (dmem_write_data    ),
        .dout   (dmem_read_data_mem )
    );
`else
    ama_riscv_core_top DUT_ama_riscv_core_top_i (
        .clk    (clk    ),
        .rst    (rst    ),
        // outputs
        .inst_wb_nop_or_clear   (inst_wb_nop_or_clear   ),
        .mmio_reset_cnt         (mmio_reset_cnt         )
    );
`endif

//------------------------------------------------------------------------------
// Testbench tasks
task load_memories;
    input string test_hex_path;
    integer fd;
    begin
        fd = $fopen(test_hex_path, "r");
        if (fd == 0) begin
            $display("Error: Could not open file %0s", test_hex_path);
            $finish();
        end
        $fclose(fd);
        $readmemh(test_hex_path, `DUT_IMEM, 0, `MEM_SIZE-1);
        $readmemh(test_hex_path, `DUT_DMEM, 0, `MEM_SIZE-1);
    end
endtask

task print_test_status;
    input test_run_success;
    begin
        if (!test_run_success) begin
            $display("Test timed out");
        end else begin 
            $display("Test ran to completion");
            $display("Warnings: %2d", warnings);
            $display("Errors:   %2d", errors);
            
            if (isa_passed_dut == 1) begin 
                $display("==== PASS ====");
            end else begin
                $display("==== FAIL ====");
                $display("Failed test # : %0d", `DUT_CORE.tohost[31:1]);
            end
        end
    end
endtask

task finish_sim;
    begin
        $display($sformatf("%0s End of the simulation %0s", `DELIM, `DELIM));
        $finish();
    end
endtask


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

//task checker_t;
//    input string checker_name;
//    input reg checker_active;
//    // input reg  [ 5:0]   checker_width           ;
//    input reg  [31:0]   checker_dut_signal      ;
//    input reg  [31:0]   checker_model_signal    ;
//    
//    begin
//        if (checker_active == 1) begin
//            if (checker_dut_signal !== checker_model_signal) begin
//                $display("*ERROR @ %0t. Checker: \"%0s\"; DUT: %0d, Model: %0d ", 
//                    $time-`CHECK_DELAY, checker_name, checker_dut_signal, checker_model_signal);
//                errors = errors + 1;
//            end // checker compare
//        end // checker valid
//    end
//endtask

//`ifndef STANDALONE
//    `include "checkers_task.sv"
//`endif

//------------------------------------------------------------------------------
// Config

// Log to file
// integer lclk_cnt = 0;
// initial begin
//     forever begin
//         @(posedge clk);
//         #1;
//         lclk_cnt = lclk_cnt + 1;
//         $fwrite(fd, "clk: ");
//         $fwrite(fd, "%0d", lclk_cnt);
//         $fwrite(fd, "; Inst WB: ");
//         $fdisplay(fd, "%8x", `DUT_CORE.inst_wb );
//     end
// end

always #(`CLK_PERIOD/2) clk = ~clk;

initial begin
    // set %t scaled in ns (-9), with 2 precision digits, with the " ns" string
    $timeformat(-9, 2, " ns", 20);
    errors = 0;
    warnings = 0;
    done = 0;
    isa_passed_dut = 0;
    i = 0;
end

// initial begin
//     forever begin
//         $display("\n\n\n --- Sim time : %0t ---\n", $time);
//         @(posedge clk);
//     end
// end

initial begin
    forever begin
        @go_in_reset;
        #1;
        rst = 1;
        repeat (rst_pulses) begin
            @(posedge clk); 
            #1;
        end
        rst = 0;
        ->reset_end;
    end
end

//------------------------------------------------------------------------------
// Test
assign tohost_source = `DUT_CORE.tohost[0];
perf_stats stats;
initial begin
    if (! $value$plusargs("test_path=%s", test_path)) begin
        $error("test_path not defined. Exiting.");
        $finish();
    end
    stats = new();

    $display($sformatf("%0s Simulation started %0s", `DELIM, `DELIM));
    load_memories({test_path,".hex"});
    emu_setup({test_path,".bin"}, `RESET_VECTOR);

    ->go_in_reset;
    @reset_end;

    fork
    begin
        while (tohost_source !== 1'b1) begin
            @(posedge clk); #1;
            stats.update(`DUT_CORE.inst_wb, `DUT_CORE.stall_id_seq[2]);
            if (`DUT_CORE.inst_wb_nop_or_clear == 1'b0) emu_exec();
            //run_checkers(); // check always, when inst is nop, arch state shouldn't
                              // changed, and it has to be confirmed in RTL
            
            //`ifndef STANDALONE
            //    if (rst == 0) run_checkers;
            //`endif
            //print_single_instruction_results();
        end
        done = 1;
    end
    begin
        repeat (`TIMEOUT_CLOCKS) begin
            if (!done) @(posedge clk);
        end
        if (!done) begin // timed-out
            print_test_status(done);
            finish_sim();
        end
    end
    join
    
    if (`DUT_CORE.tohost === `TOHOST_PASS) isa_passed_dut = 1;
    else isa_passed_dut = 0;
    
    print_test_status(done);
    stats.display();
    emu_dump();
    //stats.compare_dut(mmio_cycle_cnt, mmio_instr_cnt);
    finish_sim();
end // test

endmodule
